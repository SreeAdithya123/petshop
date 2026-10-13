import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';
import 'pharmacy_intents.dart';

// Customer-facing: no cost_price, and the shop embed is name-only.
const _productColumns =
    'id, shop_id, name, description, price, stock_quantity, photo_urls, requires_prescription, category, shops(name)';
const _maxMessageLength = 300;
const _amber = Color(0xFFB45309);

class _ChatMessage {
  final int id;
  final String? text; // non-null for a customer message
  final PharmacyReply? reply; // non-null for an assistant message

  const _ChatMessage({required this.id, this.text, this.reply});
}

/// Rule-based pharmacy assistant (mirrors src/components/health/PharmacyChat.jsx).
/// Replies come from pharmacy_intents.dart (no AI), followed by a catalogue
/// lookup for related products. Emergency red flags get an urgent message and
/// never any products.
///
/// Lays itself out to fill the space it is given (message list + composer), so
/// place it where it has a bounded height. [topNotice] scrolls with the
/// conversation; [onBookVet] is called by the "Book a video consult" links.
class PharmacyChat extends StatefulWidget {
  final VoidCallback onBookVet;
  final Widget? topNotice;

  const PharmacyChat({super.key, required this.onBookVet, this.topNotice});

  @override
  State<PharmacyChat> createState() => _PharmacyChatState();
}

class _PharmacyChatState extends State<PharmacyChat> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  late List<_ChatMessage> _messages;
  // Ids only ever grow, so a message never reuses another's widget state.
  int _nextId = 1;

  @override
  void initState() {
    super.initState();
    _messages = _freshConversation();
    _inputFocus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _inputFocus.removeListener(_onFocusChanged);
    _inputFocus.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The quick-reply chips make way for the keyboard while typing, and the
  /// newest message is kept in view once the keyboard has finished opening.
  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
    if (_inputFocus.hasFocus) {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _scrollToBottom();
      });
    }
  }

  List<_ChatMessage> _freshConversation() {
    return [
      _ChatMessage(
        id: _nextId++,
        reply: const PharmacyReply(kind: PharmacyReplyKind.greeting, message: pharmacyIntroMessage),
      ),
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _send(String text) {
    var trimmed = text.trim();
    if (trimmed.length > _maxMessageLength) trimmed = trimmed.substring(0, _maxMessageLength).trim();
    if (trimmed.isEmpty) return;
    final message = trimmed;
    final reply = getReply(message);
    setState(() {
      _messages = [
        ..._messages,
        _ChatMessage(id: _nextId++, text: message),
        _ChatMessage(id: _nextId++, reply: reply),
      ];
    });
    _controller.clear();
    _scrollToBottom();
  }

  void _newChat() {
    setState(() => _messages = _freshConversation());
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final lastId = _messages.last.id;
    final hasNotice = widget.topNotice != null;
    final itemCount = _messages.length + (hasNotice ? 1 : 0);

    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Expanded(
          child: Container(
            color: AppColors.paper,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                if (hasNotice && index == 0) {
                  return Padding(padding: const EdgeInsets.only(bottom: 14), child: widget.topNotice);
                }
                final message = _messages[hasNotice ? index - 1 : index];
                return Padding(
                  key: ValueKey(message.id),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: message.text != null
                      ? _UserBubble(text: message.text!)
                      : _BotBubble(
                          reply: message.reply!,
                          onSend: _send,
                          onBookVet: widget.onBookVet,
                          onSettled: message.id == lastId ? _scrollToBottom : null,
                        ),
                );
              },
            ),
          ),
        ),
        _buildComposer(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pharmacy assistant (automated)',
                  style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Rule-based tips. Not a vet or a pharmacist.',
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (_messages.length > 1)
            TextButton(
              onPressed: _newChat,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              child: const Text('New chat'),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_inputFocus.hasFocus) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final reply in pharmacyQuickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(reply, style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        onPressed: () => _send(reply),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _inputFocus,
                  maxLength: _maxMessageLength,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: _send,
                  decoration: const InputDecoration(
                    hintText: 'e.g. my cat keeps scratching her ear',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  return IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: value.text.trim().isEmpty ? null : () => _send(_controller.text),
                    icon: const Icon(Icons.send, size: 20),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(text, style: AppTheme.body(fontSize: 14, color: Colors.white)),
        ),
      ),
    );
  }
}

class _BotBubble extends StatelessWidget {
  final PharmacyReply reply;
  final ValueChanged<String> onSend;
  final VoidCallback onBookVet;
  final VoidCallback? onSettled;

