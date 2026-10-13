import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// Mirrors src/components/cart/CartDrawer.jsx's actual feature set, shown as
/// a dedicated full-screen route rather than a slide-out drawer (a
/// full-screen equivalent makes more sense for mobile).
///
/// The cart only stores pet ids: names, photos, prices and shops are resolved
/// from the live catalog, and any pet the catalog no longer lists (sold,
/// reserved, deleted) is pruned from the cart once the catalog has loaded.
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  int _removedCount = 0;

  Future<void> _refresh() async {
    ref.invalidate(catalogProvider);
    try {
      await ref.read(catalogProvider.future).timeout(const Duration(seconds: 15));
    } catch (_) {
      // The screen renders the error state itself.
    }
  }

  /// Drops cart pets the catalog doesn't list. Runs after the frame so the
  /// cart isn't mutated during build; pruning twice is harmless.
  void _pruneAfterFrame(Set<String> validIds) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final removed = await ref.read(cartControllerProvider).prunePets(validIds);
      if (removed > 0 && mounted) setState(() => _removedCount += removed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final petLines = cart.items.where((line) => line.itemType == 'pet').toList();

    // An empty cart never needs the catalog.
    if (petLines.isEmpty) {
      return RoleShell(title: 'Your cart', child: _emptyCart());
    }

    final catalogAsync = ref.watch(catalogProvider);
    final loading = catalogAsync.isLoading && !catalogAsync.hasValue;
    final failed = catalogAsync.hasError && !catalogAsync.isLoading;
    final catalog = failed ? null : catalogAsync.value;

    if (loading) {
      return RoleShell(title: 'Your cart (${petLines.length})', child: _CartSkeleton(count: petLines.length));
    }

    if (catalog == null) {
      return RoleShell(
        title: 'Your cart',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't load your cart",
            description: errorText(catalogAsync.error ?? 'Something went wrong.'),
            action: ElevatedButton(
              onPressed: () => ref.invalidate(catalogProvider),
              child: const Text('Try again'),
            ),
          ),
        ),
      );
    }

    final validIds = {for (final pet in catalog.pets) pet.id};
    if (petLines.any((line) => !validIds.contains(line.itemId))) {
      _pruneAfterFrame(validIds);
    }

    final pets = petLines.map((line) => catalog.petById(line.itemId)).whereType<Pet>().toList();
    if (pets.isEmpty) {
      return RoleShell(title: 'Your cart', child: _emptyCart());
    }

    final subtotal = pets.fold<num>(0, (sum, pet) => sum + pet.price);

    return RoleShell(
      title: 'Your cart (${pets.length})',
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: kScreenPadding,
                children: [
                  if (_removedCount > 0) ...[
                    NoticeBox(message: _removedMessage()),
                    const SizedBox(height: 12),
                  ],
                  for (var i = 0; i < pets.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _CartLineItem(pet: pets[i], shopName: catalog.shopById(pets[i].shopId)?.name),
                  ],
                ],
              ),
            ),
          ),
          _CartFooter(subtotal: subtotal),
        ],
      ),
    );
  }

  String _removedMessage() => _removedCount == 1
      ? '1 pet in your cart is no longer available and was removed.'
      : '$_removedCount pets in your cart are no longer available and were removed.';

  Widget _emptyCart() {
    return ListView(
      padding: kScreenPadding,
      children: [
        if (_removedCount > 0) ...[
          NoticeBox(message: _removedMessage()),
          const SizedBox(height: 12),
        ],
        EmptyState(
          title: 'Your cart is empty',
          description: 'Add a pet to your cart to hold it while you browse.',
          action: ElevatedButton(
            onPressed: () => context.go('/pets'),
            child: const Text('Browse pets'),
          ),
        ),
      ],
    );
  }
}

class _CartLineItem extends ConsumerWidget {
  final Pet pet;
  final String? shopName;
  const _CartLineItem({required this.pet, required this.shopName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = shopName;
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
                child: PetPhotoView(src: petCoverPhoto(pet), species: pet.species),
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
                    pet.displayName,
                    style: AppTheme.body(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Pickup at $name',
                    style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  formatPrice(pet.price),
                  style: AppTheme.body(fontWeight: FontWeight.w600, color: AppColors.accent),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(cartControllerProvider).removeFromCart('pet', pet.id),
            icon: const Icon(Icons.delete_outline),
            color: AppColors.inkSoft,
            tooltip: 'Remove ${pet.displayName} from cart',
          ),
        ],
      ),
    );
  }
}

class _CartFooter extends StatelessWidget {
  final num subtotal;
  const _CartFooter({required this.subtotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTheme.body(color: AppColors.inkSoft)),
              Text(formatPrice(subtotal), style: AppTheme.display(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pickup and final payment happen at each shop — nothing ships.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/checkout'),
            child: const Text('Proceed to Checkout'),
          ),
        ],
      ),
    );
  }
}

class _CartSkeleton extends StatelessWidget {
  final int count;
  const _CartSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 64, height: 64, radius: 10),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 140, height: 15),
                        SizedBox(height: 8),
                        SkeletonBox(width: 100, height: 12),
                        SizedBox(height: 8),
                        SkeletonBox(width: 60, height: 15),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
