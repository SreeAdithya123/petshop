import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

/// One demo request on the seller's list. Mirrors
/// src/components/seller/DemoCard.jsx.
class DemoCard extends StatelessWidget {
  final DemoRequest demo;
  final CustomerInfo? customer;
  final bool readOnly;
  final VoidCallback onRespond;

  const DemoCard({
    super.key,
    required this.demo,
    required this.customer,
    required this.readOnly,
    required this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    final petDetails = [demo.petBreed, demo.petSpecies].where((part) => part != null && part.isNotEmpty).join(' · ');
    final subtitle = [
      if (petDetails.isNotEmpty) petDetails,
      'Requested ${formatOrderDate(demo.createdAt)}',
    ].join(' · ');
    final pending = demo.status == 'pending';
    final canRespond = !readOnly && (pending || demo.status == 'approved');
    final confirmedTime = (demo.confirmedTime ?? '').trim();
    final hasConfirmed = demo.confirmedDate != null || confirmedTime.isNotEmpty;
    final meetLink = (demo.meetLink ?? '').trim();
    final message = (demo.message ?? '').trim();
    final note = (demo.sellerNote ?? '').trim();

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
                      demo.petName ?? 'Pet',
                      style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: demo.status, label: pending ? 'Awaiting your response' : null),
            ],
          ),
          const SizedBox(height: 12),
          SellerMetaRow('Customer', child: SellerCustomerContact(customer: customer)),
          SellerMetaRow('Customer asked for', text: formatSlot(demo.preferredDate, demo.preferredTime)),
          SellerMetaRow('How', text: modeLabel(demo.mode)),
          if (hasConfirmed)
            SellerMetaRow('Confirmed for', text: formatSlot(demo.confirmedDate, confirmedTime)),
          if (meetLink.isNotEmpty) SellerMetaRow('Video link', child: SellerVideoLink(meetLink)),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            SellerNoteBox(label: 'Customer message', text: message),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            SellerNoteBox(label: 'Your note', text: note),
          ],
          if (canRespond) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: pending
                  ? ElevatedButton(onPressed: onRespond, child: const Text('Respond'))
                  : OutlinedButton(onPressed: onRespond, child: const Text('Complete or update')),
            ),
          ],
        ],
      ),
    );
  }
}
