import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/supabase_service.dart';

// Data layer for the seller analytics screen. Mirrors the loading and
// summarising helpers in src/pages/seller/Analytics.jsx: revenue is priced
// per order line (price_at_purchase * quantity) for THIS shop's pets,
// products and services only, so an order that mixes several shops is never
// double counted, and cancelled orders are excluded from revenue.

/// Date ranges offered on the analytics screen (RANGES in the web page).
enum AnalyticsRange {
  days7('7 days', days: 7),
  days30('30 days', days: 30),
  months12('12 months', months: 12),
  all('All time');

  const AnalyticsRange(this.label, {this.days, this.months});

  final String label;
  final int? days;
  final int? months;

  /// First moment of the range, or null for "all time".
  DateTime? get start {
    final now = DateTime.now();
    final dayCount = days;
    if (dayCount != null) return DateTime(now.year, now.month, now.day - (dayCount - 1));
    final monthCount = months;
    if (monthCount != null) return DateTime(now.year, now.month - (monthCount - 1), 1);
    return null;
  }
}

/// One order line belonging to the shop (a pet, product or service sold).
class AnalyticsLine {
  final String orderId;
  final String orderStatus;
  final DateTime createdAt;
  final String itemId;
  final String type; // pet | product | service
  final String label;
  final int quantity;
  final double amount;

  const AnalyticsLine({
    required this.orderId,
    required this.orderStatus,
    required this.createdAt,
    required this.itemId,
    required this.type,
    required this.label,
    required this.quantity,
    required this.amount,
  });
}

/// A demo request or service booking, reduced to what the funnel needs.
class AnalyticsEvent {
  final String status;
  final DateTime createdAt;
  const AnalyticsEvent({required this.status, required this.createdAt});
}

/// Everything fetched for one shop, before a date range is applied.
class ShopAnalyticsData {
  final int listingCount;
  final List<AnalyticsLine> lines;
  final List<AnalyticsEvent> demos;
  final List<AnalyticsEvent> bookings;

  const ShopAnalyticsData({
    required this.listingCount,
    required this.lines,
    required this.demos,
    required this.bookings,
  });
}

class AnalyticsTopItem {
  final String id;
  final String label;
  final String type;
  int units = 0;
  double revenue = 0;

  AnalyticsTopItem({required this.id, required this.label, required this.type});
}

class _OrderTotal {
  final DateTime createdAt;
  double total = 0;
  _OrderTotal(this.createdAt);
}

/// Everything the screen renders for one date range.
class AnalyticsSummary {
  final double revenue;
  final int orderCount;
  final double averageOrder;
  final int itemsSold;
  final List<({DateTime createdAt, num totalAmount})> chartOrders;
  final Map<String, int> statusCounts;
  final Map<String, double> revenueByType;
  final List<AnalyticsTopItem> topItems;
  final Map<String, int> demoCounts;
  final int demoTotal;
  final Map<String, int> bookingCounts;
  final int bookingTotal;

  const AnalyticsSummary({
    required this.revenue,
    required this.orderCount,
    required this.averageOrder,
    required this.itemsSold,
    required this.chartOrders,
    required this.statusCounts,
    required this.revenueByType,
    required this.topItems,
    required this.demoCounts,
    required this.demoTotal,
    required this.bookingCounts,
    required this.bookingTotal,
  });
}

const _pageSize = 1000;
const _idChunkSize = 100;

List<List<T>> _chunk<T>(List<T> list, int size) {
  final chunks = <List<T>>[];
  for (var i = 0; i < list.length; i += size) {
    chunks.add(list.sublist(i, i + size > list.length ? list.length : i + size));
  }
  return chunks;
}

/// Pages through a query past PostgREST's row cap so totals are never
/// silently truncated. Ordered by id so pages never overlap.
Future<List<Map<String, dynamic>>> _fetchAll(PostgrestFilterBuilder<PostgrestList> Function() buildQuery) async {
  final rows = <Map<String, dynamic>>[];
  for (var from = 0;; from += _pageSize) {
    final page = await buildQuery().order('id', ascending: true).range(from, from + _pageSize - 1);
    rows.addAll(page);
    if (page.length < _pageSize) return rows;
  }
}

String _petLabel(Map<String, dynamic> pet) {
  final breed = pet['breed'] as String? ?? '';
  final species = pet['species'] as String? ?? '';
  final name = (pet['name'] as String? ?? '').trim();
  final detail = breed.isNotEmpty ? '$breed ($species)' : species;
  return name.isNotEmpty ? '$name · $detail' : detail;
}

