import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../repositories/repositories.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';

const _statusOptions = ['open', 'in_progress', 'resolved', 'closed'];

/// Mirrors src/pages/seller/Support.jsx: support tickets addressed to the
/// signed-in seller's shop, with an expandable message thread + reply box.
class SellerSupportScreen extends ConsumerStatefulWidget {
  const SellerSupportScreen({super.key});

  @override
  ConsumerState<SellerSupportScreen> createState() => _SellerSupportScreenState();
}

class _SellerSupportScreenState extends ConsumerState<SellerSupportScreen> {
  bool _loading = true;
  String? _error;
  Shop? _shop;
  List<SupportTicket> _tickets = [];

  String? _selectedId;
  List<SupportMessage> _messages = [];
  bool _messagesLoading = false;
  final TextEditingController _replyController = TextEditingController();
  bool _sending = false;
  bool _updatingStatus = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final shop = await ShopsRepository().getByOwnerId(profile.id);
      if (shop == null) {
        if (!mounted) return;
        setState(() {
          _shop = null;
          _loading = false;
        });
        return;
      }

      final tickets = await SupportTicketsRepository().listForShop(shop.id);
      if (!mounted) return;
      setState(() {
        _shop = shop;
        _tickets = tickets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
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

  void _selectTicket(String ticketId) {
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

  @override
  Widget build(BuildContext context) {
    return RoleShell(title: 'Support', child: _buildBody());
  }

  Widget _buildBody() {
    if (_loading) {
      return const LoadingView(label: 'Loading support tickets…');
    }

    if (_shop == null) {
      return Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "You haven't set up your shop yet",
          description: 'Create your shop profile first.',
          action: ElevatedButton(
            onPressed: () => context.push('/seller/store'),
            child: const Text('Set up your shop'),
          ),
        ),
      );
    }

    if (_error != null) {
      return ErrorView(message: "Couldn't load support tickets: $_error");
    }

    if (_tickets.isEmpty) {
      return const Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: 'No support tickets yet',
          description: 'Customer questions about your shop will show up here.',
        ),
      );
    }

    return ListView(
      padding: kScreenPadding,
      children: [
        const ScreenHeader(
          title: 'Support tickets',
          subtitle: 'Questions from customers about your shop.',
        ),
        const SizedBox(height: 24),
        for (final ticket in _tickets) ...[
          _TicketCardView(
            ticket: ticket,
            isOpen: _selectedId == ticket.id,
            statusColor: _statusColor(ticket.status),
            onTap: () => _selectTicket(ticket.id),
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
    );
  }
}

class _TicketCardView extends StatelessWidget {
  final SupportTicket ticket;
  final bool isOpen;
  final Color statusColor;
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
    required this.statusColor,
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
                          '${ticket.customer?.name ?? 'Customer'} · ${formatOrderDate(ticket.createdAt)}',
                          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusPill(status: ticket.status, color: statusColor),
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
                  Text('Ticket status', style: AppTheme.body(fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    key: ValueKey('status-${ticket.id}-${ticket.status}'),
                    initialValue: ticket.status,
                    isExpanded: true,
                    items: [
                      for (final option in _statusOptions)
                        DropdownMenuItem(value: option, child: Text(option.replaceAll('_', ' '))),
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
                                        message.sender?.name ?? 'User',
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
                  AnimatedBuilder(
                    animation: replyController,
                    builder: (context, _) {
                      final hasText = replyController.text.trim().isNotEmpty;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Reply', style: AppTheme.body(fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: replyController,
                            minLines: 3,
                            maxLines: 5,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              onPressed: (sending || !hasText) ? null : onSendReply,
                              child: Text(sending ? 'Sending…' : 'Send reply'),
                            ),
                          ),
                        ],
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
