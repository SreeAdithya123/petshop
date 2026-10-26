import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../content_width.dart';
import '../skeletons.dart';
import '../ui_kit.dart';
import 'account_widgets.dart';

/// How often an open conversation quietly checks for new replies.
const _pollInterval = Duration(seconds: 20);

const _messageColumns = 'id, ticket_id, sender_id, message, created_at';

/// A message the customer has typed that the server has not confirmed yet.
class _Outgoing {
  final int id;
  final String text;
  bool failed = false;
  String error = '';

  _Outgoing(this.id, this.text);
}

/// One support conversation: the ticket summary, the message thread (sent and
/// received bubbles) and a composer. Pushed on top of the Support screen.
///
/// New replies are fetched on pull-to-refresh, with the refresh button, and
/// every few seconds while the page is open. A message that fails to send
/// stays in the thread with Retry / Discard.
class SupportThreadPage extends StatefulWidget {
  final SupportTicket ticket;

  /// The signed-in user; their messages are the "sent" bubbles.
  final String userId;

  const SupportThreadPage({super.key, required this.ticket, required this.userId});

  @override
  State<SupportThreadPage> createState() => _SupportThreadPageState();
}

class _SupportThreadPageState extends State<SupportThreadPage> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Outgoing> _outgoing = [];
  Timer? _poll;

  List<SupportMessage> _messages = const [];
  bool _loading = true;
  bool _hasLoaded = false;
  String? _error;
  int _generation = 0;
  int _nextOutgoingId = 0;
  bool _sending = false;
  late String _status = widget.ticket.status;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollInterval, (_) {
      if (!_sending) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _closed => _status == 'closed';

  bool _nearBottom() {
    if (!_scroll.hasClients) return true;
    final position = _scroll.position;
    return position.maxScrollExtent - position.pixels < 160;
  }

  /// Scrolls to the newest message once the frame that added it is laid out.
  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
        // Long threads only know their full height after the first jump.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    });
  }

  Future<String?> _fetchStatus() async {
    try {
      final row = await SupabaseService.client
          .from('support_tickets')
          .select('status')
          .eq('id', widget.ticket.id)
          .maybeSingle();
      final status = row?['status'];
      return status is String ? status : null;
    } catch (_) {
      return null;
    }
  }

  /// Loads the thread. [silent] (background polling) never shows errors or a
  /// spinner; [showSkeleton] swaps the thread for placeholders (retry).
  Future<void> _load({bool showSkeleton = false, bool silent = false}) async {
    final generation = ++_generation;
    if (showSkeleton) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final statusFuture = _fetchStatus();
      final rows = await SupabaseService.client
          .from('support_messages')
          .select(_messageColumns)
          .eq('ticket_id', widget.ticket.id)
          .order('created_at', ascending: true);
      final messages = [for (final row in rows) SupportMessage.fromJson(row)];
      final status = await statusFuture;
      if (!mounted || generation != _generation) return;

      final firstLoad = !_hasLoaded;
      final grew = messages.length > _messages.length;
      final stick = firstLoad || _nearBottom();
      setState(() {
        _messages = messages;
        if (status != null) _status = status;
        _loading = false;
        _hasLoaded = true;
        _error = null;
      });
      if (firstLoad) {
        _scrollToBottom(animate: false);
      } else if (grew && stick) {
        _scrollToBottom();
      }
    } catch (error) {
      if (!mounted || generation != _generation) return;
      if (_hasLoaded) {
        // Keep the thread that is already on screen.
        if (!silent) showSnack(context, errorText(error), error: true);
        return;
      }
      setState(() {
        _loading = false;
        _error = errorText(error);
      });
    }
  }

  Future<void> _send([_Outgoing? retry]) async {
    if (_sending) return;
    final text = retry?.text ?? _composer.text.trim();
    if (text.isEmpty) return;

    final item = retry ?? _Outgoing(_nextOutgoingId++, text);
    setState(() {
      if (retry == null) {
        _outgoing.add(item);
        _composer.clear();
      }
      item.failed = false;
      item.error = '';
      _sending = true;
    });
    _scrollToBottom();

    try {
      final row = await SupabaseService.client
          .from('support_messages')
          .insert({
            'ticket_id': widget.ticket.id,
            'sender_id': widget.userId,
            'message': text,
          })
          .select(_messageColumns)
          .single();
      if (!mounted) return;
      final sent = SupportMessage.fromJson(row);
      setState(() {
        _outgoing.remove(item);
        if (!_messages.any((message) => message.id == sent.id)) _messages = [..._messages, sent];
        _sending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        item.failed = true;
        item.error = errorText(error);
        _sending = false;
      });
    }
  }

  void _discard(_Outgoing item) => setState(() => _outgoing.remove(item));

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: Column(
          children: [
            _ThreadHeader(ticket: ticket, status: _status),
            Expanded(child: _buildThread(context)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThread(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: ListSkeleton(count: 3, itemHeight: 72),
      );
    }

    final children = <Widget>[];
    if (_error != null) {
      children.add(AccountErrorNote(message: _error!, onRetry: () => _load(showSkeleton: true)));
    } else {
      final maxBubble = math.min(MediaQuery.sizeOf(context).width * 0.82, 520.0);
      final fallbackName = widget.ticket.shop?.name ?? 'PETSTA team';
      if (_messages.isEmpty && _outgoing.isEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              _closed
                  ? 'No messages were sent on this ticket.'
                  : 'No messages yet. Write the first one below and the '
                      '${widget.ticket.shop == null ? 'PETSTA team' : 'shop'} will reply here.',
              textAlign: TextAlign.center,
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
          ),
        );
      }
      for (final message in _messages) {
        final mine = message.senderId == widget.userId;
        children.add(
          _MessageBubble(
            key: ValueKey('m-${message.id}'),
            text: message.message,
            mine: mine,
            sender: mine ? 'You' : (message.sender?.name ?? fallbackName),
            time: formatDateTime(message.createdAt),
            maxWidth: maxBubble,
          ),
        );
      }
      for (final item in _outgoing) {
        children.add(
          _MessageBubble(
            key: ValueKey('o-${item.id}'),
            text: item.text,
            mine: true,
            sender: 'You',
            time: item.failed ? 'Not sent' : 'Sending…',
            maxWidth: maxBubble,
            pending: !item.failed,
            failure: item.failed
                ? _SendFailure(
                    message: item.error,
                    onRetry: _sending ? null : () => _send(item),
                    onDiscard: () => _discard(item),
                  )
                : null,
          ),
        );
      }
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(),
      child: ListView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: children,
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    if (_closed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Text(
            'This ticket is closed. Open a new ticket if you still need help.',
            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: _composer,
              builder: (context, _) {
                final canSend = !_sending && _composer.text.trim().isNotEmpty;
                return IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: canSend ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    disabledForegroundColor: AppColors.inkSoft,
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned strip under the app bar: who the ticket is with and where it stands.
class _ThreadHeader extends StatelessWidget {
  final SupportTicket ticket;
  final String status;
  const _ThreadHeader({required this.ticket, required this.status});

  @override
  Widget build(BuildContext context) {
    final shopName = ticket.shop?.name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusBadge(status: status),
          Text(
            shopName == null || shopName.isEmpty ? 'General' : shopName,
            style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          Text(
            'Opened ${formatOrderDate(ticket.createdAt)}',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _SendFailure {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onDiscard;
  const _SendFailure({required this.message, required this.onRetry, required this.onDiscard});
}

class _MessageBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final String sender;
  final String time;
  final double maxWidth;
  final bool pending;
  final _SendFailure? failure;

  const _MessageBubble({
    super.key,
    required this.text,
    required this.mine,
    required this.sender,
    required this.time,
    required this.maxWidth,
    this.pending = false,
    this.failure,
  });

  @override
  Widget build(BuildContext context) {
    final failed = failure;
    final fill = mine ? AppColors.primary : AppColors.surface;
    final textColor = mine ? Colors.white : AppColors.ink;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: AppColors.border),
      ),
      child: Text(text, style: AppTheme.body(fontSize: 14.5, color: textColor)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: '${mine ? 'You' : sender} said: $text. $time',
                child: ExcludeSemantics(
                  child: Opacity(opacity: pending ? 0.6 : 1, child: bubble),
                ),
              ),
              const SizedBox(height: 3),
              ExcludeSemantics(
                child: Text(
                  mine ? time : '$sender · $time',
                  style: AppTheme.body(
                    fontSize: 11.5,
                    color: failed != null ? AppColors.error : AppColors.inkSoft,
                  ),
                ),
              ),
              if (failed != null) ...[
                if (failed.message.isNotEmpty)
                  Text(
                    failed.message,
                    textAlign: mine ? TextAlign.end : TextAlign.start,
                    style: AppTheme.body(fontSize: 12.5, color: AppColors.error),
                  ),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: failed.onRetry,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: failed.onDiscard,
                      style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                      child: const Text('Discard'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
