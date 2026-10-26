import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../utils/format.dart';
import '../../widgets/seller/refund_card.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/Refunds.jsx: refund requests on orders that
/// include this shop's items. PETSTA records the decision but never moves money.
class SellerRefundsScreen extends StatelessWidget {
  const SellerRefundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Refunds',
      subtitle: 'Refund requests from customers on orders that include your items.',
      builder: (context, shop) => _RefundsWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('approved', 'Approved'),
  StatusFilter('rejected', 'Rejected'),
  StatusFilter('all', 'All'),
];

const _approveNotice =
    'Approving records that you will refund the customer in person or off-platform — PETSTA does not move money, so you return the payment to the customer directly.';
const _rejectNotice = "The customer will see this request as rejected. The decision can't be changed afterwards.";

String _statusOf(RefundRequest refund) => refund.status;

Future<WithCustomers<RefundRequest>> _fetchRefunds(String shopId) async {
  final data = await fetchAllRows(() => SupabaseService.client.from('refunds').select().eq('shop_id', shopId));
  final rows = data.map(RefundRequest.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return attachCustomers<RefundRequest>(rows, (refund) => refund.customerId);
}

class _RefundsWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _RefundsWorkspace({required this.shop});

  @override
  ConsumerState<_RefundsWorkspace> createState() => _RefundsWorkspaceState();
}

class _RefundsWorkspaceState extends ConsumerState<_RefundsWorkspace> {
  late final SellerQuery<WithCustomers<RefundRequest>> _query;
  String? _filter;
  int _limit = kPageSize;
  String? _busyId;
  String? _busyStatus;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<WithCustomers<RefundRequest>>(() => _fetchRefunds(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _decide(RefundRequest refund, String status) async {
    if (_busyId != null) return;
    final approving = status == 'approved';
    final label = (refund.itemLabel ?? '').trim();
    final summary = [
      label.isEmpty ? 'Refund request' : label,
      formatPrice(refund.amount),
      'Order ${shortId(refund.orderId)}',
    ].join(' · ');

    final confirmed = await confirmAction(
      context,
      title: approving ? 'Approve this refund?' : 'Reject this refund?',
      message: '$summary\n\n${approving ? _approveNotice : _rejectNotice}',
      confirmLabel: approving ? 'Approve refund' : 'Reject refund',
      destructive: !approving,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busyId = refund.id;
      _busyStatus = status;
    });
    // Guard on "pending" so a decision made elsewhere in the meantime isn't overwritten.
    final failure = await updateRow(
      'refunds',
      refund.id,
      {'status': status},
      match: {'status': 'pending'},
    );
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _busyStatus = null;
    });

    if (failure != null) {
      showSnack(context, failure, error: true);
      // A stale card (decided elsewhere) should show its real state.
      if (failure == kNothingChanged) _query.reload();
      return;
    }
    showSnack(
      context,
      approving ? 'Refund approved. Remember to return the payment to the customer directly.' : 'Refund rejected.',
    );
    _query.reload();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final readOnly = widget.shop.status != 'approved';

    return SellerQueryPanel<WithCustomers<RefundRequest>>(
      query: _query,
      what: 'refund requests',
      builder: (context, data) {
        final rows = data.rows;
        final pendingCount = rows.where((refund) => refund.status == 'pending').length;
        final approvedTotal = rows
            .where((refund) => refund.status == 'approved')
            .fold<num>(0, (sum, refund) => sum + refund.amount);
        // Open on "Pending" when there is something to decide, otherwise show everything.
        final active = _filter ?? (pendingCount > 0 ? 'pending' : 'all');
        final visible = applyStatusFilter(_filters, active, rows, _statusOf);
        final shown = math.min(_limit, visible.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const NoticeBox(
              message:
                  'How refunds work: PETSTA records your decision but does not move money. If you approve a refund, return the payment to the customer directly.',
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SellerSummaryTile(label: 'Pending', value: '$pendingCount')),
                const SizedBox(width: 12),
                Expanded(child: SellerSummaryTile(label: 'Total approved', value: formatPrice(approvedTotal))),
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
                  title: rows.isEmpty ? 'No refund requests' : 'Nothing here',
                  description: rows.isEmpty
                      ? 'If a customer asks for a refund on an order that includes your items, it shows up here.'
                      : 'No refund requests match this filter.',
                ),
              )
            else ...[
              for (final refund in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RefundCard(
                    key: ValueKey(refund.id),
                    refund: refund,
                    customer: data.customers[refund.customerId],
                    readOnly: readOnly,
                    busy: _busyId == refund.id,
                    busyStatus: _busyId == refund.id ? _busyStatus : null,
                    onDecide: (status) => _decide(refund, status),
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
