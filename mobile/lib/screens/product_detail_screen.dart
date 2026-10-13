import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

const _amber = Color(0xFFB45309);

/// Mirrors src/pages/ProductDetail.jsx: loads one product (public columns and
/// the shop's NAME only -- never its address or phone) and lets a signed-in
/// user place a pickup order, paid in person.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  String? _loadError;

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
      _loadError = null;
      _product = null;
      _purchased = false;
      _purchaseError = null;
    });
    try {
      final product = await ProductsRepository().getById(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        // 22P02: the id in the link isn't a valid uuid, i.e. there is no such product.
        _loadError = e.code == '22P02' ? null : errorText(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    final profile = ref.read(authControllerProvider).profile;
    final product = _product;
    if (profile == null || product == null || _purchasing) return;

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
        _purchaseError = errorText(e);
        _purchasing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isSignedIn = auth.status == AuthStatus.signedIn && auth.profile != null;
    final product = _product;

    final Widget body;
    if (_loading) {
      body = const _ProductSkeleton();
    } else if (_loadError != null) {
      body = Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "We couldn't load that product",
          description: _loadError,
          action: ElevatedButton(onPressed: _load, child: const Text('Try again')),
        ),
      );
    } else if (product == null) {
      body = Padding(
        padding: kScreenPadding,
        child: EmptyState(
          title: "We couldn't find that product",
          action: ElevatedButton(
            onPressed: () => context.go('/store'),
            child: const Text('Browse the store'),
          ),
        ),
      );
    } else {
      body = _buildProduct(product, isSignedIn);
    }

    return RoleShell(title: product?.name ?? 'Product', child: body);
  }

  Widget _buildProduct(Product product, bool isSignedIn) {
    final outOfStock = product.stockQuantity <= 0;
    final unavailable = product.status != 'available' || outOfStock;
    final description = product.description;
    final shopName = product.shop?.name ?? '';
    final photo = product.photoUrls.isEmpty ? null : product.photoUrls.first;

    return ListView(
      padding: kScreenPadding,
      children: [
        if (photo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: PetPhotoView(src: photo, species: ''),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Text(titleCase(product.category), style: AppTheme.body(color: AppColors.inkSoft)),
            if (product.requiresPrescription) ...[
              const SizedBox(width: 10),
              const StatusPill(status: 'Prescription needed', color: _amber),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(product.name, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          formatPrice(product.price),
          style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent),
        ),
        if (description != null && description.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(description.trim(), style: AppTheme.body(color: AppColors.inkSoft)),
        ],
        const SizedBox(height: 8),
        Text(
          outOfStock ? 'Out of stock' : '${product.stockQuantity} in stock',
          style: AppTheme.body(fontSize: 13, color: outOfStock ? AppColors.error : AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        CardBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shopName.isNotEmpty) ...[
                Text(shopName, style: AppTheme.body(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
              ],
              Text(
                'The shop will confirm pickup details with you after you place the order.',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_purchased)
          SuccessPanel(
            title: 'Order placed',
            message: 'The shop will confirm pickup details with you. Pay in person at pickup.',
            actions: [
              ElevatedButton(
                onPressed: () => context.go('/account/orders'),
                child: const Text('View my orders'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/store'),
                child: const Text('Keep browsing'),
              ),
            ],
          )
        else if (unavailable)
          Text("This product isn't available right now.", style: AppTheme.body(color: AppColors.inkSoft))
        else if (isSignedIn) ...[
          LoadingButton(
            label: 'Order for pickup',
            loading: _purchasing,
            expand: true,
            onPressed: _handlePurchase,
          ),
          if (_purchaseError != null) ...[
            const SizedBox(height: 10),
            NoticeBox.error(message: _purchaseError!),
          ],
        ] else
          const LoginPromptCard(
            compact: true,
            title: 'Log in to order',
            description: 'Log in to order this product.',
          ),
      ],
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 70, height: 14),
            SizedBox(height: 12),
            SkeletonBox(width: 220, height: 28),
            SizedBox(height: 14),
            SkeletonBox(width: 100, height: 24),
            SizedBox(height: 22),
            SkeletonBox(height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 260, height: 14),
          ],
        ),
      ),
    );
  }
}
