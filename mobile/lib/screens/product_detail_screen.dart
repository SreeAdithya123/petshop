import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/ui_kit.dart';
import 'store_screen.dart' show discardPendingOrder, stockColor, stockLabel;

/// Mirrors src/pages/ProductDetail.jsx: loads one product (public columns and
/// the shop's NAME only -- never its address or phone) and lets a signed-in
/// customer place a pickup order, paid in person. Out-of-stock products can't
/// be ordered; pull to refresh reloads the product (and its stock).
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  Object? _loadError;

  bool _purchasing = false;
  String? _purchaseError;
  bool _purchased = false;
  String? _orderId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the product. A [quiet] reload (pull to refresh, or after a failed
  /// order to pick up changed stock) keeps what is on screen and the order
  /// state, and only replaces the product when it succeeds.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _loading = true;
        _loadError = null;
        _product = null;
        _purchased = false;
        _purchaseError = null;
        _orderId = null;
      });
    }
    try {
      final product = await ProductsRepository().getById(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loadError = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      // 22P02: the id in the link isn't a valid uuid, i.e. there is no such product.
      final notFound = error is PostgrestException && error.code == '22P02';
      setState(() {
        _loading = false;
        if (notFound) {
          _product = null;
          _loadError = null;
        } else if (!quiet || _product == null) {
          _loadError = error;
        }
      });
    }
  }

  Future<void> _handlePurchase() async {
    final auth = ref.read(authControllerProvider);
    final profile = auth.profile;
    final product = _product;
    if (profile == null || profile.role != 'customer' || product == null || _purchasing) return;

    setState(() {
      _purchasing = true;
      _purchaseError = null;
    });
    String? orderId;
    try {
      orderId = await OrdersRepository().insert({
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
    } catch (error) {
      // Don't leave an empty pending order behind for the shop to puzzle over.
      if (orderId != null) unawaited(discardPendingOrder(orderId));
      if (!mounted) return;
      setState(() {
        _purchasing = false;
        _purchaseError = commerceErrorText(error);
      });
      // The stock or availability may have changed: show the latest.
      unawaited(_load(quiet: true));
      return;
    }
    if (!mounted) return;
    setState(() {
      _purchasing = false;
      _purchased = true;
      _orderId = orderId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    final Widget body;
    if (_loading) {
      body = const _ProductDetailSkeleton();
    } else if (_loadError != null) {
      body = ScrollableMessage(
        child: CommerceRetryView(
          title: "We couldn't load that product",
          error: _loadError,
          onRetry: _load,
        ),
      );
    } else if (product == null) {
      body = RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ScrollableMessage(
          child: EmptyState(
            title: "We couldn't find that product",
            description: 'It may have been removed, or the link is out of date.',
            action: ElevatedButton(
              onPressed: () => context.go('/store'),
              child: const Text('Browse the store'),
            ),
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => _load(quiet: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [ContentWidth(maxWidth: 720, child: _buildProduct(product))],
        ),
      );
    }

    return RoleShell(
      title: product?.name ?? 'Product',
      actions: const [CartAppBarAction()],
      child: body,
    );
  }

  Widget _buildProduct(Product product) {
    final stock = product.stockQuantity;
    final outOfStock = stock <= 0;
    final unavailable = product.status != 'available' || outOfStock;
    final description = product.description?.trim() ?? '';
    final shopName = product.shop?.name ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (product.photoUrls.isNotEmpty) ...[
          PhotoGallery(
            key: ValueKey(product.id),
            photos: product.photoUrls,
            label: 'Photos of ${product.name}',
            statusLabel: unavailable ? (outOfStock ? 'Out of stock' : 'Unavailable') : null,
            photoBuilder: (url, cacheWidth, label) => ProductPhotoView(
              src: url,
              category: product.category,
              cacheWidth: cacheWidth,
              semanticLabel: label,
            ),
          ),
          const SizedBox(height: 20),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(titleCase(product.category), style: AppTheme.body(color: AppColors.inkSoft)),
            if (product.requiresPrescription) const StatusPill(status: 'Prescription needed', color: kAmberTextColor),
          ],
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(product.name, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        Text(
          formatPrice(product.price),
          style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: kPetPriceColor),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(description, style: AppTheme.body(color: AppColors.inkSoft).copyWith(height: 1.5)),
        ],
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            stockLabel(product),
            style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600, color: stockColor(product)),
          ),
        ),
        if (product.requiresPrescription) ...[
          const SizedBox(height: 16),
          const NoticeBox.warning(
            message: 'Prescription needed. Bring a valid prescription when you collect this item; the shop may '
                'ask to see it before handing it over.',
          ),
        ],
        const SizedBox(height: 20),
        CardBox(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shopName.isNotEmpty) ...[
                Text('Sold by', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
                Text(shopName, style: AppTheme.body(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
              ],
              Text(
                'The shop will confirm pickup details with you after you place the order. You pay in person at '
                'pickup; nothing is charged online.',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => context.push(shopSupportRoute(shopId: product.shopId)),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48), padding: EdgeInsets.zero),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message the shop'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildAction(product, unavailable: unavailable, outOfStock: outOfStock),
      ],
    );
  }

  Widget _buildAction(Product product, {required bool unavailable, required bool outOfStock}) {
    if (_purchased) {
      return SuccessPanel(
        title: 'Order placed',
        message: 'The shop will confirm pickup details with you. Pay in person at pickup; nothing was charged online.',
        actions: [
          ElevatedButton(
            onPressed: () => context.go('/account/orders'),
            child: const Text('View my orders'),
          ),
          OutlinedButton(
            onPressed: () => context.push(shopSupportRoute(shopId: product.shopId, orderId: _orderId)),
            child: const Text('Message the shop'),
          ),
          TextButton(
            onPressed: () => context.go('/store'),
            child: const Text('Keep browsing'),
          ),
        ],
      );
    }

    if (unavailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: Text(outOfStock ? 'Out of stock' : 'Not available'),
          ),
          const SizedBox(height: 8),
          Text(
            outOfStock
                ? 'This product is out of stock right now. Pull down to refresh, or check back later.'
                : "This product isn't available right now.",
            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      );
    }

    final auth = ref.watch(authControllerProvider);
    if (auth.status == AuthStatus.loading) {
      return const SkeletonBox(height: 52, radius: 12);
    }
    final profile = auth.status == AuthStatus.signedIn ? auth.profile : null;
    if (profile == null) {
      return const LoginPromptCard(
        compact: true,
        title: 'Log in to order',
        description: 'Log in to order this product.',
      );
    }
    if (profile.role != 'customer') {
      return const NoticeBox(
        message: 'Only customer accounts can order products. Log in with a customer account to order this item.',
      );
    }

    final error = _purchaseError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LoadingButton(
          label: 'Order for pickup · ${formatPrice(product.price)}',
          loading: _purchasing,
          expand: true,
          onPressed: _handlePurchase,
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Semantics(liveRegion: true, child: NoticeBox.error(message: error)),
        ],
      ],
    );
  }
}

/// Placeholder shown while the product loads.
class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading product',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: const [
          ContentWidth(
            maxWidth: 720,
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
        ],
      ),
    );
  }
}
