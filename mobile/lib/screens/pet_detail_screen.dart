import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../state/cart_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/PetDetail.jsx: photo gallery, spec table, add-to-cart /
/// wishlist actions, the shop card, and a "more from this shop" strip.
class PetDetailScreen extends ConsumerStatefulWidget {
  final String petId;
  const PetDetailScreen({super.key, required this.petId});

  @override
  ConsumerState<PetDetailScreen> createState() => _PetDetailScreenState();
}

class _PetDetailScreenState extends ConsumerState<PetDetailScreen> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pet = getSeedPetById(widget.petId);

    if (pet == null) {
      return RoleShell(
        title: 'Pet detail',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't find that pet",
            description: 'It may have already sold, or the link is out of date.',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Shop pets'),
            ),
          ),
        ),
      );
    }

    final shop = getSeedShopById(pet.shopId);
    final isSold = pet.status == 'sold';
    final photos = pet.photos ?? const <String>[];
    final activeIndex = _activeIndex < photos.length ? _activeIndex : 0;
    final relatedPets = getSeedPetsByShop(pet.shopId).where((p) => p.id != pet.id).take(4).toList();

    final cart = ref.watch(cartControllerProvider);
    final inCart = cart.isInCart('pet', pet.id);
    final inWishlist = cart.isInWishlist('pet', pet.id);

    return RoleShell(
      title: pet.name,
      child: ListView(
        padding: kScreenPadding,
        children: [
          // Photo gallery.
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Opacity(
                      opacity: isSold ? 0.55 : 1,
                      child: PetPhotoView(
                        src: photos.isNotEmpty ? photos[activeIndex] : null,
                        species: pet.species,
                      ),
                    ),
                  ),
                ),
                if (isSold)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        'Sold',
                        style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (photos.length > 1) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final selected = index == activeIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _activeIndex = index),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: PetPhotoView(src: photos[index], species: pet.species),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 20),
          Text('${pet.species} · ${pet.breed}', style: AppTheme.body(color: AppColors.inkSoft)),
          const SizedBox(height: 4),
          Text(pet.name, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            formatPrice(pet.price),
            style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),

          // Spec rows.
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              children: [
                _SpecRow(label: 'Species', value: pet.species),
                _SpecRow(label: 'Breed', value: pet.breed),
                _SpecRow(label: 'Age', value: pet.ageLabel),
                _SpecRow(label: 'Gender', value: pet.gender),
              ],
            ),
          ),

          // Quantity indicator (always 1).
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Opacity(
                opacity: 0.5,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.remove, size: 15, color: AppColors.inkSoft),
                      ),
                      SizedBox(
                        width: 22,
                        child: Text('1', textAlign: TextAlign.center, style: AppTheme.body(color: AppColors.ink)),
                      ),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.add, size: 15, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Quantity is always 1 — each pet is a unique animal.',
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),

          // Add to cart + wishlist.
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: isSold
                        ? null
                        : () {
                            if (inCart) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Already in your cart.')),
                              );
                            } else {
                              ref.read(cartControllerProvider).addToCart('pet', pet.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${pet.name} added to your cart.')),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSold ? AppColors.border : (inCart ? AppColors.trust : AppColors.accent),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.inkSoft,
                    ),
                    icon: Icon(
                      isSold
                          ? Icons.block
                          : inCart
                              ? Icons.check_circle
                              : Icons.shopping_cart_outlined,
                      size: 18,
                    ),
                    label: Text(isSold ? 'Sold' : (inCart ? 'In Cart' : 'Add to Cart')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => ref.read(cartControllerProvider).toggleWishlist('pet', pet.id),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: inWishlist ? AppColors.primary : AppColors.border),
                  ),
                  child: Icon(
                    inWishlist ? Icons.favorite : Icons.favorite_border,
                    color: inWishlist ? AppColors.primary : AppColors.inkSoft,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          // Shop card.
          if (shop != null) ...[
            const SizedBox(height: 24),
            InkWell(
              onTap: () => context.push('/sellers/${shop.id}'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shop.name, style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    RatingStarsView(rating: shop.rating, reviewCount: shop.reviewCount),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSoft),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(shop.address, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 15, color: AppColors.inkSoft),
                        const SizedBox(width: 6),
                        Text(shop.phone, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'License #${shop.licenseNumber}',
                      style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // More from this shop.
          if (relatedPets.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'More from ${shop?.name ?? "this shop"}',
              style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relatedPets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) => _MiniPetCard(pet: relatedPets[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  const _SpecRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTheme.body(color: AppColors.inkSoft)),
          Text(value, style: AppTheme.body(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Small linking pet card used in the "more from this shop" strip.
class _MiniPetCard extends StatelessWidget {
  final SeedPet pet;
  const _MiniPetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final isSold = pet.status == 'sold';
    final photo = (pet.photos != null && pet.photos!.isNotEmpty) ? pet.photos!.first : null;

    return InkWell(
      onTap: () => context.push('/pets/${pet.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: isSold ? 0.55 : 1,
                      child: PetPhotoView(src: photo, species: pet.species),
                    ),
                  ),
                  if (isSold)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(5)),
                        child: Text(
                          'Sold',
                          style: AppTheme.body(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: AppTheme.body(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${pet.breed} · ${pet.ageLabel}',
                    style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(pet.price),
                    style: AppTheme.display(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.accent),
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
