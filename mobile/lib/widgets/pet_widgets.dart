import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_error.dart' show friendlyError;
import '../models/models.dart';
import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import 'content_width.dart';
import 'shared_widgets.dart';
import 'skeletons.dart';

// ---------------------------------------------------------------------------
// Colours for text and fills that must stay readable on white. The brand pink
// and green are only ~3.5:1 and ~2.5:1 against white, which is too faint for
// small price / status text.
// ---------------------------------------------------------------------------

/// Price text: pink-700, about 6:1 on white.
const kPetPriceColor = Color(0xFFBE185D);

/// Fill for the pink call-to-action buttons (white text passes 4.5:1).
const kPetCtaColor = Color(0xFFDB2777);

/// Green for status text such as "In cart" (emerald-700, about 5.5:1).
const kTrustTextColor = Color(0xFF047857);

/// Amber for warnings such as "Prescription needed" (amber-700, about 5:1).
const kAmberTextColor = Color(0xFFB45309);

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Customer-friendly text for any thrown error: offline, timeout, expired
/// session and "function not deployed yet" get plain wording, messages raised
/// deliberately by our own database functions pass through, and anything
/// unrecognised becomes a generic sentence (never a raw exception dump).
/// See core/app_error.dart.
String commerceErrorText(Object error) => friendlyError(error);

/// Reloads the shared catalog and waits for it (for pull-to-refresh). Never
/// throws: a failed reload leaves the screen to show its own error state, or
/// the last catalog it loaded.
Future<void> refreshCatalog(WidgetRef ref) async {
  ref.invalidate(catalogProvider);
  try {
    await ref.read(catalogProvider.future).timeout(const Duration(seconds: 15));
  } catch (_) {
    // The screen renders the error state itself.
  }
}

/// Loading / failure helpers for screens driven by [catalogProvider]. While a
/// refresh runs (or fails) [AsyncValue.value] keeps the last loaded catalog, so
/// screens show that rather than a spinner or an error.
extension CatalogAsyncView on AsyncValue<Catalog> {
  /// No catalog yet and one is on its way: show a skeleton.
  bool get isInitialLoad => value == null && (isLoading || !hasError);

  /// No catalog at all and the last attempt failed: show Retry.
  bool get hasFailed => value == null && hasError && !isLoading;
}

/// A scrollable page holding one centred message (empty / error state) so
/// pull-to-refresh still works on it.
class ScrollableMessage extends StatelessWidget {
  final Widget child;
  const ScrollableMessage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: kScreenPadding,
      children: [ContentWidth(maxWidth: 560, child: child)],
    );
  }
}

/// App-bar cart button with an item-count badge, for the customer-facing
/// screens. Hidden for shop owners and admins (they have no cart).
class CartAppBarAction extends ConsumerWidget {
  const CartAppBarAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).profile?.role;
    if (role == 'shop_owner' || role == 'admin') return const SizedBox.shrink();
    final count = ref.watch(cartControllerProvider).items.where((line) => line.itemType == 'pet').length;
    return IconButton(
      tooltip: count == 0 ? 'Cart' : 'Cart, $count ${count == 1 ? 'item' : 'items'}',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}

/// Error panel with a Retry button, used by every network screen in the
/// shopping flow. Pass either the thrown [error] or a ready-made [message].
class CommerceRetryView extends StatelessWidget {
  final String title;
  final Object? error;
  final String? message;
  final VoidCallback onRetry;

  const CommerceRetryView({super.key, required this.title, this.error, this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failure = error;
    final detail = message ?? (failure == null ? 'Something went wrong.' : commerceErrorText(failure));
    return Semantics(
      liveRegion: true,
      child: EmptyState(
        title: title,
        description: detail,
        action: ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
        ),
      ),
    );
  }
}

/// Route to the support screen for [shopId] / [orderId] (either may be null).
String shopSupportRoute({String? shopId, String? orderId}) {
  final params = <String, String>{
    if (shopId != null && shopId.isNotEmpty) 'shop': shopId,
    if (orderId != null && orderId.isNotEmpty) 'order': orderId,
  };
  if (params.isEmpty) return '/support';
  return Uri(path: '/support', queryParameters: params).toString();
}

