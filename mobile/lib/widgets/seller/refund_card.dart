import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

/// One refund request on the seller's list (Approve / Reject while pending).
/// Mirrors RefundCard in src/pages/seller/Refunds.jsx.
class RefundCard extends StatelessWidget {
  final RefundRequest refund;
  final CustomerInfo? customer;
  final bool readOnly;

  /// True while a decision on this refund is being saved.
  final bool busy;

  /// Called with 'approved' or 'rejected'.
  final void Function(String status) onDecide;

  const RefundCard({
    super.key,
    required this.refund,
    required this.customer,
    required this.readOnly,
    required this.busy,
    required this.onDecide,
  });

  @override
  Widget build(BuildContext context) {
    final pending = refund.status == 'pending';
    final label = (refund.itemLabel ?? '').trim();
    final notes = (refund.notes ?? '').trim();
    final resolvedAt = refund.resolvedAt;

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
                      label.isEmpty ? 'Refund request' : label,
                      style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order ${shortId(refund.orderId)} · Requested ${formatOrderDate(refund.createdAt)}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  StatusBadge(status: refund.status),
                  const SizedBox(height: 8),
                  Text(
                    formatPrice(refund.amount),
                    style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SellerMetaRow('Customer', child: SellerCustomerContact(customer: customer)),
          if (!pending && resolvedAt != null) SellerMetaRow('Resolved', text: formatOrderDate(resolvedAt)),
          const SizedBox(height: 10),
          SellerNoteBox(label: 'Reason', text: refund.reason),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            SellerNoteBox(label: 'Notes', text: notes),
          ],
          if (pending && !readOnly) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: busy ? null : () => onDecide('approved'), child: const Text('Approve')),
                OutlinedButton(onPressed: busy ? null : () => onDecide('rejected'), child: const Text('Reject')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
