import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart' show UserFacingException, kGenericError;
import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/seller/order_card.dart';
import '../../widgets/seller/order_data.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/skeletons.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/Dashboard.jsx and adds the "needs your attention"
/// counters (orders, demos, refunds, bookings, custom requests) as tiles that
/// open the matching screen.
class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Dashboard',
      subtitle: 'What needs your attention and how your shop is doing.',
      builder: (context, shop) => _DashboardWorkspace(shop: shop),
    );
  }
}

/// Everything the dashboard shows. A part that failed to load is null (its
/// tiles show a dash) so one failing table doesn't blank the whole page.
class _DashboardData {
  /// Orders and listing counts; null when that part failed ([ordersError]).
  final ShopOrdersData? orders;
  final String? ordersError;
  final int? pendingDemos;
  final int? pendingRefunds;
  final int? pendingBookings;
  final int? openRequests;

  const _DashboardData({
    required this.orders,
    required this.ordersError,
    required this.pendingDemos,
    required this.pendingRefunds,
    required this.pendingBookings,
    required this.openRequests,
  });

  bool get countsIncomplete =>
      orders == null || pendingDemos == null || pendingRefunds == null || pendingBookings == null || openRequests == null;
}

Future<int?> _safeCount(Future<int> Function() run) async {
  try {
    return await run();
  } catch (_) {
    return null;
  }
}

Future<_DashboardData> _loadDashboard(String shopId) async {
  final client = SupabaseService.client;
  Object? ordersFailure;

  Future<ShopOrdersData?> safeOrders() async {
    try {
      return await loadShopOrders(shopId);
    } catch (e) {
      ordersFailure = e;
      return null;
    }
  }

  final results = await Future.wait<Object?>([
    safeOrders(),
    _safeCount(() => client.from('demo_requests').count().eq('shop_id', shopId).eq('status', 'pending')),
    _safeCount(() => client.from('refunds').count().eq('shop_id', shopId).eq('status', 'pending')),
    _safeCount(() => client.from('service_bookings').count().eq('shop_id', shopId).eq('status', 'pending')),
    // Open requests are visible to every approved shop: they are the ones to quote on.
    _safeCount(() => client.from('custom_service_requests').count().eq('status', 'open')),
  ]);
  final orders = results[0] as ShopOrdersData?;
  final counts = results.sublist(1).cast<int?>();

  // Everything failed (typically offline): show the full-page Retry instead of a
  // page of dashes.
  if (orders == null && counts.every((count) => count == null)) {
    final failure = ordersFailure;
    throw failure ?? const UserFacingException(kGenericError);
  }

  return _DashboardData(
    orders: orders,
    ordersError: orders == null ? describeError(ordersFailure ?? const UserFacingException(kGenericError)) : null,
    pendingDemos: counts[0],
    pendingRefunds: counts[1],
    pendingBookings: counts[2],
    openRequests: counts[3],
  );
}

const _shopStatusLabels = {
  'approved': 'Approved',
  'pending': 'Awaiting approval',
  'suspended': 'Suspended',
};

class _DashboardWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _DashboardWorkspace({required this.shop});

  @override
  ConsumerState<_DashboardWorkspace> createState() => _DashboardWorkspaceState();
}

