import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/async_utils.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../seller/seller_common.dart';
import '../shared_widgets.dart';
import '../skeletons.dart';
import '../ui_kit.dart';

/// Admin side of support: one ticket row plus the expandable conversation card
/// (status chips, message thread, reply box with retry).
///
/// Tickets created by the "Sell on PETSTA" form carry the subject
/// "Shop application: <shop name>" and no shop; they are flagged so admins can
/// find new shop applications at a glance.

/// Columns for the admin `support_tickets` list query.
const kAdminTicketColumns = 'id, customer_id, shop_id, subject, status, created_at, profiles(name, email), shops(name)';

/// Columns for `support_messages` queries.
const kAdminMessageColumns = 'id, ticket_id, sender_id, message, created_at, profiles(name)';

/// Subject prefix the Sell on PETSTA form puts on shop applications.
const kShopApplicationPrefix = 'Shop application:';

const kAdminTicketStatuses = ['open', 'in_progress', 'resolved', 'closed'];

const _statusLabels = {
  'open': 'Open',
  'in_progress': 'In progress',
  'resolved': 'Resolved',
  'closed': 'Closed',
};

String adminTicketStatusLabel(String status) => _statusLabels[status] ?? titleCase(status);

/// An embedded relation arrives as a map (or a one-element list).
Map<String, dynamic>? _embedded(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty) return _embedded(raw.first);
  return null;
}

DateTime _timestamp(Object? raw) {
  if (raw is String) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed.toLocal();
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class AdminTicket {
  final String id;
  final String customerId;
  final String? shopId;
  final String subject;
  final String status; // open | in_progress | resolved | closed
  final DateTime createdAt;
  final String customerName;
  final String customerEmail;
  final String? shopName;

  const AdminTicket({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.customerEmail,
    required this.shopName,
  });

  factory AdminTicket.fromJson(Map<String, dynamic> json) {
    final customer = _embedded(json['profiles']);
    final shop = _embedded(json['shops']);
    final shopName = ((shop?['name'] as String?) ?? '').trim();
    return AdminTicket(
      id: json['id'] as String,
      customerId: json['customer_id'] as String? ?? '',
      shopId: json['shop_id'] as String?,
      subject: (json['subject'] as String? ?? '').trim(),
      status: json['status'] as String? ?? 'open',
      createdAt: _timestamp(json['created_at']),
      customerName: ((customer?['name'] as String?) ?? '').trim(),
      customerEmail: ((customer?['email'] as String?) ?? '').trim(),
      shopName: shopName.isEmpty ? null : shopName,
    );
  }

  /// True for a shop application submitted from the Sell on PETSTA form.
  bool get isApplication => shopId == null && subject.toLowerCase().startsWith(kShopApplicationPrefix.toLowerCase());

  AdminTicket withStatus(String next) => AdminTicket(
        id: id,
        customerId: customerId,
        shopId: shopId,
        subject: subject,
        status: next,
        createdAt: createdAt,
        customerName: customerName,
        customerEmail: customerEmail,
        shopName: shopName,
      );
}

class _AdminMessage {
  final String id;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String senderName;

  const _AdminMessage({
    required this.id,
    required this.senderId,
    required this.message,
    required this.createdAt,
    required this.senderName,
  });

  factory _AdminMessage.fromJson(Map<String, dynamic> json) {
    final sender = _embedded(json['profiles']);
    return _AdminMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: _timestamp(json['created_at']),
      senderName: ((sender?['name'] as String?) ?? '').trim(),
    );
  }
}

