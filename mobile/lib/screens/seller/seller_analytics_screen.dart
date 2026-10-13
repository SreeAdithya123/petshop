import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/seller_analytics/analytics_data.dart';
import '../../widgets/seller_analytics/analytics_widgets.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _orderStatuses = ['pending', 'paid', 'fulfilled', 'cancelled'];

const _typeLabels = {'pet': 'Pet', 'product': 'Product', 'service': 'Service'};

Color _statusBarTone(String status) {
  switch (status) {
    case 'pending':
      return AppColors.warning;
    case 'paid':
      return AppColors.primary;
    case 'fulfilled':
      return AppColors.trust;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.inkSoft;
  }
}

/// Ports src/pages/seller/Analytics.jsx: range chips, KPI tiles, the revenue
/// chart, orders by status, revenue by type, top items and the demo funnel
/// for the signed-in seller's shop.
class SellerAnalyticsScreen extends StatelessWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Analytics',
      subtitle: 'How your shop is doing, based on orders that include your pets, products and services.',
      builder: (context, shop) => _AnalyticsView(shop: shop),
    );
  }
}

class _AnalyticsView extends StatefulWidget {
  final Shop shop;
  const _AnalyticsView({required this.shop});

  @override
  State<_AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends State<_AnalyticsView> {
  AnalyticsRange _range = AnalyticsRange.days30;
  ShopAnalyticsData? _data;
  AnalyticsSummary? _summary;
  String? _error;
  bool _loading = true;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _AnalyticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pull-to-refresh on the scaffold re-reads the shop, which hands us a
    // fresh Shop instance: use that as the cue to reload the numbers too.
    if (!identical(oldWidget.shop, widget.shop)) _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    try {
      final data = await loadShopAnalytics(widget.shop.id);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _data = data;
        _summary = summarize(data, _range);
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  void _selectRange(AnalyticsRange range) {
    final data = _data;
    setState(() {
      _range = range;
      _summary = data == null ? null : summarize(data, range);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterChipBar<AnalyticsRange>(
          options: [for (final range in AnalyticsRange.values) FilterOption(range, range.label)],
          selected: _range,
          onSelected: _selectRange,
        ),
        const SizedBox(height: 16),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    final data = _data;
    final summary = _summary;

    if (data == null || summary == null) {
      if (_loading) return const LoadingView(label: 'Loading analytics…');
      return AnalyticsErrorView(
        message: "Couldn't load analytics: ${_error ?? 'Something went wrong loading your analytics.'}",
        onRetry: _retry,
      );
    }

    if (data.listingCount == 0 && data.demos.isEmpty && data.bookings.isEmpty) {
      return EmptyState(
        title: 'Nothing to analyse yet',
        description: 'List a pet, product or service and your sales and requests will be summarised here.',
        action: ElevatedButton(
          onPressed: () => context.go('/seller/pets'),
          child: const Text('Add a listing'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) ...[
          NoticeBox.error(message: "Couldn't refresh analytics: $_error"),
          const SizedBox(height: 16),
        ],
        _buildStatTiles(summary),
        const SizedBox(height: 20),
        _buildRevenue(summary),
        const SizedBox(height: 16),
        _buildStatusCard(summary),
        const SizedBox(height: 16),
        _buildTypeCard(summary),
        const SizedBox(height: 16),
        _buildTopItemsCard(summary),
        const SizedBox(height: 16),
        _buildDemoFunnelCard(summary),
      ],
    );
  }

  Widget _buildStatTiles(AnalyticsSummary summary) {
    final cancelled = summary.statusCounts['cancelled'] ?? 0;
    final pendingDemos = summary.demoCounts['pending'] ?? 0;
    final pendingBookings = summary.bookingCounts['pending'] ?? 0;

    final tiles = <Widget>[
      AnalyticsStatTile(label: 'Revenue', value: formatPrice(summary.revenue), hint: 'Cancelled orders excluded'),
      AnalyticsStatTile(
        label: 'Orders',
        value: '${summary.orderCount}',
        hint: cancelled > 0 ? '$cancelled cancelled' : null,
      ),
      AnalyticsStatTile(label: 'Average order value', value: formatPrice(summary.averageOrder)),
      AnalyticsStatTile(label: 'Items sold', value: '${summary.itemsSold}'),
      AnalyticsStatTile(
        label: 'Demo requests',
        value: '${summary.demoTotal}',
        hint: pendingDemos > 0 ? '$pendingDemos awaiting reply' : null,
      ),
      AnalyticsStatTile(
        label: 'Service bookings',
        value: '${summary.bookingTotal}',
        hint: pendingBookings > 0 ? '$pendingBookings awaiting reply' : null,
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 12),
                Expanded(child: tiles[i + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRevenue(AnalyticsSummary summary) {
    if (summary.chartOrders.isNotEmpty) return RevenueChart(orders: summary.chartOrders);
    return AnalyticsCard(
      title: 'Revenue',
      child: AnalyticsEmptyText(
        _range == AnalyticsRange.all
            ? 'No orders yet. Orders for your pets, products and services will show up here.'
            : 'No orders in this range. Try a wider date range to see more of your sales.',
      ),
    );
  }

  Widget _buildStatusCard(AnalyticsSummary summary) {
    final counts = summary.statusCounts;
    final statuses = [
      ..._orderStatuses,
      ...counts.keys.where((status) => !_orderStatuses.contains(status)),
    ];
    final rows = [
      for (final status in statuses)
        BarRowData(label: titleCase(status), value: counts[status] ?? 0, tone: _statusBarTone(status)),
    ];
    final total = rows.fold<num>(0, (sum, row) => sum + row.value);

    return AnalyticsCard(
      title: 'Orders by status',
      subtitle: 'Every order in range, including cancelled ones.',
      child: total == 0
          ? const AnalyticsEmptyText('No orders in this range.')
          : AnalyticsBarList(rows: rows, total: total),
    );
  }

  Widget _buildTypeCard(AnalyticsSummary summary) {
    final rows = [
      for (final type in const ['pet', 'product', 'service'])
        BarRowData(
          label: '${_typeLabels[type]}s',
          value: summary.revenueByType[type] ?? 0,
          tone: AppColors.accent,
        ),
    ];
    final total = rows.fold<num>(0, (sum, row) => sum + row.value);

    return AnalyticsCard(
      title: 'Revenue by type',
      subtitle: 'Where your revenue comes from.',
      child: total == 0
          ? const AnalyticsEmptyText('No revenue in this range.')
          : AnalyticsBarList(rows: rows, total: total, formatValue: formatPrice),
    );
  }

  Widget _buildTopItemsCard(AnalyticsSummary summary) {
    final items = summary.topItems;

    return AnalyticsCard(
      title: 'Top items',
      subtitle: 'Your five best sellers by revenue.',
      child: items.isEmpty
          ? const AnalyticsEmptyText('No sales in this range.')
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                items[i].label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.body(fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_typeLabels[items[i].type] ?? titleCase(items[i].type)}'
                                ' · ${items[i].units} ${items[i].units == 1 ? 'unit' : 'units'}',
                                style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formatPrice(items[i].revenue),
                          style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildDemoFunnelCard(AnalyticsSummary summary) {
    final counts = summary.demoCounts;
    final total = summary.demoTotal;
    final rows = [
      BarRowData(label: 'Requested', value: total, tone: AppColors.primary),
      BarRowData(label: 'Approved', value: counts['approved'] ?? 0, tone: AppColors.trust),
      BarRowData(label: 'Completed', value: counts['completed'] ?? 0, tone: AppColors.trust),
      BarRowData(label: 'Rejected', value: counts['rejected'] ?? 0, tone: AppColors.error),
    ];

    return AnalyticsCard(
      title: 'Demo funnel',
      subtitle: 'What happens to the demo requests you receive.',
      child: total == 0
          ? const AnalyticsEmptyText('No demo requests in this range.')
          : AnalyticsBarList(rows: rows, total: total, max: total),
    );
  }
}
