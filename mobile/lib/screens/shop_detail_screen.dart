import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';

/// Mirrors src/pages/ShopDetail.jsx: a banner (photo when the shop has one),
/// rating, license number and description, and a grid of the shop's available
/// pets. Only public details are shown: no address, phone or city -- pickup
/// details are confirmed by the shop after a reservation. Pull to refresh.
class ShopDetailScreen extends ConsumerWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    final catalog = catalogAsync.value;

    if (catalog == null) {
      return RoleShell(
        title: 'Shop',
        actions: const [CartAppBarAction()],
        child: catalogAsync.hasFailed
            ? ScrollableMessage(
                child: CommerceRetryView(
                  title: "We couldn't load this shop",
                  error: catalogAsync.error,
                  onRetry: () => ref.invalidate(catalogProvider),
                ),
              )
            : const _ShopDetailSkeleton(),
      );
    }

    final shop = catalog.shopById(shopId);
    if (shop == null) {
      return RoleShell(
        title: 'Shop',
        actions: const [CartAppBarAction()],
        child: RefreshIndicator(
          onRefresh: () => refreshCatalog(ref),
          child: ScrollableMessage(
            child: EmptyState(
              title: "We couldn't find that shop",
              description: 'It may have closed, or the link is out of date.',
              action: ElevatedButton(
                onPressed: () => context.go('/sellers'),
                child: const Text('Browse shops'),
              ),
            ),
          ),
        ),
      );
    }

    final stats = catalog.statsFor(shop.id);
    final shopPets = catalog.petsByShop(shop.id);
    final description = shop.description?.trim() ?? '';

    return RoleShell(
      title: shop.name,
      actions: const [CartAppBarAction()],
      child: RefreshIndicator(
        onRefresh: () => refreshCatalog(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ContentWidth(
              maxWidth: 1100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ShopBanner(shop: shop),
                  const SizedBox(height: 20),
                  if (stats.reviewCount > 0)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: RatingStarsView(rating: stats.rating, reviewCount: stats.reviewCount),
                    )
                  else
                    Text('No reviews yet', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                  if (shop.licenseNumber.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('License #${shop.licenseNumber}', style: AppTheme.body(color: AppColors.inkSoft)),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    shopPets.isEmpty
                        ? 'No pets listed right now'
                        : '${shopPets.length} ${shopPets.length == 1 ? 'pet' : 'pets'} listed',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(description, style: AppTheme.body(color: AppColors.inkSoft).copyWith(height: 1.5)),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Reserve a pet and the shop will confirm pickup details with you. You pay in person at pickup.',
                    style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(shopSupportRoute(shopId: shop.id)),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Message the shop'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    header: true,
                    child: Text(
                      'Pets at ${shop.name}',
                      style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (shopPets.isNotEmpty)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: shopPets.length,
                          gridDelegate: petGridDelegate(context, constraints.maxWidth),
                          itemBuilder: (context, index) => PetCard(pet: shopPets[index]),
                        );
                      },
                    )
                  else
                    EmptyState(
                      title: 'No pets listed right now',
                      description: 'Check back soon, or browse other shops.',
                      action: ElevatedButton(
                        onPressed: () => context.go('/sellers'),
                        child: const Text('Browse shops'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner photo with the shop name on top; falls back to a plain colour block
/// if there's no photo or it fails to load.
class _ShopBanner extends StatelessWidget {
  final Shop shop;
  const _ShopBanner({required this.shop});

  @override
  Widget build(BuildContext context) {
    final rawBanner = shop.bannerUrl;
    final bannerUrl = (rawBanner != null && rawBanner.isNotEmpty) ? rawBanner : null;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final height = MediaQuery.sizeOf(context).width >= 640 ? 208.0 : 160.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: height,
        color: AppColors.primary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bannerUrl != null) ...[
              ExcludeSemantics(
                child: CachedNetworkImage(
                  imageUrl: bannerUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: (900 * pixelRatio).round(),
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xB30F172A), Color(0x000F172A)],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(20),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Semantics(
                  header: true,
                  child: Text(
                    shop.name,
                    style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.paper),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown while the catalog loads.
class _ShopDetailSkeleton extends StatelessWidget {
  const _ShopDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading shop',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: const [
          ContentWidth(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SkeletonBox(height: 160, radius: 16),
                SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 140, height: 14)),
                SizedBox(height: 12),
                SkeletonBox(height: 14),
                SizedBox(height: 28),
                Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 180, height: 20)),
                SizedBox(height: 14),
                PetGridSkeleton(count: 4, shrinkWrap: true, padding: EdgeInsets.zero),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