DateTime _parseDate(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Everything the page needs in a handful of requests: the shop's own listing
/// ids (to scope order_items), the matching order lines with their order, and
/// demo / booking rows.
Future<ShopAnalyticsData> loadShopAnalytics(String shopId) async {
  final client = SupabaseService.client;

  final results = await Future.wait<List<Map<String, dynamic>>>([
    _fetchAll(() => client.from('pets').select('id, name, breed, species').eq('shop_id', shopId)),
    _fetchAll(() => client.from('products').select('id, name').eq('shop_id', shopId)),
    _fetchAll(() => client.from('services').select('id, name').eq('shop_id', shopId)),
    _fetchAll(() => client.from('demo_requests').select('id, status, created_at').eq('shop_id', shopId)),
    _fetchAll(() => client.from('service_bookings').select('id, status, created_at').eq('shop_id', shopId)),
  ]);
  final pets = results[0];
  final products = results[1];
  final services = results[2];
  final demos = results[3];
  final bookings = results[4];

  // item id -> (type, label); ids are uuids so they never collide across tables.
  final listings = <String, ({String type, String label})>{};
  for (final pet in pets) {
    listings[pet['id'] as String] = (type: 'pet', label: _petLabel(pet));
  }
  for (final product in products) {
    listings[product['id'] as String] = (type: 'product', label: product['name'] as String? ?? 'Product');
  }
  for (final service in services) {
    listings[service['id'] as String] = (type: 'service', label: service['name'] as String? ?? 'Service');
  }

  final itemChunks = await Future.wait<List<Map<String, dynamic>>>([
    for (final ids in _chunk(listings.keys.toList(), _idChunkSize))
      _fetchAll(
        () => client
            .from('order_items')
            .select('id, item_id, quantity, price_at_purchase, orders(id, status, created_at, order_type)')
            .inFilter('item_id', ids),
      ),
  ]);

  final lines = <AnalyticsLine>[];
  for (final row in itemChunks.expand((chunk) => chunk)) {
    final rawOrder = row['orders'];
    final orderJson = rawOrder is List ? (rawOrder.isEmpty ? null : rawOrder.first) : rawOrder;
    final listing = listings[row['item_id']];
    if (orderJson is! Map || listing == null) continue;

    final rawQuantity = (row['quantity'] as num?)?.toInt() ?? 0;
    final quantity = rawQuantity == 0 ? 1 : rawQuantity;
    final price = (row['price_at_purchase'] as num?)?.toDouble() ?? 0;
    lines.add(
      AnalyticsLine(
        orderId: orderJson['id'] as String,
        orderStatus: orderJson['status'] as String? ?? '',
        createdAt: _parseDate(orderJson['created_at']),
        itemId: row['item_id'] as String,
        type: listing.type,
        label: listing.label,
        quantity: quantity,
        amount: price * quantity,
      ),
    );
  }

  AnalyticsEvent toEvent(Map<String, dynamic> row) =>
      AnalyticsEvent(status: row['status'] as String? ?? '', createdAt: _parseDate(row['created_at']));

  return ShopAnalyticsData(
    listingCount: listings.length,
    lines: lines,
    demos: demos.map(toEvent).toList(),
    bookings: bookings.map(toEvent).toList(),
  );
}

Map<String, int> _countBy(Iterable<String> values) {
  final counts = <String, int>{};
  for (final value in values) {
    counts[value] = (counts[value] ?? 0) + 1;
  }
  return counts;
}

/// Turns the raw rows into everything the screen renders for one range.
AnalyticsSummary summarize(ShopAnalyticsData data, AnalyticsRange range) {
  final start = range.start;
  bool inRange(DateTime value) => start == null || !value.isBefore(start);

  final orderStatuses = <String, String>{};
  final revenueOrders = <String, _OrderTotal>{};
  final revenueByType = <String, double>{'pet': 0, 'product': 0, 'service': 0};
  final topItems = <String, AnalyticsTopItem>{};
  var itemsSold = 0;

  for (final line in data.lines) {
    if (!inRange(line.createdAt)) continue;
    orderStatuses[line.orderId] = line.orderStatus;
    if (line.orderStatus == 'cancelled') continue;

    final order = revenueOrders.putIfAbsent(line.orderId, () => _OrderTotal(line.createdAt));
    order.total += line.amount;

    revenueByType[line.type] = (revenueByType[line.type] ?? 0) + line.amount;
    itemsSold += line.quantity;

    final top = topItems.putIfAbsent(
      line.itemId,
      () => AnalyticsTopItem(id: line.itemId, label: line.label, type: line.type),
    );
    top.units += line.quantity;
    top.revenue += line.amount;
  }

  final List<({DateTime createdAt, num totalAmount})> chartOrders = [
    for (final order in revenueOrders.values) (createdAt: order.createdAt, totalAmount: order.total),
  ];
  final revenue = revenueOrders.values.fold<double>(0, (sum, order) => sum + order.total);
  final demos = data.demos.where((demo) => inRange(demo.createdAt)).toList();
  final bookings = data.bookings.where((booking) => inRange(booking.createdAt)).toList();

  final ranked = topItems.values.toList()
    ..sort((a, b) {
      final byRevenue = b.revenue.compareTo(a.revenue);
      if (byRevenue != 0) return byRevenue;
      final byUnits = b.units.compareTo(a.units);
      return byUnits != 0 ? byUnits : a.label.compareTo(b.label);
    });

  return AnalyticsSummary(
    revenue: revenue,
    orderCount: chartOrders.length,
    averageOrder: chartOrders.isNotEmpty ? revenue / chartOrders.length : 0,
    itemsSold: itemsSold,
    chartOrders: chartOrders,
    statusCounts: _countBy(orderStatuses.values),
    revenueByType: revenueByType,
    topItems: ranked.take(5).toList(),
    demoCounts: _countBy(demos.map((demo) => demo.status)),
    demoTotal: demos.length,
    bookingCounts: _countBy(bookings.map((booking) => booking.status)),
    bookingTotal: bookings.length,
  );
}
