import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// (value, label) pairs, mirroring the categoryTabs array in Store.jsx.
const _categoryTabs = [
  ('all', 'All'),
  ('medicine', 'Medicine'),
  ('store', 'Store'),
];

/// Mirrors src/pages/Store.jsx: a category-filtered grid of available
/// products loaded straight from Supabase (the real marketplace catalog,
/// not the static seed data used by the customer pet-browsing screens).
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
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
        _error = "Couldn't load the store. Try again.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = const LoadingView();
    } else if (_error != null) {
      content = ErrorView(message: _error!);
    } else {
      final filtered = _category == 'all'
          ? _products
          : _products.where((p) => p.category == _category).toList();

      content = ListView(
        padding: kScreenPadding,
        children: [
          Text(
            'Store',
            style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Medicine and everyday supplies from shops near you.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final tab in _categoryTabs) ...[
                _CategoryTab(
                  label: tab.$2,
                  selected: _category == tab.$1,
                  onTap: () => setState(() => _category = tab.$1),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 24),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: EmptyState(
                title: 'No products found',
                description: 'Try a different category, or check back later.',
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) =>
                  _ProductCard(product: filtered[index]),
            ),
        ],
      );
    }

    return RoleShell(title: 'Store', child: content);
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          border: selected ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: AppTheme.body(
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/store/${product.id}'),
      child: Container(
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
            Text(
              product.name,
              style: AppTheme.body(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              product.shop?.name ?? '',
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              formatPrice(product.price),
              style: AppTheme.display(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${product.stockQuantity} in stock',
              style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
