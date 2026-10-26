import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/admin/admin_stat_tile.dart';
import '../../widgets/admin/admin_ticket_card.dart' show kShopApplicationPrefix;
import '../../widgets/revenue_chart.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Matches src/pages/admin/Dashboard.jsx: a platform-wide snapshot (shops,
/// orders, support) as tiles that open the matching screen, a revenue tracker
/// and a "needs your attention" list of shops pending approval.
///
/// Every figure is loaded on its own, so one failing table leaves a dash on
/// that tile instead of blanking the page.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

typedef _Revenue = List<({DateTime createdAt, num totalAmount})>;

/// Everything the dashboard shows. A figure that failed to load is null.
class _DashboardData {
  final int? totalShops;
  final int? approvedShops;
  final int? pendingShops;
  final int? suspendedShops;
  final int? pendingServices;
  final int? totalOrders;
  final int? pendingOrders;
  final int? openTickets;
  final int? applications;
  final int? totalPets;
  final int? totalProducts;
  final int? totalCustomers;

  /// Shops awaiting approval, newest first (at most five).
  final List<AdminShopRow>? pendingList;
  final _Revenue? revenue;

  const _DashboardData({
    required this.totalShops,
    required this.approvedShops,
    required this.pendingShops,
    required this.suspendedShops,
    required this.pendingServices,
    required this.totalOrders,
    required this.pendingOrders,
    required this.openTickets,
    required this.applications,
    required this.totalPets,
    required this.totalProducts,
    required this.totalCustomers,
    required this.pendingList,
    required this.revenue,
  });

  bool get incomplete =>
      totalShops == null ||
      approvedShops == null ||
      pendingShops == null ||
      suspendedShops == null ||
      pendingServices == null ||
      totalOrders == null ||
      pendingOrders == null ||
      openTickets == null ||
      applications == null ||
      totalPets == null ||
      totalProducts == null ||
      totalCustomers == null ||
      pendingList == null ||
      revenue == null;

  /// "12 approved · 3 suspended" under the total, once both counts are known.
  String? get shopBreakdown =>
      approvedShops == null || suspendedShops == null ? null : '$approvedShops approved · $suspendedShops suspended';
}

/// One figure's outcome: its value, or the failure that stopped it.
class _Outcome<T> {
  final T? value;
  final Object? error;
  const _Outcome(this.value, this.error);

  bool get failed => error != null;
}

Future<_Outcome<T>> _attempt<T>(Future<T> Function() run) async {
  try {
    return _Outcome<T>(await run(), null);
  } catch (e) {
    return _Outcome<T>(null, e);
  }
}

Future<_Outcome<int>> _count(Future<int> Function() run) => _attempt<int>(run);

