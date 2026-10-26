import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/seller/seller_common.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';
import 'admin_common.dart';

const _recentDays = 30;

const _filters = <StatusFilter>[
  StatusFilter('pending', 'Pending'),
  StatusFilter('approved', 'Approved'),
  StatusFilter('suspended', 'Suspended'),
  StatusFilter('all', 'All'),
];

const _statusLabels = {
  'pending': 'Pending approval',
  'approved': 'Approved',
  'suspended': 'Suspended',
};

const _emptyMessages = {
  'pending': 'No services are waiting for approval.',
  'approved': 'No services are approved yet.',
  'suspended': 'No services are suspended.',
};

const _serviceColumns =
    'id, shop_id, category, name, description, price, duration_minutes, status, created_at, shops(name)';

String _statusOf(ServiceItem service) => service.status;

/// The services plus platform-wide activity counts for the last
/// [_recentDays] days. A count that failed to load is null (shown as a dash)
/// so a problem there never hides the approval queue.
class _ServicesData {
  final List<ServiceItem> services;
  final int? requests;
  final int? bookings;

  const _ServicesData({required this.services, required this.requests, required this.bookings});
}

Future<int?> _countSince(String table, String since) async {
  try {
    final int count = await SupabaseService.client.from(table).count().gte('created_at', since);
    return count;
  } catch (_) {
    return null;
  }
}

Future<_ServicesData> _loadServices() async {
  final since = DateTime.now().subtract(const Duration(days: _recentDays)).toUtc().toIso8601String();
  // Started first so both run together; neither can throw.
  final activity = Future.wait<int?>([
    _countSince('custom_service_requests', since),
    _countSince('service_bookings', since),
  ]);

  final rows = await fetchAllRows(() => SupabaseService.client.from('services').select(_serviceColumns));
  final services = rows.map(ServiceItem.fromJson).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final counts = await activity;
  return _ServicesData(services: services, requests: counts[0], bookings: counts[1]);
}

/// Mirrors src/pages/admin/Services.jsx: the approval queue for seller
/// services. New services start as pending and stay hidden from customers
/// until an admin approves them; approved ones can be suspended again.
class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  late final SellerQuery<_ServicesData> _query;
  String? _filter;
  int _limit = kPageSize;
  String? _busyId;
  String? _busyStatus;

  @override
  void initState() {
    super.initState();
    _query = SellerQuery<_ServicesData>(_loadServices);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _update(ServiceItem service, String next) async {
    if (_busyId != null) return;

    if (next == 'suspended') {
      final rejecting = service.status == 'pending';
      final from = service.shopName ?? 'this shop';
      final confirmed = await confirmAction(
        context,
        title: rejecting ? 'Reject this service?' : 'Suspend this service?',
        message: rejecting
            ? 'Reject "${service.name}" from $from? It will not be approved. '
                'It is marked as suspended and can be reactivated later.'
            : 'Suspend "${service.name}" from $from? It will no longer be visible to customers.',
        confirmLabel: rejecting ? 'Reject' : 'Suspend',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() {
      _busyId = service.id;
      _busyStatus = next;
    });
    // RLS filters rows silently, so updateRow checks that a row really changed;
    // matching on the status the card showed keeps a stale screen from
    // overwriting a newer decision.
    final failure = await updateRow('services', service.id, {'status': next}, match: {'status': service.status});
    if (!mounted) return;

    if (failure != null) {
      showSnack(context, failure, error: true);
      if (failure == kNothingChanged) await _query.reload();
    } else {
      showSnack(
        context,
        next == 'approved'
            ? 'Approved "${service.name}".'
            : service.status == 'pending'
                ? 'Rejected "${service.name}".'
                : 'Suspended "${service.name}".',
      );
      await _query.reload();
    }
    if (!mounted) return;
    setState(() {
      _busyId = null;
      _busyStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Services',
      heading: 'Manage services',
      subtitle: 'Review new services before customers can see or book them.',
      onRefresh: _query.reload,
      child: SellerQueryPanel<_ServicesData>(
        query: _query,
        what: 'services',
        builder: (context, data) {
          final services = data.services;
          final pendingCount = services.where((service) => service.status == 'pending').length;
          final active = _filter ?? (pendingCount > 0 ? 'pending' : 'all');
          final visible = applyStatusFilter(_filters, active, services, _statusOf);
          final shown = math.min(_limit, visible.length);
          final activityFailed = data.requests == null || data.bookings == null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardBox(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  children: [
                    _SummaryRow(label: 'Awaiting approval', value: '$pendingCount'),
                    const Divider(height: 1, color: AppColors.border),
                    _SummaryRow(
                      label: 'Custom requests, last $_recentDays days',
                      value: data.requests == null ? '–' : '${data.requests}',
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    _SummaryRow(
                      label: 'Service bookings, last $_recentDays days',
                      value: data.bookings == null ? '–' : '${data.bookings}',
                    ),
                  ],
                ),
              ),
              if (activityFailed) ...[
                const SizedBox(height: 10),
                Text(
                  "Couldn't load recent activity. Pull down to refresh.",
                  style: AppTheme.body(fontSize: 13, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 20),
              if (services.isNotEmpty) ...[
                FilterChipBar<String>(
                  options: filterOptions(_filters, services, _statusOf),
                  selected: active,
                  onSelected: (value) => setState(() {
                    _filter = value;
                    _limit = kPageSize;
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (services.isEmpty)
                const CardBox(
                  child: EmptyState(
                    title: 'No services yet',
                    description: 'Services will appear here once sellers create them.',
                  ),
                )
              else if (visible.isEmpty)
                CardBox(
                  child: EmptyState(
                    title: 'Nothing here',
                    description: _emptyMessages[active] ?? 'No services match this filter.',
                  ),
                )
              else ...[
                for (final service in visible.take(shown))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ServiceCard(
                      key: ValueKey(service.id),
                      service: service,
                      busyStatus: _busyId == service.id ? _busyStatus : null,
                      locked: _busyId != null,
                      onUpdate: (next) => _update(service, next),
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
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft))),
            const SizedBox(width: 12),
            Text(value, style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceItem service;

  /// The status being applied to this service right now (null when idle).
  final String? busyStatus;

  /// True while any service is being updated; all actions wait.
  final bool locked;
  final void Function(String status) onUpdate;

  const _ServiceCard({
    super.key,
    required this.service,
    required this.busyStatus,
    required this.locked,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final duration = formatDuration(service.durationMinutes);
    final description = (service.description ?? '').trim();

    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  service.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: service.status, label: _statusLabels[service.status] ?? titleCase(service.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${service.shopName ?? 'Unknown shop'} · ${serviceCategoryLabel(service.category)}',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              children: [
                TextSpan(
                  text: formatPrice(service.price),
                  style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
                if (duration.isNotEmpty) TextSpan(text: ' · $duration'),
                TextSpan(text: ' · Added ${formatDate(service.createdAt.toLocal())}'),
              ],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _actions(),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    Widget approve(String label) => LoadingButton(
          label: label,
          loading: busyStatus == 'approved',
          onPressed: locked ? null : () => onUpdate('approved'),
        );
    Widget stop(String label) => LoadingButton(
          label: label,
          outlined: true,
          loading: busyStatus == 'suspended',
          onPressed: locked ? null : () => onUpdate('suspended'),
        );

    switch (service.status) {
      case 'pending':
        return [approve('Approve'), stop('Reject')];
      case 'approved':
        return [stop('Suspend')];
      default:
        return [approve('Reactivate')];
    }
  }
}
