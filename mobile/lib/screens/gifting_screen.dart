import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_actions/gift_pet_sheet.dart' show isEmailOrPhone;
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/ui_kit.dart';
import 'store_screen.dart' show discardPendingOrder, stockColor, stockLabel;

/// Mirrors src/pages/Gifting.jsx: a list of available products (public
/// columns plus the shop's name only), each with an inline "Send as gift"
/// form that places an order + order_item + gift row. The shop confirms
/// pickup details afterwards; payment happens in person. (Pets are gifted from
/// their own page.)
class GiftingScreen extends ConsumerStatefulWidget {
  const GiftingScreen({super.key});

  @override
  ConsumerState<GiftingScreen> createState() => _GiftingScreenState();
}

class _GiftingScreenState extends ConsumerState<GiftingScreen> {
  List<Product> _products = [];
  bool _loading = true;
  Object? _error;
  String? _activeProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _fetch() async {
    try {
      final products = await ProductsRepository().listAvailable();
      if (!mounted) return;
      setState(() {
        _products = products;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  /// Pull-to-refresh: keeps the list on screen if the reload fails.
  Future<void> _refresh() async {
    final hadProducts = _products.isNotEmpty;
    await _fetch();
    final error = _error;
    if (mounted && hadProducts && error != null) {
      showSnack(context, commerceErrorText(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final authLoading = auth.status == AuthStatus.loading;
    final profile = auth.status == AuthStatus.signedIn ? auth.profile : null;

    final Widget state;
    if (_loading) {
      state = const _GiftSkeleton();
    } else if (_error != null && _products.isEmpty) {
      state = CommerceRetryView(title: "We couldn't load gift ideas", error: _error, onRetry: _load);
    } else if (_products.isEmpty) {
      state = const EmptyState(
        title: 'No products available to gift right now',
        description: 'Shops have not listed any products yet. Check back soon.',
      );
    } else {
      state = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final product in _products) ...[
            _GiftProductCard(
              key: ValueKey(product.id),
              product: product,
              isActive: _activeProductId == product.id,
              profile: profile,
              authLoading: authLoading,
              onSendTap: () => setState(() => _activeProductId = product.id),
              onDone: () => setState(() => _activeProductId = null),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }

    return RoleShell(
      title: 'Gifting',
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: kScreenPadding,
          children: [
            ContentWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Send a gift', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick something from the store and send it to someone else. The shop will confirm pickup details '
                    'with you, and you pay in person.',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  const NoticeBox(
                    message: 'Want to gift a pet? Open any pet and choose "Send as gift" on its page.',
                  ),
                  const SizedBox(height: 20),
                  state,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder cards shown while the products load.
class _GiftSkeleton extends StatelessWidget {
  const _GiftSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading gift ideas',
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 72, height: 72, radius: 10),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 50, height: 12),
                          SizedBox(height: 8),
                          SkeletonBox(width: 160, height: 15),
                          SizedBox(height: 8),
                          SkeletonBox(width: 100, height: 13),
                          SizedBox(height: 10),
                          SkeletonBox(width: 70, height: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GiftProductCard extends StatelessWidget {
  final Product product;
  final bool isActive;
  final Profile? profile;
  final bool authLoading;
  final VoidCallback onSendTap;
  final VoidCallback onDone;

  const _GiftProductCard({
    super.key,
    required this.product,
    required this.isActive,
    required this.profile,
    required this.authLoading,
    required this.onSendTap,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final signedInProfile = profile;
    final shopName = product.shop?.name ?? '';
    final outOfStock = product.stockQuantity <= 0;

    final Widget action;
    if (isActive && signedInProfile != null && signedInProfile.role == 'customer') {
      action = _GiftForm(product: product, profile: signedInProfile, onDone: onDone);
    } else if (isActive && signedInProfile != null) {
      action = const NoticeBox(
        message: 'Only customer accounts can send gifts. Log in with a customer account to continue.',
      );
    } else if (isActive && !authLoading) {
      action = const LoginPromptCard(
        compact: true,
        title: 'Log in to send a gift',
        description: 'Log in to send this as a gift.',
      );
    } else {
      action = Semantics(
        button: true,
        enabled: !outOfStock,
        label: outOfStock ? '${product.name} is out of stock' : 'Send ${product.name} as a gift',
        excludeSemantics: true,
        onTap: outOfStock ? null : onSendTap,
        child: OutlinedButton.icon(
          onPressed: outOfStock ? null : onSendTap,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          icon: const Icon(Icons.card_giftcard, size: 18),
          label: Text(outOfStock ? 'Out of stock' : 'Send as gift'),
        ),
      );
    }

    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ProductPhotoView(
                    src: product.photoUrls.isEmpty ? null : product.photoUrls.first,
                    category: product.category,
                    cacheWidth: 144,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titleCase(product.category), style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: AppTheme.body(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shopName.isNotEmpty)
                      Text(
                        shopName,
                        style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(product.price),
                      style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700, color: kPetPriceColor),
                    ),
                    Text(
                      stockLabel(product),
                      style: AppTheme.body(fontSize: 12, color: stockColor(product)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          action,
        ],
      ),
    );
  }
}

class _GiftForm extends StatefulWidget {
  final Product product;
  final Profile profile;
  final VoidCallback onDone;

  const _GiftForm({
    required this.product,
    required this.profile,
    required this.onDone,
  });

  @override
  State<_GiftForm> createState() => _GiftFormState();
}

class _GiftFormState extends State<_GiftForm> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _messageController = TextEditingController();

  String? _nameError;
  String? _contactError;
  String? _formError;
  bool _submitting = false;
  String? _sentRecipientName;
  String? _sentOrderId;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final message = _messageController.text.trim();
    final nameError = name.isEmpty ? "Enter the recipient's name." : null;
    final contactError = contact.isEmpty
        ? "Enter the recipient's email or phone number."
        : (isEmailOrPhone(contact) ? null : 'Enter a valid email address or phone number.');
    setState(() {
      _nameError = nameError;
      _contactError = contactError;
      _formError = null;
    });
    if (nameError != null || contactError != null) return;

    setState(() => _submitting = true);
    String? orderId;
    try {
      orderId = await OrdersRepository().insert({
        'customer_id': widget.profile.id,
        'order_type': 'gift',
        'status': 'pending',
        'payment_type': 'full',
        'total_amount': widget.product.price,
      });
      await OrderItemsRepository().insert({
        'order_id': orderId,
        'item_type': 'product',
        'item_id': widget.product.id,
        'quantity': 1,
        'price_at_purchase': widget.product.price,
      });
      await GiftsRepository().insert({
        'order_id': orderId,
        'sender_id': widget.profile.id,
        'recipient_name': name,
        'recipient_contact': contact,
        'message': message.isEmpty ? null : message,
        'delivery_status': 'pending',
      });
    } catch (error) {
      // Don't leave a half-built gift order behind for the shop to puzzle over.
      if (orderId != null) unawaited(discardPendingOrder(orderId));
      if (!mounted) return;
      setState(() {
        _formError = commerceErrorText(error);
        _submitting = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _sentRecipientName = name;
      _sentOrderId = orderId;
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipient = _sentRecipientName;
    if (recipient != null) {
      return SuccessPanel(
        title: 'Gift order placed',
        message: 'Your gift for $recipient is reserved. The shop will confirm pickup details with you, and you pay '
            'in person. Nothing was charged online.',
        actions: [
          ElevatedButton(
            onPressed: () => context.go('/account/orders'),
            child: const Text('View my orders'),
          ),
          OutlinedButton(
            onPressed: () =>
                context.push(shopSupportRoute(shopId: widget.product.shopId, orderId: _sentOrderId)),
            child: const Text('Message the shop'),
          ),
          TextButton(onPressed: widget.onDone, child: const Text('Done')),
        ],
      );
    }

    return PopScope(
      canPop: !_submitting,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_submitting,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: AppTheme.body(fontSize: 14),
              decoration: InputDecoration(labelText: 'Recipient name', errorText: _nameError, counterText: ''),
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactController,
              enabled: !_submitting,
              maxLength: 120,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              style: AppTheme.body(fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Recipient phone or email',
                errorText: _contactError,
                counterText: '',
              ),
              onChanged: (_) {
                if (_contactError != null) setState(() => _contactError = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: AppTheme.body(fontSize: 14),
              decoration: const InputDecoration(labelText: 'Message (optional)'),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: NoticeBox.error(message: _formError!)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                LoadingButton(label: 'Send gift', loading: _submitting, onPressed: _submit),
                TextButton(
                  onPressed: _submitting ? null : widget.onDone,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
