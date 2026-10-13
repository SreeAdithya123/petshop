import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../state/catalog_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

const _demoColumns =
    'id, customer_id, pet_id, shop_id, pet_name, pet_breed, pet_species, shop_name, preferred_date, preferred_time, mode, message, status, meet_link, seller_note, confirmed_date, confirmed_time, created_at';

const _activeStatuses = ['pending', 'approved'];
const _modeLabels = {'video': 'Video call', 'in_person': 'In person'};

enum _DemoFilter { all, active, past }

bool _isActive(DemoRequest demo) => _activeStatuses.contains(demo.status);

bool _matches(_DemoFilter filter, DemoRequest demo) {
  switch (filter) {
    case _DemoFilter.all:
      return true;
    case _DemoFilter.active:
      return _isActive(demo);
    case _DemoFilter.past:
      return !_isActive(demo);
  }
}

/// Mirrors src/pages/account/AccountDemos.jsx: the customer's demo requests
/// with a small progress stepper, the shop's note / video link, and cancel.
class AccountDemosScreen extends StatelessWidget {
  const AccountDemosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/demos',
      title: 'Demo requests',
      subtitle:
          "Follow the demos you've asked for, from request to confirmation. The shop confirms the meeting details with you.",
      builder: (context, profile) => _DemosBody(key: ValueKey(profile.id), userId: profile.id),
    );
  }
}

class _DemosBody extends ConsumerStatefulWidget {
  final String userId;
  const _DemosBody({super.key, required this.userId});

  @override
  ConsumerState<_DemosBody> createState() => _DemosBodyState();
}

