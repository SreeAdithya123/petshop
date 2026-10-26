import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../utils/format.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/seller/support_thread.dart';
import '../../widgets/seller_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/seller/Support.jsx: support tickets addressed to the
/// signed-in seller's shop, with an expandable message thread + reply box.
class SellerSupportScreen extends StatelessWidget {
  const SellerSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SellerScaffold(
      title: 'Support',
      subtitle: 'Questions from customers about your shop. Reply here to message a customer.',
      builder: (context, shop) => _SupportWorkspace(shop: shop),
    );
  }
}

const _filters = <StatusFilter>[
  StatusFilter('all', 'All'),
  StatusFilter('open', 'Open'),
  StatusFilter('in_progress', 'In progress'),
  StatusFilter('resolved', 'Resolved'),
  StatusFilter('closed', 'Closed'),
];

String _statusOf(SupportTicketRow ticket) => ticket.status;

Future<List<SupportTicketRow>> _fetchTickets(String shopId) async {
  final rows = await fetchAllRows(
    () => SupabaseService.client.from('support_tickets').select(kTicketColumns).eq('shop_id', shopId),
  );
  final tickets = rows.map(SupportTicketRow.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return tickets;
}

class _SupportWorkspace extends ConsumerStatefulWidget {
  final Shop shop;
  const _SupportWorkspace({required this.shop});

  @override
  ConsumerState<_SupportWorkspace> createState() => _SupportWorkspaceState();
}

class _SupportWorkspaceState extends ConsumerState<_SupportWorkspace> {
  late final SellerQuery<List<SupportTicketRow>> _query;
  String _filter = 'all';
  int _limit = kPageSize;

  /// Statuses saved from this screen, shown until the next reload confirms them.
  final Map<String, String> _statuses = {};

  @override
  void initState() {
    super.initState();
    final shopId = widget.shop.id;
    _query = SellerQuery<List<SupportTicketRow>>(() => _fetchTickets(shopId));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _handleStatusChanged(SupportTicketRow ticket, String status) {
    setState(() => _statuses[ticket.id] = status);
    _query.reload().then((_) {
      if (mounted && _query.error == null) setState(_statuses.clear);
    });
  }

  @override
  Widget build(BuildContext context) {
    listenForShopRefresh(ref, _query.reload);
    final userId = ref.watch(authControllerProvider).profile?.id;

    return SellerQueryPanel<List<SupportTicketRow>>(
      query: _query,
      what: 'support tickets',
      builder: (context, loaded) {
        final tickets = [
          for (final ticket in loaded)
            _statuses.containsKey(ticket.id) ? ticket.withStatus(_statuses[ticket.id]!) : ticket,
        ];
        final visible = applyStatusFilter(_filters, _filter, tickets, _statusOf);
        final shown = math.min(_limit, visible.length);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (tickets.isNotEmpty) ...[
              FilterChipBar<String>(
                options: filterOptions(_filters, tickets, _statusOf),
                selected: _filter,
                onSelected: (value) => setState(() {
                  _filter = value;
                  _limit = kPageSize;
                }),
              ),
              const SizedBox(height: 16),
            ],
            if (tickets.isEmpty)
              const CardBox(
                child: EmptyState(
                  title: 'No support tickets yet',
                  description: 'Customer questions about your shop will show up here.',
                ),
              )
            else if (visible.isEmpty)
              const CardBox(
                child: EmptyState(title: 'Nothing here', description: 'No tickets match this filter.'),
              )
            else ...[
              for (final ticket in visible.take(shown))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SupportTicketCard(
                    key: ValueKey(ticket.id),
                    ticket: ticket,
                    subtitle:
                        '${ticket.customerName.isEmpty ? 'Customer' : ticket.customerName} · ${formatDateTime(ticket.createdAt)}',
                    currentUserId: userId,
                    onStatusChanged: (status) => _handleStatusChanged(ticket, status),
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
