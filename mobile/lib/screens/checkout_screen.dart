import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_error.dart' show isNetworkError, isTimeoutError;
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../state/auth_provider.dart';
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

/// One reserved pet on the confirmation screen (the pet as it was when the
/// order was placed, plus its shop's name).
class _PlacedLine {
  final Pet pet;
  final String? shopName;
  const _PlacedLine(this.pet, this.shopName);
}

class _PlacedOrder {
  /// Null only if the server confirmed the order without returning its id.
  final String? orderId;
  final num total;
  final List<_PlacedLine> lines;
  const _PlacedOrder({required this.orderId, required this.total, required this.lines});
}

/// Shown when the request may or may not have reached the server.
const _uncertainOrderMessage = "We couldn't confirm your reservation because the connection dropped. "
    'Please check My account → Orders before trying again, so you do not reserve twice.';

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

  /// Set when that first fetch failed (the cart cannot be verified).
  Object? _checkError;
  int _removedCount = 0;
  bool _placing = false;
  String? _placeError;
  _PlacedOrder? _placed;
  bool _pruneScheduled = false;

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
  /// available. Never throws. A failure is remembered in [_checkError] (and
  /// shown with a retry) unless [quiet], which is used for background refreshes
  /// after a failed order and just keeps what is on screen.
  Future<void> _refreshAndPrune({bool quiet = false}) async {
    ref.invalidate(catalogProvider);
    var removed = 0;
    Object? failure;
    try {
      final catalog = await ref.read(catalogProvider.future).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      removed = await ref.read(cartControllerProvider).prunePets({for (final pet in catalog.pets) pet.id});
    } catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() {
      _removedCount += removed;
      if (!quiet) {
        _checkError = failure;
        _refreshed = true;
      }
    });
  }

  Future<void> _retry() async {
    setState(() {
      _refreshed = false;
      _checkError = null;
    });
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

    Object? result;
    try {
      result = await SupabaseService.client
          .rpc('place_pet_order', params: {'p_pet_ids': pets.map((pet) => pet.id).toList()})
          .timeout(const Duration(seconds: 30));
    } catch (error) {
      if (!mounted) return;
      // After a dropped connection the order may have gone through: don't
      // tell people to simply tap again, and don't prune (the pets could be
      // reserved by this very order).
      final uncertain = isNetworkError(error) || isTimeoutError(error);
      setState(() {
        _placing = false;
        _placeError = uncertain ? _uncertainOrderMessage : commerceErrorText(error);
      });
      // A pet may have just been reserved by someone else: refresh so it drops
      // out of the cart instead of failing again.
      if (!uncertain) unawaited(_refreshAndPrune(quiet: true));
      return;
    }

    final orderId = result is Map ? result['id']?.toString() : result?.toString();
    // Show the confirmation first so the emptied cart never flashes on screen.
    if (mounted) {
      setState(() {
        _placing = false;
        _placed = _PlacedOrder(orderId: orderId, total: total, lines: lines);
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
    if (_pruneScheduled) return;
    _pruneScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final removed = await ref.read(cartControllerProvider).prunePets(validIds);
      _pruneScheduled = false;
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
          child: ContentWidth(maxWidth: 560, child: _ConfirmedView(order: placed)),
        ),
      );
    }

    final auth = ref.watch(authControllerProvider);
    if (auth.status == AuthStatus.loading) {
      if (auth.profileFailed) {
        return RoleShell(
          title: 'Checkout',
          child: ScrollableMessage(
            child: CommerceRetryView(
              title: "We couldn't load your account",
              message: 'Check your internet connection and try again.',
              onRetry: () => ref.read(authControllerProvider).refreshProfile(),
            ),
          ),
        );
      }
      return const RoleShell(title: 'Checkout', child: _CheckoutSkeleton(count: 2, checking: false));
    }

    final profile = auth.profile;
    if (auth.status != AuthStatus.signedIn || profile == null) {
      return const RoleShell(
        title: 'Checkout',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: ContentWidth(
            maxWidth: 560,
            child: LoginPromptCard(
              title: 'Log in to reserve your pets',
              description: 'Sign in to confirm your reservation. Your cart will be waiting for you.',
            ),
          ),
        ),
      );
    }

    if (profile.role != 'customer') {
      return RoleShell(
        title: 'Checkout',
        child: ScrollableMessage(
          child: EmptyState(
            title: 'Reservations are for customer accounts',
            description: 'You are signed in with ${profile.role == 'admin' ? 'an admin' : 'a shop'} account, which '
                'cannot reserve pets. Log in with a customer account to continue.',
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
    final catalog = catalogAsync.value;
    final checking = !_refreshed || (catalog == null && catalogAsync.isInitialLoad);
    if (checking) {
      return RoleShell(title: 'Checkout', child: _CheckoutSkeleton(count: petLines.length));
    }

    final checkError = _checkError;
    if (catalog == null || checkError != null) {
      return RoleShell(
        title: 'Checkout',
        child: ScrollableMessage(
          child: CommerceRetryView(
            title: "We couldn't check your pets",
            error: checkError ?? catalogAsync.error,
            onRetry: _retry,
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
    final email = profile.email;
    final contact = (email != null && email.isNotEmpty) ? email : (auth.session?.user.email ?? '');
    final placeError = _placeError;

    return RoleShell(
      title: 'Checkout',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: ContentWidth(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('Checkout', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 6),
              Text(
                'Reserve your pets now, then pick them up and pay in person at each shop. Nothing is charged online.',
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
              if (_removedCount > 0) ...[
                const SizedBox(height: 16),
                Semantics(liveRegion: true, child: NoticeBox(message: _removedMessage())),
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
              const SizedBox(height: 14),
              const _HowItWorks(),
              if (placeError != null) ...[
                const SizedBox(height: 14),
                Semantics(liveRegion: true, child: NoticeBox.error(message: placeError)),
              ],
              const SizedBox(height: 14),
              LoadingButton(
                label: 'Confirm reservation · ${formatPrice(total)}',
                loading: _placing,
                expand: true,
                onPressed: () => _placeOrder(pets, catalog),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: _placing ? null : () => context.push('/cart'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: const Text('Back to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _removedMessage() => _removedCount == 1
      ? '1 pet in your cart is no longer available and was removed.'
      : '$_removedCount pets in your cart are no longer available and were removed.';

  Widget _emptyCart() {
    return ScrollableMessage(
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
      padding: EdgeInsets.fromLTRB(12, 12, remove == null ? 12 : 4, 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: PetPhotoView(src: petCoverPhoto(pet), species: pet.species, cacheWidth: 112),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (name != null && name.isNotEmpty)
                  Text(
                    'Pickup at $name',
                    style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  formatPrice(pet.price),
                  style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700, color: kPetPriceColor),
                ),
              ],
            ),
          ),
          if (remove != null)
            IconButton(
              onPressed: remove,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AppColors.inkSoft,
              tooltip: 'Remove ${pet.displayName} from cart',
            ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      pet.displayName,
                      style: AppTheme.body(fontSize: 14),
                      maxLines: 2,
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
              Text('Total due at pickup', style: AppTheme.body(color: AppColors.inkSoft)),
              Text(formatPrice(total), style: AppTheme.display(fontSize: 17)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You pay the shop in person. Nothing is charged online.',
            style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// The three steps after tapping "Confirm reservation".
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.lock_outline, 'We hold your pets for you as soon as you confirm.'),
      (Icons.chat_bubble_outline, 'The shop confirms pickup details with you.'),
      (Icons.storefront_outlined, 'You collect the pets and pay in person.'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What happens next', style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(step.$1, size: 17, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step.$2, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft))),
                ],
              ),
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
    final orderId = order.orderId;
    // One entry per shop, in cart order.
    final shops = <String, String>{};
    for (final line in order.lines) {
      shops.putIfAbsent(line.pet.shopId, () => line.shopName ?? 'the shop');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExcludeSemantics(child: Icon(Icons.check_circle, size: 48, color: AppColors.trust)),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            'Reservation confirmed',
            style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your pets are reserved. The shop will confirm pickup details with you, and you pay in person when you '
          'collect them. Nothing was charged online.',
          style: AppTheme.body(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        CardBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (orderId != null) ...[
                Row(
                  children: [
                    Text('Order', style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        shortId(orderId),
                        textAlign: TextAlign.end,
                        style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              _PetList(
                children: [for (final line in order.lines) _PetRow(pet: line.pet, shopName: line.shopName)],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('Amount due at pickup', style: AppTheme.body(color: AppColors.inkSoft))),
                  const SizedBox(width: 12),
                  Text(formatPrice(order.total), style: AppTheme.display(fontSize: 17)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/account/orders'),
          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('View my orders'),
        ),
        for (final entry in shops.entries) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.push(shopSupportRoute(shopId: entry.key, orderId: orderId)),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: Text(
              shops.length == 1 ? 'Message the shop' : 'Message ${entry.value}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/pets'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Continue shopping'),
        ),
      ],
    );
  }
}

/// Placeholder shown while availability is being re-checked.
class _CheckoutSkeleton extends StatelessWidget {
  final int count;
  final bool checking;
  const _CheckoutSkeleton({required this.count, this.checking = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: checking ? 'Checking availability' : 'Loading',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: kScreenPadding,
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Checkout', style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  checking ? 'Checking availability…' : 'Loading…',
                  style: AppTheme.body(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < count && i < 5; i++) ...[
                  const SkeletonBox(height: 80, radius: 12),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
