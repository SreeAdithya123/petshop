import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'ui_kit.dart';

/// Flat icon placeholder for a species, used both as the card image for
/// species with no reliable photo source (Rabbit, Bird, Small Pet) and as
/// the fallback when any pet photo URL fails to load. Mirrors the intent of
/// src/components/icons/SpeciesIcon.jsx (a hand-illustrated icon per
/// species) with a single Material glyph instead, since this is a mobile
/// port rather than a pixel-identical redraw.
class SpeciesIconView extends StatelessWidget {
  final String species;
  const SpeciesIconView({super.key, required this.species});

  IconData get _icon {
    switch (species) {
      case 'Dog':
        return Icons.pets;
      case 'Cat':
        return Icons.pets;
      case 'Bird':
        return Icons.flutter_dash;
      case 'Rabbit':
        return Icons.cruelty_free;
      case 'Small Pet':
        return Icons.grain;
      default:
        return Icons.pets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.07),
      alignment: Alignment.center,
      child: Icon(_icon, color: AppColors.primary, size: 32),
    );
  }
}

/// Renders one photo when [src] is given, and the species icon otherwise --
/// either because the species has no reliable photo source ([src] is null)
/// or the URL failed to load at runtime. Never renders a broken-image
/// glyph. Mirrors src/components/ui/PetPhoto.jsx.
class PetPhotoView extends StatelessWidget {
  final String? src;
  final String species;
  final BoxFit fit;

  const PetPhotoView({super.key, required this.src, required this.species, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (src == null || src!.isEmpty) return SpeciesIconView(species: species);
    return CachedNetworkImage(
      imageUrl: src!,
      fit: fit,
      errorWidget: (context, url, error) => SpeciesIconView(species: species),
      placeholder: (context, url) => Container(color: AppColors.primary.withValues(alpha: 0.05)),
    );
  }
}

/// Star rating row. Always shows something -- "New shop" text when there
/// are no reviews yet. Mirrors src/components/ui/RatingStars.jsx.
class RatingStarsView extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double size;

  const RatingStarsView({super.key, required this.rating, required this.reviewCount, this.size = 15});

  @override
  Widget build(BuildContext context) {
    if (reviewCount == 0) {
      return Text('New shop', style: AppTheme.body(color: AppColors.inkSoft));
    }

    final full = rating.floor();
    final hasHalf = (rating - full) >= 0.25 && (rating - full) < 0.75;
    final roundedFull = hasHalf ? full : rating.round();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          IconData icon;
          Color color;
          if (index < roundedFull) {
            icon = Icons.star;
            color = AppColors.trust;
          } else if (index == roundedFull && hasHalf) {
            icon = Icons.star_half;
            color = AppColors.trust;
          } else {
            icon = Icons.star_border;
            color = AppColors.trust.withValues(alpha: 0.3);
          }
          return Icon(icon, size: size, color: color);
        }),
        const SizedBox(width: 6),
        Text('${rating.toStringAsFixed(1)} ($reviewCount)', style: AppTheme.body(color: AppColors.inkSoft, fontSize: 13)),
      ],
    );
  }
}

/// First photo of [pet], or null when it has none (the card then shows the
/// species icon instead).
String? petCoverPhoto(Pet pet) => pet.photoUrls.isEmpty ? null : pet.photoUrls.first;

/// Grid layout shared by every screen that lists [PetCard]s (two columns, a
/// fixed row height so the card's photo flexes rather than overflowing).
const kPetGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  mainAxisExtent: 304,
);

/// Height of a [PetCard] when placed in a horizontal strip.
const kPetStripHeight = 304.0;

/// The one pet card used on every screen that lists pets (home strips, the
/// /pets grid, shop storefronts). Mirrors src/components/ui/PetCard.jsx: photo,
/// name, breed, age and gender, price, the shop's NAME (never contact
/// details) and an Add to Cart button. Needs a bounded height (grid cell or
/// sized box): the photo takes whatever the text block leaves.
class PetCard extends ConsumerWidget {
  final Pet pet;

  /// Shop name to show under the price; null hides the line (e.g. on that
  /// shop's own page).
  final String? shopName;