Future<List<_AdminMessage>> _fetchMessages(String ticketId) async {
  final rows = await withTimeout(
    fetchAllRows(
      () => SupabaseService.client.from('support_messages').select(kAdminMessageColumns).eq('ticket_id', ticketId),
    ),
    timeout: const Duration(seconds: 45),
  );
  return rows.map(_AdminMessage.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

/// One ticket: a tappable header that expands into the status chips, the
/// conversation and a reply box.
class AdminTicketCard extends StatefulWidget {
  final AdminTicket ticket;

  /// The signed-in admin, recorded as the sender of replies.
  final String? currentUserId;

  /// Runs after a new status has been saved, so the list can update its copy.
  final ValueChanged<String> onStatusChanged;

  /// Runs when a status change was refused because the ticket moved on, so the
  /// list can reload.
  final VoidCallback onStale;

  const AdminTicketCard({
    super.key,
    required this.ticket,
    required this.currentUserId,
    required this.onStatusChanged,
    required this.onStale,
  });

  @override
  State<AdminTicketCard> createState() => _AdminTicketCardState();
}

class _AdminTicketCardState extends State<AdminTicketCard> {
  static const _maxReplyLength = 2000;

  final TextEditingController _reply = TextEditingController();
  SellerQuery<List<_AdminMessage>>? _messages;
  bool _open = false;
  bool _sending = false;
  bool _updatingStatus = false;
  String? _replyError;
  String? _statusError;

  @override
  void dispose() {
    _messages?.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      _replyError = null;
      _statusError = null;
      if (_open && _messages == null) {
        final ticketId = widget.ticket.id;
        _messages = SellerQuery<List<_AdminMessage>>(() => _fetchMessages(ticketId));
      }
    });
  }

  /// Sends the typed reply. The text stays in the box when sending fails, so
  /// "Try again" (or the Send button) simply sends it once more.
  Future<void> _send() async {
    if (_sending) return;
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final userId = widget.currentUserId;
    if (userId == null) {
      setState(() => _replyError = 'Please log in again to reply.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _replyError = null;
    });
    String? failure;
    try {
      await withTimeout(
        SupabaseService.client.from('support_messages').insert({
          'ticket_id': widget.ticket.id,
          'sender_id': userId,
          'message': text,
        }),
      );
    } catch (e) {
      failure = describeError(e);
    }
    if (!mounted) return;
    setState(() {
      _sending = false;
      _replyError = failure;
    });
    if (failure == null) {
      _reply.clear();
      _messages?.reload();
    }
  }

  Future<void> _changeStatus(String next) async {
    if (_updatingStatus || next == widget.ticket.status) return;
    final previous = widget.ticket.status;
    setState(() {
      _updatingStatus = true;
      _statusError = null;
    });
    // Guard on the status this card showed so a newer change isn't overwritten.
    final failure = await updateRow(
      'support_tickets',
      widget.ticket.id,
      {'status': next},
      match: {'status': previous},
    );
    if (!mounted) return;
    setState(() {
      _updatingStatus = false;
      _statusError = failure;
    });
    if (failure == null) {
      widget.onStatusChanged(next);
    } else if (failure == kNothingChanged) {
      widget.onStale();
    }
  }

  String get _subtitle {
    final ticket = widget.ticket;
    return [
      ticket.customerName.isEmpty ? 'Customer' : ticket.customerName,
      if (!ticket.isApplication) ticket.shopName ?? 'General',
      formatDateTime(ticket.createdAt),
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final subject = ticket.subject.isEmpty ? 'Support request' : ticket.subject;
    final application = ticket.isApplication;

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: '${application ? 'Shop application. ' : ''}$subject. '
                '${adminTicketStatusLabel(ticket.status)}. $_subtitle',
            hint: _open ? 'Double tap to collapse the conversation' : 'Double tap to open the conversation',
            onTap: _toggle,
            excludeSemantics: true,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (application) ...[
                              const StatusPill(status: 'Shop application', color: AppColors.adminAccent),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          StatusBadge(status: ticket.status, label: adminTicketStatusLabel(ticket.status)),
                          const SizedBox(height: 6),
                          Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.inkSoft),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildThread(ticket),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThread(AdminTicket ticket) {
    final messages = _messages;
    final contact = [
      if (ticket.customerName.isNotEmpty) ticket.customerName,
      if (ticket.customerEmail.isNotEmpty) ticket.customerEmail,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SellerMetaRow('From', text: contact.isEmpty ? 'Unknown customer' : contact),
        if (!ticket.isApplication) SellerMetaRow('Shop', text: ticket.shopName ?? 'General (no shop)'),
        const SizedBox(height: 12),
        Text('Status', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final status in kAdminTicketStatuses)
              ChoiceChip(
                label: Text(adminTicketStatusLabel(status)),
                selected: ticket.status == status,
                onSelected: _updatingStatus ? null : (_) => _changeStatus(status),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTheme.body(
                  fontSize: 13,
                  fontWeight: ticket.status == status ? FontWeight.w600 : FontWeight.w400,
                  color: ticket.status == status ? AppColors.primary : AppColors.ink,
                ),
                side: BorderSide(color: ticket.status == status ? AppColors.primary : AppColors.border),
                backgroundColor: AppColors.surface,
                showCheckmark: false,
              ),
          ],
        ),
        if (_updatingStatus) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_statusError != null) ...[
          const SizedBox(height: 8),
          NoticeBox.error(message: _statusError!),
        ],
        const SizedBox(height: 16),
        if (messages != null)
          ListenableBuilder(
            listenable: messages,
            builder: (context, _) => _buildMessages(messages),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _reply,
          enabled: !_sending,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [LengthLimitingTextInputFormatter(_maxReplyLength)],
          decoration: const InputDecoration(labelText: 'Reply', alignLabelWithHint: true),
        ),
        if (_replyError != null) ...[
          const SizedBox(height: 12),
          NoticeBox.error(message: "Your reply wasn't sent. $_replyError"),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try again'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: ListenableBuilder(
            listenable: _reply,
            builder: (context, _) => LoadingButton(
              label: 'Send reply',
              loading: _sending,
              onPressed: _reply.text.trim().isEmpty ? null : _send,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessages(SellerQuery<List<_AdminMessage>> query) {
    final data = query.data;
    if (data == null) {
      if (query.loading) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 14),
            SizedBox(height: 10),
            SkeletonBox(width: 180, height: 14),
          ],
        );
      }
      return SellerLoadError(
        what: 'messages',
        message: query.error ?? 'Something went wrong.',
        onRetry: query.reload,
      );
    }
    if (data.isEmpty) {
      return Text('No messages yet.', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (query.error != null) ...[
          SellerLoadError(what: 'messages', message: query.error!, onRetry: query.reload, compact: true),
          const SizedBox(height: 8),
        ],
        for (final message in data)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: message.senderId == widget.currentUserId
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      message.senderId == widget.currentUserId
                          ? 'You'
                          : (message.senderName.isEmpty ? 'User' : message.senderName),
                      style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      formatDateTime(message.createdAt),
                      style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SelectableText(message.message, style: AppTheme.body(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}
