import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/ShopDetail.jsx: a banner (photo when the shop has one),
/// rating, license number and description, and a grid of the shop's available
/// pets. Only public details are shown: no address, phone or city -- pickup
/// details are confirmed by the shop after a reservation.
class ShopDetailScreen extends ConsumerWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

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

    if (loading) {
      return const RoleShell(title: 'Shop', child: _ShopDetailSkeleton());
    }

    if (catalog == null) {
      return RoleShell(
        title: 'Shop',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't load this shop",
            description: errorText(catalogAsync.error ?? 'Something went wrong.'),
            action: ElevatedButton(
              onPressed: () => ref.invalidate(catalogProvider),
              child: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    final shop = catalog.shopById(shopId);
    if (shop == null) {
      return RoleShell(
        title: 'Shop',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't find that shop",
            description: 'It may have closed, or the link is out of date.',
            action: ElevatedButton(
              onPressed: () => context.go('/sellers'),
              child: const Text('Browse shops'),
            ),
          ),
        ),
      );
    }

    final stats = catalog.statsFor(shop.id);
    final shopPets = catalog.petsByShop(shop.id);
    final description = shop.description;

    return RoleShell(
      title: shop.name,
      child: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            _ShopBanner(shop: shop),
            const SizedBox(height: 20),
            if (stats.reviewCount > 0)
              RatingStarsView(rating: stats.rating, reviewCount: stats.reviewCount)
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
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(description.trim(), style: AppTheme.body(color: AppColors.inkSoft)),
            ],
            const SizedBox(height: 14),
            Text(
              'Reserve a pet and the shop will confirm pickup details with you.',
              style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 28),
            Text('Pets at ${shop.name}', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (shopPets.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: shopPets.length,
                gridDelegate: kPetGridDelegate,
                itemBuilder: (context, index) => PetCard(pet: shopPets[index]),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 160,
        color: AppColors.primary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bannerUrl != null) ...[
              CachedNetworkImage(
                imageUrl: bannerUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const SizedBox.shrink(),
                errorWidget: (context, url, error) => const SizedBox.shrink(),
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
                child: Text(
                  shop.name,
                  style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.paper),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopDetailSkeleton extends StatelessWidget {
  const _ShopDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 160, radius: 16),
            SizedBox(height: 24),
            SkeletonBox(width: 140, height: 14),
            SizedBox(height: 12),
            SkeletonBox(height: 14),
            SizedBox(height: 28),
            SkeletonBox(width: 180, height: 20),
          ],
        ),
      ),
    );
  }
}