  const PetCard({super.key, required this.pet, this.shopName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref.watch(cartControllerProvider).isInCart('pet', pet.id);
    final unavailable = pet.status == 'sold' || pet.status == 'reserved';
    final unavailableLabel = pet.status == 'reserved' ? 'Reserved' : 'Sold';
    final gender = pet.gender;
    final meta = [
      formatAge(pet.ageMonths),
      if (gender != null && gender.isNotEmpty) gender,
    ].where((part) => part.isNotEmpty).join(' · ');
    // An unnamed listing's display name is its breed: show the species below
    // it instead of repeating the breed.
    final subtitle = pet.displayName == pet.breed ? pet.species : pet.breed;
    final name = shopName;

    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/pets/${pet.id}'),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: unavailable ? 0.5 : 1,
                    child: PetPhotoView(src: petCoverPhoto(pet), species: pet.species),
                  ),
                  if (unavailable)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          unavailableLabel,
                          style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => context.push('/pets/${pet.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pet.displayName,
                        style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        meta.isEmpty ? ' ' : meta,
                        style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatPrice(pet.price),
                        style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
                if (name != null && name.isNotEmpty)
                  InkWell(
                    onTap: () => context.push('/sellers/${pet.shopId}'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        name,
                        style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _CartButton(
                  unavailable: unavailable,
                  unavailableLabel: unavailableLabel,
                  inCart: inCart,
                  onAdd: () {
                    ref.read(cartControllerProvider).addToCart('pet', pet.id);
                    showSnack(context, '${pet.displayName} added to your cart.');
                  },
                  onViewCart: () => context.push('/cart'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final bool unavailable;
  final String unavailableLabel;
  final bool inCart;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;

  const _CartButton({
    required this.unavailable,
    required this.unavailableLabel,
    required this.inCart,
    required this.onAdd,
    required this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600);
    const padding = EdgeInsets.symmetric(horizontal: 8);
    const size = Size.fromHeight(36);

    if (unavailable) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: size, padding: padding, textStyle: textStyle),
        child: Text(unavailableLabel),
      );
    }
    if (inCart) {
      return OutlinedButton.icon(
        onPressed: onViewCart,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('In Cart'),
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          textStyle: textStyle,
          foregroundColor: AppColors.trust,
          side: BorderSide(color: AppColors.trust.withValues(alpha: 0.4)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.shopping_cart_outlined, size: 16),
      label: const Text('Add to Cart'),
      style: ElevatedButton.styleFrom(
        minimumSize: size,
        padding: padding,
        textStyle: textStyle,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Shop summary card (mirrors src/components/ui/ShopCard.jsx): name, rating,
/// blurb, pet count and license number. Never shows an address or phone.
class ShopCard extends StatelessWidget {
  final Shop shop;
  final ShopStats stats;
  final int petCount;

  const ShopCard({super.key, required this.shop, required this.stats, required this.petCount});

  @override
  Widget build(BuildContext context) {
    final description = shop.description;
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => context.push('/sellers/${shop.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(shop.name, style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (stats.reviewCount > 0)
                RatingStarsView(rating: stats.rating, reviewCount: stats.reviewCount)
              else
                Text('No reviews yet', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
              if (description != null && description.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description.trim(),
                  style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.pets, size: 15, color: AppColors.inkSoft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      petCount > 0
                          ? '$petCount ${petCount == 1 ? 'pet' : 'pets'} listed'
                          : 'No pets listed right now',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ),
                ],
              ),
              if (shop.licenseNumber.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  'License #${shop.licenseNumber}',
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeletons (mirror the PetCardSkeleton / ShopCardSkeleton placeholders
// the web app shows while the catalog loads).
// ---------------------------------------------------------------------------

/// Fades its [child] in and out to signal "loading". Wrap a whole skeleton
/// (grid, list) in one of these rather than animating every bone.
class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

/// A grey rounded bar/box used inside skeletons.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x140F172A),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Placeholder with the footprint of a [PetCard]. Needs a bounded height.
class PetCardSkeleton extends StatelessWidget {
  const PetCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SkeletonBox(radius: 0)),
          Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonBox(width: 90, height: 14),
                SizedBox(height: 6),
                SkeletonBox(width: 60, height: 12),
                SizedBox(height: 6),
                SkeletonBox(width: 70, height: 16),
                SizedBox(height: 10),
                SkeletonBox(height: 36, radius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing grid of [PetCardSkeleton]s, used as the loading state of any
/// screen that shows a grid of [PetCard]s.
class PetGridSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  const PetGridSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 32),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: GridView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: kPetGridDelegate,
        itemCount: count,
        itemBuilder: (context, index) => const PetCardSkeleton(),
      ),
    );
  }
}

/// Placeholder with the footprint of a [ShopCard].
class ShopCardSkeleton extends StatelessWidget {
  const ShopCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 150, height: 18),
          SizedBox(height: 10),
          SkeletonBox(width: 100, height: 14),
          SizedBox(height: 14),
          SkeletonBox(height: 14),
          SizedBox(height: 8),
          SkeletonBox(width: 200, height: 14),
        ],
      ),
    );
  }
}
