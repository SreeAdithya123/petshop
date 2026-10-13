import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/supabase_service.dart';
import '../state/auth_provider.dart';
import '../state/cart_provider.dart';
import '../state/catalog_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

/// One reserved pet on the confirmation screen (the pet as it was when the
/// order was placed, plus its shop's name).
class _PlacedLine {
  final Pet pet;
  final String? shopName;
  const _PlacedLine(this.pet, this.shopName);
}

class _PlacedOrder {
  final String orderId;
  final num total;
  final List<_PlacedLine> lines;
  const _PlacedOrder({required this.orderId, required this.total, required this.lines});
}

/// Mirrors src/pages/Checkout.jsx: re-checks the cart against fresh listings
/// (sold, reserved or deleted pets drop out), then reserves every remaining pet
/// in one server-priced `place_pet_order` call. Nothing is paid online: the
/// shop confirms pickup details and payment happens in person, so there are no
/// card or UPI fields here. Only a shop's NAME is ever shown.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  /// False until the first fresh catalog fetch + prune has finished, so a stale
  /// cart is never shown as if it were confirmed available.
  bool _refreshed = false;
  int _removedCount = 0;
  bool _placing = false;
  String? _placeError;
  _PlacedOrder? _placed;

  @override
  void initState() {
    super.initState();
    // A cart can be days old: re-check availability against fresh listings
    // before showing it. Deferred so no provider is touched during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAndPrune();
    });
  }

  /// Re-fetches the listings, then drops cart pets that are no longer
  /// available. Never throws: a failed fetch is shown by [build] with a retry.
  Future<void> _refreshAndPrune() async {
    ref.invalidate(catalogProvider);
    var removed = 0;
    try {
      final catalog = await ref.read(catalogProvider.future).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      removed = await ref.read(cartControllerProvider).prunePets({for (final pet in catalog.pets) pet.id});
    } catch (_) {
      // The error state in build() explains what went wrong and offers a retry.
    }
    if (!mounted) return;
    setState(() {
      _removedCount += removed;
      _refreshed = true;
    });
  }

  Future<void> _retry() async {
    setState(() => _refreshed = false);
    await _refreshAndPrune();
  }

  Future<void> _placeOrder(List<Pet> pets, Catalog catalog) async {
    if (_placing || pets.isEmpty) return;
    // Captured up front: the order must still clear the cart if the user
    // navigates away while the request is in flight.
    final container = ProviderScope.containerOf(context, listen: false);
    final cart = container.read(cartControllerProvider);
    final lines = [for (final pet in pets) _PlacedLine(pet, catalog.shopById(pet.shopId)?.name)];
    final total = pets.fold<num>(0, (sum, pet) => sum + pet.price);

    setState(() {
      _placing = true;
      _placeError = null;
    });

    Object? orderId;
    try {
      orderId = await SupabaseService.client.rpc(
        'place_pet_order',
        params: {'p_pet_ids': pets.map((pet) => pet.id).toList()},
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _placing = false;
        _placeError = errorText(error);
      });
      // A pet may have just been reserved by someone else: refresh so it drops
      // out of the cart instead of failing again.
      unawaited(_refreshAndPrune());
      return;
    }

    // Show the confirmation first so the emptied cart never flashes on screen.
    if (mounted) {
      setState(() {
        _placing = false;
        _placed = _PlacedOrder(orderId: '$orderId', total: total, lines: lines);
      });
    }
    for (final pet in pets) {
      await cart.removeFromCart('pet', pet.id);
    }
    // The reserved pets are no longer "available": refresh the listings behind us.
    container.invalidate(catalogProvider);
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
    final placed = _placed;
    if (placed != null) {
      return RoleShell(
        title: 'Reservation confirmed',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: _ConfirmedView(order: placed),
        ),
      );
    }

    final auth = ref.watch(authControllerProvider);
    if (auth.status == AuthStatus.loading) {
      return const RoleShell(title: 'Checkout', child: LoadingView());
    }

    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return const RoleShell(
        title: 'Checkout',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: LoginPromptCard(
            title: 'Log in to reserve your pets',
            description: 'Sign in to confirm your reservation. Your cart will be waiting for you.',
          ),
        ),
      );
    }

    if (profile.role != 'customer') {
      return RoleShell(
        title: 'Checkout',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'Reservations are for customer accounts',
            description: 'Log in with a customer account to reserve pets.',
            action: OutlinedButton(
              onPressed: () => context.go(roleHomePath(profile.role)),
              child: const Text('Back to my dashboard'),
            ),
          ),
        ),
      );
    }

    final cart = ref.watch(cartControllerProvider);
    final petLines = cart.items.where((line) => line.itemType == 'pet').toList();
    if (petLines.isEmpty) {
      return RoleShell(title: 'Checkout', child: _emptyCart());
    }

    final catalogAsync = ref.watch(catalogProvider);
    final loading = catalogAsync.isLoading && !catalogAsync.hasValue;
    if (loading || !_refreshed) {
      return RoleShell(title: 'Checkout', child: _CheckoutSkeleton(count: petLines.length));
    }

    final failed = catalogAsync.hasError && !catalogAsync.isLoading;
    final catalog = failed ? null : catalogAsync.value;
    if (catalog == null) {
      return RoleShell(
        title: 'Checkout',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't check your pets",
            description: errorText(catalogAsync.error ?? 'Something went wrong.'),
            action: ElevatedButton(onPressed: _retry, child: const Text('Try again')),
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
      return RoleShell(title: 'Checkout', child: _emptyCart());
    }

    final total = pets.fold<num>(0, (sum, pet) => sum + pet.price);
    final contact = (profile.email != null && profile.email!.isNotEmpty)
        ? profile.email!
        : (auth.session?.user.email ?? '');

    return RoleShell(
      title: 'Checkout',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Checkout', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Reserve your pets now, then pick them up and pay in person at each shop. Nothing is charged online.',
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            if (_removedCount > 0) ...[
              const SizedBox(height: 16),
              NoticeBox(message: _removedMessage()),
            ],
            const SizedBox(height: 24),
            Text('Pets to reserve', style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _PetList(
              children: [
                for (final pet in pets)
                  _PetRow(
                    pet: pet,
                    shopName: catalog.shopById(pet.shopId)?.name,
                    onRemove: _placing ? null : () => ref.read(cartControllerProvider).removeFromCart('pet', pet.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Each pet is collected from its own shop. The shop will confirm pickup details with you after you reserve.',
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            Text('Reserving as', style: AppTheme.display(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              [if (profile.name.isNotEmpty) profile.name, if (contact.isNotEmpty) contact].join(' · '),
              style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            _OrderSummary(pets: pets, total: total),
            if (_placeError != null) ...[
              const SizedBox(height: 14),
              NoticeBox.error(message: _placeError!),
            ],
            const SizedBox(height: 14),
            LoadingButton(
              label: 'Confirm reservation',
              loading: _placing,
              expand: true,
              onPressed: () => _placeOrder(pets, catalog),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _placing ? null : () => context.push('/cart'),
                child: const Text('Back to cart'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _removedMessage() => _removedCount == 1
      ? '1 pet in your cart is no longer available and was removed.'
      : '$_removedCount pets in your cart are no longer available and were removed.';

  Widget _emptyCart() {
    return SingleChildScrollView(
      padding: kScreenPadding,
      child: EmptyState(
        title: 'Your cart is empty',
        description: _removedCount > 0
            ? 'The pets in your cart are no longer available, so they were removed.'
            : 'Add a pet to your cart before checking out.',
        action: ElevatedButton(
          onPressed: () => context.go('/pets'),
          child: const Text('Shop pets'),
        ),
      ),
    );
  }
}

/// Bordered, divided list container shared by the cart review and the
/// confirmation screen.
class _PetList extends StatelessWidget {
  final List<Widget> children;
  const _PetList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A pet's shop is fixed, never a buyer choice: this shows which shop each pet
/// comes from. Only the shop's name is shown.
class _PetRow extends StatelessWidget {
  final Pet pet;
  final String? shopName;
  final VoidCallback? onRemove;

  const _PetRow({required this.pet, required this.shopName, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final name = shopName;
    final remove = onRemove;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: PetPhotoView(src: petCoverPhoto(pet), species: pet.species),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.displayName,
                  style: AppTheme.body(fontSize: 14.5, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (name != null && name.isNotEmpty)
                  Text(
                    'Pickup at $name',
                    style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatPrice(pet.price),
            style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent),
          ),
          if (remove != null)
            IconButton(
              onPressed: remove,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.inkSoft,
              tooltip: 'Remove ${pet.displayName} from cart',
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final List<Pet> pets;
  final num total;
  const _OrderSummary({required this.pets, required this.total});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order summary', style: AppTheme.display(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final pet in pets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pet.displayName,
                      style: AppTheme.body(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatPrice(pet.price), style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: AppTheme.body(color: AppColors.inkSoft)),
              Text(formatPrice(total), style: AppTheme.display(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Due at pickup — nothing is charged online.',
            style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ConfirmedView extends StatelessWidget {
  final _PlacedOrder order;
  const _ConfirmedView({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, size: 48, color: AppColors.trust),
        const SizedBox(height: 16),
        Text(
          'Reservation confirmed',
          style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your pets are reserved. The shop will confirm pickup details with you; payment happens in person.',
          style: AppTheme.body(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SelectableText(
                      order.orderId,
                      textAlign: TextAlign.end,
                      style: AppTheme.body(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PetList(
                children: [for (final line in order.lines) _PetRow(pet: line.pet, shopName: line.shopName)],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amount due at pickup', style: AppTheme.body(color: AppColors.inkSoft)),
                  Text(formatPrice(order.total), style: AppTheme.display(fontSize: 17)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/account/orders'),
          child: const Text('View my orders'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => context.go('/pets'),
          child: const Text('Continue shopping'),
        ),
      ],
    );
  }
}

/// Placeholder shown while availability is being re-checked.
class _CheckoutSkeleton extends StatelessWidget {
  final int count;
  const _CheckoutSkeleton({required this.count});

  @override
  Widget build(BuildContext context) {
    return SkeletonPulse(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Checking availability…', style: AppTheme.body(color: AppColors.inkSoft)),
            const SizedBox(height: 24),
            for (var i = 0; i < count; i++) ...[
              const SkeletonBox(height: 80, radius: 12),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
