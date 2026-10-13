import 'package:flutter/material.dart';

import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

class _Decision {
  final String value;
  final String label;
  final String hint;
  const _Decision(this.value, this.label, this.hint);
}

const _pendingDecisions = <_Decision>[
  _Decision('approve', 'Approve', 'Confirm a date and time'),
  _Decision('reject', 'Reject', 'Decline with a reason'),
];

const _approvedDecisions = <_Decision>[
  _Decision('complete', 'Mark completed', 'The demo has happened'),
  _Decision('update', 'Update details', 'Change the slot or link'),
  _Decision('reject', 'Reject', 'Call it off with a reason'),
];

/// Approve / reject a pending demo request, or complete / update / reject an
/// approved one, in a bottom sheet. Mirrors
/// src/components/seller/DemoRespondModal.jsx.
///
/// [onDone] runs once the response is saved (even if the sheet was dismissed
/// meanwhile) so the caller can reload.
Future<void> showDemoRespondSheet(
  BuildContext context, {
  required DemoRequest demo,
  required CustomerInfo? customer,
  required VoidCallback onDone,
}) {
  return showFormSheet<void>(
    context,
    title: 'Respond to demo request',
    description: demo.petName,
    builder: (sheetContext) => _DemoRespondForm(demo: demo, customer: customer, onDone: onDone),
  );
}

class _DemoRespondForm extends StatefulWidget {
  final DemoRequest demo;
  final CustomerInfo? customer;
  final VoidCallback onDone;

  const _DemoRespondForm({required this.demo, required this.customer, required this.onDone});

  @override
  State<_DemoRespondForm> createState() => _DemoRespondFormState();
}

class _DemoRespondFormState extends State<_DemoRespondForm> {
  late final TextEditingController _link;
  late final TextEditingController _note;
  late String _decision;

  /// Confirmed date as 'yyyy-MM-dd' (null until picked) and time as 'HH:mm'
  /// (empty until picked).
  String? _date;
  String _time = '';

  String? _dateError;
  String? _timeError;
  String? _linkError;
  String? _noteError;
  String? _formError;
  bool _submitting = false;

  DemoRequest get _demo => widget.demo;
  bool get _isVideo => _demo.mode == 'video';
  List<_Decision> get _decisions => _demo.status == 'pending' ? _pendingDecisions : _approvedDecisions;
  bool get _showSlot => _decision == 'approve' || _decision == 'update';

  @override
  void initState() {
    super.initState();
    _decision = _decisions.first.value;
    _date = toDateParam(_demo.confirmedDate ?? _demo.preferredDate);
    _time = toTimeValue(_demo.confirmedTime ?? _demo.preferredTime);
    _link = TextEditingController(text: _demo.meetLink ?? '');
    _note = TextEditingController(text: _demo.sellerNote ?? '');
  }

  @override
  void dispose() {
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  void _selectDecision(String value) {
    setState(() {
      _decision = value;
      _dateError = null;
      _timeError = null;
      _linkError = null;
      _noteError = null;
      _formError = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Only a new approval has to be today or later (matches the web date input's `min`).
    final first = _decision == 'approve' ? today : DateTime(2000);
    final stored = _date;
    var initial = (stored == null ? null : DateTime.tryParse(stored)) ?? today;
    if (initial.isBefore(first)) initial = first;
    var last = DateTime(now.year + 3, 12, 31);
    if (initial.isAfter(last)) last = initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = toDateParam(picked);
      _dateError = null;
    });
  }

  Future<void> _pickTime() async {
    var initial = const TimeOfDay(hour: 11, minute: 0);
    final parts = _time.split(':');
    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null && hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        initial = TimeOfDay(hour: hour, minute: minute);
      }
    }
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    setState(() {
      _time = formatTimeOfDay(picked);
      _timeError = null;
    });
  }

