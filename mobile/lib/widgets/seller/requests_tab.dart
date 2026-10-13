import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../shared_widgets.dart';
import '../ui_kit.dart';
import 'quote_sheet.dart';
import 'request_card.dart';
import 'seller_common.dart';

const _requestFilters = <StatusFilter>[
  StatusFilter('open', 'Open'),
  StatusFilter('quoted', 'Quoted'),
  StatusFilter('accepted', 'Accepted'),
  StatusFilter('ended', 'Declined & closed', statuses: ['declined', 'cancelled', 'closed']),
  StatusFilter('all', 'All'),
];

String _statusOf(CustomServiceRequest request) => request.status;

/// "Custom requests" tab: open requests from customers, plus the ones this
/// shop has quoted. Mirrors src/components/seller/RequestsTab.jsx.
class RequestsTab extends StatefulWidget {
  final String shopId;
  final bool readOnly;
  final SellerQuery<List<CustomServiceRequest>> query;

  const RequestsTab({super.key, required this.shopId, required this.readOnly, required this.query});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  String? _filter;

  void _openQuote(CustomServiceRequest request) {
    showQuoteSheet(context, request: request, shopId: widget.shopId, onSent: _handleSent);
  }

  void _handleSent(String message) {
    if (!mounted) return;
    showSnack(context, message);
    widget.query.reload();
  }

  @override
  Widget build(BuildContext context) {
    return SellerQueryPanel<List<CustomServiceRequest>>(
      query: widget.query,
      what: 'custom requests',
      builder: (context, requests) {
        final openCount = requests.where((request) => request.status == 'open').length;
        final active = _filter ?? (openCount > 0 ? 'open' : 'all');
        final visible = applyStatusFilter(_requestFilters, active, requests, _statusOf);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Customers describe what they need and any approved shop can send a quote. They then accept or decline it.',
              style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            FilterChipBar<String>(
              options: filterOptions(_requestFilters, requests, _statusOf),
              selected: active,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              CardBox(
                child: EmptyState(
                  title: requests.isEmpty ? 'No custom requests' : 'Nothing here',
                  description: requests.isEmpty
                      ? 'New requests from customers show up here so you can send a quote.'
                      : 'No requests match this filter.',
                ),
              )
            else
              for (final request in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RequestCard(
                    key: ValueKey(request.id),
                    request: request,
                    shopId: widget.shopId,
                    readOnly: widget.readOnly,
                    onQuote: _openQuote,
                    onChanged: widget.query.reload,
                  ),
                ),
          ],
        );
      },
    );
  }
}
