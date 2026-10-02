import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Mirrors src/pages/seller/Dashboard.jsx: the shop owner's landing page,
/// showing stats for their own shop and its most recent orders.
class SellerDashboardScreen extends ConsumerStatefulWidget {
  const SellerDashboardScreen({super.key});

  @override
  ConsumerState<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends ConsumerState<SellerDashboardScreen> {
  Shop? _shop;
  bool _shopLoading = true;
  bool _statsLoading = true;

  int _petsCount = 0;
  int _productsCount = 0;
  int _soldCount = 0;
  int _ordersCount = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  List<({DateTime createdAt, num totalAmount})> _revenueOrders = [];

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      if (!mounted) return;
      setState(() {
        _shop = null;
        _shopLoading = false;
        _statsLoading = false;
      });
      return;
    }

    final shop = await ShopsRepository().getByOwnerId(profile.id);
    if (!mounted) return;
    setState(() {
      _shop = shop;
      _shopLoading = false;
    });

    if (shop != null) {
      await _loadStats(shop.id);
    } else {
      if (!mounted) return;
      setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadStats(String shopId) async {
    if (!mounted) return;
    setState(() => _statsLoading = true);

    final pets = await PetsRepository().listByShop(shopId);
    final products = await ProductsRepository().listByShop(shopId);
    final soldCount = pets.where((p) => p.status == 'sold').length;

    final petIds = pets.map((p) => p.id).toList();
    final productIds = products.map((p) => p.id).toList();

    final orderItemsRepo = OrderItemsRepository();
    final petOrderIds = await orderItemsRepo.orderIdsForItems(itemType: 'pet', itemIds: petIds);
    final productOrderIds = await orderItemsRepo.orderIdsForItems(itemType: 'product', itemIds: productIds);
    final orderIds = {...petOrderIds, ...productOrderIds}.toList();

    List<Map<String, dynamic>> recentOrders = [];
    List<({DateTime createdAt, num totalAmount})> revenueOrders = [];
    if (orderIds.isNotEmpty) {
      final orders = await OrdersRepository().listByIds(orderIds);
      recentOrders = orders.take(5).toList();
      revenueOrders = orders
          .map((o) => (
                createdAt: DateTime.tryParse(o['created_at'] as String? ?? '') ?? DateTime.now(),
                totalAmount: o['total_amount'] as num? ?? 0,
              ))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _petsCount = pets.length;
      _productsCount = products.length;
      _soldCount = soldCount;
      _ordersCount = orderIds.length;
      _recentOrders = recentOrders;
      _revenueOrders = revenueOrders;
      _statsLoading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.trust;
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.inkSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shopLoading && _shop == null) {
      return RoleShell(
        title: 'Dashboard',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "You haven't set up your shop yet",
            description: 'Create your shop profile to start listing pets and products.',
            action: ElevatedButton(
              onPressed: () => context.push('/seller/store'),
              child: const Text('Set up your shop'),
            ),
          ),
        ),
      );
    }

    final loading = _shopLoading || _statsLoading;

    return RoleShell(
      title: 'Dashboard',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'Dashboard',
              trailing: _shop != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _shop!.status,
                        style: AppTheme.body(
                          fontWeight: FontWeight.w600,
                          color: _statusColor(_shop!.status),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: LoadingView(),
              )
            else ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _StatCard(label: 'Pets listed', value: _petsCount),
                  _StatCard(label: 'Products listed', value: _productsCount),
                  _StatCard(label: 'Pets sold', value: _soldCount),
                  _StatCard(label: 'Orders', value: _ordersCount),
                ],
              ),
              const SizedBox(height: 24),
              RevenueChart(orders: _revenueOrders),
              const SizedBox(height: 32),
              Text('Recent orders', style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Orders containing your pets or products, most recent first.',
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              if (_recentOrders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('No orders yet.', style: AppTheme.body(color: AppColors.inkSoft)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < _recentOrders.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.border),
                        _RecentOrderRow(order: _recentOrders[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Text('$value', style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RecentOrderRow extends StatelessWidget {
  final Map<String, dynamic> order;
  const _RecentOrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final orderType = (order['order_type'] as String? ?? '').replaceAll('_', ' ');
    final status = order['status'] as String? ?? '';
    final totalAmount = order['total_amount'] as num? ?? 0;
    final createdAt = DateTime.tryParse(order['created_at'] as String? ?? '') ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(orderType, style: AppTheme.body()),
                const SizedBox(height: 2),
                Text(formatOrderDate(createdAt), style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(totalAmount),
                style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
              ),
              const SizedBox(height: 2),
              Text(status, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
