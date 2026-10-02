import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
