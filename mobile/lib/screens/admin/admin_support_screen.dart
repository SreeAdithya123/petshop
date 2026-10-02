import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

const _statusFilterOptions = [
  ('all', 'All'),
  ('open', 'Open'),
  ('in_progress', 'In progress'),
  ('resolved', 'Resolved'),
  ('closed', 'Closed'),
];

const _statusOptions = ['open', 'in_progress', 'resolved', 'closed'];

String _statusLabel(String status) {
  switch (status) {
    case 'open':
      return 'Open';
    case 'in_progress':
      return 'In progress';
    case 'resolved':
      return 'Resolved';
    case 'closed':
      return 'Closed';
    default:
      return status;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'open':
    case 'in_progress':
      return AppColors.primary;
    case 'resolved':
      return AppColors.trust;
    case 'closed':
      return AppColors.inkSoft;
    default:
      return AppColors.inkSoft;
  }
}

/// Mirrors src/pages/admin/Support.jsx: every support ticket across the
/// platform, with a status filter and an expandable message thread + reply.
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  bool _loading = true;
  List<SupportTicket> _tickets = [];
  String _statusFilter = 'all';

  String? _selectedId;
  List<SupportMessage> _messages = [];
  bool _messagesLoading = false;
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      final tickets = await SupportTicketsRepository().listAll();
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMessages(String ticketId) async {
    setState(() => _messagesLoading = true);
    try {
      final messages = await SupportMessagesRepository().listForTicket(ticketId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _messagesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _messagesLoading = false);
    }
  }

  void _toggleTicket(String ticketId) {
    final wasSelected = _selectedId == ticketId;
    setState(() {
      _selectedId = wasSelected ? null : ticketId;
      _replyController.clear();
      if (!wasSelected) _messages = [];
    });
    if (!wasSelected) {
      _loadMessages(ticketId);
    }
  }

  Future<void> _sendReply(String ticketId) async {
    final text = _replyController.text.trim();
    final profile = ref.read(authControllerProvider).profile;
    if (text.isEmpty || profile == null) return;

    setState(() => _sending = true);
    try {
      await SupportMessagesRepository().insert({
        'ticket_id': ticketId,
        'sender_id': profile.id,
        'message': text,
      });
      if (!mounted) return;
      _replyController.clear();
      await _loadMessages(ticketId);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeStatus(SupportTicket ticket, String nextStatus) async {
    setState(() => _updatingStatus = true);
    try {
      await SupportTicketsRepository().updateStatus(ticket.id, nextStatus);
      if (!mounted) return;
      setState(() {
        _tickets = _tickets
            .map(
              (t) => t.id == ticket.id
                  ? SupportTicket(
                      id: t.id,
                      customerId: t.customerId,
                      shopId: t.shopId,
                      subject: t.subject,
                      status: nextStatus,
                      createdAt: t.createdAt,
                      customer: t.customer,
                      shop: t.shop,
                    )
                  : t,
            )
            .toList();
      });
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTickets =
        _statusFilter == 'all' ? _tickets : _tickets.where((t) => t.status == _statusFilter).toList();

    return RoleShell(
      title: 'Support',
      child: _loading
          ? const LoadingView(label: 'Loading tickets…')
          : ListView(
              padding: kScreenPadding,
              children: [
                ScreenHeader(
                  title: 'Support tickets',
                  subtitle: 'All customer support tickets across the platform.',
                  trailing: _StatusFilterDropdown(
                    value: _statusFilter,
                    onChanged: (value) => setState(() => _statusFilter = value),
                  ),
                ),
                const SizedBox(height: 24),
                if (_tickets.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      title: 'No support tickets yet',
                      description: 'Customer support tickets will show up here.',
                    ),
                  )
                else
                  for (final ticket in filteredTickets) ...[
                    _TicketCardView(
                      ticket: ticket,
                      isOpen: _selectedId == ticket.id,
                      onTap: () => _toggleTicket(ticket.id),
                      onStatusChange: (status) => _changeStatus(ticket, status),
                      updatingStatus: _updatingStatus,
                      messagesLoading: _messagesLoading,
                      messages: _messages,
                      replyController: _replyController,
                      sending: _sending,
                      onSendReply: () => _sendReply(ticket.id),
                    ),
                    const SizedBox(height: 16),
                  ],
              ],
            ),
    );
  }
}

class _StatusFilterDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: AppTheme.body(fontSize: 14),
          items: [
            for (final option in _statusFilterOptions)
              DropdownMenuItem(value: option.$1, child: Text(option.$2)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _TicketCardView extends StatelessWidget {
  final SupportTicket ticket;
  final bool isOpen;
  final VoidCallback onTap;
  final ValueChanged<String> onStatusChange;
  final bool updatingStatus;
  final bool messagesLoading;
  final List<SupportMessage> messages;
  final TextEditingController replyController;
  final bool sending;
  final VoidCallback onSendReply;

  const _TicketCardView({
    required this.ticket,
    required this.isOpen,
    required this.onTap,
    required this.onStatusChange,
    required this.updatingStatus,
    required this.messagesLoading,
    required this.messages,
    required this.replyController,
    required this.sending,
    required this.onSendReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket.subject,
                          style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ticket.customer?.name.isNotEmpty == true ? ticket.customer!.name : 'Customer'} · '
                          '${ticket.shop?.name.isNotEmpty == true ? ticket.shop!.name : 'General'} · '
                          '${formatDateTime(ticket.createdAt)}',
                          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusPill(status: _statusLabel(ticket.status), color: _statusColor(ticket.status)),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status', style: AppTheme.body(fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('status-${ticket.id}-${ticket.status}'),
                    initialValue: ticket.status,
                    isExpanded: true,
                    items: [
                      for (final option in _statusOptions)
                        DropdownMenuItem(value: option, child: Text(_statusLabel(option))),
                    ],
                    onChanged: updatingStatus
                        ? null
                        : (value) {
                            if (value != null) onStatusChange(value);
                          },
                  ),
                  const SizedBox(height: 20),
                  if (messagesLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Loading messages…',
                        style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                      ),
                    )
                  else if (messages.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No messages yet.',
                        style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final message in messages)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.paper,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        message.sender?.name.isNotEmpty == true
                                            ? message.sender!.name
                                            : 'Unknown',
                                        style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      formatDateTime(message.createdAt),
                                      style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(message.message, style: AppTheme.body(fontSize: 14)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text('Reply', style: AppTheme.body(fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: replyController,
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: replyController,
                    builder: (context, _) {
                      final hasText = replyController.text.trim().isNotEmpty;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: (sending || !hasText) ? null : onSendReply,
                          child: Text(sending ? 'Sending…' : 'Send reply'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
