import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'order_data.dart';
import 'seller_common.dart';

const _orderTypeLabels = {
  'product_purchase': 'Product purchase',
  'pet_reservation': 'Pet reservation',
  'gift': 'Gift',
};

String orderTypeLabel(String type) => _orderTypeLabels[type] ?? titleCase(type);

const _petStatusLabels = {'available': 'Available', 'reserved': 'Reserved', 'sold': 'Sold'};

/// One order that includes this shop's items, with the next-step actions:
/// Mark paid (pending), Mark handed over (paid) and Cancel order (pending or
/// paid). Payment and pickup happen in person, so the shop owner records them.
class SellerOrderCard extends StatelessWidget {
  final SellerOrder order;

  /// True when the shop isn't approved: the order is shown but can't change.
  final bool readOnly;

  /// The status being applied to this order right now (null when idle). While
  /// it is set every action on the card is disabled.
  final String? busyStatus;

  /// Called with the status to move the order to: 'paid', 'fulfilled' or
  /// 'cancelled'.
  final void Function(String status) onAction;

  const SellerOrderCard({
    super.key,
    required this.order,
    required this.readOnly,
    required this.busyStatus,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = order.shopSubtotal;
    final differs = (order.totalAmount - subtotal).abs() > 0.5;
    final busy = busyStatus != null;
    final pending = order.status == 'pending';
    final paid = order.status == 'paid';
    final canAct = !readOnly && (pending || paid);

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
                      '${orderTypeLabel(order.orderType)} ${shortId(order.id)}',
                      style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.customerName} · ${formatOrderDate(order.createdAt)}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: order.status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          for (final line in order.lines) _OrderLineRow(line: line),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),
          SellerMetaRow('Your items', text: formatPrice(subtotal)),
          if (differs) SellerMetaRow('Order total', text: formatPrice(order.totalAmount)),
          SellerMetaRow('Payment', text: order.paymentType == 'deposit' ? 'Deposit' : 'Full payment'),
          if (canAct) ...[
            const SizedBox(height: 12),
            Text(
              pending
                  ? 'Mark this order paid once you have received the payment in person.'
                  : 'Mark this order handed over once the customer has collected everything.',
              style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pending)
                  LoadingButton(
                    label: 'Mark paid',
                    loading: busyStatus == 'paid',
                    onPressed: busy ? null : () => onAction('paid'),
                  ),
                if (paid)
                  LoadingButton(
                    label: 'Mark handed over',
                    loading: busyStatus == 'fulfilled',
                    onPressed: busy ? null : () => onAction('fulfilled'),
                  ),
                OutlinedButton(
                  onPressed: busy ? null : () => onAction('cancelled'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: busy ? AppColors.border : AppColors.error),
                  ),
                  child: busyStatus == 'cancelled'
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                        )
                      : const Text('Cancel order'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: 'Customers write to your shop from Support; reply to their ticket there',
              child: TextButton.icon(
                onPressed: () => context.push('/seller/support'),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message customer'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderLineRow extends StatelessWidget {
  final SellerOrderLine line;
  const _OrderLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final petStatus = line.petStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: AppTheme.body(fontSize: 14),
                    children: [
                      TextSpan(text: line.name),
                      if (line.quantity > 1)
                        TextSpan(
                          text: '  × ${line.quantity}',
                          style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                        ),
                    ],
                  ),
                ),
                if (petStatus != null && petStatus.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    label: 'Pet is ${_petStatusLabels[petStatus] ?? petStatus}',
                    excludeSemantics: true,
                    child: StatusBadge(status: petStatus, label: _petStatusLabels[petStatus] ?? titleCase(petStatus)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(formatPrice(line.total), style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}
