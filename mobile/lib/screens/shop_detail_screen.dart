import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/ShopDetail.jsx: a primary-colored banner, shop details,
/// and a grid of that shop's pets.
class ShopDetailScreen extends StatelessWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  Widget build(BuildContext context) {
    final shop = getSeedShopById(shopId);

    if (shop == null) {
      return RoleShell(
        title: 'Shop detail',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't find that shop",
            description: 'It may have closed, or the link is out of date.',
            action: ElevatedButton(
              onPressed: () => context.push('/sellers'),
              child: const Text('Browse shops'),
            ),
          ),
        ),
      );
    }

    final shopPets = getSeedPetsByShop(shop.id);

    return RoleShell(
      title: shop.name,
      child: ListView(
        padding: kScreenPadding,
        children: [
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 150),
            padding: const EdgeInsets.all(20),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              shop.name,
              style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.paper),
            ),
          ),

          const SizedBox(height: 20),
          RatingStarsView(rating: shop.rating, reviewCount: shop.reviewCount),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Expanded(child: Text(shop.address, style: AppTheme.body(color: AppColors.inkSoft))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text(shop.phone, style: AppTheme.body(color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 6),
          Text('License #${shop.licenseNumber}', style: AppTheme.body(color: AppColors.inkSoft)),

          const SizedBox(height: 28),
          Text('Pets at ${shop.name}', style: AppTheme.display(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),

          if (shopPets.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shopPets.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) => _ShopPetGridCard(pet: shopPets[index]),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                title: 'No pets listed right now',
                description: 'Check back soon, or browse other shops.',
                action: ElevatedButton(
                  onPressed: () => context.push('/sellers'),
                  child: const Text('Browse shops'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small linking pet card used in this shop's pet grid.
class _ShopPetGridCard extends StatelessWidget {
  final SeedPet pet;
  const _ShopPetGridCard({required this.pet});

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
