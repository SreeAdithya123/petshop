import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/Gifting.jsx: a list of available products (public
/// columns plus the shop's name only), each with an inline "Send as gift"
/// form that places an order + order_item + gift row. The shop confirms
/// pickup details afterwards; payment happens in person.
class GiftingScreen extends ConsumerStatefulWidget {
  const GiftingScreen({super.key});

  @override
  ConsumerState<GiftingScreen> createState() => _GiftingScreenState();
}

class _GiftingScreenState extends ConsumerState<GiftingScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final profile = auth.status == AuthStatus.signedIn ? auth.profile : null;

    final header = <Widget>[
      Text('Send a gift', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Pick something from the store and send it to someone else — the shop will confirm pickup details with you.',
        style: AppTheme.body(color: AppColors.inkSoft),
      ),
      const SizedBox(height: 20),
    ];

    final Widget content;
    if (_loading) {
      content = ListView(
        padding: kScreenPadding,
        children: [
          ...header,
          const SkeletonPulse(
            child: Column(
              children: [
                _GiftCardSkeleton(),
                SizedBox(height: 12),
                _GiftCardSkeleton(),
                SizedBox(height: 12),
                _GiftCardSkeleton(),
              ],
            ),
          ),
        ],
      );
    } else if (_error != null) {
      content = RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ...header,
            EmptyState(
              title: "We couldn't load gift ideas",
              description: _error,
              action: ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ),
          ],
        ),
      );
    } else {
      content = RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ...header,
            if (_products.isEmpty)
              const EmptyState(title: 'No products available to gift right now')
            else
              for (final product in _products) ...[
                _GiftProductCard(
                  product: product,
                  isActive: _activeProductId == product.id,
                  profile: profile,
                  onSendTap: () => setState(() => _activeProductId = product.id),
                  onDone: () => setState(() => _activeProductId = null),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      );
    }

    return RoleShell(title: 'Gifting', child: content);
  }
}

class _GiftCardSkeleton extends StatelessWidget {
  const _GiftCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 50, height: 12),
          SizedBox(height: 8),
          SkeletonBox(width: 160, height: 15),
          SizedBox(height: 8),
          SkeletonBox(width: 100, height: 13),
          SizedBox(height: 10),
          SkeletonBox(width: 70, height: 18),
          SizedBox(height: 12),
          SkeletonBox(height: 40, radius: 10),
        ],
      ),
    );
  }
}

class _GiftProductCard extends StatelessWidget {
  final Product product;
  final bool isActive;
  final Profile? profile;
  final VoidCallback onSendTap;
  final VoidCallback onDone;

  const _GiftProductCard({
    required this.product,
    required this.isActive,
    required this.profile,
    required this.onSendTap,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final signedInProfile = profile;
    final shopName = product.shop?.name ?? '';

    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titleCase(product.category), style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Text(product.name, style: AppTheme.body(fontWeight: FontWeight.w600)),
          if (shopName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              shopName,
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            formatPrice(product.price),
            style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: signedInProfile != null
                  ? _GiftForm(product: product, profile: signedInProfile, onDone: onDone)
                  : const LoginPromptCard(
                      compact: true,
                      title: 'Log in to send a gift',
                      description: 'Log in to send this as a gift.',
                    ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: onSendTap, child: const Text('Send as gift')),
              ),
            ),
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
  bool _sent = false;
  String _sentRecipientName = '';

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    setState(() {
      _nameError = name.isEmpty ? "Enter the recipient's name." : null;
      _contactError = contact.isEmpty ? 'Enter a phone number or email for the recipient.' : null;
      _formError = null;
    });
    if (_nameError != null || _contactError != null) return;

    setState(() => _submitting = true);
    try {
      final orderId = await OrdersRepository().insert({
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
      final message = _messageController.text.trim();
      await GiftsRepository().insert({
        'order_id': orderId,
        'sender_id': widget.profile.id,
        'recipient_name': name,
        'recipient_contact': contact,
        'message': message.isEmpty ? null : message,
        'delivery_status': 'pending',
      });
      if (!mounted) return;
      setState(() {
        _sent = true;
        _sentRecipientName = name;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = errorText(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return NoticeBox(
        message: 'Gift order placed for $_sentRecipientName — the shop will confirm pickup details with you.',
        color: AppColors.trust,
        icon: Icons.check_circle_outline,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recipient name', style: AppTheme.body(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
            controller: _nameController,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.words,
            style: AppTheme.body(fontSize: 14),
            decoration: InputDecoration(errorText: _nameError, isDense: true),
          ),
          const SizedBox(height: 10),
          Text('Recipient phone or email', style: AppTheme.body(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
            controller: _contactController,
            enabled: !_submitting,
            style: AppTheme.body(fontSize: 14),
            decoration: InputDecoration(errorText: _contactError, isDense: true),
          ),
          const SizedBox(height: 10),
          Text('Message (optional)', style: AppTheme.body(fontSize: 13)),
          const SizedBox(height: 4),
          TextField(
            controller: _messageController,
            enabled: !_submitting,
            style: AppTheme.body(fontSize: 14),
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(isDense: true),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 10),
            NoticeBox.error(message: _formError!),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              LoadingButton(label: 'Send gift', loading: _submitting, onPressed: _submit),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _submitting ? null : widget.onDone,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
