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

/// Mirrors src/pages/ProductDetail.jsx: loads one product (with its shop's
/// name/address/phone via the join), and lets a signed-in customer place a
/// direct pickup-and-pay-at-shop order for it.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  bool _notFound = false;

  bool _purchasing = false;
  String? _purchaseError;
  bool _purchased = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    try {
      final product = await ProductsRepository().getById(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _notFound = product == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    final profile = ref.read(authControllerProvider).profile;
    final product = _product;
    if (profile == null || product == null) return;

    setState(() {
      _purchasing = true;
      _purchaseError = null;
    });
    try {
      final orderId = await OrdersRepository().insert({
        'customer_id': profile.id,
        'order_type': 'product_purchase',
        'status': 'pending',
        'payment_type': 'full',
        'total_amount': product.price,
      });
      await OrderItemsRepository().insert({
        'order_id': orderId,
        'item_type': 'product',
        'item_id': product.id,
        'quantity': 1,
        'price_at_purchase': product.price,
      });
      if (!mounted) return;
      setState(() {
        _purchased = true;
        _purchasing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseError = e is PostgrestException && e.message.isNotEmpty
            ? e.message
            : "Couldn't place that order. Try again.";
        _purchasing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isSignedIn =
        auth.status == AuthStatus.signedIn && auth.profile != null;

    Widget body;
    if (_loading) {
      body = const LoadingView();
    } else if (_notFound || _product == null) {
      body = Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "We couldn't find that product",
          action: ElevatedButton(
            onPressed: () => context.push('/store'),
            child: const Text('Browse the store'),
          ),
        ),
      );
    } else {
      final product = _product!;
      body = ListView(
        padding: kScreenPadding,
        children: [
          Text(
            _capitalize(product.category),
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            formatPrice(product.price),
            style: AppTheme.display(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
          if (product.description != null &&
              product.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              product.description!,
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${product.stockQuantity} in stock',
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
          if (product.shop != null) ...[
            const SizedBox(height: 20),
            Container(
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
                    product.shop!.name,
                    style: AppTheme.body(fontWeight: FontWeight.w600),
                  ),
                  if (product.shop!.address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.shop!.address,
                      style: AppTheme.body(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  if (product.shop!.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.shop!.phone,
                      style: AppTheme.body(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_purchased)
            Text(
              'Order placed — pick up and pay at ${product.shop?.name ?? 'the shop'}.',
              style: AppTheme.body(color: AppColors.trust),
            )
          else if (isSignedIn) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _purchasing ? null : _handlePurchase,
                child: Text(_purchasing ? 'Placing order…' : 'Add to Cart'),
              ),
            ),
            if (_purchaseError != null) ...[
              const SizedBox(height: 8),
              Text(
                _purchaseError!,
                style: AppTheme.body(fontSize: 13, color: AppColors.error),
              ),
            ],
          ] else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Log in to buy'),
              ),
            ),
        ],
      );
    }

    return RoleShell(title: _product?.name ?? 'Product detail', child: body);
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
