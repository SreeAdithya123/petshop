import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

/// Add (service == null) or edit a service in a bottom sheet. Mirrors
/// src/components/seller/ServiceFormModal.jsx.
///
/// [onSaved] is called with the success message once the row is saved, even
/// if the sheet was dismissed in the meantime, so the caller can reload.
Future<void> showServiceFormSheet(
  BuildContext context, {
  required String shopId,
  ServiceItem? service,
  required void Function(String message) onSaved,
}) {
  return showFormSheet<void>(
    context,
    title: service == null ? 'Add a service' : 'Edit service',
    description: service == null ? 'New services go live after admin approval.' : null,
    builder: (sheetContext) => _ServiceForm(shopId: shopId, service: service, onSaved: onSaved),
  );
}

class _ServiceForm extends StatefulWidget {
  final String shopId;
  final ServiceItem? service;
  final void Function(String message) onSaved;

  const _ServiceForm({required this.shopId, required this.service, required this.onSaved});

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late String _category;

  String? _nameError;
  String? _priceError;
  String? _durationError;
  String? _formError;
  bool _submitting = false;

  bool get _editing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _name = TextEditingController(text: service?.name ?? '');
    _price = TextEditingController(text: service == null ? '' : _numberText(service.price));
    _duration = TextEditingController(text: service?.durationMinutes?.toString() ?? '');
    _description = TextEditingController(text: service?.description ?? '');
    _category = (service != null && serviceCategories.any((category) => category.key == service.category))
        ? service.category
        : serviceCategories.first.key;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _duration.dispose();
    _description.dispose();
    super.dispose();
  }

  /// 1500 -> "1500", 99.5 -> "99.5" (no trailing ".0" in the field).
  static String _numberText(num value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  bool _validate() {
    String? nameError;
    String? priceError;
    String? durationError;

    if (_name.text.trim().isEmpty) nameError = 'Enter a service name.';

    final priceText = _price.text.trim();
    final price = double.tryParse(priceText);
    if (priceText.isEmpty) {
      priceError = 'Enter a price.';
    } else if (price == null || !price.isFinite || price <= 0) {
      priceError = 'Price must be greater than zero.';
    }

    final durationText = _duration.text.trim();
    if (durationText.isNotEmpty) {
      final minutes = int.tryParse(durationText);
      if (minutes == null || minutes <= 0) durationError = 'Enter whole minutes, like 45.';
    }

    setState(() {
      _nameError = nameError;
      _priceError = priceError;
      _durationError = durationError;
    });
    return nameError == null && priceError == null && durationError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);
    if (!_validate()) return;

    setState(() => _submitting = true);
    final durationText = _duration.text.trim();
    // Never send `status`: the database forces new services to "pending" and
    // blocks sellers from changing it.
    final fields = <String, dynamic>{
      'category': _category,
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': double.parse(_price.text.trim()),
      'duration_minutes': durationText.isEmpty ? null : int.parse(durationText),
    };

    final existing = widget.service;
    final failure = existing != null
        ? await updateRow('services', existing.id, fields)
        : await insertRow('services', {'shop_id': widget.shopId, ...fields});

    if (failure != null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = failure;
      });
      return;
    }

    widget.onSaved(_editing ? 'Service updated.' : 'Service submitted. New services go live after admin approval.');
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_submitting;
    return PopScope(
      canPop: !_submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in serviceCategories)
                DropdownMenuItem<String>(value: category.key, child: Text(category.label)),
            ],
            onChanged: enabled
                ? (value) {
                    if (value != null) setState(() => _category = value);
                  }
                : null,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: enabled,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Service name', errorText: _nameError),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: 'Price (INR)', prefixText: '₹ ', errorText: _priceError),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Duration in minutes (optional)',
              helperText: 'How long one session takes.',
              errorText: _durationError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description (optional)', alignLabelWithHint: true),
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
                child: LoadingButton(
                  label: _editing ? 'Save changes' : 'Add service',
                  loading: _submitting,
                  onPressed: _submit,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
