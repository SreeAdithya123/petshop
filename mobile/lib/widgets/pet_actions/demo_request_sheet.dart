import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../pet_widgets.dart';
import '../ui_kit.dart';

/// Bottom-sheet version of src/components/pets/DemoRequestModal.jsx: a
/// customer asks a shop to show them [pet] over video or in person.
///
/// Resolves to true when a request was submitted (even if the sheet was
/// dismissed afterwards), false otherwise.
Future<bool> showDemoRequestSheet(
  BuildContext context, {
  required Pet pet,
  String? shopName,
}) async {
  var requested = false;
  await showFormSheet<void>(
    context,
    title: 'Request a demo',
    description: shopName == null ? pet.displayName : '${pet.displayName} · sold by $shopName',
    builder: (sheetContext) => _DemoRequestForm(
      pet: pet,
      onRequested: () => requested = true,
    ),
  );
  return requested;
}

class _DemoMode {
  final String value; // video | in_person
  final String label;
  final String hint;
  final IconData icon;
  const _DemoMode(this.value, this.label, this.hint, this.icon);
}

const _demoModes = [
  _DemoMode('video', 'Video call', 'The shop will send a video link once approved', Icons.videocam_outlined),
  _DemoMode(
    'in_person',
    'Visit the shop in person',
    'The shop confirms visit details once they approve',
    Icons.storefront_outlined,
  ),
];

// Hourly slots from 10:00 AM to 6:00 PM, stored as their label text.
final List<String> _demoTimeSlots = List<String>.generate(9, (index) {
  final hour = 10 + index;
  return '${hour > 12 ? hour - 12 : hour}:00 ${hour >= 12 ? 'PM' : 'AM'}';
});

const _maxDaysAhead = 30;
const _messageLimit = 500;

class _RequestedDemo {
  final String modeLabel;
  final DateTime date;
  final String time;
  const _RequestedDemo({required this.modeLabel, required this.date, required this.time});
}

class _DemoRequestForm extends ConsumerStatefulWidget {
  final Pet pet;
  final VoidCallback onRequested;
  const _DemoRequestForm({required this.pet, required this.onRequested});

  @override
  ConsumerState<_DemoRequestForm> createState() => _DemoRequestFormState();
}

class _DemoRequestFormState extends ConsumerState<_DemoRequestForm> {
  final _messageController = TextEditingController();
  late final DateTime _minDate;
  late final DateTime _maxDate;
  late DateTime _date;
  String _mode = 'video';
  String? _time;
  String? _dateError;
  String? _timeError;
  String? _submitError;
  bool _submitting = false;
  _RequestedDemo? _requested;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _minDate = DateTime(now.year, now.month, now.day + 1);
    _maxDate = DateTime(now.year, now.month, now.day + _maxDaysAhead);
    _date = _minDate;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _minDate,
      lastDate: _maxDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;

    final dateOnly = DateTime(_date.year, _date.month, _date.day);
    final dateError = (dateOnly.isBefore(_minDate) || dateOnly.isAfter(_maxDate))
        ? 'Pick a date between ${formatDate(_minDate)} and ${formatDate(_maxDate)}.'
        : null;
    final time = _time;
    final timeError = time == null ? 'Choose a preferred time.' : null;
    setState(() {
      _dateError = dateError;
      _timeError = timeError;
      _submitError = null;
    });
    if (dateError != null || timeError != null || time == null) return;

