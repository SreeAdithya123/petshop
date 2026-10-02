import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../theme/app_theme.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/Shops.jsx: a heading and a list of all seeded shops.
class ShopsScreen extends StatelessWidget {
  const ShopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Shops',
      child: ListView(
        padding: kScreenPadding,
        children: [
          Text('Shops', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Browse licensed local pet shops and see what they currently have available.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          ...seedShops.map(
            (shop) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ShopListCard(shop: shop),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopListCard extends StatelessWidget {
  final SeedShop shop;
  const _ShopListCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final availableCount = getSeedPetsByShop(shop.id).where((p) => p.status != 'sold').length;

    return InkWell(
      onTap: () => context.push('/sellers/${shop.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            RatingStarsView(rating: shop.rating, reviewCount: shop.reviewCount),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 15, color: AppColors.inkSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(shop.address, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              availableCount > 0
                  ? '$availableCount ${availableCount == 1 ? 'pet' : 'pets'} listed'
                  : 'No pets listed right now',
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 3),
            Text('License #${shop.licenseNumber}', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
