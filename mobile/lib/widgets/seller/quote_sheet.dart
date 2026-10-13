import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/service_categories.dart';
import '../../models/service_models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

/// Send a first quote on an open request, or revise a quote this shop already
/// made. Mirrors src/components/seller/QuoteModal.jsx.
///
/// [onSent] is called with the success message once saved (even if the sheet
/// was dismissed meanwhile) so the caller can reload.
Future<void> showQuoteSheet(
  BuildContext context, {
  required CustomServiceRequest request,
  required String shopId,
  required void Function(String message) onSent,
}) {
  return showFormSheet<void>(
    context,
    title: request.status == 'quoted' ? 'Revise your quote' : 'Send a quote',
    description: request.title,
    builder: (sheetContext) => _QuoteForm(request: request, shopId: shopId, onSent: onSent),
  );
}

class _QuoteForm extends StatefulWidget {
  final CustomServiceRequest request;
  final String shopId;
  final void Function(String message) onSent;

  const _QuoteForm({required this.request, required this.shopId, required this.onSent});

  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  late final TextEditingController _price;
  late final TextEditingController _message;
  String? _priceError;
  String? _formError;
  bool _submitting = false;

  bool get _revising => widget.request.status == 'quoted';

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    final quoted = request.quotedPrice;
    _price = TextEditingController(
      text: _revising && quoted != null ? (quoted == quoted.roundToDouble() ? quoted.toStringAsFixed(0) : quoted.toString()) : '',
    );
    _message = TextEditingController(text: _revising ? (request.responseMessage ?? '') : '');
  }

  @override
  void dispose() {
    _price.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    final text = _price.text.trim();
    final amount = double.tryParse(text);
    String? priceError;
    if (text.isEmpty) {
      priceError = 'Enter your price.';
    } else if (amount == null || !amount.isFinite) {
      priceError = 'Enter a valid price.';
    } else if (amount < 0) {
      priceError = "Price can't be negative.";
    }
    setState(() => _priceError = priceError);
    if (priceError != null || amount == null) return;

    setState(() => _submitting = true);
    final note = _message.text.trim();
    final fields = <String, dynamic>{
      'quoted_price': amount,
      'response_message': note.isEmpty ? null : note,
    };
    // The database fills in the shop name and response time itself.
    final request = widget.request;
    final failure = _revising
        ? await updateRow(
            'custom_service_requests',
            request.id,
            fields,
            match: {'status': 'quoted', 'shop_id': widget.shopId},
          )
        : await updateRow(
            'custom_service_requests',
            request.id,
            {'status': 'quoted', 'shop_id': widget.shopId, ...fields},
            match: {'status': 'open'},
          );

    if (failure != null) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _formError = failure;
      });
      return;
    }

    widget.onSent(_revising ? 'Quote updated.' : "Quote sent. You'll see it here if the customer accepts.");
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final category = request.category;
    final budget = request.budget;
    final preferred = request.preferredDate;
    final facts = [
      if (category != null && category.isNotEmpty) serviceCategoryLabel(category),
      if (budget != null) 'Budget ${formatPrice(budget)}',
      if (preferred != null) 'Preferred ${formatDate(preferred)}',
    ].join(' · ');
    final enabled = !_submitting;

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
                Text(request.description, style: AppTheme.body(fontSize: 14)),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(facts, style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _price,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: 'Your price (INR)', prefixText: '₹ ', errorText: _priceError),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Message to the customer (optional)',
              helperText:
                  "Say what's included and when you can do it. Please keep phone numbers and addresses out of it.",
              helperMaxLines: 3,
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'The customer sees your shop name, this price and your message.',
            style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
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
                  label: _revising ? 'Update quote' : 'Send quote',
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
