import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// (value, label) options, mirroring the categoryTabs array in Store.jsx.
const _categoryOptions = [
  FilterOption<String>('all', 'All'),
  FilterOption<String>('medicine', 'Medicine'),
  FilterOption<String>('store', 'Store'),
];

/// Mirrors src/pages/Store.jsx: a category-filtered grid of available
/// products loaded straight from Supabase (public columns plus the shop's
/// name only, via ProductsRepository). Pull to refresh.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _category = 'all';

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
    final header = <Widget>[
      Text('Store', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Medicine and everyday supplies from shops near you.',
        style: AppTheme.body(color: AppColors.inkSoft),
      ),
      const SizedBox(height: 16),
      FilterChipBar<String>(
        options: _categoryOptions,
        selected: _category,
        onSelected: (value) => setState(() => _category = value),
      ),
      const SizedBox(height: 20),
    ];

    final Widget content;
    if (_loading) {
      content = ListView(
        padding: kScreenPadding,
        children: [
          ...header,
          SkeletonPulse(
            child: _ProductGrid(children: [for (var i = 0; i < 6; i++) const _ProductSkeleton()]),
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
              title: "We couldn't load the store",
              description: _error,
              action: ElevatedButton(onPressed: _load, child: const Text('Try again')),
            ),
          ],
        ),
      );
    } else {
      final filtered = _category == 'all'
          ? _products
          : _products.where((p) => p.category == _category).toList();

      content = RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ...header,
            if (filtered.isEmpty)
              const EmptyState(
                title: 'No products found',
                description: 'Try a different category, or check back later.',
              )
            else
              _ProductGrid(children: [for (final product in filtered) _ProductCard(product: product)]),
          ],
        ),
      );
    }

    return RoleShell(title: 'Store', child: content);
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Widget> children;
  const _ProductGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 196,
      ),
      children: children,
    );
  }
}

class _ProductSkeleton extends StatelessWidget {
  const _ProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          SkeletonBox(width: 110, height: 15),
          SizedBox(height: 8),
          SkeletonBox(width: 80, height: 13),
          Spacer(),
          SkeletonBox(width: 60, height: 18),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity <= 0;
    final shopName = product.shop?.name ?? '';
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/store/${product.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titleCase(product.category),
                style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(
                product.name,
                style: AppTheme.body(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (shopName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  shopName,
                  style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Text(
                formatPrice(product.price),
                style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
              const SizedBox(height: 2),
              Text(
                outOfStock ? 'Out of stock' : '${product.stockQuantity} in stock',
                style: AppTheme.body(fontSize: 12, color: outOfStock ? AppColors.error : AppColors.inkSoft),
              ),
              if (product.requiresPrescription)
                Text(
                  'Prescription needed',
                  style: AppTheme.body(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