/// "<pet> added to your cart." with a View cart action.
void showAddedToCart(BuildContext context, Pet pet) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final router = GoRouter.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('${pet.displayName} added to your cart.'),
        backgroundColor: AppColors.ink,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'View cart', onPressed: () => router.push('/cart')),
      ),
    );
}

// ---------------------------------------------------------------------------
// Responsive grid helpers
// ---------------------------------------------------------------------------

const double kPetGridSpacing = 12;
const double _basePetCardHeight = 312;

/// Grid layout shared by every screen that lists [PetCard]s on a phone (two
/// columns, a fixed row height so the card's photo flexes rather than
/// overflowing). Prefer [petGridDelegate], which adapts to width and text size.
const kPetGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: kPetGridSpacing,
  crossAxisSpacing: kPetGridSpacing,
  mainAxisExtent: _basePetCardHeight,
);

/// Height of a [PetCard] on a phone at normal text size. Prefer
/// [petStripHeight] for horizontal strips.
const kPetStripHeight = _basePetCardHeight;

/// Columns for a card grid [width] dp wide: two on phones, more on tablets.
int petGridColumns(double width) {
  if (width >= 960) return 4;
  if (width >= 640) return 3;
  return 2;
}

/// The system text scale (1.0 at default), clamped to a sane range.
double petTextScale(BuildContext context) {
  final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
  return scaled.clamp(1.0, 2.0).toDouble();
}

/// Height of one [PetCard]: grows with the text size so the labels never
/// squeeze the photo to nothing, and with the cell width so the photo stays
/// roughly square on wide screens.
double petCardHeight(BuildContext context, {double cellWidth = 170}) {
  final photoBonus = ((cellWidth - 170) * 0.6).clamp(0.0, 150.0).toDouble();
  return _basePetCardHeight + photoBonus + (petTextScale(context) - 1) * 170;
}

/// Height of a horizontal strip of [PetCard]s.
double petStripHeight(BuildContext context) => petCardHeight(context);

/// Grid delegate for [PetCard]s in a grid [gridWidth] dp wide (the width of
/// the grid itself, after its horizontal padding).
SliverGridDelegate petGridDelegate(BuildContext context, double gridWidth) {
  final columns = petGridColumns(gridWidth);
  final cell = (gridWidth - kPetGridSpacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: kPetGridSpacing,
    crossAxisSpacing: kPetGridSpacing,
    mainAxisExtent: petCardHeight(context, cellWidth: cell),
  );
}

// ---------------------------------------------------------------------------
// Photos
// ---------------------------------------------------------------------------

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

/// A cached network photo that decodes no wider than [cacheWidth] logical
/// pixels, fades in, and swaps to [fallback] when there is no URL or it fails
/// to load. Never renders a broken-image glyph. [semanticLabel] describes the
/// photo to screen readers; without it the photo is decorative.
class _NetworkPhoto extends StatelessWidget {
  final String? src;
  final Widget fallback;
  final BoxFit fit;
  final double cacheWidth;
  final String? semanticLabel;

  const _NetworkPhoto({
    required this.src,
    required this.fallback,
    required this.fit,
    required this.cacheWidth,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final url = src;
    final Widget image;
    if (url == null || url.isEmpty) {
      image = fallback;
    } else {
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      image = CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        memCacheWidth: (cacheWidth * pixelRatio).round(),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, imageUrl) => Container(color: AppColors.primary.withValues(alpha: 0.05)),
        errorWidget: (context, imageUrl, error) => fallback,
      );
    }
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: image);
    return Semantics(image: true, label: label, excludeSemantics: true, child: image);
  }
}

