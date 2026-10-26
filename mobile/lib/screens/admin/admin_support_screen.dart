import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin/admin_ticket_card.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

/// Mirrors src/pages/admin/Support.jsx: every support ticket across the
/// platform, with status filters and an expandable message thread + reply.
///
/// Shop applications (tickets from the Sell on PETSTA form: subject
/// "Shop application: ...", no shop) are called out with a banner, their own
/// "New applications" filter and a badge on each ticket.
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

/// Ticket counts for the filter chips and the applications banner. A count
/// that failed to load is null (the chip simply shows no number).
class _TicketCounts {
  final int? all;
  final Map<String, int?> byStatus;

  /// Shop applications still open or in progress.
  final int? applications;

  const _TicketCounts({required this.all, required this.byStatus, required this.applications});
}

const _applicationFilter = 'applications';

Future<int?> _safeCount(Future<int> Function() run) async {
  try {
    return await run();
  } catch (_) {
    return null;
  }
}

Future<_TicketCounts> _loadCounts() async {
  final client = SupabaseService.client;
  final results = await Future.wait<int?>([
    _safeCount(() => client.from('support_tickets').count()),
    for (final status in kAdminTicketStatuses)
      _safeCount(() => client.from('support_tickets').count().eq('status', status)),
    _safeCount(
      () => client
          .from('support_tickets')
          .count()
          .ilike('subject', '$kShopApplicationPrefix%')
          .isFilter('shop_id', null)
          .inFilter('status', ['open', 'in_progress']),
    ),
  ]);
  return _TicketCounts(
    all: results[0],
    byStatus: {
      for (var i = 0; i < kAdminTicketStatuses.length; i++) kAdminTicketStatuses[i]: results[i + 1],
    },
    applications: results.last,
  );
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  late PagedQuery<AdminTicket> _query;
  late final SellerQuery<_TicketCounts> _counts;
  String _filter = 'all';

  /// Statuses saved from the cards since the list was last loaded.
  final Map<String, String> _savedStatus = {};

  @override
  void initState() {
    super.initState();
    _query = _buildQuery(_filter);
    _counts = SellerQuery<_TicketCounts>(_loadCounts);
  }

  @override
  void dispose() {
    _query.dispose();
    _counts.dispose();
    super.dispose();
  }

  PagedQuery<AdminTicket> _buildQuery(String filter) {
    return PagedQuery<AdminTicket>((from, to) async {
      var query = SupabaseService.client.from('support_tickets').select(kAdminTicketColumns);
      if (filter == _applicationFilter) {
        query = query
            .ilike('subject', '$kShopApplicationPrefix%')
            .isFilter('shop_id', null)
            .inFilter('status', ['open', 'in_progress']);
      } else if (filter != 'all') {
        query = query.eq('status', filter);
      }
      final rows = await query.order('created_at', ascending: false).order('id').range(from, to);
      return rows.map(AdminTicket.fromJson).toList();
    });
  }

  void _selectFilter(String value) {
    if (value == _filter) return;
    final old = _query;
    setState(() {
      _filter = value;
      _query = _buildQuery(value);
      _savedStatus.clear();
    });
    old.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([_query.reload(), _counts.reload()]);
    if (!mounted) return;
    setState(_savedStatus.clear);
  }

  void _statusSaved(AdminTicket ticket, String next) {
    setState(() => _savedStatus[ticket.id] = next);
    // Chip numbers (and the applications banner) changed.
    _counts.reload();
  }

  List<FilterOption<String>> _options(_TicketCounts? counts) {
    return [
      FilterOption('all', 'All', count: counts?.all),
      FilterOption(_applicationFilter, 'New applications', count: counts?.applications),
      for (final status in kAdminTicketStatuses)
        FilterOption(status, adminTicketStatusLabel(status), count: counts?.byStatus[status]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).profile?.id;

    return AdminScaffold(
      title: 'Support',
      heading: 'Support tickets',
      subtitle: 'Customer requests and new shop applications.',
      onRefresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListenableBuilder(
            listenable: _counts,
            builder: (context, _) {
              final waiting = _counts.data?.applications ?? 0;
              if (waiting == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ApplicationsBanner(
                  count: waiting,
                  showing: _filter == _applicationFilter,
                  onView: () => _selectFilter(_applicationFilter),
                ),
              );
            },
          ),
          ListenableBuilder(
            listenable: _counts,
            builder: (context, _) => FilterChipBar<String>(
              options: _options(_counts.data),
              selected: _filter,
              onSelected: _selectFilter,
            ),
          ),
          const SizedBox(height: 16),
          PagedQueryPanel<AdminTicket>(
            query: _query,
            what: 'tickets',
            builder: (context, tickets) {
              if (tickets.isEmpty) {
                return CardBox(child: _emptyState());
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final ticket in tickets)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AdminTicketCard(
                        key: ValueKey(ticket.id),
                        ticket: _savedStatus.containsKey(ticket.id)
                            ? ticket.withStatus(_savedStatus[ticket.id]!)
                            : ticket,
                        currentUserId: currentUserId,
                        onStatusChanged: (next) => _statusSaved(ticket, next),
                        onStale: _refresh,
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

  Widget _emptyState() {
    switch (_filter) {
      case 'all':
        return const EmptyState(
          title: 'No support tickets yet',
          description: 'Customer support tickets and shop applications will show up here.',
        );
      case _applicationFilter:
        return const EmptyState(
          title: 'No new applications',
          description: 'Shop applications that still need a decision will show up here.',
        );
      default:
        return EmptyState(
          title: 'Nothing here',
          description: 'No ${adminTicketStatusLabel(_filter).toLowerCase()} tickets.',
        );
    }
  }
}

/// Call-out above the list while shop applications are waiting for a decision.
class _ApplicationsBanner extends StatelessWidget {
  final int count;
  final bool showing;
  final VoidCallback onView;

  const _ApplicationsBanner({required this.count, required this.showing, required this.onView});

  @override
  Widget build(BuildContext context) {
    final text = count == 1 ? '1 new shop application to review' : '$count new shop applications to review';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.adminAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.adminAccent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined, size: 20, color: AppColors.adminAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(text, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          if (!showing)
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              child: const Text('Review'),
            ),
        ],
      ),
    );
  }
}
