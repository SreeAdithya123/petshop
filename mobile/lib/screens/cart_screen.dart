import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/content_width.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/skeletons.dart';
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
  bool _pruneScheduled = false;

  /// Drops cart pets the catalog doesn't list. Runs after the frame so the
  /// cart isn't mutated during build; pruning twice is harmless.
  void _pruneAfterFrame(Set<String> validIds) {
    if (_pruneScheduled) return;
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cart = ref.read(cartControllerProvider);
      final removed = await cart.prunePets(validIds);
      _pruneScheduled = false;
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
    final catalog = catalogAsync.value;

    if (catalog == null) {
      final title = 'Your cart (${petLines.length})';
      if (catalogAsync.hasFailed) {
        return RoleShell(
          title: title,
          child: ScrollableMessage(
            child: CommerceRetryView(
              title: "We couldn't load your cart",
              error: catalogAsync.error,
              onRetry: () => ref.invalidate(catalogProvider),
            ),
          ),
        );
      }
      return RoleShell(title: title, child: _CartSkeleton(count: petLines.length));
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
                        if (_removedCount > 0) ...[
                          NoticeBox(message: _removedMessage()),
                          const SizedBox(height: 12),
                        ],
                        for (var i = 0; i < pets.length; i++) ...[
                          if (i > 0) const Divider(height: 1, color: AppColors.border),
                          _CartLineItem(pet: pets[i], shopName: catalog.shopById(pets[i].shopId)?.name),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => context.go('/pets'),
                            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add more pets'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _CartFooter(subtotal: subtotal, count: pets.length),
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
        ContentWidth(
          maxWidth: 560,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
    final hasShop = name != null && name.isNotEmpty;
    final summary = [
      pet.displayName,
      formatPrice(pet.price),
      if (hasShop) 'pickup at $name',
    ].join(', ');
    void open() => context.push('/pets/${pet.id}');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: summary,
            hint: 'Opens the pet page',
            onTap: open,
            excludeSemantics: true,
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: PetPhotoView(src: petCoverPhoto(pet), species: pet.species, cacheWidth: 128),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.displayName,
                            style: AppTheme.body(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasShop) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Pickup at $name',
                              style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            formatPrice(pet.price),
                            style: AppTheme.body(fontWeight: FontWeight.w700, color: kPetPriceColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => ref.read(cartControllerProvider).removeFromCart('pet', pet.id),
          icon: const Icon(Icons.delete_outline),
          color: AppColors.inkSoft,
          tooltip: 'Remove ${pet.displayName} from cart',
        ),
      ],
    );
  }
}

class _CartFooter extends StatelessWidget {
  final num subtotal;
  final int count;
  const _CartFooter({required this.subtotal, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: ContentWidth(
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Subtotal ($count ${count == 1 ? 'pet' : 'pets'})',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                ),
                const SizedBox(width: 12),
                Text(formatPrice(subtotal), style: AppTheme.display(fontSize: 17)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reserve now, then pick up and pay in person at each shop. Nothing ships and nothing is charged online.',
              style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => context.push('/checkout'),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Proceed to checkout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSkeleton extends StatelessWidget {
  final int count;
  const _CartSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your cart',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: [
          ContentWidth(
            maxWidth: 720,
            child: Column(
              children: [
                for (var i = 0; i < count && i < 6; i++)
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
          ),
        ],
      ),
    );
  }
}