    final message = _messageController.text.trim();
    final mode = _mode;
    setState(() => _submitting = true);
    try {
      await SupabaseService.client.from('demo_requests').insert({
        'customer_id': profile.id,
        'pet_id': widget.pet.id,
        'preferred_date': toDateParam(dateOnly),
        'preferred_time': time,
        'mode': mode,
        'message': message.isEmpty ? null : message,
      });
      // Report success even if the sheet was dismissed while the request was in flight.
      widget.onRequested();
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _requested = _RequestedDemo(
          modeLabel: _demoModes.firstWhere((m) => m.value == mode).label,
          date: dateOnly,
          time: time,
        );
      });
    } catch (error) {
      if (!mounted) return;
      final duplicate = error is PostgrestException && error.code == '23505';
      setState(() {
        _submitting = false;
        _submitError = duplicate
            ? 'You already have a demo request for this pet. Track it under My account → Demo requests.'
            : commerceErrorText(error);
      });
    }
  }

  /// Closes the sheet, then opens [path] (so Back returns to the pet).
  void _closeThenPush(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final name = widget.pet.displayName;

    if (auth.status == AuthStatus.loading) {
      return Text('Checking your account…', style: AppTheme.body(color: AppColors.inkSoft));
    }
    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return LoginPromptCard(
        compact: true,
        title: 'Log in to request a demo',
        description: 'Sign in or sign up to request a demo of $name.',
      );
    }
    if (profile.role != 'customer') {
      return NoticeBox(
        message: 'Only customer accounts can request demos. Sign in with a customer account to meet $name.',
      );
    }

    final requested = _requested;
    if (requested != null) return _buildSuccess(requested);
    return _buildForm(name);
  }

  Widget _buildSuccess(_RequestedDemo requested) {
    final isVideo = requested.modeLabel == _demoModes.first.label;
    return SuccessPanel(
      title: 'Demo requested',
      message: 'The shop will confirm — track it under My account → Demo requests.'
          '${isVideo ? ' Once approved, the shop will send you a video link.' : ''}\n\n'
          '${widget.pet.displayName} · ${requested.modeLabel} · ${formatDate(requested.date)}, ${requested.time}',
      actions: [
        ElevatedButton(
          onPressed: () => _closeThenPush('/account/demos'),
          child: const Text('View my demo requests'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildForm(String name) {
    return PopScope(
      canPop: !_submitting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How would you like to meet $name?', style: AppTheme.body(fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          for (final mode in _demoModes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ModeTile(
                mode: mode,
                selected: _mode == mode.value,
                onTap: _submitting ? null : () => setState(() => _mode = mode.value),
              ),
            ),
          const SizedBox(height: 8),
          const _FieldLabel('Preferred date'),
          Semantics(
            button: true,
            label: 'Preferred date, ${formatDate(_date)}.${_dateError == null ? '' : ' $_dateError.'} Double tap to change.',
            excludeSemantics: true,
            onTap: _submitting ? null : _pickDate,
            child: InkWell(
              onTap: _submitting ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText: _dateError,
                  suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(formatDate(_date), style: AppTheme.body()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a day between ${formatDate(_minDate)} and ${formatDate(_maxDate)}.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Preferred time'),
          DropdownButtonFormField<String>(
            initialValue: _time,
            isExpanded: true,
            hint: Text('Select a time', style: AppTheme.body(color: AppColors.inkSoft)),
            decoration: InputDecoration(errorText: _timeError),
            items: [
              for (final slot in _demoTimeSlots) DropdownMenuItem<String>(value: slot, child: Text(slot)),
            ],
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                      _time = value;
                      _timeError = null;
                    }),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Message', optional: true),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 4,
            maxLength: _messageLimit,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: "Anything you'd like the shop to know?"),
          ),
          const SizedBox(height: 4),
          Text(
            'The shop will review your request and confirm a time with you. Pickup details are shared by the '
            'shop after they confirm — contact details stay private.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            NoticeBox.error(message: _submitError!),
          ],
          const SizedBox(height: 20),
          LoadingButton(
            label: 'Request demo',
            icon: Icons.videocam_outlined,
            loading: _submitting,
            onPressed: _submit,
            expand: true,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

/// One selectable "how to meet" option (the radio cards in the web modal).
class _ModeTile extends StatelessWidget {
  final _DemoMode mode;
  final bool selected;
  final VoidCallback? onTap;
  const _ModeTile({required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(mode.icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mode.label, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(mode.hint, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool optional;
  const _FieldLabel(this.text, {this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        optional ? '$text (optional)' : text,
        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
      ),
    );
  }
}