class _DemosBodyState extends ConsumerState<_DemosBody> {
  List<DemoRequest>? _demos;
  String? _loadError;
  _DemoFilter _filter = _DemoFilter.all;
  String? _cancellingId;
  String? _cancelErrorId;
  String _cancelError = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _retryLoad() {
    setState(() {
      _demos = null;
      _loadError = null;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await SupabaseService.client
          .from('demo_requests')
          .select(_demoColumns)
          .eq('customer_id', widget.userId)
          .order('created_at', ascending: false);
      final demos = [for (final row in rows) DemoRequest.fromJson(row)];
      if (!mounted) return;
      setState(() {
        _demos = demos;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (_demos != null) {
        // A background refresh failed: keep the list on screen.
        showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() => _loadError = errorText(error));
    }
  }

  Future<void> _cancel(DemoRequest demo) async {
    final petName = _petName(demo, fallback: 'this pet');
    final confirmed = await confirmAction(
      context,
      title: 'Cancel demo request?',
      message: 'Cancel your demo request for $petName?',
      confirmLabel: 'Cancel request',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _cancellingId = demo.id;
      _cancelErrorId = null;
      _cancelError = '';
    });
    try {
      final rows = await SupabaseService.client
          .from('demo_requests')
          .update({'status': 'cancelled'})
          .eq('id', demo.id)
          .select('id');
      if (!mounted) return;
      if (rows.isEmpty) {
        // Nothing changed: the shop most likely just completed or rejected
        // it, so show the latest.
        setState(() {
          _cancellingId = null;
          _cancelErrorId = demo.id;
          _cancelError = "This request can't be cancelled any more. The shop may have just updated it.";
        });
      } else {
        setState(() => _cancellingId = null);
        showSnack(context, 'Demo request cancelled.');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _cancellingId = null;
        _cancelErrorId = demo.id;
        _cancelError = errorText(error);
      });
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) return AccountErrorNote(message: _loadError!, onRetry: _retryLoad);
    final demos = _demos;
    if (demos == null) return const AccountLoadingNote();

    if (demos.isEmpty) {
      return EmptyState(
        title: 'No demo requests yet',
        description: "Ask for a video or in-person demo from any pet's page to meet them before you decide.",
        action: ElevatedButton(
          onPressed: () => context.push('/pets'),
          child: const Text('Browse pets'),
        ),
      );
    }

    final catalog = ref.watch(catalogProvider).value;
    final visible = demos.where((demo) => _matches(_filter, demo)).toList();

    int count(_DemoFilter filter) => demos.where((demo) => _matches(filter, demo)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilterChipBar<_DemoFilter>(
                options: [
                  FilterOption(_DemoFilter.all, 'All', count: count(_DemoFilter.all)),
                  FilterOption(_DemoFilter.active, 'Active', count: count(_DemoFilter.active)),
                  FilterOption(_DemoFilter.past, 'Past', count: count(_DemoFilter.past)),
                ],
                selected: _filter,
                onSelected: (value) => setState(() => _filter = value),
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 22, color: AppColors.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _filter == _DemoFilter.active ? 'No active demo requests right now.' : 'No past demo requests yet.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
          )
        else
          for (final demo in visible) ...[
            _DemoCard(
              key: ValueKey(demo.id),
              demo: demo,
              petAvailable: catalog?.petById(demo.petId) != null,
              cancelling: _cancellingId == demo.id,
              error: _cancelErrorId == demo.id ? _cancelError : '',
              onCancel: () => _cancel(demo),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

String _petName(DemoRequest demo, {String fallback = 'Pet'}) {
  for (final candidate in [demo.petName, demo.petBreed]) {
    if (candidate != null && candidate.trim().isNotEmpty) return candidate.trim();
  }
  return fallback;
}

// -- progress stepper --------------------------------------------------------

enum _StepState { done, next, todo, ended }

class _Step {
  final String label;
  final _StepState state;
  const _Step(this.label, this.state);
}

class _Progress {
  final List<_Step> steps;
  final int reached;
  const _Progress(this.steps, this.reached);
}

/// Requested -> Approved -> Completed, or Requested -> a terminal
/// "Rejected" / "Cancelled".
_Progress _progressFor(String status) {
  if (status == 'rejected' || status == 'cancelled') {
    return _Progress([
      const _Step('Requested', _StepState.done),
      _Step(status == 'rejected' ? 'Rejected' : 'Cancelled', _StepState.ended),
    ], 1);
  }
  final reached = const {'pending': 0, 'approved': 1, 'completed': 2}[status] ?? 0;
  const labels = ['Requested', 'Approved', 'Completed'];
  return _Progress([
    for (var index = 0; index < labels.length; index++)
      _Step(
        labels[index],
        index <= reached ? _StepState.done : (index == reached + 1 ? _StepState.next : _StepState.todo),
      ),
  ], reached);
}

class _Stepper extends StatelessWidget {
  final String status;
  const _Stepper({required this.status});

  @override
  Widget build(BuildContext context) {
    final progress = _progressFor(status);
    final steps = progress.steps;

    Widget connector(bool visible, bool active) => Expanded(
          child: Container(
            height: 2,
            color: !visible ? Colors.transparent : (active ? AppColors.primary : AppColors.border),
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    // Line to the previous step, then the dot, then the line to the next.
                    connector(index > 0, index - 1 < progress.reached),
                    _StepDot(index: index, state: steps[index].state),
                    connector(index < steps.length - 1, index < progress.reached),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  steps[index].label,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(
                    fontSize: 11.5,
                    fontWeight: steps[index].state == _StepState.done || steps[index].state == _StepState.ended
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: steps[index].state == _StepState.ended
                        ? AppColors.error
                        : (steps[index].state == _StepState.done ? AppColors.ink : AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final _StepState state;
  const _StepDot({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final BoxBorder? border;
    final Widget child;
    switch (state) {
      case _StepState.done:
        fill = AppColors.primary;
        border = null;
        child = const Icon(Icons.check, size: 14, color: Colors.white);
      case _StepState.ended:
        fill = AppColors.error;
        border = null;
        child = const Icon(Icons.close, size: 14, color: Colors.white);
      case _StepState.next:
        fill = AppColors.surface;
        border = Border.all(color: AppColors.primary, width: 2);
        child = Text('${index + 1}', style: AppTheme.body(fontSize: 11.5, color: AppColors.primary));
      case _StepState.todo:
        fill = AppColors.surface;
        border = Border.all(color: AppColors.border);
        child = Text('${index + 1}', style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft));
    }
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
      child: child,
    );
  }
}

// -- card --------------------------------------------------------------------

class _DemoCard extends StatelessWidget {
  final DemoRequest demo;
  final bool petAvailable;
  final bool cancelling;
  final String error;
  final VoidCallback onCancel;

  const _DemoCard({
    super.key,
    required this.demo,
    required this.petAvailable,
    required this.cancelling,
    required this.error,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final details = [demo.petBreed, demo.petSpecies]
        .where((part) => part != null && part.isNotEmpty)
        .map((part) => part!)
        .join(' · ');
    final meetUri = safeExternalUri(demo.meetLink);
    final isActive = _isActive(demo);

    final asked = [
      formatDate(demo.preferredDate),
      if (demo.preferredTime.isNotEmpty) formatClock(demo.preferredTime),
    ].join(' at ');
    final confirmedTime = demo.confirmedTime;
    final confirmed = [
      if (demo.confirmedDate != null) formatDate(demo.confirmedDate!),
      if (confirmedTime != null && confirmedTime.isNotEmpty) formatClock(confirmedTime),
    ].join(' at ');
    final message = demo.message ?? '';
    final sellerNote = demo.sellerNote ?? '';
    final shopName = demo.shopName ?? '';

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
                    Text(_petName(demo), style: AppTheme.body(fontWeight: FontWeight.w600)),
                    if (details.isNotEmpty)
                      Text(details, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                    if (shopName.isNotEmpty)
                      Text('at $shopName', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusBadge(status: demo.status),
            ],
          ),
          const SizedBox(height: 16),
          _Stepper(status: demo.status),
          const SizedBox(height: 14),
          InfoRow('You asked for', asked),
          InfoRow('Format', _modeLabels[demo.mode] ?? titleCase(demo.mode)),
          if (confirmed.isNotEmpty) InfoRow('Confirmed for', confirmed),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Your message: “$message”', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
          ],
          if (sellerNote.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note from the shop', style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sellerNote, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ],
          if (demo.status == 'approved' && demo.mode == 'video') ...[
            const SizedBox(height: 14),
            if (meetUri != null)
              ElevatedButton.icon(
                onPressed: () => openExternalUri(context, meetUri),
                icon: const Icon(Icons.videocam_outlined, size: 18),
                label: const Text('Join video demo'),
              )
            else
              Text(
                'The shop will add the video link here before your demo.',
                style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
              ),
          ],
          if (demo.status == 'approved' && demo.mode == 'in_person') ...[
            const SizedBox(height: 14),
            Text(
              'The shop will confirm the visit details with you.',
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(error, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Requested ${formatOrderDate(demo.createdAt)}',
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                ),
              ),
              if (petAvailable)
                TextButton(
                  onPressed: () => context.push('/pets/${demo.petId}'),
                  child: const Text('View pet'),
                ),
              if (isActive)
                OutlinedButton(
                  onPressed: cancelling ? null : onCancel,
                  child: Text(cancelling ? 'Cancelling…' : 'Cancel request'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
