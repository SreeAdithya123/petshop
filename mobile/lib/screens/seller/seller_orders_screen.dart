import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../utils/format.dart';
import '../../widgets/seller/order_card.dart';
import '../../widgets/seller/order_data.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/Orders.jsx and adds the order lifecycle: orders
/// that include this shop's items, with Mark paid / Mark handed over / Cancel
/// (customers pay and collect in person, so the shop owner records each step).
class SellerOrdersScreen extends StatelessWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Orders',
      subtitle: 'Orders that include items from your shop.',
      builder: (context, shop) => _OrdersWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('paid', 'Paid'),
  StatusFilter('fulfilled', 'Handed over'),
  StatusFilter('cancelled', 'Cancelled'),
  StatusFilter('all', 'All'),
];

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
    'Confirm you have received the payment for this order in person.',
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
        'The customer will see the order as cancelled. This can\'t be undone.',
    'Cancel order',
    'Order cancelled. Any reserved pets are back in the catalog.',
  ),
};

String _statusOf(SellerOrder order) => order.status;

class _OrdersWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _OrdersWorkspace({required this.shop});

  @override
  ConsumerState<_OrdersWorkspace> createState() => _OrdersWorkspaceState();
}

class _OrdersWorkspaceState extends ConsumerState<_OrdersWorkspace> {
  late final SellerQuery<ShopOrdersData> _query;
  String? _filter;
  int _limit = kPageSize;
  String? _busyOrderId;
  String? _busyStatus;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<ShopOrdersData>(() => loadShopOrders(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _move(SellerOrder order, String status) async {
    if (_busyOrderId != null) return;
    final transition = _transitions[status];
    if (transition == null) return;

    final confirmed = await confirmAction(
      context,
      title: transition.title,
      message: '${orderTypeLabel(order.orderType)} ${shortId(order.id)} · ${order.customerName}\n\n${transition.message}',
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

    if (failure == null) {
      // Re-read the orders while the card is still busy so it shows the real
      // state, and so we can confirm the change actually stuck.
      await _query.reload();
      if (!mounted) return;
    }
    setState(() {
      _busyOrderId = null;
      _busyStatus = null;
    });

    if (failure != null) {
      showSnack(context, failure, error: true);
      // The order may have moved on elsewhere (the customer cancelled, another
      // device): show its real state. Nothing to refresh when the server
      // function isn't deployed yet.
      if (failure != kNotAvailableYet) _query.reload();
      return;
    }

    // The server accepted the call; if the fresh data still shows another
    // status, a rule on the server refused it quietly.
    String? currentStatus;
    for (final candidate in _query.data?.orders ?? const <SellerOrder>[]) {
      if (candidate.id == order.id) currentStatus = candidate.status;
    }
    final unchanged = _query.error == null && currentStatus != null && currentStatus != status;
    if (unchanged) {
      showSnack(context, kNothingChanged, error: true);
      return;
    }
    showSnack(context, transition.success);
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final readOnly = widget.shop.status != 'approved';

    return SellerQueryPanel<ShopOrdersData>(
      query: _query,
      what: 'orders',
      builder: (context, data) {
        final rows = data.orders;
        final pendingCount = rows.where((order) => order.status == 'pending').length;
        final paidCount = rows.where((order) => order.status == 'paid').length;
        // Open on "Pending" when something needs doing, otherwise show everything.
        final active = _filter ?? (pendingCount > 0 ? 'pending' : 'all');
        final visible = applyStatusFilter(_filters, active, rows, _statusOf);
        final shown = math.min(_limit, visible.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoticeBox(
              message:
                  'Customers pay and collect in person. Mark an order paid when you receive the payment, then handed over '
                  'once they have collected it. Cancelling releases any reserved pets back to the catalog.',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SellerSummaryTile(label: 'Awaiting payment', value: '$pendingCount')),
                const SizedBox(width: 12),
                Expanded(child: SellerSummaryTile(label: 'Ready to hand over', value: '$paidCount')),
              ],
            ),
            const SizedBox(height: 20),
            FilterChipBar<String>(
              options: filterOptions(_filters, rows, _statusOf),
              selected: active,
              onSelected: (value) => setState(() {
                _filter = value;
                _limit = kPageSize;
              }),
            ),
            const SizedBox(height: 16),
            if (data.customersError != null) ...[
              NoticeBox.error(message: "Couldn't load customer names: ${data.customersError}"),
              const SizedBox(height: 12),
            ],
            if (visible.isEmpty)
              CardBox(
                child: EmptyState(
                  title: rows.isEmpty ? 'No orders yet' : 'Nothing here',
                  description: rows.isEmpty
                      ? 'Orders for your pets and products will show up here.'
                      : 'No orders match this filter.',
                ),
              )
            else ...[
              for (final order in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SellerOrderCard(
                    key: ValueKey(order.id),
                    order: order,
                    readOnly: readOnly,
                    busyStatus: _busyOrderId == order.id ? _busyStatus : null,
                    onAction: (status) => _move(order, status),
                  ),
                ),
              LoadMoreButton(
                shown: shown,
                total: visible.length,
                onPressed: () => setState(() => _limit += kPageSize),
              ),
            ],
          ],
        );
      },
    );
  }
}
