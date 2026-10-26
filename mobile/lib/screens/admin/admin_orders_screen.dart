import 'package:flutter/material.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Matches src/pages/admin/Orders.jsx: every order placed across the
/// platform, newest first, with a status filter. Orders load a page at a time.
///
/// Admins may also move an order along (paid, handed over, cancelled) through
/// the `seller_update_order_status` database function; until it is deployed the
/// buttons report that the action isn't available yet.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

const _filters = <FilterOption<String>>[
  FilterOption('all', 'All'),
  FilterOption('pending', 'Pending'),
  FilterOption('paid', 'Paid'),
  FilterOption('fulfilled', 'Handed over'),
  FilterOption('cancelled', 'Cancelled'),
];

const _orderColumns = 'id, order_type, status, payment_type, total_amount, created_at, profiles(name, email)';

const _orderTypeLabels = {
  'product_purchase': 'Product purchase',
  'pet_reservation': 'Pet reservation',
  'gift': 'Gift',
};

String _typeLabel(String type) => type.isEmpty ? 'Order' : (_orderTypeLabels[type] ?? titleCase(type));

class _Transition {
  final String title;
  final String message;
  final String confirmLabel;
  final String success;
  const _Transition(this.title, this.message, this.confirmLabel, this.success);
}

const _transitions = <String, _Transition>{
  'paid': _Transition(
    'Mark this order as paid?',
    'Confirm the payment for this order was received in person.',
    'Mark paid',
    'Order marked as paid.',
  ),
  'fulfilled': _Transition(
    'Mark this order as handed over?',
    'Confirm the customer has collected their items. Reserved pets in this order are marked as sold.',
    'Mark handed over',
    'Order marked as handed over.',
  ),
  'cancelled': _Transition(
    'Cancel this order?',
    'Reserved pets go back to the catalog so other customers can reserve them again. '
        "The customer will see the order as cancelled. This can't be undone.",
    'Cancel order',
    'Order cancelled. Any reserved pets are back in the catalog.',
  ),
};

class _AdminOrder {
  final String id;
  final String orderType;
  final String status;
  final String paymentType;
  final num totalAmount;
  final DateTime createdAt;
  final String customerName;
  final String customerEmail;

  const _AdminOrder({
    required this.id,
    required this.orderType,
    required this.status,
    required this.paymentType,
    required this.totalAmount,
    required this.createdAt,
    required this.customerName,
    required this.customerEmail,
  });

  factory _AdminOrder.fromJson(Map<String, dynamic> json) {
    var customer = json['profiles'];
    if (customer is List) customer = customer.isEmpty ? null : customer.first;
    final profile = customer is Map ? Map<String, dynamic>.from(customer) : const <String, dynamic>{};
    return _AdminOrder(
      id: json['id'] as String,
      orderType: json['order_type'] as String? ?? '',
      status: json['status'] as String? ?? '',
      paymentType: json['payment_type'] as String? ?? '',
      totalAmount: json['total_amount'] as num? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      customerName: ((profile['name'] as String?) ?? '').trim(),
      customerEmail: ((profile['email'] as String?) ?? '').trim(),
    );
  }
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late PagedQuery<_AdminOrder> _query;
  String _filter = 'all';
  String? _busyOrderId;
  String? _busyStatus;

  @override
  void initState() {
    super.initState();
    _query = _buildQuery(_filter);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  PagedQuery<_AdminOrder> _buildQuery(String status) {
    return PagedQuery<_AdminOrder>((from, to) async {
      var query = SupabaseService.client.from('orders').select(_orderColumns);
      if (status != 'all') query = query.eq('status', status);
      final rows = await query.order('created_at', ascending: false).order('id').range(from, to);
      return rows.map(_AdminOrder.fromJson).toList();
    });
  }

  void _selectFilter(String value) {
    if (value == _filter) return;
    final old = _query;
    setState(() {
      _filter = value;
      _query = _buildQuery(value);
    });
    old.dispose();
  }

  Future<void> _move(_AdminOrder order, String status) async {
    if (_busyOrderId != null) return;
    final transition = _transitions[status];
    if (transition == null) return;

    final who = order.customerName.isEmpty ? 'Unknown customer' : order.customerName;
    final confirmed = await confirmAction(
      context,
      title: transition.title,
      message: '${_typeLabel(order.orderType)} ${shortId(order.id)} · $who · ${formatPrice(order.totalAmount)}'
          '\n\n${transition.message}',
      confirmLabel: transition.confirmLabel,
      cancelLabel: status == 'cancelled' ? 'Keep order' : 'Cancel',
      destructive: status == 'cancelled',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyOrderId = order.id;
      _busyStatus = status;
    });
    final failure = await callRpc('seller_update_order_status', {'p_order_id': order.id, 'p_status': status});
    if (!mounted) return;
    setState(() {
      _busyOrderId = null;
      _busyStatus = null;
    });

    if (failure != null) {
      showSnack(context, failure, error: true);
      return;
    }
    showSnack(context, transition.success);
    _query.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Orders',
      heading: 'All orders',
      subtitle: 'Every order placed across the platform.',
      onRefresh: _query.reload,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterChipBar<String>(
            options: _filters,
            selected: _filter,
            onSelected: _selectFilter,
          ),
          const SizedBox(height: 16),
          PagedQueryPanel<_AdminOrder>(
            query: _query,
            what: 'orders',
            builder: (context, orders) {
              if (orders.isEmpty) {
                return CardBox(
                  child: EmptyState(
                    title: 'No orders found',
                    description: _filter == 'all'
                        ? 'Orders will appear here once customers start purchasing.'
                        : 'No orders match the selected status.',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final order in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OrderCard(
                        key: ValueKey(order.id),
                        order: order,
                        busyStatus: _busyOrderId == order.id ? _busyStatus : null,
                        locked: _busyOrderId != null,
                        onAction: (status) => _move(order, status),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _AdminOrder order;

  /// The status being applied to this order right now (null when idle).
  final String? busyStatus;

  /// True while any order is being updated; all actions wait.
  final bool locked;
  final void Function(String status) onAction;

  const _OrderCard({
    super.key,
    required this.order,
    required this.busyStatus,
    required this.locked,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final customer = [
      order.customerName.isEmpty ? 'Unknown customer' : order.customerName,
      if (order.customerEmail.isNotEmpty) order.customerEmail,
    ].join(' · ');
    final pending = order.status == 'pending';
    final paid = order.status == 'paid';

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_typeLabel(order.orderType)} ${shortId(order.id)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.display(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(order.totalAmount),
                    style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                  const SizedBox(height: 6),
                  StatusBadge(
                    status: order.status,
                    label: order.status == 'fulfilled' ? 'Handed over' : null,
                  ),
                ],
              ),
            ],
          ),
          if (pending || paid) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pending)
                  LoadingButton(
                    label: 'Mark paid',
                    loading: busyStatus == 'paid',
                    onPressed: locked ? null : () => onAction('paid'),
                  ),
                if (paid)
                  LoadingButton(
                    label: 'Mark handed over',
                    loading: busyStatus == 'fulfilled',
                    onPressed: locked ? null : () => onAction('fulfilled'),
                  ),
                LoadingButton(
                  label: 'Cancel order',
                  outlined: true,
                  loading: busyStatus == 'cancelled',
                  onPressed: locked ? null : () => onAction('cancelled'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
