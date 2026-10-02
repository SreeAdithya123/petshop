import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

/// Matches src/pages/admin/Orders.jsx: every order placed across the
/// platform, with a client-side status filter.
class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

const _statusOptions = ['all', 'pending', 'paid', 'fulfilled', 'cancelled'];

Color _statusColor(String status) {
  switch (status) {
    case 'paid':
    case 'fulfilled':
      return AppColors.trust;
    case 'cancelled':
      return AppColors.error;
    case 'pending':
    default:
      return AppColors.inkSoft;
  }
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<OrderRow> _orders = [];
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await OrdersRepository().listAllWithCustomer();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<OrderRow> get _filteredOrders {
    if (_statusFilter == 'all') return _orders;
    return _orders.where((order) => order.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(title: 'Orders', child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(label: 'Loading orders…');
    }
    if (_error != null) {
      return ErrorView(message: "Couldn't load orders: $_error");
    }

    final filtered = _filteredOrders;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: kScreenPadding,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All orders', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Every order placed across the platform.',
                      style: AppTheme.body(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusFilterDropdown(
                value: _statusFilter,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            EmptyState(
              title: 'No orders found',
              description: _orders.isEmpty
                  ? 'Orders will appear here once customers start purchasing.'
                  : 'No orders match the selected status.',
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _OrderRowView(order: filtered[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusFilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: AppTheme.body(fontSize: 14),
          items: [
            for (final option in _statusOptions)
              DropdownMenuItem(
                value: option,
                child: Text(option == 'all' ? 'All statuses' : option),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _OrderRowView extends StatelessWidget {
  final OrderRow order;
  const _OrderRowView({required this.order});

  @override
  Widget build(BuildContext context) {
    final customer = order.customer;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.orderType.replaceAll('_', ' ')} · ${formatPrice(order.totalAmount)}',
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${customer?.name ?? 'Unknown customer'}'
                  '${customer?.email != null && customer!.email!.isNotEmpty ? ' · ${customer.email}' : ''}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.paymentType == 'deposit' ? 'Deposit payment' : 'Full payment'} · '
                  '${formatOrderDate(order.createdAt)}',
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            order.status,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _statusColor(order.status),
            ),
          ),
        ],
      ),
    );
  }
}
