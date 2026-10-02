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

/// Mirrors src/components/cart/CartDrawer.jsx's actual feature set, shown as
/// a dedicated full-screen route rather than a slide-out drawer (a
/// full-screen equivalent makes more sense for mobile).
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final pets = cart.items
        .where((line) => line.itemType == 'pet')
        .map((line) => getSeedPetById(line.itemId))
        .whereType<SeedPet>()
        .toList();

    final subtotal = pets.fold<num>(0, (sum, pet) => sum + pet.price);

    return RoleShell(
      title: pets.isEmpty ? 'Your cart' : 'Your cart (${pets.length})',
      child: pets.isEmpty
          ? Padding(
              padding: kScreenPadding,
              child: EmptyState(
                title: 'Your cart is empty',
                description:
                    'Add a pet to your cart to hold it while you browse.',
                action: ElevatedButton(
                  onPressed: () => context.push('/pets'),
                  child: const Text('Browse pets'),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: kScreenPadding,
                    itemCount: pets.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) =>
                        _CartLineItem(pet: pets[index]),
                  ),
                ),
                _CartFooter(subtotal: subtotal),
              ],
            ),
    );
  }
}

class _CartLineItem extends ConsumerWidget {
  final SeedPet pet;
  const _CartLineItem({required this.pet});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = getSeedShopById(pet.shopId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/pets/${pet.id}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: PetPhotoView(
                  src: pet.photos?.firstOrNull,
                  species: pet.species,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => context.push('/pets/${pet.id}'),
                  child: Text(
                    pet.name,
                    style: AppTheme.body(fontWeight: FontWeight.w600),
                  ),
                ),
                if (shop != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Pickup at ${shop.name}',
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  formatPrice(pet.price),
                  style: AppTheme.body(
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                ref.read(cartControllerProvider).removeFromCart('pet', pet.id),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.inkSoft,
            tooltip: 'Remove ${pet.name} from cart',
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _CartFooter extends StatelessWidget {
  final num subtotal;
  const _CartFooter({required this.subtotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTheme.body(color: AppColors.inkSoft)),
              Text(
                formatPrice(subtotal),
                style: AppTheme.display(fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pickup and final payment happen at each shop — nothing ships.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/checkout'),
              child: const Text('Proceed to Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}
