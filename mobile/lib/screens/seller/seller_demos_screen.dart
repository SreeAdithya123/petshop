import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../utils/format.dart';
import '../../widgets/seller/demo_card.dart';
import '../../widgets/seller/demo_respond_sheet.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/Demos.jsx: demo requests on this shop's pets, with
/// a respond sheet (approve / reject / complete / update).
class SellerDemosScreen extends StatelessWidget {
  const SellerDemosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Demo requests',
      subtitle: 'Customers who want to meet or video-call one of your pets before they decide.',
      builder: (context, shop) => _DemosWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('approved', 'Approved'),
  StatusFilter('completed', 'Completed'),
  StatusFilter('ended', 'Rejected & cancelled', statuses: ['rejected', 'cancelled']),
  StatusFilter('all', 'All'),
];

String _statusOf(DemoRequest demo) => demo.status;

Future<WithCustomers<DemoRequest>> _fetchDemos(String shopId) async {
  final data = await SupabaseService.client
      .from('demo_requests')
      .select()
      .eq('shop_id', shopId)
      .order('created_at', ascending: false);
  final rows = data.map(DemoRequest.fromJson).toList();
  return attachCustomers<DemoRequest>(rows, (demo) => demo.customerId);
}

class _DemoStats {
  final int pending;
  final int upcoming;
  final int completedThisMonth;
  const _DemoStats(this.pending, this.upcoming, this.completedThisMonth);
}

_DemoStats _summarize(List<DemoRequest> rows) {
  final today = toDateParam(DateTime.now());
  final thisMonth = today.substring(0, 7);
  // The day a demo is held on: what the shop confirmed, else what the customer asked for.
  String heldOn(DemoRequest demo) => toDateParam(demo.confirmedDate ?? demo.preferredDate);

  return _DemoStats(
    rows.where((demo) => demo.status == 'pending').length,
    rows.where((demo) => demo.status == 'approved' && heldOn(demo).compareTo(today) >= 0).length,
    rows.where((demo) => demo.status == 'completed' && heldOn(demo).startsWith(thisMonth)).length,
  );
}

class _DemosWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _DemosWorkspace({required this.shop});

  @override
  ConsumerState<_DemosWorkspace> createState() => _DemosWorkspaceState();
}

class _DemosWorkspaceState extends ConsumerState<_DemosWorkspace> {
  late final SellerQuery<WithCustomers<DemoRequest>> _query;
  String? _filter;

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<WithCustomers<DemoRequest>>(() => _fetchDemos(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _respond(DemoRequest demo, CustomerInfo? customer) {
    showDemoRespondSheet(
      context,
      demo: demo,
      customer: customer,
      onDone: _handleDone,
    );
  }

  void _handleDone() {
    if (!mounted) return;
    showSnack(context, 'Your response was saved and the customer can see it.');
    _query.reload();
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final readOnly = widget.shop.status != 'approved';

    return SellerQueryPanel<WithCustomers<DemoRequest>>(
      query: _query,
      what: 'demo requests',
      builder: (context, data) {
        final rows = data.rows;
        final stats = _summarize(rows);
        // Open on "Pending" when there is something to answer, otherwise show everything.
        final active = _filter ?? (stats.pending > 0 ? 'pending' : 'all');
        final visible = applyStatusFilter(_filters, active, rows, _statusOf);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SellerSummaryTile(label: 'Pending', value: '${stats.pending}')),
                const SizedBox(width: 12),
                Expanded(child: SellerSummaryTile(label: 'Upcoming approved', value: '${stats.upcoming}')),
              ],
            ),
            const SizedBox(height: 12),
            SellerSummaryTile(label: 'Completed this month', value: '${stats.completedThisMonth}'),
            const SizedBox(height: 20),
            FilterChipBar<String>(
              options: filterOptions(_filters, rows, _statusOf),
              selected: active,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 16),
            if (data.customersError != null) ...[
              NoticeBox.error(message: "Couldn't load customer names: ${data.customersError}"),
              const SizedBox(height: 12),
            ],
            if (visible.isEmpty)
              CardBox(
                child: EmptyState(
                  title: rows.isEmpty ? 'No demo requests yet' : 'Nothing here',
                  description: rows.isEmpty
                      ? 'When a customer asks to see one of your pets, the request shows up here.'
                      : 'No demo requests match this filter.',
                ),
              )
            else
              for (final demo in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DemoCard(
                    key: ValueKey(demo.id),
                    demo: demo,
                    customer: data.customers[demo.customerId],
                    readOnly: readOnly,
                    onRespond: () => _respond(demo, data.customers[demo.customerId]),
                  ),
                ),
          ],
        );
      },
    );
  }
}
