import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/async_utils.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'service_support.dart';

/// Opens the booking bottom sheet (the Flutter counterpart of BookingModal.jsx).
///
/// [consult] switches to the vet teleconsultation flavour: video pre-selected
/// and pet / concern fields instead of free notes. [onBooked] fires as soon as
/// the booking is saved (so lists can reload even if the sheet is dismissed).
/// Resolves to true when the user tapped "View my ..." on the success panel.
Future<bool?> showBookingSheet(
  BuildContext context, {
  required ServiceItem service,
  bool consult = false,
  VoidCallback? onBooked,
}) {
  return showFormSheet<bool>(
    context,
    title: consult ? 'Book a video consult' : 'Book this service',
    description: service.name,
    builder: (sheetContext) => ServiceBookingForm(service: service, consult: consult, onBooked: onBooked),
  );
}

class ServiceBookingForm extends ConsumerStatefulWidget {
  final ServiceItem service;
  final bool consult;
  final VoidCallback? onBooked;

  const ServiceBookingForm({super.key, required this.service, this.consult = false, this.onBooked});

  @override
  ConsumerState<ServiceBookingForm> createState() => _ServiceBookingFormState();
}

class _ServiceBookingFormState extends ConsumerState<ServiceBookingForm> {
  final _notesController = TextEditingController();
  final _petNameController = TextEditingController();
  final _concernController = TextEditingController();

  late String _mode;
  DateTime? _date;
  String? _time;
  String? _petSpecies;

  String? _dateError;
  String? _timeError;
  String? _formError;
  bool _submitting = false;
  bool _booked = false;
  String _confirmation = '';