class _DashboardWorkspaceState extends ConsumerState<_DashboardWorkspace> {
  late final SellerQuery<_DashboardData> _query;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<_DashboardData>(() => _loadDashboard(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final shop = widget.shop;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                shop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            StatusBadge(status: shop.status, label: _shopStatusLabels[shop.status] ?? titleCase(shop.status)),
          ],
        ),
        const SizedBox(height: 20),
        SellerQueryPanel<_DashboardData>(
          query: _query,
          what: 'your dashboard',
          skeleton: const _DashboardSkeleton(),
          builder: (context, data) => _DashboardBody(data: data, onRetry: _query.reload),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final _DashboardData data;
  final VoidCallback onRetry;
  const _DashboardBody({required this.data, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final shopOrders = data.orders;
    final orders = shopOrders?.orders ?? const <SellerOrder>[];
    final pendingOrders = shopOrders == null ? null : orders.where((order) => order.status == 'pending').length;
    final paidOrders = orders.where((order) => order.status == 'paid').length;

    // Revenue counts this shop's own lines on orders that weren't cancelled.
    final List<({DateTime createdAt, num totalAmount})> revenueOrders = [
      for (final order in orders)
        if (order.status != 'cancelled') (createdAt: order.createdAt, totalAmount: order.shopSubtotal),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Needs your attention'),
        const SizedBox(height: 12),
        if (data.countsIncomplete) ...[
          NoticeBox.warning(
            message: data.ordersError == null
                ? "Some counts couldn't be loaded. Pull down to refresh."
                : "Your orders and listings couldn't be loaded: ${data.ordersError}",
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ),
          const SizedBox(height: 4),
        ],
        _TileGrid(
          tiles: [
            _ActionTile(
              label: 'Orders awaiting payment',
              value: pendingOrders,
              hint: paidOrders > 0 ? '$paidOrders paid, to hand over' : null,
              icon: Icons.receipt_long_outlined,
              route: '/seller/orders',
              attention: true,
            ),
            _ActionTile(
              label: 'Demo requests to answer',
              value: data.pendingDemos,
              icon: Icons.videocam_outlined,
              route: '/seller/demos',
              attention: true,
            ),
            _ActionTile(
              label: 'Refund requests',
              value: data.pendingRefunds,
              icon: Icons.assignment_return_outlined,
              route: '/seller/refunds',
              attention: true,
            ),
            _ActionTile(
              label: 'Service bookings to confirm',
              value: data.pendingBookings,
              icon: Icons.event_available_outlined,
              route: '/seller/services?tab=bookings',
              attention: true,
            ),
            _ActionTile(
              label: 'Open custom requests',
              value: data.openRequests,
              icon: Icons.request_quote_outlined,
              route: '/seller/services?tab=requests',
              attention: true,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Your shop'),
        const SizedBox(height: 12),
        _TileGrid(
          tiles: [
            _ActionTile(
              label: 'Pets listed',
              value: shopOrders?.petCount,
              icon: Icons.pets_outlined,
              route: '/seller/pets',
            ),
            _ActionTile(
              label: 'Products listed',
              value: shopOrders?.productCount,
              icon: Icons.inventory_2_outlined,
              route: '/seller/products',
            ),
            _ActionTile(
              label: 'Pets sold',
              value: shopOrders?.soldCount,
              icon: Icons.verified_outlined,
              route: '/seller/pets',
            ),
            _ActionTile(
              label: 'Orders',
              value: shopOrders == null ? null : orders.length,
              icon: Icons.shopping_bag_outlined,
              route: '/seller/orders',
            ),
          ],
        ),
        if (shopOrders != null) ...[
          const SizedBox(height: 28),
          RevenueChart(orders: revenueOrders),
          const SizedBox(height: 28),
          const _SectionTitle('Recent orders'),
          const SizedBox(height: 4),
          Text(
            'Orders containing your pets, products or services, most recent first.',
            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 12),
          if (orders.isEmpty)
            CardBox(
              child: Text('No orders yet.', style: AppTheme.body(color: AppColors.inkSoft)),
            )
          else
            CardBox(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < orders.length && i < 5; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _RecentOrderRow(order: orders[i]),
                  ],
                ],
              ),
            ),
          if (orders.length > 5) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/seller/orders'),
                child: const Text('See all orders'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Placeholder tiles shown while the dashboard loads.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonBox(width: 170, height: 20),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 96, radius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96, radius: 14)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 96, radius: 14)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 96, radius: 14)),
            ],
          ),
          SizedBox(height: 28),
          SkeletonBox(height: 220, radius: 16),
        ],
      ),
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

/// Lays tiles out two per row at equal height, or one per row on narrow
/// screens and large text sizes where two columns would squeeze the labels.
class _TileGrid extends StatelessWidget {
  final List<Widget> tiles;
  const _TileGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 340 || textScale > 1.25;
        if (singleColumn) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 1 < tiles.length ? 12 : 0),
                  child: tiles[i],
                ),
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < tiles.length; i += 2)
              Padding(
                padding: EdgeInsets.only(bottom: i + 2 < tiles.length ? 12 : 0),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tiles[i]),
                      const SizedBox(width: 12),
                      Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A tappable counter. [attention] tiles highlight while the count is above
/// zero; a null [value] (the count failed to load) shows a dash.
class _ActionTile extends StatelessWidget {
  final String label;
  final int? value;
  final String? hint;
  final IconData icon;
  final String route;
  final bool attention;

  const _ActionTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.route,
    this.hint,
    this.attention = false,
  });

  @override
  Widget build(BuildContext context) {
    final count = value;
    final highlighted = attention && (count ?? 0) > 0;
    final accent = highlighted ? AppColors.accent : AppColors.inkSoft;
    final spoken = '$label: ${count ?? 'unavailable'}${hint == null ? '' : '. $hint'}';

    return Semantics(
      button: true,
      label: spoken,
      hint: 'Opens the list',
      onTap: () => context.push(route),
      excludeSemantics: true,
      child: Material(
        color: highlighted ? AppColors.accent.withValues(alpha: 0.06) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: highlighted ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: InkWell(
          onTap: () => context.push(route),
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon, size: 18, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(count == null ? '–' : '$count', style: AppTheme.display(fontSize: 24)),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint!, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  final SellerOrder order;
  const _RecentOrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final title = '${orderTypeLabel(order.orderType)} ${shortId(order.id)}';
    final subtitle = '${order.customerName} · ${formatOrderDate(order.createdAt)}';
    return Semantics(
      button: true,
      label: '$title, $subtitle, ${formatPrice(order.shopSubtotal)}, ${titleCase(order.status)}',
      onTap: () => context.push('/seller/orders'),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/seller/orders'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(order.shopSubtotal),
                      style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.accent),
                    ),
                    const SizedBox(height: 4),
                    StatusBadge(status: order.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
