import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/Shops.jsx: a heading and the list of approved shops from
/// the shared catalog. Cards show name, rating, blurb, pet count and license
/// number only -- never an address or phone number. Pull to refresh.
class ShopsScreen extends ConsumerWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final catalog = catalogAsync.value;

    final Widget content;
    if (catalog == null) {
      content = catalogAsync.hasFailed
          ? ScrollableMessage(
              child: CommerceRetryView(
                title: "We couldn't load shops",
                error: catalogAsync.error,
                onRetry: () => ref.invalidate(catalogProvider),
              ),
            )
          : const _ShopsSkeleton();
    } else {
      content = RefreshIndicator(
        onRefresh: () => refreshCatalog(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ContentWidth(
              maxWidth: 1000,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Header(),
                  if (catalog.shops.isEmpty)
                    EmptyState(
                      title: 'No shops yet',
                      description: "Licensed shops will appear here once they're approved. Check back soon.",
                      action: ElevatedButton(
                        onPressed: () => context.push('/pets'),
                        child: const Text('Browse pets'),
                      ),
                    )
                  else
                    _ShopGrid(
                      cards: [
                        for (final shop in catalog.shops)
                          ShopCard(
                            shop: shop,
                            stats: catalog.statsFor(shop.id),
                            petCount: catalog.petsByShop(shop.id).length,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RoleShell(title: 'Shops', child: content);
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Shops', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(
            'Browse licensed local pet shops and see what they currently have available.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Shop cards in one column on phones and two on wide screens. Cards in a row
/// share a height; the list never scrolls on its own.
class _ShopGrid extends StatelessWidget {
  final List<Widget> cards;
  const _ShopGrid({required this.cards});

  static const double _gap = 14;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: _gap), child: card),
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < cards.length; i += columns)
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: _gap),
                      Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Header plus three card placeholders while the catalog loads.
class _ShopsSkeleton extends StatelessWidget {
  const _ShopsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading shops',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: const [
          ContentWidth(
            maxWidth: 1000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(),
                ShopCardSkeleton(),
                SizedBox(height: 14),
                ShopCardSkeleton(),
                SizedBox(height: 14),
                ShopCardSkeleton(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