  bool _validate() {
    String? dateError;
    String? timeError;
    String? linkError;
    String? noteError;

    if (_showSlot) {
      final date = _date;
      if (date == null || date.isEmpty) {
        dateError = 'Pick the date.';
      } else if (_decision == 'approve' && date.compareTo(toDateParam(DateTime.now())) < 0) {
        dateError = 'Pick today or a later date.';
      }
      if (_time.isEmpty) timeError = 'Pick the time.';

      final link = _link.text.trim();
      if (_isVideo && link.isEmpty) {
        linkError = 'Add the video link for this demo.';
      } else if (link.isNotEmpty && !isHttpsUrl(link)) {
        linkError = 'The link must start with https://';
      }
    }

    if (_decision == 'reject' && _note.text.trim().isEmpty) {
      noteError = "Tell the customer why you can't do it.";
    }

    setState(() {
      _dateError = dateError;
      _timeError = timeError;
      _linkError = linkError;
      _noteError = noteError;
    });
    return dateError == null && timeError == null && linkError == null && noteError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_validate()) return;

    final note = _note.text.trim();
    final link = _link.text.trim();
    final slot = <String, dynamic>{
      'confirmed_date': _date,
      'confirmed_time': _time,
      'meet_link': link.isEmpty ? null : link,
      'seller_note': note.isEmpty ? null : note,
    };
    final Map<String, dynamic> patch;
    switch (_decision) {
      case 'approve':
        patch = {'status': 'approved', ...slot};
      case 'update':
        patch = slot;
      case 'complete':
        patch = {'status': 'completed', 'seller_note': note.isEmpty ? null : note};
      default:
        patch = {'status': 'rejected', 'seller_note': note.isEmpty ? null : note};
    }

    setState(() => _submitting = true);
    // Guard on the status this sheet was showing so a stale screen can't
    // overwrite a newer decision.
    final failure = await updateRow('demo_requests', _demo.id, patch, match: {'status': _demo.status});

    if (failure != null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = failure;
      });
      return;
    }

    widget.onDone();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final demo = _demo;
    final enabled = !_submitting;
    final decisions = _decisions;
    final selectedLabel = decisions.firstWhere((option) => option.value == _decision).label;
    final message = (demo.message ?? '').trim();
    final reject = _decision == 'reject';

    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SellerCustomerContact(customer: widget.customer),
                const SizedBox(height: 4),
                Text(
                  'Asked for ${formatSlot(demo.preferredDate, demo.preferredTime)} · ${modeLabel(demo.mode)}',
                  style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('“$message”', style: AppTheme.body(fontSize: 14)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Your decision', style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final option in decisions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DecisionTile(
                decision: option,
                selected: option.value == _decision,
                onTap: enabled ? () => _selectDecision(option.value) : null,
              ),
            ),
          if (_showSlot) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SellerPickerField(
                    label: 'Confirmed date',
                    value: _date == null ? null : formatDateString(_date),
                    icon: Icons.calendar_today_outlined,
                    onTap: enabled ? _pickDate : null,
                    errorText: _dateError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SellerPickerField(
                    label: 'Confirmed time',
                    value: _time.isEmpty ? null : formatTimeLabel(_time),
                    icon: Icons.schedule,
                    onTap: enabled ? _pickTime : null,
                    errorText: _timeError,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _link,
              enabled: enabled,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: _isVideo ? 'Video link' : 'Meeting link (optional)',
                hintText: 'https://meet.google.com/...',
                helperText: _isVideo
                    ? 'Paste a Google Meet/Zoom link; the customer sees it on their Services & Health pages.'
                    : 'Only needed if you want to share an online link as well.',
                helperMaxLines: 3,
                errorText: _linkError,
                errorMaxLines: 2,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: reject ? 'Reason for the customer' : 'Note for the customer (optional)',
              helperText: "Shared with the customer. Please keep your shop's address and phone number out of it.",
              helperMaxLines: 3,
              errorText: _noteError,
              alignLabelWithHint: true,
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            NoticeBox.error(message: _formError!),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enabled ? () => Navigator.of(context).pop() : null,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: enabled ? _submit : null,
                  style: reject ? ElevatedButton.styleFrom(backgroundColor: AppColors.error) : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(selectedLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  final _Decision decision;
  final bool selected;
  final VoidCallback? onTap;

  const _DecisionTile({required this.decision, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? AppColors.primary : AppColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(decision.label, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
                    Text(decision.hint, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