/// Renders one photo when [src] is given, and the species icon otherwise --
/// either because the species has no reliable photo source ([src] is null)
/// or the URL failed to load at runtime. Never renders a broken-image
/// glyph. Mirrors src/components/ui/PetPhoto.jsx.
///
/// [cacheWidth] is the logical width the photo is shown at (the image is
/// decoded no larger than that, so long lists stay light on memory).
class PetPhotoView extends StatelessWidget {
  final String? src;
  final String species;
  final BoxFit fit;
  final double cacheWidth;
  final String? semanticLabel;

  const PetPhotoView({
    super.key,
    required this.src,
    required this.species,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _NetworkPhoto(
      src: src,
      fallback: SpeciesIconView(species: species),
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
    );
  }
}

/// Product photo with a category icon as the fallback (medicine vs. store
/// supplies). Same loading behaviour as [PetPhotoView].
class ProductPhotoView extends StatelessWidget {
  final String? src;
  final String category;
  final BoxFit fit;
  final double cacheWidth;
  final String? semanticLabel;

  const ProductPhotoView({
    super.key,
    required this.src,
    required this.category,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _NetworkPhoto(
      src: src,
      fallback: Container(
        color: AppColors.primary.withValues(alpha: 0.07),
        alignment: Alignment.center,
        child: Icon(
          category == 'medicine' ? Icons.medication_outlined : Icons.shopping_bag_outlined,
          color: AppColors.primary,
          size: 32,
        ),
      ),
      fit: fit,
      cacheWidth: cacheWidth,
      semanticLabel: semanticLabel,
    );
  }
}

/// Builds one photo for [PhotoGallery]: [url] is null when there is nothing to
/// show, [cacheWidth] is the logical width it is displayed at and
/// [semanticLabel] describes it to screen readers.
typedef GalleryPhotoBuilder = Widget Function(String? url, double cacheWidth, String? semanticLabel);

/// Swipeable photo gallery with a thumbnail strip and a "2 / 5" counter, shared
/// by the pet and product pages. With no photos it shows [photoBuilder]'s
/// fallback. [statusLabel] (e.g. "Sold") dims the photo and labels it. Key it
/// by the item id so it resets when the item changes.
class PhotoGallery extends StatefulWidget {
  final List<String> photos;
  final GalleryPhotoBuilder photoBuilder;

  /// What the photos show, e.g. "Photos of Bruno" (read out by screen readers).
  final String label;
  final String? statusLabel;

