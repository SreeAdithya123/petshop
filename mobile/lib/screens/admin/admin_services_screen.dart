import 'package:flutter/material.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _recentDays = 30;

const _emptyMessages = {
  'pending': 'No services are waiting for approval.',
  'approved': 'No services are approved yet.',
  'suspended': 'No services are suspended.',
  'all': 'No services yet.',
};

/// Platform-wide activity counts for the last [_recentDays] days.
class _Activity {
  final int requests;
  final int bookings;
  final String? error;

  const _Activity({this.requests = 0, this.bookings = 0, this.error});
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
  List<ServiceItem> _services = const [];
  _Activity? _activity;
  bool _loading = true;
  bool _loaded = false;
  String? _error;
  String _tab = 'pending';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<ServiceItem>> _fetchServices() async {
    final rows = await SupabaseService.client
        .from('services')
        .select('id, shop_id, category, name, description, price, duration_minutes, status, created_at, shops(name)')
        .order('created_at', ascending: false);
    return rows.map(ServiceItem.fromJson).toList();
  }

  Future<int> _countSince(String table, String since) async {
    final int count = await SupabaseService.client.from(table).count().gte('created_at', since);
    return count;
  }

  /// Never throws: a failed activity count only dims those tiles.
  Future<_Activity> _fetchActivity() async {
    final since = DateTime.now().subtract(const Duration(days: _recentDays)).toUtc().toIso8601String();
    try {
      final counts = await Future.wait<int>([
        _countSince('custom_service_requests', since),
        _countSince('service_bookings', since),
      ]);
      return _Activity(requests: counts[0], bookings: counts[1]);
    } catch (e) {
      return _Activity(error: errorText(e));
    }
  }

  Future<void> _load() async {
    final activityFuture = _fetchActivity();
    try {
      final services = await _fetchServices();
      final activity = await activityFuture;
      if (!mounted) return;
      setState(() {
        _services = services;
        _activity = activity;
        _loaded = true;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (_loaded) {
        // Keep the queue on screen; just report that the refresh failed.
        showSnack(context, errorText(e), error: true);
      } else {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  Future<void> _updateStatus(ServiceItem service, String nextStatus, {String? confirmMessage}) async {
    if (confirmMessage != null) {
      final confirmed = await confirmAction(
        context,
        title: 'Suspend this service?',
        message: confirmMessage,
        confirmLabel: 'Suspend',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busyId = service.id);
    try {
      final rows = await SupabaseService.client
          .from('services')
          .update({'status': nextStatus})
          .eq('id', service.id)
          .select('id');
      if (!mounted) return;
      if (rows.isEmpty) {
        // RLS filters rows silently, so "no error" alone doesn't prove the update landed.
        showSnack(context, "That didn't go through — its status may have changed.", error: true);
      } else {
        showSnack(context, nextStatus == 'approved' ? 'Approved "${service.name}".' : 'Suspended "${service.name}".');
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Map<String, int> get _counts {
    final counts = <String, int>{'pending': 0, 'approved': 0, 'suspended': 0, 'all': _services.length};
    for (final service in _services) {
      if (counts.containsKey(service.status)) counts[service.status] = counts[service.status]! + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(title: 'Services', child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) return const LoadingView(label: 'Loading services…');
    if (_error != null) return _LoadFailure(message: "Couldn't load services: $_error", onRetry: _retry);

    final counts = _counts;
    final visible = _tab == 'all' ? _services : _services.where((service) => service.status == _tab).toList();
    final activity = _activity;
    final activityFailed = activity?.error != null;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: [
          const ScreenHeader(
            title: 'Manage services',
            subtitle: 'Review new services before customers can see or book them.',
          ),
          const SizedBox(height: 20),
          CardBox(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                _SummaryRow(label: 'Awaiting approval', value: '${counts['pending']}'),
                const Divider(height: 1, color: AppColors.border),
                _SummaryRow(
                  label: 'Custom requests, last $_recentDays days',
                  value: activityFailed ? '—' : '${activity?.requests ?? 0}',
                ),
                const Divider(height: 1, color: AppColors.border),
                _SummaryRow(
                  label: 'Service bookings, last $_recentDays days',
                  value: activityFailed ? '—' : '${activity?.bookings ?? 0}',
                ),
              ],
            ),
          ),
          if (activityFailed) ...[
            const SizedBox(height: 10),
            Text(
              "Couldn't load recent activity: ${activity!.error}",
              style: AppTheme.body(fontSize: 13, color: AppColors.error),
            ),
          ],
          const SizedBox(height: 20),
          FilterChipBar<String>(
            options: [
              FilterOption('pending', 'Pending', count: counts['pending']),
              FilterOption('approved', 'Approved', count: counts['approved']),
              FilterOption('suspended', 'Suspended', count: counts['suspended']),
              FilterOption('all', 'All', count: counts['all']),
            ],
            selected: _tab,
            onSelected: (value) => setState(() => _tab = value),
          ),
          const SizedBox(height: 16),
          if (_services.isEmpty)
            const EmptyState(
              title: 'No services yet',
              description: 'Services will appear here once sellers create them.',
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                _emptyMessages[_tab] ?? 'No services.',
                textAlign: TextAlign.center,
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
            )
          else
            for (final service in visible) ...[
              _ServiceCard(
                service: service,
                busy: _busyId == service.id,
                onApprove: () => _updateStatus(service, 'approved'),
                onSuspend: () => _updateStatus(
                  service,
                  'suspended',
                  confirmMessage: service.status == 'approved'
                      ? 'Suspend "${service.name}" from ${service.shopName ?? 'this shop'}? '
                          'It will no longer be visible to customers.'
                      : 'Suspend "${service.name}" from ${service.shopName ?? 'this shop'}? '
                          'It will not be approved.',
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft))),
          const SizedBox(width: 12),
          Text(value, style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceItem service;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onSuspend;

  const _ServiceCard({
    required this.service,
    required this.busy,
    required this.onApprove,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    final duration = formatDuration(service.durationMinutes);
    final description = (service.description ?? '').trim();

    final approveStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size(0, 36),
      textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
    );
    final suspendStyle = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      minimumSize: const Size(0, 36),
      textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
    );

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
                  style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: service.status),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (service.status != 'approved')
                ElevatedButton(
                  style: approveStyle,
                  onPressed: busy ? null : onApprove,
                  child: const Text('Approve'),
                ),
              if (service.status == 'approved' || service.status == 'pending')
                OutlinedButton(
                  style: suspendStyle,
                  onPressed: busy ? null : onSuspend,
                  child: const Text('Suspend'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Centered "couldn't load" note with a retry button.
class _LoadFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppTheme.body(color: AppColors.error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