  @override
  void initState() {
    super.initState();
    final modes = modesForCategory(widget.service.category);
    _mode = widget.consult && modes.contains('video') ? 'video' : modes.first;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _petNameController.dispose();
    _concernController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Recomputed on every open, so a sheet left open past midnight still
    // offers only days that are still in the future.
    final first = tomorrowDate();
    final last = addDays(first, bookingAdvanceDays);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampDate(_date ?? first, first, last),
      firstDate: first,
      lastDate: last,
      helpText: 'Select a date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateError = null;
      _formError = null;
    });
  }

  Future<void> _submit(String userId) async {
    if (_submitting) return;
    final minDate = tomorrowDate();
    final maxDate = addDays(minDate, bookingAdvanceDays);
    final date = _date;
    final time = _time;

    String? dateError;
    if (date == null) {
      dateError = 'Pick a date.';
    } else if (date.isBefore(minDate)) {
      dateError = 'Pick a date from tomorrow onwards.';
    } else if (date.isAfter(maxDate)) {
      dateError = 'Slots can be booked up to $bookingAdvanceDays days ahead.';
    }
    String? timeError;
    if (time == null) {
      timeError = 'Pick a time slot.';
    } else if (date != null && dateError == null && isPastSlot(date, time)) {
      timeError = 'That time has already passed. Pick a later slot.';
    }
    setState(() {
      _formError = null;
      _dateError = dateError;
      _timeError = timeError;
    });
    if (date == null || time == null || dateError != null || timeError != null) return;

    final notesText = _notesController.text.trim();
    final notes = widget.consult
        ? composeConsultNotes(
            petName: _petNameController.text,
            petSpecies: _petSpecies,
            concern: _concernController.text,
          )
        : (notesText.isEmpty ? null : notesText);

    setState(() => _submitting = true);
    String? failure;
    try {
      await withTimeout(
        SupabaseService.client.from('service_bookings').insert({
          'service_id': widget.service.id,
          'customer_id': userId,
          'booking_date': toDateParam(date),
          'booking_time': time,
          'delivery_mode': _mode,
          'notes': notes,
        }),
      );
    } catch (error) {
      failure = isTimeoutError(error)
          ? "$kTimeoutError Check My bookings first, in case your slot was saved."
          : errorText(error);
    }

    if (failure == null) widget.onBooked?.call();
    if (!mounted) return;

    final failureText = failure;
    setState(() {
      _submitting = false;
      if (failureText == null) {
        _booked = true;
        final mode = deliveryModeFor(_mode);
        _confirmation = '${widget.service.name} on ${formatDate(date)} at ${formatClock(time)} '
            '(${mode.label.toLowerCase()}). ${mode.hint}';
      } else {
        // Everything typed so far stays in place so the person can just retry.
        _formError = failureText;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ServiceAccess.from(ref.watch(authControllerProvider));

    // Closing the sheet mid-request would hide the outcome and invite a second
    // booking, so back / drag / the close button wait until it has finished.
    return PopScope(
      canPop: !_submitting,
      child: _buildBody(access),
    );
  }

  Widget _buildBody(ServiceAccess access) {
    if (_booked) return _buildSuccess();
    final userId = access.userId;
    if (!access.canBook || userId == null) {
      return ServiceAccessNotice(
        access: access,
        action: widget.consult ? 'book a consultation' : 'book a service',
      );
    }
    return _buildForm(userId);
  }

  Widget _buildSuccess() {
    final provider = widget.consult ? 'clinic' : 'shop';
    final video = _mode == 'video';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuccessPanel(
          title: 'Booked — the $provider will confirm',
          message: _confirmation,
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(widget.consult ? 'View my consultations' : 'View my bookings'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Done'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        NextStepsList(
          steps: [
            'The $provider reviews your request and confirms the slot. You can cancel any time before then.',
            if (video)
              'Once confirmed, a Join video consult button appears on your booking.'
            else
              'Once confirmed, your booking shows as confirmed. Arrive a few minutes early.',
            if (video) 'Join a few minutes early. The clinic may need to let you in, and the call opens in your browser.',
          ],
        ),
      ],
    );
  }

  Widget _buildForm(String userId) {
    final service = widget.service;
    final modes = modesForCategory(service.category);
    final duration = formatDuration(service.durationMinutes);
    final shopName = service.shopName?.trim() ?? '';
    final summary = [
      if (shopName.isNotEmpty) 'by $shopName',
      if (duration.isNotEmpty) duration,
      formatPrice(service.price),
    ].join(' · ');
    final date = _date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(service.name, style: AppTheme.body(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(summary, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            ],
          ),
        ),
        if (widget.consult) ...[
          const SizedBox(height: 12),
          const NoticeBox.warning(
            message: "Emergency? Don't wait for a slot — go to your nearest vet clinic immediately.",
          ),
        ],
        const SizedBox(height: 16),
        const SheetFieldLabel('Date'),
        Semantics(
          button: true,
          label: date == null ? 'Date, not selected' : 'Date, ${formatDate(date)}',
          excludeSemantics: true,
          onTap: _submitting ? null : _pickDate,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _submitting ? null : _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: _dateError,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                date == null ? 'Select a date' : formatDate(date),
                style: AppTheme.body(color: date == null ? AppColors.inkSoft : AppColors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SheetFieldLabel('Time'),
        DropdownButtonFormField<String>(
          initialValue: _time,
          isExpanded: true,
          menuMaxHeight: 320,
          hint: const Text('Select a time'),
          decoration: InputDecoration(errorText: _timeError),
          items: [
            for (final slot in bookingTimeSlots) DropdownMenuItem<String>(value: slot, child: Text(formatClock(slot))),
          ],
          onChanged: _submitting
              ? null
              : (value) => setState(() {
                    _time = value;
                    _timeError = null;
                    _formError = null;
                  }),
        ),
        const SizedBox(height: 16),
        _buildModePicker(modes),
        const SizedBox(height: 16),
        if (widget.consult) ..._buildConsultFields() else ..._buildNotesField(),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(_formError!, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
          ),
        ],
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            LoadingButton(
              label: 'Book this slot',
              loading: _submitting,
              onPressed: () => _submit(userId),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModePicker(List<String> modes) {
    if (modes.length <= 1) {
      return Text(deliveryModeFor('in_person').hint, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SheetFieldLabel('How would you like to meet?'),
        Row(
          children: [
            for (var i = 0; i < modes.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _ModeTile(
                  info: deliveryModeFor(modes[i]),
                  selected: _mode == modes[i],
                  onTap: _submitting ? null : () => setState(() => _mode = modes[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(deliveryModeFor(_mode).hint, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
        if (_mode == 'video') ...[
          const SizedBox(height: 6),
          Text(videoExpectationText, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
        ],
      ],
    );
  }

  List<Widget> _buildConsultFields() {
    return [
      const SheetFieldLabel("Pet's name", optional: true),
      TextField(
        controller: _petNameController,
        maxLength: 60,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(counterText: ''),
      ),
      const SizedBox(height: 16),
      const SheetFieldLabel('Species', optional: true),
      DropdownButtonFormField<String?>(
        initialValue: _petSpecies,
        isExpanded: true,
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Select')),
          for (final species in petSpeciesOptions) DropdownMenuItem<String?>(value: species, child: Text(species)),
        ],
        onChanged: _submitting ? null : (value) => setState(() => _petSpecies = value),
      ),
      const SizedBox(height: 16),
      const SheetFieldLabel("What's the concern?", optional: true),
      TextField(
        controller: _concernController,
        maxLength: 500,
        minLines: 3,
        maxLines: 5,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: "Symptoms, how long they've lasted, anything the vet should know.",
          counterText: '',
        ),
      ),
    ];
  }

  List<Widget> _buildNotesField() {
    return [
      const SheetFieldLabel('Notes', optional: true),
      TextField(
        controller: _notesController,
        maxLength: 500,
        minLines: 3,
        maxLines: 5,
        enabled: !_submitting,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: "Anything the shop should know — your pet's name, temperament, preferences.",
          counterText: '',
        ),
      ),
    ];
  }
}

class _ModeTile extends StatelessWidget {
  final DeliveryModeInfo info;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeTile({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: info.label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(info.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                info.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.body(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
