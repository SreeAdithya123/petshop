import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final minDate = tomorrowDate();
    final current = _date;
    final initial = current != null && !current.isBefore(minDate) ? current : minDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate,
      lastDate: minDate.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      _dateError = null;
    });
  }

  Future<void> _submit(String userId) async {
    final minDate = tomorrowDate();
    final date = _date;
    final time = _time;
    final dateError = date == null
        ? 'Pick a date.'
        : (date.isBefore(minDate) ? 'Pick a date from tomorrow onwards.' : null);
    final timeError = time == null ? 'Pick a time slot.' : null;
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
      await SupabaseService.client.from('service_bookings').insert({
        'service_id': widget.service.id,
        'customer_id': userId,
        'booking_date': toDateParam(date),
        'booking_time': time,
        'delivery_mode': _mode,
        'notes': notes,
      });
    } catch (error) {
      final message = errorText(error);
      failure = message.isEmpty ? "Couldn't book that slot. Try again." : message;
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
        _formError = failureText;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ServiceAccess.from(ref.watch(authControllerProvider));

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
    return SuccessPanel(
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
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              errorText: _dateError,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            ),
            child: Text(
              _date == null ? 'Select a date' : formatDate(_date!),
              style: AppTheme.body(color: _date == null ? AppColors.inkSoft : AppColors.ink),
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
          onChanged: (value) => setState(() {
            _time = value;
            _timeError = null;
          }),
        ),
        const SizedBox(height: 16),
        _buildModePicker(modes),
        const SizedBox(height: 16),
        if (widget.consult) ..._buildConsultFields() else ..._buildNotesField(),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(_formError!, style: AppTheme.body(fontSize: 13, color: AppColors.error)),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
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
                  onTap: () => setState(() => _mode = modes[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(deliveryModeFor(_mode).hint, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
      ],
    );
  }

  List<Widget> _buildConsultFields() {
    return [
      const SheetFieldLabel("Pet's name", optional: true),
      TextField(
        controller: _petNameController,
        maxLength: 60,
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
        onChanged: (value) => setState(() => _petSpecies = value),
      ),
      const SizedBox(height: 16),
      const SheetFieldLabel("What's the concern?", optional: true),
      TextField(
        controller: _concernController,
        maxLength: 500,
        minLines: 3,
        maxLines: 5,
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
  final VoidCallback onTap;

  const _ModeTile({required this.info, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: info.label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                info.label,
                textAlign: TextAlign.center,
                maxLines: 1,
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
