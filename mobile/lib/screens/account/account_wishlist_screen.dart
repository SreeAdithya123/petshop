import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/catalog_provider.dart';
import '../../state/wishlist_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/account/account_widgets.dart';
import '../../widgets/account_scaffold.dart';
import '../../widgets/pet_widgets.dart';
import '../../widgets/shared_widgets.dart';
import '../../widgets/ui_kit.dart';

/// Mirrors src/pages/account/AccountWishlist.jsx: the pets saved to the
/// database-backed wishlist, with remove buttons and a clean-up action for
/// pets that are no longer available.
class AccountWishlistScreen extends StatelessWidget {
  const AccountWishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/wishlist',
      title: 'Wishlist',
      subtitle: "Pets you've saved. Only pets that are still available show up here.",
      builder: (context, profile) => const _WishlistBody(),
    );
  }
}

class _WishlistBody extends ConsumerStatefulWidget {
  const _WishlistBody();

  @override
  ConsumerState<_WishlistBody> createState() => _WishlistBodyState();
}

class _WishlistBodyState extends ConsumerState<_WishlistBody> {
  Set<String> _removing = {};
  String? _removeError;

  Future<void> _remove(List<String> ids) async {
    final controller = ref.read(wishlistControllerProvider);
    // toggle() adds an id that isn't saved any more, so only pass saved ones.
    final targets = ids.where(controller.isWishlisted).toList();
    if (targets.isEmpty) return;

    setState(() {
      _removeError = null;
      _removing = {..._removing, ...targets};
    });
    final results = await Future.wait([for (final id in targets) controller.toggle(id)]);
    if (!mounted) return;
    setState(() {
      _removing = {..._removing}..removeAll(targets);
      if (results.any((message) => message != null)) {
        _removeError = "Couldn't update your wishlist. Please try again.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlist = ref.watch(wishlistControllerProvider);
    final catalogAsync = ref.watch(catalogProvider);

    if (!wishlist.signedIn) {
      return const EmptyState(
        title: 'Wishlists are for customer accounts',
        description: 'Log in with a customer account to save pets for later.',
      );
    }

    if (!catalogAsync.hasValue) {
      if (catalogAsync.hasError) {
        return AccountErrorNote(
          message: errorText(catalogAsync.error!),
          onRetry: () => ref.invalidate(catalogProvider),
        );
      }
      return const AccountLoadingNote();
    }
    if (wishlist.loading) return const AccountLoadingNote();

    final catalog = catalogAsync.requireValue;
    final petIds = wishlist.petIds.toList();

    if (petIds.isEmpty) {
      return EmptyState(
        title: 'Your wishlist is empty',
        description: 'Tap the heart on any pet to save it here for later.',
        action: ElevatedButton(
          onPressed: () => context.push('/pets'),
          child: const Text('Browse pets'),
        ),
      );
    }

    final availablePets = <Pet>[
      for (final id in petIds)
        if (catalog.petById(id) != null) catalog.petById(id)!,
    ];
    final unavailableIds = [
      for (final id in petIds)
        if (catalog.petById(id) == null) id,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (unavailableIds.isNotEmpty) ...[
          CardBox(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailableIds.length == 1
                      ? '1 pet on your wishlist is no longer available.'
                      : '${unavailableIds.length} pets on your wishlist are no longer available.',
                  style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: unavailableIds.any(_removing.contains) ? null : () => _remove(unavailableIds),
                  child: Text(unavailableIds.length == 1 ? 'Remove unavailable pet' : 'Remove unavailable pets'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_removeError != null) ...[
          NoticeBox.error(message: _removeError!),
          const SizedBox(height: 14),
        ],
        if (availablePets.isEmpty)
          EmptyState(
            title: 'Nothing available right now',
            description: 'The pets you saved have found homes. Browse more to save new favourites.',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Browse pets'),
            ),
          )
        else
          for (final pet in availablePets) ...[
            _WishlistPetCard(
              key: ValueKey(pet.id),
              pet: pet,
              shopName: catalog.shopById(pet.shopId)?.name,
              removing: _removing.contains(pet.id),
              onRemove: () => _remove([pet.id]),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// Compact horizontal pet card (photo, name, price) with a remove button.
class _WishlistPetCard extends StatelessWidget {
  final Pet pet;
  final String? shopName;
  final bool removing;
  final VoidCallback onRemove;

  const _WishlistPetCard({
    super.key,
    required this.pet,
    required this.shopName,
    required this.removing,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final age = formatAge(pet.ageMonths);
    final details = [pet.species, pet.breed, if (age.isNotEmpty) age].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => context.push('/pets/${pet.id}'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: PetPhotoView(
                    src: pet.photoUrls.isNotEmpty ? pet.photoUrls.first : null,
                    species: pet.species,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.displayName,
                          style: AppTheme.body(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          details,
                          style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (shopName != null && shopName!.isNotEmpty)
                          Text(
                            shopName!,
                            style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 6),
                        Text(
                          formatPrice(pet.price),
                          style: AppTheme.display(fontSize: 16, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: removing ? null : onRemove,
              icon: const Icon(Icons.heart_broken_outlined, size: 18),
              label: Text(removing ? 'Removing…' : 'Remove from wishlist'),
              style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