Future<_DashboardData> _loadDashboard() async {
  final client = SupabaseService.client;
  final now = DateTime.now();
  // Revenue covers the last 12 months (the chart's longest range).
  final since = DateTime(now.year, now.month - 11, 1).toUtc().toIso8601String();

  // Every figure runs on its own and never throws, so they all start together
  // and one failure can't take the others down.
  final totalShops = _count(() => client.from('shops').count());
  final approvedShops = _count(() => client.from('shops').count().eq('status', 'approved'));
  final pendingShops = _count(() => client.from('shops').count().eq('status', 'pending'));
  final suspendedShops = _count(() => client.from('shops').count().eq('status', 'suspended'));
  final pendingServices = _count(() => client.from('services').count().eq('status', 'pending'));
  final totalOrders = _count(() => client.from('orders').count());
  final pendingOrders = _count(() => client.from('orders').count().eq('status', 'pending'));
  final openTickets =
      _count(() => client.from('support_tickets').count().inFilter('status', ['open', 'in_progress']));
  final applications = _count(
    () => client
        .from('support_tickets')
        .count()
        .ilike('subject', '$kShopApplicationPrefix%')
        .isFilter('shop_id', null)
        .inFilter('status', ['open', 'in_progress']),
  );
  final totalPets = _count(() => client.from('pets').count());
  final totalProducts = _count(() => client.from('products').count());
  final totalCustomers = _count(() => client.from('profiles').count().eq('role', 'customer'));
  final pendingList = _attempt<List<AdminShopRow>>(() async {
    final rows = await client
        .from('shops')
        .select(kAdminShopColumns)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(5);
    return rows.map(AdminShopRow.fromJson).toList();
  });
  final revenue = _attempt<_Revenue>(() async {
    final rows = await fetchAllRows(
      () => client
          .from('orders')
          .select('created_at, total_amount')
          .neq('status', 'cancelled')
          .gte('created_at', since),
    );
    return [
      for (final row in rows)
        (
          createdAt: DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
          totalAmount: (row['total_amount'] as num?) ?? 0,
        ),
    ];
  });

  final outcomes = await Future.wait<_Outcome<Object?>>([
    totalShops,
    approvedShops,
    pendingShops,
    suspendedShops,
    pendingServices,
    totalOrders,
    pendingOrders,
    openTickets,
    applications,
    totalPets,
    totalProducts,
    totalCustomers,
    pendingList,
    revenue,
  ]);
  // Offline (or signed out): every figure failed, so show the retry card
  // instead of a page of dashes.
  if (outcomes.every((outcome) => outcome.failed)) throw outcomes.first.error!;

  return _DashboardData(
    totalShops: (await totalShops).value,
    approvedShops: (await approvedShops).value,
    pendingShops: (await pendingShops).value,
    suspendedShops: (await suspendedShops).value,
    pendingServices: (await pendingServices).value,
    totalOrders: (await totalOrders).value,
    pendingOrders: (await pendingOrders).value,
    openTickets: (await openTickets).value,
    applications: (await applications).value,
    totalPets: (await totalPets).value,
    totalProducts: (await totalProducts).value,
    totalCustomers: (await totalCustomers).value,
    pendingList: (await pendingList).value,
    revenue: (await revenue).value,
  );
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final SellerQuery<_DashboardData> _query;

  @override
  void initState() {
    super.initState();
    _query = SellerQuery<_DashboardData>(_loadDashboard);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Dashboard',
      heading: 'Admin dashboard',
      subtitle: 'A platform-wide snapshot of shops, listings, and orders.',
      onRefresh: _query.reload,
      child: SellerQueryPanel<_DashboardData>(
        query: _query,
        what: 'the dashboard',
        builder: (context, data) => _DashboardBody(data: data, onRetry: _query.reload),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;
  final Future<void> Function() onRetry;

  const _DashboardBody({required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final pendingShops = data.pendingList;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data.incomplete) ...[
          const NoticeBox.warning(message: "Some figures couldn't be loaded. They show a dash."),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const _SectionTitle('Needs your attention'),
        const SizedBox(height: 12),
        AdminTileGrid(
          tiles: [
            AdminStatTile(
              label: 'Shops awaiting approval',
              value: data.pendingShops,
              icon: Icons.storefront_outlined,
              route: '/admin/shops',
              attention: true,
            ),
            AdminStatTile(
              label: 'Services awaiting approval',
              value: data.pendingServices,
              icon: Icons.design_services_outlined,
              route: '/admin/services',
              attention: true,
            ),
            AdminStatTile(
              label: 'New shop applications',
              value: data.applications,
              icon: Icons.assignment_ind_outlined,
              route: '/admin/support',
              attention: true,
            ),
            AdminStatTile(
              label: 'Open support tickets',
              value: data.openTickets,
              icon: Icons.support_agent_outlined,
              route: '/admin/support',
              attention: true,
            ),
            AdminStatTile(
              label: 'Orders awaiting payment',
              value: data.pendingOrders,
              icon: Icons.receipt_long_outlined,
              route: '/admin/orders',
              attention: true,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Platform'),
        const SizedBox(height: 12),
        AdminTileGrid(
          tiles: [
            AdminStatTile(
              label: 'Total shops',
              value: data.totalShops,
              hint: data.shopBreakdown,
              icon: Icons.store_mall_directory_outlined,
              route: '/admin/shops',
            ),
            AdminStatTile(
              label: 'Total orders',
              value: data.totalOrders,
              icon: Icons.shopping_bag_outlined,
              route: '/admin/orders',
            ),
            AdminStatTile(label: 'Total pets', value: data.totalPets, icon: Icons.pets_outlined),
            AdminStatTile(label: 'Total products', value: data.totalProducts, icon: Icons.inventory_2_outlined),
            AdminStatTile(label: 'Total customers', value: data.totalCustomers, icon: Icons.people_outline),
          ],
        ),
        const SizedBox(height: 28),
        if (data.revenue != null)
          RevenueChart(orders: data.revenue!)
        else
          const CardBox(child: NoticeBox.warning(message: "Revenue couldn't be loaded. Pull down to refresh.")),
        const SizedBox(height: 28),
        const _SectionTitle('Shops awaiting approval'),
        const SizedBox(height: 4),
        Text(
          'Most recent first.',
          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 12),
        if (pendingShops == null)
          const NoticeBox.warning(message: "The list of pending shops couldn't be loaded. Pull down to refresh.")
        else if (pendingShops.isEmpty)
          CardBox(
            child: Text(
              'No shops are currently pending approval.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
          )
        else
          CardBox(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < pendingShops.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _PendingShopRow(shop: pendingShops[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.adminAccent),
            onPressed: () => context.push('/admin/shops'),
            child: const Text('Review shops'),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
    );
  }
}

class _PendingShopRow extends StatelessWidget {
  final AdminShopRow shop;
  const _PendingShopRow({required this.shop});

  @override
  Widget build(BuildContext context) {
    final name = shop.name.isEmpty ? 'Unnamed shop' : shop.name;
    final owner = shop.ownerName.isEmpty ? 'Unknown owner' : shop.ownerName;
    final subtitle = '$owner · Registered ${formatOrderDate(shop.createdAt)}';
    void open() => context.push('/admin/shops');

    return Semantics(
      button: true,
      label: '$name, $subtitle, pending approval',
      hint: 'Opens the shops list',
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const StatusBadge(status: 'pending', label: 'Pending'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
