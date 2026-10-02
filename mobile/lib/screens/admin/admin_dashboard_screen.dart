import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/revenue_chart.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Matches src/pages/admin/Dashboard.jsx: a platform-wide stats snapshot
/// plus a "needs your attention" list of shops pending approval.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _StatDef {
  final String key;
  final String label;
  const _StatDef(this.key, this.label);
}

const _statDefs = [
  _StatDef('totalShops', 'Total shops'),
  _StatDef('pendingShops', 'Shops pending approval'),
  _StatDef('totalPets', 'Total pets'),
  _StatDef('totalProducts', 'Total products'),
  _StatDef('totalOrders', 'Total orders'),
  _StatDef('totalCustomers', 'Total customers'),
];

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loading = true;
  Map<String, int> _stats = {};
  List<Shop> _pendingShops = [];
  List<({DateTime createdAt, num totalAmount})> _revenueOrders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<int> _count(String table, {String? statusEq}) async {
    var query = SupabaseService.client.from(table).select('id');
    if (statusEq != null) {
      query = query.eq('status', statusEq);
    }
    final res = await query.count(CountOption.exact);
    return res.count;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _count('shops'),
        _count('shops', statusEq: 'pending'),
        _count('pets'),
        _count('products'),
        _count('orders'),
        SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('role', 'customer')
            .count(CountOption.exact)
            .then((r) => r.count),
        ShopsRepository().listAllWithOwner(),
        SupabaseService.client.from('orders').select('created_at, total_amount'),
      ]);

      if (!mounted) return;

      final allShops = results[6] as List<Shop>;
      final pending = allShops.where((s) => s.status == 'pending').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final orderRows = results[7] as List<dynamic>;
      final revenueOrders = orderRows
          .cast<Map<String, dynamic>>()
          .map((o) => (
                createdAt: DateTime.tryParse(o['created_at'] as String? ?? '') ?? DateTime.now(),
                totalAmount: o['total_amount'] as num? ?? 0,
              ))
          .toList();

      setState(() {
        _stats = {
          'totalShops': results[0] as int,
          'pendingShops': results[1] as int,
          'totalPets': results[2] as int,
          'totalProducts': results[3] as int,
          'totalOrders': results[4] as int,
          'totalCustomers': results[5] as int,
        };
        _pendingShops = pending.take(5).toList();
        _revenueOrders = revenueOrders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Dashboard',
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: kScreenPadding,
          children: [
            Text('Admin dashboard', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'A platform-wide snapshot of shops, listings, and orders.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                for (final def in _statDefs)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _loading ? '—' : '${_stats[def.key] ?? 0}',
                          style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          def.label,
                          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_loading) RevenueChart(orders: _revenueOrders),
            const SizedBox(height: 28),
            Text('Needs your attention', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Shops awaiting approval, most recent first.',
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            if (!_loading && _pendingShops.isEmpty)
              Text(
                'No shops are currently pending approval.',
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
            if (_pendingShops.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < _pendingShops.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pendingShops[i].name,
                                    style: AppTheme.body(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pendingShops[i].address,
                                    style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text('pending', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => context.push('/admin/shops'),
                child: const Text('Review shops'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
