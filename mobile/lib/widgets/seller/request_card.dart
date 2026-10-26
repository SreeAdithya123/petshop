import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

const _statusLabels = {
  'open': 'Awaiting your quote',
  'quoted': 'Quote sent',
  'accepted': 'Accepted by customer',
  'declined': 'Declined by customer',
  'cancelled': 'Cancelled by customer',
  'closed': 'Closed',
};

/// One custom service request. Deliberately shows no customer identity or
/// contact details (the query doesn't even select customer_id). Mirrors
/// src/components/seller/RequestCard.jsx.
class RequestCard extends StatefulWidget {
  final CustomServiceRequest request;
  final String shopId;
  final bool readOnly;

  /// Opens the quote sheet (first quote, or a revision while "quoted").
  final void Function(CustomServiceRequest request) onQuote;

  /// Called after a successful change so the list can reload.
  final VoidCallback onChanged;

  const RequestCard({
    super.key,
    required this.request,
    required this.shopId,
    required this.readOnly,
    required this.onQuote,
    required this.onChanged,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard> {
  bool _busy = false;
  String? _error;

  Future<void> _markClosed() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await updateRow(
      'custom_service_requests',
      widget.request.id,
      {'status': 'closed'},
      match: {'status': 'accepted'},
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
    });
    if (failure == null || failure == kNothingChanged) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final mine = request.shopId == widget.shopId;
    final description = request.description.trim();
    final petName = (request.petName ?? '').trim();
    final petSpecies = (request.petSpecies ?? '').trim();
    final pet = [
      if (petName.isNotEmpty) petName,
      if (petSpecies.isNotEmpty) '($petSpecies)',
    ].join(' ');
    final category = request.category;
    final preferredDate = request.preferredDate;
    final budget = request.budget;
    final quotedPrice = request.quotedPrice;
    final respondedAt = request.respondedAt;
    final message = (request.responseMessage ?? '').trim();

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
                    Text(request.title, style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      'Requested ${formatOrderDate(request.createdAt)}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: request.status, label: _statusLabels[request.status]),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(description, style: AppTheme.body(fontSize: 14)),
          ],
          const SizedBox(height: 10),
          if (category != null && category.isNotEmpty) SellerMetaRow('Category', text: serviceCategoryLabel(category)),
          if (pet.isNotEmpty) SellerMetaRow('Pet', text: pet),
          if (preferredDate != null) SellerMetaRow('Preferred date', text: formatDate(preferredDate)),
          if (budget != null) SellerMetaRow('Customer budget', text: formatPrice(budget)),
          if (mine && quotedPrice != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: AppTheme.body(fontSize: 14),
                      children: [
                        TextSpan(text: 'Your quote: ', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                        TextSpan(
                          text: formatPrice(quotedPrice),
                          style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent),
                        ),
                        if (respondedAt != null)
                          TextSpan(
                            text: ' · ${formatOrderDate(respondedAt)}',
                            style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                          ),
                      ],
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(message, style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            NoticeBox.error(message: _error!),
          ],
          if (!widget.readOnly) ..._actions(request, mine),
        ],
      ),
    );
  }

  List<Widget> _actions(CustomServiceRequest request, bool mine) {
    Widget? content;
    if (request.status == 'open') {
      content = Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(onPressed: () => widget.onQuote(request), child: const Text('Send quote')),
      );
    } else if (request.status == 'quoted' && mine) {
      content = Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(onPressed: () => widget.onQuote(request), child: const Text('Revise quote')),
          Text(
            'Waiting for the customer to accept or decline.',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      );
    } else if (request.status == 'accepted' && mine) {
      content = Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          LoadingButton(label: 'Mark closed', loading: _busy, onPressed: _markClosed),
          Text(
            'Close this once you have delivered the service.',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      );
    }
    if (content == null) return const [];
    return [
      const SizedBox(height: 12),
      const Divider(height: 1, color: AppColors.border),
      const SizedBox(height: 12),
      content,
    ];
  }
}
