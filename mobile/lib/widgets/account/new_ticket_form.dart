import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../theme/app_theme.dart';
import '../ui_kit.dart';
import 'account_widgets.dart';

/// What the new-ticket sheet hands back once the ticket exists.
class NewTicketResult {
  final String ticketId;

  /// True when the ticket was created but its first message could not be sent.
  final bool messageFailed;

  const NewTicketResult(this.ticketId, {this.messageFailed = false});
}

/// Form shown in the "New ticket" bottom sheet. Creates the ticket (and, when
/// the customer typed one, its first message) and pops with a
/// [NewTicketResult]. Customers talk to a shop through tickets because shop
/// contact details are private.
class NewTicketForm extends StatefulWidget {
  final String customerId;

  /// Approved shops the ticket can be addressed to.
  final List<Shop> shops;

  /// Shop to preselect (ignored when it is not one of [shops]).
  final String? initialShopId;
  final String? initialSubject;

  /// Order this ticket is about, e.g. "Order #1A2B3C4D" (shown as context).
  final String? orderLabel;

  const NewTicketForm({
    super.key,
    required this.customerId,
    required this.shops,
    this.initialShopId,
    this.initialSubject,
    this.orderLabel,
  });

  @override
  State<NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends State<NewTicketForm> {
  late final TextEditingController _subject = TextEditingController(text: widget.initialSubject ?? '');
  final TextEditingController _message = TextEditingController();

  /// Empty string means "General (not about a shop)".
  late String _shopId = widget.shops.any((shop) => shop.id == widget.initialShopId) ? widget.initialShopId! : '';
  String? _subjectError;
  String _error = '';
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final subject = _subject.text.trim();
    final message = _message.text.trim();
    final subjectError = subject.isEmpty ? 'Enter a subject.' : null;
    setState(() {
      _subjectError = subjectError;
      _error = '';
    });
    if (subjectError != null) return;

    setState(() => _submitting = true);
    final String ticketId;
    try {
      ticketId = await SupportTicketsRepository().insert({
        'customer_id': widget.customerId,
        'shop_id': _shopId.isEmpty ? null : _shopId,
        'subject': subject,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorText(error);
      });
      return;
    }

    var messageFailed = false;
    if (message.isNotEmpty) {
      try {
        await SupportMessagesRepository().insert({
          'ticket_id': ticketId,
          'sender_id': widget.customerId,
          'message': message,
        });
      } catch (_) {
        // The ticket exists; the thread lets the customer send the message again.
        messageFailed = true;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(NewTicketResult(ticketId, messageFailed: messageFailed));
  }

  @override
  Widget build(BuildContext context) {
    final orderLabel = widget.orderLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (orderLabel != null) ...[
          NoticeBox(
            message: 'This ticket is about $orderLabel. Shops arrange pickup through tickets, '
                'because their contact details stay private.',
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 16),
        ],
        const FormLabel('Subject'),
        TextField(
          controller: _subject,
          enabled: !_submitting,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(120)],
          onChanged: (_) {
            if (_subjectError != null) setState(() => _subjectError = null);
          },
          decoration: InputDecoration(errorText: _subjectError),
        ),
        const SizedBox(height: 16),
        const FormLabel('Who is it for?'),
        DropdownField<String>(
          value: _shopId,
          hint: 'Choose…',
          onChanged: _submitting ? null : (value) => setState(() => _shopId = value ?? ''),
          items: [
            const DropdownMenuItem<String>(
              value: '',
              child: Text('General (the PETSTA team)', maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            for (final shop in widget.shops)
              DropdownMenuItem<String>(
                value: shop.id,
                child: Text(shop.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const FormLabel('Message', optional: true),
        TextField(
          controller: _message,
          enabled: !_submitting,
          minLines: 3,
          maxLines: 6,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(helperText: 'What do you need help with?'),
        ),
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 8),
          NoticeBox.error(message: _error),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LoadingButton(
                label: 'Open ticket',
                loading: _submitting,
                onPressed: _submit,
                expand: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Replies show up in your ticket under Support.',
          style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
        ),
      ],
    );
  }
}