  const _BotBubble({required this.reply, required this.onSend, required this.onBookVet, this.onSettled});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.92),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBody(),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(pharmacyDisclaimer, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (reply.kind) {
      case PharmacyReplyKind.emergency:
        return _buildEmergency();
      case PharmacyReplyKind.advice:
        return _buildAdvice();
      case PharmacyReplyKind.greeting:
        return Text(reply.message, style: AppTheme.body(fontSize: 14));
      case PharmacyReplyKind.fallback:
        return _buildFallback();
    }
  }

  Widget _buildEmergency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emergency, size: 18, color: AppColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'Urgent',
                    style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(reply.message, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _BulletList(items: reply.steps),
            ],
          ),
        ),
        _VetLink(label: 'Book a video consult for follow-up advice', onPressed: onBookVet),
      ],
    );
  }

  Widget _buildAdvice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (reply.title != null) Text(reply.title!, style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(reply.message, style: AppTheme.body(fontSize: 14)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: _amber),
                  const SizedBox(width: 6),
                  Text(
                    'SEE A VET IF',
                    style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w700, color: _amber),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _BulletList(items: reply.seeVet),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (reply.searchKeywords.isNotEmpty)
          _ProductSuggestions(
            keywords: reply.searchKeywords,
            category: reply.category,
            onSettled: onSettled,
          )
        else if (reply.noProductsNote != null)
          Text(reply.noProductsNote!, style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
        _VetLink(label: 'Book a video consult with a vet', onPressed: onBookVet),
      ],
    );
  }

  Widget _buildFallback() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(reply.message, style: AppTheme.body(fontSize: 14)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in pharmacyTopics)
              ActionChip(
                label: Text(topic, style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w500)),
                onPressed: () => onSend(topic),
                backgroundColor: AppColors.paper,
                side: const BorderSide(color: AppColors.border),
              ),
          ],
        ),
        _VetLink(label: 'Book a video consult with a vet', onPressed: onBookVet),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  const _BulletList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: AppTheme.body(fontSize: 13.5)),
                Expanded(child: Text(item, style: AppTheme.body(fontSize: 13.5))),
              ],
            ),
          ),
      ],
    );
  }
}

class _VetLink extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _VetLink({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.medical_services_outlined, size: 16),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 6),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
          textStyle: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SuggestedProduct {
  final String id;
  final String name;
  final num price;
  final String? shopName;
  final String? photoUrl;
  final bool requiresPrescription;

  const _SuggestedProduct({
    required this.id,
    required this.name,
    required this.price,
    this.shopName,
    this.photoUrl,
    required this.requiresPrescription,
  });

  factory _SuggestedProduct.fromJson(Map<String, dynamic> json) {
    final photos = json['photo_urls'];
    final shop = json['shops'];
    final firstPhoto = photos is List && photos.isNotEmpty ? photos.first : null;
    return _SuggestedProduct(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Product',
      price: json['price'] as num? ?? 0,
      shopName: shop is Map ? shop['name'] as String? : null,
      photoUrl: firstPhoto is String ? firstPhoto : null,
      requiresPrescription: json['requires_prescription'] as bool? ?? false,
    );
  }
}

/// Looks up catalogue products matching the reply's keywords and lists up to four.
class _ProductSuggestions extends StatefulWidget {
  final List<String> keywords;
  final String? category;
  final VoidCallback? onSettled;

  const _ProductSuggestions({required this.keywords, required this.category, this.onSettled});

  @override
  State<_ProductSuggestions> createState() => _ProductSuggestionsState();
}

class _ProductSuggestionsState extends State<_ProductSuggestions> with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<_SuggestedProduct> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final filter = buildProductFilter(widget.keywords);
    var items = <_SuggestedProduct>[];
    String? error;
    if (filter.isNotEmpty) {
      try {
        var query = SupabaseService.client
            .from('products')
            .select(_productColumns)
            .eq('status', 'available')
            .or(filter);
        final category = widget.category;
        if (category != null) query = query.eq('category', category);
        final rows = await query.limit(4);
        items = rows.map(_SuggestedProduct.fromJson).toList();
      } catch (e) {
        error = errorText(e);
      }
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _error = error;
      _loading = false;
    });
    // The list grows once results arrive; let the chat keep the newest reply in view.
    widget.onSettled?.call();
  }

  // The chat list builds lazily; keep each reply's results so scrolling back
  // up doesn't search the store again.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('Looking for related products…', style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
      );
    }
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          "Couldn't search the store: $error",
          style: AppTheme.body(fontSize: 13.5, color: AppColors.error),
        ),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'Nothing in the store matches right now. A vet can recommend the right option for your pet.',
          style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'IN THE STORE',
          style: AppTheme.body(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        for (final product in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProductTile(product: product),
          ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  final _SuggestedProduct product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final shopName = product.shopName?.trim() ?? '';
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/store/${product.id}'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _ProductThumb(url: product.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (shopName.isNotEmpty)
                      Text(
                        shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                      ),
                    if (product.requiresPrescription) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Prescription needed',
                          style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: _amber),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatPrice(product.price),
                style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final String? url;
  const _ProductThumb({required this.url});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 40,
      height: 40,
      color: AppColors.primary.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: const Icon(Icons.medication_outlined, size: 20, color: AppColors.primary),
    );
    final src = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 40,
        height: 40,
        child: src == null || src.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: src,
                fit: BoxFit.cover,
                errorWidget: (context, imageUrl, error) => fallback,
                placeholder: (context, imageUrl) => fallback,
              ),
      ),
    );
  }
}
