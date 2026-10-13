import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/Shops.jsx: a heading and the list of approved shops from
/// the shared catalog. Cards show name, rating, blurb, pet count and license
/// number only -- never an address or phone number.
class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(catalogProvider);
    try {
      await ref.read(catalogProvider.future).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The screen renders the error state itself.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final loading = catalogAsync.isLoading && !catalogAsync.hasValue;
    final failed = catalogAsync.hasError && !catalogAsync.isLoading;
    final catalog = failed ? null : catalogAsync.value;

    final children = <Widget>[
      Text('Shops', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(
        'Browse licensed local pet shops and see what they currently have available.',
        style: AppTheme.body(color: AppColors.inkSoft),
      ),
      const SizedBox(height: 20),
    ];

    if (loading) {
      children.add(
        const SkeletonPulse(
          child: Column(
            children: [
              ShopCardSkeleton(),
              SizedBox(height: 14),
              ShopCardSkeleton(),
              SizedBox(height: 14),
              ShopCardSkeleton(),
            ],
          ),
        ),
      );
    } else if (catalog == null) {
      children.add(
        EmptyState(
          title: "We couldn't load shops",
          description: errorText(catalogAsync.error ?? 'Something went wrong.'),
          action: ElevatedButton(
            onPressed: () => ref.invalidate(catalogProvider),
            child: const Text('Try again'),
          ),
        ),
      );
    } else if (catalog.shops.isEmpty) {
      children.add(
        EmptyState(
          title: 'No shops yet',
          description: "Licensed shops will appear here once they're approved. Check back soon.",
          action: ElevatedButton(
            onPressed: () => context.push('/pets'),
            child: const Text('Browse pets'),
          ),
        ),
      );
    } else {
      for (final shop in catalog.shops) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: ShopCard(
              shop: shop,
              stats: catalog.statsFor(shop.id),
              petCount: catalog.petsByShop(shop.id).length,
            ),
          ),
        );
      }
    }

    return RoleShell(
      title: 'Shops',
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: children,
        ),
      ),
    );
  }
}