  const PhotoGallery({
    super.key,
    required this.photos,
    required this.photoBuilder,
    required this.label,
    this.statusLabel,
  });

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showPhoto(int index) {
    if (!_controller.hasClients) return;
    _controller.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final count = photos.length;
    final active = _index < count ? _index : 0;
    final status = widget.statusLabel;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 560;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: wide ? 4 / 3 : 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Opacity(
                        opacity: status != null ? 0.5 : 1,
                        child: count == 0
                            ? widget.photoBuilder(null, 400, null)
                            : PageView.builder(
                                controller: _controller,
                                itemCount: count,
                                onPageChanged: (index) => setState(() => _index = index),
                                itemBuilder: (context, index) => widget.photoBuilder(
                                  photos[index],
                                  wide ? 900 : 600,
                                  count == 1 ? widget.label : '${widget.label}, photo ${index + 1} of $count',
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (status != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          status,
                          style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                  if (count > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${active + 1} / $count',
                            style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (count > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: count,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final selected = index == active;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Show photo ${index + 1} of $count',
                      excludeSemantics: true,
                      onTap: () => _showPhoto(index),
                      child: InkWell(
                        onTap: () => _showPhoto(index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: widget.photoBuilder(photos[index], 128, null),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
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

    return Semantics(
      label: 'Rated ${rating.toStringAsFixed(1)} out of 5 from $reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
      excludeSemantics: true,
      child: Row(
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
          Flexible(
            child: Text(
              '${rating.toStringAsFixed(1)} ($reviewCount)',
              style: AppTheme.body(color: AppColors.inkSoft, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// First photo of [pet], or null when it has none (the card then shows the
/// species icon instead).
String? petCoverPhoto(Pet pet) => pet.photoUrls.isEmpty ? null : pet.photoUrls.first;

// ---------------------------------------------------------------------------
// Cards
// ---------------------------------------------------------------------------

/// The one pet card used on every screen that lists pets (home strips, the
/// /pets grid, shop storefronts). Mirrors src/components/ui/PetCard.jsx: photo,
/// name, breed, age and gender, price, the shop's NAME (never contact
/// details) and an Add to Cart button. Needs a bounded height (grid cell or
/// sized box -- see [petGridDelegate] / [petStripHeight]): the photo takes
/// whatever the text block leaves.
///
/// The photo and the text block are a single 48dp+ tap target that opens the
/// pet; the shop's page is one tap further, on the pet's own page.
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
    final hasShop = name != null && name.isNotEmpty;
    final summary = [
      pet.displayName,
      subtitle,
      if (meta.isNotEmpty) meta,
      formatPrice(pet.price),
      if (hasShop) 'sold by $name',
      if (unavailable) unavailableLabel,
    ].join(', ');
    void openPet() => context.push('/pets/${pet.id}');

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
            child: Semantics(
              button: true,
              label: summary,
              onTap: openPet,
              excludeSemantics: true,
              child: InkWell(
                onTap: openPet,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
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
                            style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w700, color: kPetPriceColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasShop)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                name,
                                style: AppTheme.body(fontSize: 11.5, color: AppColors.inkSoft),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: _CartButton(
              petName: pet.displayName,
              unavailable: unavailable,
              unavailableLabel: unavailableLabel,
              inCart: inCart,
              onAdd: () {
                ref.read(cartControllerProvider).addToCart('pet', pet.id);
                showAddedToCart(context, pet);
              },
              onViewCart: () => context.push('/cart'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final String petName;
  final bool unavailable;
  final String unavailableLabel;
  final bool inCart;
  final VoidCallback onAdd;
  final VoidCallback onViewCart;

  const _CartButton({
    required this.petName,
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
    const size = Size.fromHeight(48);

    final Widget button;
    final String semanticLabel;
    if (unavailable) {
      semanticLabel = '$petName is ${unavailableLabel.toLowerCase()}';
      button = OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(minimumSize: size, padding: padding, textStyle: textStyle),
        child: Text(unavailableLabel),
      );
    } else if (inCart) {
      semanticLabel = '$petName is in your cart. View cart';
      button = OutlinedButton.icon(
        onPressed: onViewCart,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('In Cart', maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          textStyle: textStyle,
          foregroundColor: kTrustTextColor,
          side: BorderSide(color: kTrustTextColor.withValues(alpha: 0.4)),
        ),
      );
    } else {
      semanticLabel = 'Add $petName to cart';
      button = ElevatedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.shopping_cart_outlined, size: 16),
        label: const Text('Add to Cart', maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          minimumSize: size,
          padding: padding,
          textStyle: textStyle,
          backgroundColor: kPetCtaColor,
          foregroundColor: Colors.white,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: !unavailable,
      label: semanticLabel,
      onTap: unavailable ? null : (inCart ? onViewCart : onAdd),
      excludeSemantics: true,
      child: button,
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
              Text(
                shop.name,
                style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
// the web app shows while the catalog loads). Built from SkeletonBox in
// skeletons.dart.
// ---------------------------------------------------------------------------

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
          Expanded(child: SkeletonBox(height: double.infinity, radius: 0)),
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

/// Grid of [PetCardSkeleton]s laid out exactly like the real pet grid, used as
/// the loading state of any screen that shows a grid of [PetCard]s.
class PetGridSkeleton extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  final bool shrinkWrap;

  const PetGridSkeleton({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 32),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading pets',
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            padding: padding,
            shrinkWrap: shrinkWrap,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: petGridDelegate(context, constraints.maxWidth - padding.horizontal),
            itemCount: count,
            itemBuilder: (context, index) => const PetCardSkeleton(),
          );
        },
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
