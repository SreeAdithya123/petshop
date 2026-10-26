import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_error.dart';
import '../../core/async_utils.dart';
import '../../data/service_categories.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'service_support.dart';

/// Largest budget the form accepts (keeps the number inside the column's range).
const double _maxBudget = 9999999;

/// Opens the "Request a custom service" bottom sheet (the Flutter counterpart
/// of CustomServiceModal.jsx): ask nearby approved shops for a quote on
/// something that isn't listed. [onSent] fires as soon as the request is saved.
/// Resolves to true when the user tapped "View my requests".
Future<bool?> showCustomServiceSheet(BuildContext context, {VoidCallback? onSent}) {
  return showFormSheet<bool>(
    context,
    title: 'Request a custom service',
    description: 'Tell us what you need and nearby approved shops will reply with a quote.',
    builder: (sheetContext) => CustomServiceForm(onSent: onSent),
  );
}

class CustomServiceForm extends ConsumerStatefulWidget {
  final VoidCallback? onSent;

  const CustomServiceForm({super.key, this.onSent});

  @override
  ConsumerState<CustomServiceForm> createState() => _CustomServiceFormState();
}

class _CustomServiceFormState extends ConsumerState<CustomServiceForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _petNameController = TextEditingController();
  final _budgetController = TextEditingController();

  String? _category;
  String? _petSpecies;
  DateTime? _preferredDate;

  String? _titleError;
  String? _descriptionError;
  String? _dateError;
  String? _budgetError;
  String? _formError;
  bool _submitting = false;
  bool _sent = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _petNameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    // Recomputed on every open, so a sheet left open past midnight stays valid.
    final first = todayDate();
    final last = addDays(first, 365);
    final picked = await showDatePicker(
      context: context,
      initialDate: clampDate(_preferredDate ?? first, first, last),
      firstDate: first,
      lastDate: last,
      helpText: 'Preferred date',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preferredDate = picked;
      _dateError = null;
    });
  }

  Future<void> _submit(String userId) async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final petName = _petNameController.text.trim();
    final budgetText = _budgetController.text.trim();
    final preferredDate = _preferredDate;

    String? budgetError;
    double? budget;
    if (budgetText.isNotEmpty) {
      budget = double.tryParse(budgetText);
      if (budget == null || budget.isNaN || budget.isInfinite || budget < 0) {
        budgetError = 'Enter an amount of 0 or more.';
      } else if (budget > _maxBudget) {
        budgetError = 'Enter an amount up to ${formatPrice(_maxBudget)}.';
      }
    }
    final titleError = title.isEmpty ? 'Give your request a short title.' : null;
    final descriptionError = description.isEmpty ? 'Describe what you need.' : null;
    final dateError =
        preferredDate != null && preferredDate.isBefore(todayDate()) ? 'Pick today or a later date.' : null;

    setState(() {
      _formError = null;
      _titleError = titleError;
      _descriptionError = descriptionError;
      _dateError = dateError;
      _budgetError = budgetError;
    });
    if (titleError != null || descriptionError != null || dateError != null || budgetError != null) return;

    setState(() => _submitting = true);
    String? failure;
    try {
      await withTimeout(
        SupabaseService.client.from('custom_service_requests').insert({
          'customer_id': userId,
          'title': title,
          'description': description,
          'category': _category,
          'pet_name': petName.isEmpty ? null : petName,
          'pet_species': _petSpecies,
          'preferred_date': preferredDate == null ? null : toDateParam(preferredDate),
          'budget': budget,
        }),
      );
    } catch (error) {
      failure = isTimeoutError(error)
          ? "$kTimeoutError Check My requests first, in case it was sent."
          : errorText(error);
    }

    if (failure == null) widget.onSent?.call();
    if (!mounted) return;

    final failureText = failure;
    setState(() {
      _submitting = false;
      if (failureText == null) {
        _sent = true;
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
    // request, so back / drag / the close button wait until it has finished.
    return PopScope(
      canPop: !_submitting,
      child: _buildBody(access),
    );
  }

  Widget _buildBody(ServiceAccess access) {
    if (_sent) return _buildSuccess();
    final userId = access.userId;
    if (!access.canBook || userId == null) {
      return ServiceAccessNotice(access: access, action: 'send a custom service request');
    }
    return _buildForm(userId);
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SuccessPanel(
          title: "Request sent to nearby approved shops — they'll reply with a quote",
          message: 'You can accept or decline any quote under My bookings & requests.',
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('View my requests'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Done'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const NextStepsList(
          steps: [
            'Approved shops near you see your request and reply with a price.',
            'Quotes appear under My bookings & requests. Nothing is booked until you accept one.',
            'You can decline a quote or cancel the request at any time.',
          ],
        ),
      ],
    );
  }

  Widget _buildForm(String userId) {
    final preferredDate = _preferredDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetFieldLabel('Title'),
        TextField(
          controller: _titleController,
          maxLength: 120,
          enabled: !_submitting,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. Home visit grooming for a senior dog',
            errorText: _titleError,
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        const SheetFieldLabel('What do you need?'),
        TextField(
          controller: _descriptionController,
          maxLength: 1000,
          minLines: 3,
          maxLines: 6,
          enabled: !_submitting,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(errorText: _descriptionError, counterText: ''),
        ),
        const SizedBox(height: 16),
        const SheetFieldLabel('Category', optional: true),
        DropdownButtonFormField<String?>(
          initialValue: _category,
          isExpanded: true,
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Other / not sure')),
            for (final category in serviceCategories)
              DropdownMenuItem<String?>(value: category.key, child: Text(category.label)),
          ],
          onChanged: _submitting ? null : (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 16),
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
        const SheetFieldLabel('Preferred date', optional: true),
        Semantics(
          button: true,
          label: preferredDate == null ? 'Preferred date, any day' : 'Preferred date, ${formatDate(preferredDate)}',
          excludeSemantics: true,
          onTap: _submitting ? null : _pickDate,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _submitting ? null : _pickDate,
            child: InputDecorator(
              decoration: InputDecoration(
                errorText: _dateError,
                suffixIcon: preferredDate == null
                    ? const Icon(Icons.calendar_today_outlined, size: 20)
                    : IconButton(
                        tooltip: 'Clear date',
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                  _preferredDate = null;
                                  _dateError = null;
                                }),
                      ),
              ),
              child: Text(
                preferredDate == null ? 'Any day' : formatDate(preferredDate),
                style: AppTheme.body(color: preferredDate == null ? AppColors.inkSoft : AppColors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SheetFieldLabel('Budget (₹)', optional: true),
        TextField(
          controller: _budgetController,
          enabled: !_submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: InputDecoration(prefixText: '₹ ', errorText: _budgetError),
        ),
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
              label: 'Send request',
              loading: _submitting,
              onPressed: () => _submit(userId),
            ),
          ],
        ),
      ],
    );
  }
}
