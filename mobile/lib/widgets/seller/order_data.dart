import '../../services/supabase_service.dart';
import 'seller_common.dart';

// Data layer for the seller Orders and Dashboard screens. An order belongs to
// a shop through its lines: only order_items whose item_id is one of this
// shop's pets, products or services are read, so an order that mixes several
// shops only ever shows (and totals) THIS shop's lines.

const _idChunkSize = 100;

/// One line of an order that belongs to the signed-in shop.
class SellerOrderLine {
  final String itemId;
  final String itemType; // pet | product | service
  final String name;
  final int quantity;

  /// Unit price when the order was placed (`price_at_purchase`).
  final num price;

  /// Current status of the pet (available | reserved | sold); null for
  /// products and services.
  final String? petStatus;

  const SellerOrderLine({
    required this.itemId,
    required this.itemType,
    required this.name,
    required this.quantity,
    required this.price,
    this.petStatus,
  });

  num get total => price * quantity;
}

class SellerOrder {
  final String id;
  final String customerId;
  final String orderType; // pet_reservation | product_purchase | gift
  final String status; // pending | paid | fulfilled | cancelled
  final String paymentType; // deposit | full
  final num totalAmount;
  final DateTime createdAt;
  final String customerName;
  final List<SellerOrderLine> lines;

  const SellerOrder({
    required this.id,
    required this.customerId,
    required this.orderType,
    required this.status,
    required this.paymentType,
    required this.totalAmount,
    required this.createdAt,
    required this.customerName,
    required this.lines,
  });

  /// What THIS shop earns from the order: the sum of its own lines.
  num get shopSubtotal => lines.fold<num>(0, (sum, line) => sum + line.total);

  SellerOrder withCustomerName(String name) => SellerOrder(
        id: id,
        customerId: customerId,
        orderType: orderType,
        status: status,
        paymentType: paymentType,
        totalAmount: totalAmount,
        createdAt: createdAt,
        customerName: name,
        lines: lines,
      );
}

/// Everything the Orders and Dashboard screens read for one shop.
class ShopOrdersData {
  /// Newest first.
  final List<SellerOrder> orders;
  final int petCount;
  final int productCount;
  final int soldCount;

  /// Set when customer names could not be loaded (orders still show, as
  /// "Customer").
  final String? customersError;

  const ShopOrdersData({
    required this.orders,
    required this.petCount,
    required this.productCount,
    required this.soldCount,
    this.customersError,
  });
}

String _petLabel(Map<String, dynamic> pet) {
  final breed = (pet['breed'] as String? ?? '').trim();
  final species = (pet['species'] as String? ?? '').trim();
  final name = (pet['name'] as String? ?? '').trim();
  final detail = breed.isNotEmpty ? (species.isEmpty ? breed : '$breed ($species)') : species;
  if (name.isEmpty) return detail.isEmpty ? 'Pet' : detail;
  return detail.isEmpty ? name : '$name · $detail';
}

