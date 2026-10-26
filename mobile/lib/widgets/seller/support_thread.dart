import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../skeletons.dart';
import '../ui_kit.dart';
import 'seller_common.dart';

/// Support ticket list rows and the expandable conversation card shared by the
/// seller Support and admin Support screens (the Flutter counterpart of the
/// ticket cards in src/pages/seller/Support.jsx and src/pages/admin/Support.jsx).
///
/// Rows are read straight from the query result instead of the shared models,
/// because the `profiles(name)` / `shops(name)` embeds carry only a name.

/// Columns for `support_tickets` list queries.
const kTicketColumns = 'id, customer_id, shop_id, subject, status, created_at, profiles(name), shops(name)';

/// Columns for `support_messages` queries.
const kTicketMessageColumns = 'id, ticket_id, sender_id, message, created_at, profiles(name)';

const kTicketStatuses = ['open', 'in_progress', 'resolved', 'closed'];

const _statusLabels = {
  'open': 'Open',
  'in_progress': 'In progress',
  'resolved': 'Resolved',
  'closed': 'Closed',
};

String ticketStatusLabel(String status) => _statusLabels[status] ?? titleCase(status);

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

class SupportTicketRow {
  final String id;
  final String customerId;
  final String? shopId;
  final String subject;
  final String status; // open | in_progress | resolved | closed
  final DateTime createdAt;
  final String customerName;
  final String? shopName;

  const SupportTicketRow({
    required this.id,
    required this.customerId,
    required this.shopId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.shopName,
  });

  factory SupportTicketRow.fromJson(Map<String, dynamic> json) {
    final customer = _embedded(json['profiles']);
    final shop = _embedded(json['shops']);
    final shopName = ((shop?['name'] as String?) ?? '').trim();
    return SupportTicketRow(
      id: json['id'] as String,
      customerId: json['customer_id'] as String? ?? '',
      shopId: json['shop_id'] as String?,
      subject: json['subject'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      createdAt: _timestamp(json['created_at']),
      customerName: ((customer?['name'] as String?) ?? '').trim(),
      shopName: shopName.isEmpty ? null : shopName,
    );
  }

  SupportTicketRow withStatus(String next) => SupportTicketRow(
        id: id,
        customerId: customerId,
        shopId: shopId,
        subject: subject,
        status: next,
        createdAt: createdAt,
        customerName: customerName,
        shopName: shopName,
      );
}

class SupportMessageRow {
  final String id;
  final String senderId;
  final String message;
  final DateTime createdAt;
  final String senderName;

  const SupportMessageRow({
    required this.id,
    required this.senderId,
    required this.message,
    required this.createdAt,
    required this.senderName,
  });

  factory SupportMessageRow.fromJson(Map<String, dynamic> json) {
    final sender = _embedded(json['profiles']);
    return SupportMessageRow(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: _timestamp(json['created_at']),
      senderName: ((sender?['name'] as String?) ?? '').trim(),
    );
  }
}

Future<List<SupportMessageRow>> _fetchMessages(String ticketId) async {
  final rows = await fetchAllRows(
    () => SupabaseService.client.from('support_messages').select(kTicketMessageColumns).eq('ticket_id', ticketId),
  );
  final messages = rows.map(SupportMessageRow.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return messages;
}

/// One ticket: a tappable header that expands into the status selector, the
/// message thread and a reply box.
///
/// [subtitle] is the line under the subject (who/when). [onStatusChanged] runs
/// after the new status has been saved, so the list can update its copy.
class SupportTicketCard extends StatefulWidget {
  final SupportTicketRow ticket;
  final String subtitle;

  /// The signed-in user, recorded as the sender of replies.
  final String? currentUserId;
  final ValueChanged<String> onStatusChanged;

  const SupportTicketCard({
    super.key,
    required this.ticket,
    required this.subtitle,
    required this.currentUserId,
    required this.onStatusChanged,
  });

  @override
  State<SupportTicketCard> createState() => _SupportTicketCardState();
}

class _SupportTicketCardState extends State<SupportTicketCard> {
  static const _maxReplyLength = 2000;

  final TextEditingController _reply = TextEditingController();
  SellerQuery<List<SupportMessageRow>>? _messages;
  bool _open = false;
  bool _sending = false;
  bool _updatingStatus = false;
  String? _error;

  @override
  void dispose() {
    _messages?.dispose();
    _reply.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      _error = null;
      if (_open && _messages == null) {
        final ticketId = widget.ticket.id;
        _messages = SellerQuery<List<SupportMessageRow>>(() => _fetchMessages(ticketId));
      }
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final userId = widget.currentUserId;
    if (userId == null) {
      setState(() => _error = 'Please log in again to reply.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    final failure = await insertRow('support_messages', {
      'ticket_id': widget.ticket.id,
      'sender_id': userId,
      'message': text,
    });
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = failure;
    });
    if (failure == null) {
      _reply.clear();
      _messages?.reload();
    }
  }

  Future<void> _changeStatus(String next) async {
    if (_updatingStatus || next == widget.ticket.status) return;
    setState(() {
      _updatingStatus = true;
      _error = null;
    });
    final failure = await updateRow('support_tickets', widget.ticket.id, {'status': next});
    if (!mounted) return;
    setState(() {
      _updatingStatus = false;
      _error = failure;
    });
    if (failure == null) widget.onStatusChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final subject = ticket.subject.trim().isEmpty ? 'Support request' : ticket.subject.trim();

    return CardBox(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: '$subject. ${ticketStatusLabel(ticket.status)}. ${widget.subtitle}',
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
                            Text(
                              subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
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
                          StatusBadge(status: ticket.status, label: ticketStatusLabel(ticket.status)),
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

  Widget _buildThread(SupportTicketRow ticket) {
    final messages = _messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('status-${ticket.id}-${ticket.status}'),
          initialValue: kTicketStatuses.contains(ticket.status) ? ticket.status : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ticket status'),
          items: [
            for (final option in kTicketStatuses)
              DropdownMenuItem<String>(value: option, child: Text(ticketStatusLabel(option))),
          ],
          onChanged: _updatingStatus
              ? null
              : (value) {
                  if (value != null) _changeStatus(value);
                },
        ),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          NoticeBox.error(message: _error!),
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

  Widget _buildMessages(SellerQuery<List<SupportMessageRow>> query) {
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
                Text(message.message, style: AppTheme.body(fontSize: 14)),
              ],
            ),
          ),
      ],
    );
  }
}
