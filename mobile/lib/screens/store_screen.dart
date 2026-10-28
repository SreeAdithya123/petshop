import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/ui_kit.dart';

/// Stock level at or below which a product is flagged "Only N left".
const int kLowStockThreshold = 5;

/// Grid for [ProductCard]s [gridWidth] dp wide: two columns on phones, more on
/// tablets, with a row height that grows with the system text size so the
/// labels never squeeze the photo to nothing.
SliverGridDelegate productGridDelegate(BuildContext context, double gridWidth) {
  final columns = petGridColumns(gridWidth);
  final cell = (gridWidth - kPetGridSpacing * (columns - 1)) / columns;
  final photoBonus = ((cell - 170) * 0.5).clamp(0.0, 120.0).toDouble();
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: kPetGridSpacing,
    crossAxisSpacing: kPetGridSpacing,
    mainAxisExtent: 262 + photoBonus + (petTextScale(context) - 1) * 170,
  );
}

/// Short stock line for a product: "Out of stock", "Only 3 left" or "12 in stock".
String stockLabel(Product product) {
  final stock = product.stockQuantity;
  if (stock <= 0) return 'Out of stock';
  if (stock <= kLowStockThreshold) return 'Only $stock left';
  return '$stock in stock';
}

/// Colour for [stockLabel] that stays readable on white.
Color stockColor(Product product) {
  final stock = product.stockQuantity;
  if (stock <= 0) return AppColors.error;
  if (stock <= kLowStockThreshold) return kAmberTextColor;
  return AppColors.inkSoft;
}

/// Best-effort clean-up when an order was created but its items could not be
/// saved: asks the server to cancel the empty pending order (customers may
/// cancel their own pending orders). Never throws; if the cancel function
/// isn't available yet the empty order simply stays pending.
Future<void> discardPendingOrder(String orderId) async {
  try {
    await SupabaseService.client.rpc('cancel_my_order', params: {'p_order_id': orderId});
  } catch (_) {
    // Nothing more can be done from the app.
  }
}

/// (value, label) options, mirroring the categoryTabs array in Store.jsx.
const _categories = [
  ('all', 'All'),
  ('medicine', 'Medicine'),
  ('store', 'Store'),
];

/// Mirrors src/pages/Store.jsx: a category-filtered grid of available
/// products loaded straight from Supabase (public columns plus the shop's
/// name only, via ProductsRepository), with a search box. Pull to refresh.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = [];
  bool _loading = true;
  Object? _error;
  String _category = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  List<Product> get _filtered {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      if (_category != 'all' && product.category != _category) return false;
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          (product.shop?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  int _countFor(String category) =>
      category == 'all' ? _products.length : _products.where((product) => product.category == category).length;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _category = 'all';
    });
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Store', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Text(
          'Medicine and everyday supplies from shops near you. Order online, pick up and pay at the shop.',
          style: AppTheme.body(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Search products',
            prefixIcon: const Icon(Icons.search, color: AppColors.inkSoft),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilterChipBar<String>(
          options: [
            for (final entry in _categories)
              FilterOption<String>(entry.$1, entry.$2, count: _loading ? null : _countFor(entry.$1)),
          ],
          selected: _category,
          onSelected: (value) => setState(() => _category = value),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final failedToLoad = _error != null && _products.isEmpty;

    final List<Widget> body;
    if (_loading) {
      body = [const SliverToBoxAdapter(child: _ProductGridSkeleton())];
    } else if (failedToLoad) {
      body = [
        SliverToBoxAdapter(
          child: CommerceRetryView(
            title: "We couldn't load the store",
            error: _error,
            onRetry: _load,
          ),
        ),
      ];
    } else if (_products.isEmpty) {
      body = [
        const SliverToBoxAdapter(
          child: EmptyState(
            title: 'No products yet',
            description: "Shops haven't listed any products yet. Check back soon.",
          ),
        ),
      ];
    } else if (filtered.isEmpty) {
      body = [
        SliverToBoxAdapter(
          child: EmptyState(
            title: 'No products found',
            description: 'Try a different category or search, or check back later.',
            action: OutlinedButton(onPressed: _clearFilters, child: const Text('Clear filters')),
          ),
        ),
      ];
    } else {
      body = [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${filtered.length} ${filtered.length == 1 ? 'product' : 'products'}',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
            ),
          ),
        ),
        SliverLayoutBuilder(
          builder: (context, constraints) {
            return SliverGrid.builder(
              gridDelegate: productGridDelegate(context, constraints.crossAxisExtent),
              itemCount: filtered.length,
              itemBuilder: (context, index) => ProductCard(product: filtered[index]),
            );
          },
        ),
      ];
    }

    return RoleShell(
      title: 'Store',
      child: ContentWidth(
        maxWidth: 1100,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                sliver: SliverMainAxisGroup(
                  slivers: [SliverToBoxAdapter(child: _header()), ...body],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One product tile in the store grid and on the gifting page: photo, category,
/// name, shop NAME (never contact details), price and stock.
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity <= 0;
    final shopName = product.shop?.name ?? '';
    final summary = [
      product.name,
      titleCase(product.category),
      if (shopName.isNotEmpty) 'sold by $shopName',
      formatPrice(product.price),
      stockLabel(product),
      if (product.requiresPrescription) 'prescription needed',
    ].join(', ');
    void open() => context.push('/store/${product.id}');

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Semantics(
        button: true,
        label: summary,
        onTap: open,
        excludeSemantics: true,
        child: InkWell(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: outOfStock ? 0.5 : 1,
                      child: ProductPhotoView(
                        src: product.photoUrls.isEmpty ? null : product.photoUrls.first,
                        category: product.category,
                      ),
                    ),
                    if (outOfStock)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            'Out of stock',
                            style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleCase(product.category),
                      style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      product.name,
                      style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shopName.isNotEmpty)
                      Text(
                        shopName,
                        style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Text(
                      formatPrice(product.price),
                      style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700, color: kPetPriceColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      stockLabel(product),
                      style: AppTheme.body(fontSize: 12, color: stockColor(product)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.requiresPrescription)
                      Text(
                        'Prescription needed',
                        style: AppTheme.body(fontSize: 11.5, fontWeight: FontWeight.w600, color: kAmberTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder grid shown while the products load.
class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading products',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: productGridDelegate(context, constraints.maxWidth),
            itemCount: 6,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: SkeletonBox(height: double.infinity, radius: 0)),
                  Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonBox(width: 50, height: 11),
                        SizedBox(height: 6),
                        SkeletonBox(width: 110, height: 14),
                        SizedBox(height: 6),
                        SkeletonBox(width: 70, height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