DateTime _parseDate(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// Loads the shop's listings, the order lines for them, the orders those lines
/// belong to and (best effort) the customers' names.
Future<ShopOrdersData> loadShopOrders(String shopId) async {
  final client = SupabaseService.client;

  final listingRows = await Future.wait<List<Map<String, dynamic>>>([
    fetchAllRows(() => client.from('pets').select('id, name, breed, species, status').eq('shop_id', shopId)),
    fetchAllRows(() => client.from('products').select('id, name').eq('shop_id', shopId)),
    fetchAllRows(() => client.from('services').select('id, name').eq('shop_id', shopId)),
  ]);
  final pets = listingRows[0];
  final products = listingRows[1];
  final services = listingRows[2];

  // item id -> label / type / pet status; ids are uuids so they never collide.
  final labels = <String, String>{};
  final types = <String, String>{};
  final petStatuses = <String, String>{};
  var soldCount = 0;
  for (final pet in pets) {
    final id = pet['id'] as String;
    labels[id] = _petLabel(pet);
    types[id] = 'pet';
    final status = pet['status'] as String? ?? '';
    petStatuses[id] = status;
    if (status == 'sold') soldCount++;
  }
  for (final product in products) {
    final id = product['id'] as String;
    labels[id] = product['name'] as String? ?? 'Product';
    types[id] = 'product';
  }
  for (final service in services) {
    final id = service['id'] as String;
    labels[id] = service['name'] as String? ?? 'Service';
    types[id] = 'service';
  }

  if (labels.isEmpty) {
    return ShopOrdersData(
      orders: const [],
      petCount: pets.length,
      productCount: products.length,
      soldCount: soldCount,
    );
  }

  final itemChunks = await Future.wait<List<Map<String, dynamic>>>([
    for (final ids in chunkList(labels.keys.toList(), _idChunkSize))
      fetchAllRows(
        () => client
            .from('order_items')
            .select('id, order_id, item_id, item_type, quantity, price_at_purchase')
            .inFilter('item_id', ids),
      ),
  ]);

  final linesByOrder = <String, List<SellerOrderLine>>{};
  for (final row in itemChunks.expand((chunk) => chunk)) {
    final orderId = row['order_id'] as String?;
    final itemId = row['item_id'] as String?;
    if (orderId == null || itemId == null) continue;
    final rawQuantity = (row['quantity'] as num?)?.toInt() ?? 1;
    linesByOrder.putIfAbsent(orderId, () => []).add(
          SellerOrderLine(
            itemId: itemId,
            itemType: types[itemId] ?? (row['item_type'] as String? ?? ''),
            name: labels[itemId] ?? 'Item',
            quantity: rawQuantity < 1 ? 1 : rawQuantity,
            price: (row['price_at_purchase'] as num?) ?? 0,
            petStatus: petStatuses[itemId],
          ),
        );
  }

  if (linesByOrder.isEmpty) {
    return ShopOrdersData(
      orders: const [],
      petCount: pets.length,
      productCount: products.length,
      soldCount: soldCount,
    );
  }

  final orderChunks = await Future.wait<List<Map<String, dynamic>>>([
    for (final ids in chunkList(linesByOrder.keys.toList(), _idChunkSize))
      fetchAllRows(
        () => client
            .from('orders')
            .select('id, customer_id, order_type, status, payment_type, total_amount, created_at')
            .inFilter('id', ids),
      ),
  ]);

  var orders = <SellerOrder>[];
  for (final row in orderChunks.expand((chunk) => chunk)) {
    final id = row['id'] as String;
    orders.add(
      SellerOrder(
        id: id,
        customerId: row['customer_id'] as String? ?? '',
        orderType: row['order_type'] as String? ?? '',
        status: row['status'] as String? ?? '',
        paymentType: row['payment_type'] as String? ?? '',
        totalAmount: (row['total_amount'] as num?) ?? 0,
        createdAt: _parseDate(row['created_at']),
        customerName: 'Customer',
        lines: linesByOrder[id] ?? const [],
      ),
    );
  }

  // Names are a nicety: if the lookup fails the orders are still listed.
  String? customersError;
  final names = <String, String>{};
  final customerIds = {for (final order in orders) order.customerId}.where((id) => id.isNotEmpty).toList();
  try {
    for (final chunk in chunkList(customerIds, _idChunkSize)) {
      final rows = await client.from('profiles').select('id, name').inFilter('id', chunk);
      for (final row in rows) {
        final id = row['id'] as String?;
        final name = (row['name'] as String? ?? '').trim();
        if (id != null && name.isNotEmpty) names[id] = name;
      }
    }
  } catch (e) {
    customersError = describeError(e);
  }
  orders = [
    for (final order in orders)
      names.containsKey(order.customerId) ? order.withCustomerName(names[order.customerId]!) : order,
  ];

  orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return ShopOrdersData(
    orders: orders,
    petCount: pets.length,
    productCount: products.length,
    soldCount: soldCount,
    customersError: customersError,
  );
}
