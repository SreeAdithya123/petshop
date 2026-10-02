import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/Gifting.jsx: a list of available products, each with an
/// inline "Send as gift" form that places a real order + order_item + gift
/// row (pickup-and-pay-at-shop, same as a direct purchase in ProductDetail).
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
    try {
      final products = await ProductsRepository().listAvailable();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load products. Try again.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;

    Widget content;
    if (_loading) {
      content = const LoadingView();
    } else if (_error != null) {
      content = ErrorView(message: _error!);
    } else {
      content = ListView(
        padding: kScreenPadding,
        children: [
          Text(
            'Send a gift',
            style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Pick something from the store and send it to someone else — they pick it up at the shop.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                title: 'No products available to gift right now',
              ),
            )
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
      );
    }

    return RoleShell(title: 'Gifting', child: content);
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _capitalize(product.category),
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(product.name, style: AppTheme.body(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            product.shop?.name ?? '',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            formatPrice(product.price),
            style: AppTheme.display(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          if (isActive)
            profile != null
                ? _GiftForm(product: product, profile: profile!, onDone: onDone)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/login'),
                            child: Text(
                              'Log in',
                              style: AppTheme.body(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            ' to send this as a gift.',
                            style: AppTheme.body(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                  )
          else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSendTap,
                  child: const Text('Send as gift'),
                ),
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
      _contactError = contact.isEmpty
          ? "Enter a phone number or email for the recipient."
          : null;
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
        _formError = e is PostgrestException && e.message.isNotEmpty
            ? e.message
            : "Couldn't send that gift. Try again.";
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            'Gift order placed for $_sentRecipientName — pick up and pay at the shop.',
            style: AppTheme.body(color: AppColors.trust, fontSize: 13),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
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
              style: AppTheme.body(fontSize: 14),
              decoration: InputDecoration(errorText: _nameError, isDense: true),
            ),
            const SizedBox(height: 10),
            Text(
              'Recipient phone or email',
              style: AppTheme.body(fontSize: 13),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _contactController,
              style: AppTheme.body(fontSize: 14),
              decoration: InputDecoration(
                errorText: _contactError,
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Text('Message (optional)', style: AppTheme.body(fontSize: 13)),
            const SizedBox(height: 4),
            TextField(
              controller: _messageController,
              style: AppTheme.body(fontSize: 14),
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(isDense: true),
            ),
            if (_formError != null) ...[
              const SizedBox(height: 8),
              Text(
                _formError!,
                style: AppTheme.body(fontSize: 13, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Sending…' : 'Send gift'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submitting ? null : widget.onDone,
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

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
