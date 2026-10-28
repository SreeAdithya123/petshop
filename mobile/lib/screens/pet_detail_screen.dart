import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../state/wishlist_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_actions/demo_request_sheet.dart';
import '../widgets/pet_actions/emi_sheet.dart';
import '../widgets/pet_actions/gift_pet_sheet.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/pages/PetDetail.jsx: photo gallery, spec rows, the primary
/// add-to-cart action with a wishlist heart, the secondary "Request demo /
/// Send as gift / EMI options" actions (bottom sheets), the seller card (shop
/// name, rating and licence only -- never contact details) and a "More from
/// this shop" strip. Everything comes from the shared [catalogProvider];
/// pull to refresh reloads it.
class PetDetailScreen extends ConsumerStatefulWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  ConsumerState<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends ConsumerState<PetDetailScreen> {
  /// Shop id of the pet once it has been sent as a gift (the pet is reserved
  /// and its page is gone, so a confirmation replaces it).
  String? _giftedFromShopId;
  bool _wishlistBusy = false;

  @override
  void didUpdateWidget(covariant PetDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petId != widget.petId) _giftedFromShopId = null;
  }

  void _handleCartTap(Pet pet, bool inCart) {
    if (inCart) {
      context.push('/cart');
      return;
    }
    ref.read(cartControllerProvider).addToCart('pet', pet.id);
    showAddedToCart(context, pet);
  }

  Future<void> _handleWishlistTap(Pet pet) async {
    if (_wishlistBusy) return;
    final auth = ref.read(authControllerProvider);
    if (auth.status == AuthStatus.loading) {
      showSnack(context, 'Checking your account. Try again in a moment.');
      return;
    }

    final profile = auth.profile;
    if (auth.status == AuthStatus.signedIn && profile != null && profile.role != 'customer') {
      showSnack(context, 'Only customer accounts have a wishlist.');
      return;
    }
    final wishlist = ref.read(wishlistControllerProvider);
    if (!wishlist.signedIn) {
      context.push('/login?from=${Uri.encodeComponent('/pets/${pet.id}')}');
      return;
    }

    setState(() => _wishlistBusy = true);
    final message = await wishlist.toggle(pet.id);
    if (!mounted) return;
    setState(() => _wishlistBusy = false);
    if (message != null) {
      showSnack(context, commerceErrorText(message), error: true);
    }
  }

  Future<void> _openGift(Pet pet, String? shopName) async {
    final placed = await showGiftPetSheet(context, pet: pet, shopName: shopName);
    if (placed && mounted) setState(() => _giftedFromShopId = pet.shopId);
  }

  @override
  Widget build(BuildContext context) {
    final giftedShopId = _giftedFromShopId;
    if (giftedShopId != null) return _buildGiftReserved(giftedShopId);

    final catalogAsync = ref.watch(catalogProvider);
    // `value` keeps the previous catalog while a refresh is in flight or failed.
    final catalog = catalogAsync.value;

    if (catalog == null) {
      return RoleShell(
        title: 'Pet details',
        child: catalogAsync.hasFailed
            ? ScrollableMessage(
                child: CommerceRetryView(
                  title: "We couldn't load this pet",
                  error: catalogAsync.error,
                  onRetry: () => ref.invalidate(catalogProvider),
                ),
              )
            : const _PetDetailSkeleton(),
      );
    }

    final pet = catalog.petById(widget.petId);
    if (pet == null) {
      return RoleShell(
        title: 'Pet details',
        child: RefreshIndicator(
          onRefresh: () => refreshCatalog(ref),
          child: ScrollableMessage(
            child: EmptyState(
              title: 'This pet is no longer available',
              description: 'It may have already been reserved or sold, or the link is out of date.',
              action: ElevatedButton(
                onPressed: () => context.go('/pets'),
                child: const Text('Shop pets'),
              ),
            ),
          ),
        ),
      );
    }

    final shop = catalog.shopById(pet.shopId);
    final stats = shop == null ? ShopStats.none : catalog.statsFor(shop.id);
    final unavailable = pet.status != 'available';
    final relatedPets = catalog
        .petsByShop(pet.shopId)
        .where((candidate) => candidate.id != pet.id && candidate.status == 'available')
        .take(4)
        .toList();

    final inCart = ref.watch(cartControllerProvider).isInCart('pet', pet.id);
    final wishlisted = ref.watch(wishlistControllerProvider).isWishlisted(pet.id);

    final gender = pet.gender?.trim() ?? '';
    final certification = pet.certification?.trim() ?? '';
    final facts = <MapEntry<String, String>>[
      MapEntry('Species', pet.species),
      MapEntry('Breed', pet.breed),
      if (gender.isNotEmpty) MapEntry('Gender', titleCase(gender)),
      MapEntry('Age', formatAge(pet.ageMonths)),
      if (certification.isNotEmpty) MapEntry('Certification', certification),
    ];
    final description = pet.description?.trim() ?? '';

    return RoleShell(
      title: pet.displayName,
      child: RefreshIndicator(
        onRefresh: () => refreshCatalog(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: kScreenPadding,
          children: [
            ContentWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PhotoGallery(
                    key: ValueKey(pet.id),
                    photos: pet.photoUrls,
                    label: 'Photos of ${pet.displayName}',
                    statusLabel: unavailable ? titleCase(pet.status) : null,
                    photoBuilder: (url, cacheWidth, label) =>
                        PetPhotoView(src: url, species: pet.species, cacheWidth: cacheWidth, semanticLabel: label),
                  ),

                  // Title + price.
                  const SizedBox(height: 20),
                  Text('${pet.species} · ${pet.breed}', style: AppTheme.body(color: AppColors.inkSoft)),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(pet.displayName, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatPrice(pet.price),
                    style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: kPetPriceColor),
                  ),

                  // Spec rows.
                  const SizedBox(height: 16),
                  Container(
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                    child: Column(
                      children: [for (final fact in facts) _FactRow(label: fact.key, value: fact.value)],
                    ),
                  ),

                  // Primary action: add to cart + wishlist heart.
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: unavailable ? null : () => _handleCartTap(pet, inCart),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: inCart ? AppColors.primary : kPetCtaColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.border,
                            disabledForegroundColor: AppColors.inkSoft,
                          ),
                          icon: Icon(
                            unavailable
                                ? Icons.block
                                : inCart
                                    ? Icons.check_circle
                                    : Icons.shopping_cart_outlined,
                            size: 18,
                          ),
                          label: Text(
                            unavailable ? titleCase(pet.status) : (inCart ? 'In cart · View cart' : 'Add to cart'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Tooltip(
                        message: wishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                        child: Semantics(
                          button: true,
                          toggled: wishlisted,
                          label: wishlisted ? 'Remove ${pet.displayName} from wishlist' : 'Add ${pet.displayName} to wishlist',
                          excludeSemantics: true,
                          onTap: _wishlistBusy ? null : () => _handleWishlistTap(pet),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _wishlistBusy ? null : () => _handleWishlistTap(pet),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(52, 52),
                                side: BorderSide(color: wishlisted ? AppColors.primary : AppColors.border),
                              ),
                              child: Icon(
                                wishlisted ? Icons.favorite : Icons.favorite_border,
                                color: wishlisted ? AppColors.primary : AppColors.inkSoft,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    unavailable
                        ? 'This pet is no longer for sale.'
                        : 'Reserve it now, then pick up and pay in person at the shop. Nothing is charged online.',
                    style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                  ),

                  // Secondary actions, grouped under the primary one.
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not ready to add it to your cart?',
                          style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SecondaryAction(
                              icon: Icons.videocam_outlined,
                              label: 'Request demo',
                              onPressed: unavailable
                                  ? null
                                  : () => showDemoRequestSheet(context, pet: pet, shopName: shop?.name),
                            ),
                            _SecondaryAction(
                              icon: Icons.card_giftcard,
                              label: 'Send as gift',
                              onPressed: unavailable ? null : () => _openGift(pet, shop?.name),
                            ),
                            _SecondaryAction(
                              icon: Icons.credit_card,
                              label: 'EMI options',
                              onPressed: () => showEmiSheet(context, pet: pet, shopName: shop?.name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // About.
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Semantics(
                      header: true,
                      child: Text(
                        'About ${pet.displayName}',
                        style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(description, style: AppTheme.body(color: AppColors.inkSoft).copyWith(height: 1.5)),
                  ],

                  // Seller card: shop name, rating and licence only.
                  if (shop != null) ...[
                    const SizedBox(height: 28),
                    _SellerCard(shop: shop, stats: stats),
                  ],

                  // More from this shop.
                  if (relatedPets.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(
                        'More from ${shop?.name ?? 'this shop'}',
                        style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: petStripHeight(context),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: relatedPets.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 14),
                        // The strip is already scoped to this shop, so the card hides its shop-name line.
                        itemBuilder: (context, index) => SizedBox(
                          width: 168,
                          child: PetCard(pet: relatedPets[index]),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown after a gift is placed: the pet is reserved, so its page is gone.
  Widget _buildGiftReserved(String shopId) {
    return RoleShell(
      title: 'Gift reserved',
      child: ScrollableMessage(
        child: EmptyState(
          title: 'Gift reserved',
          description:
              'The shop will arrange pickup with you and you pay in person. Follow it under My account → Orders.',
          action: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => context.push('/account/orders'),
                child: const Text('View my orders'),
              ),
              OutlinedButton(
                onPressed: () => context.push(shopSupportRoute(shopId: shopId)),
                child: const Text('Message the shop'),
              ),
              OutlinedButton(
                onPressed: () => context.go('/pets'),
                child: const Text('Keep browsing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder shown while the catalog loads.
class _PetDetailSkeleton extends StatelessWidget {
  const _PetDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading pet',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: const [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: SkeletonBox(height: double.infinity, radius: 16),
                ),
                SizedBox(height: 20),
                SkeletonBox(width: 140, height: 14),
                SizedBox(height: 10),
                SkeletonBox(width: 220, height: 28),
                SizedBox(height: 12),
                SkeletonBox(width: 110, height: 24),
                SizedBox(height: 24),
                SkeletonBox(height: 16),
                SizedBox(height: 14),
                SkeletonBox(height: 16),
                SizedBox(height: 14),
                SkeletonBox(height: 16),
                SizedBox(height: 24),
                SkeletonBox(height: 52, radius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;
  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.body(color: AppColors.inkSoft)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTheme.body(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the "Request demo / Send as gift / EMI options" buttons.
class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _SecondaryAction({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "Sold by" card. Deliberately shows only the shop name, rating and licence:
/// address, phone and other contact details are never shown to customers.
class _SellerCard extends StatelessWidget {
  final Shop shop;
  final ShopStats stats;
  const _SellerCard({required this.shop, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push('/sellers/${shop.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOLD BY',
                    style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSoft)
                        .copyWith(letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(shop.name, style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.inkSoft),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RatingStarsView(rating: stats.rating, reviewCount: stats.reviewCount),
                  if (shop.licenseNumber.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified, size: 16, color: kTrustTextColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Licensed dealer · ${shop.licenseNumber}',
                            style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.shield_outlined, size: 16, color: AppColors.inkSoft),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Pickup details are shared by the shop after you reserve. Its contact details stay private.',
                    style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push(shopSupportRoute(shopId: shop.id)),
                style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message the shop'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
