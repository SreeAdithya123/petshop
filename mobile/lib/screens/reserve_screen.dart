import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/seed_data.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/pet_widgets.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// No reference implementation on the website (its /reserve/:petId route is
/// still a stub there). This builds a real, sensible deposit-hold flow that
/// stays local/no-Supabase, matching the Reservation model's shape but never
/// writing to the real reservations table (seed pet ids aren't real DB rows).
class ReserveScreen extends ConsumerStatefulWidget {
  final String petId;
  const ReserveScreen({super.key, required this.petId});

  @override
  ConsumerState<ReserveScreen> createState() => _ReserveScreenState();
}

class _ReserveScreenState extends ConsumerState<ReserveScreen> {
  bool _reserved = false;

  @override
  Widget build(BuildContext context) {
    final pet = getSeedPetById(widget.petId);

    if (pet == null) {
      return RoleShell(
        title: 'Reserve',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: "We couldn't find that pet",
            description: 'It may have been removed or the link is out of date.',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Browse pets'),
            ),
          ),
        ),
      );
    }

    final auth = ref.watch(authControllerProvider);
    final isSignedIn =
        auth.status == AuthStatus.signedIn && auth.profile != null;

    if (!isSignedIn) {
      return RoleShell(
        title: 'Reserve ${pet.name}',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'Log in to reserve this pet',
            description:
                "You'll need an account to hold ${pet.name} with a deposit.",
            action: ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('Log in'),
            ),
          ),
        ),
      );
    }

    if (pet.status == 'sold') {
      return RoleShell(
        title: 'Reserve ${pet.name}',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'This pet has already been sold',
            description: '${pet.name} is no longer available to reserve.',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Browse pets'),
            ),
          ),
        ),
      );
    }

    final shop = getSeedShopById(pet.shopId);
    final deposit = _depositFor(pet.price);

    if (_reserved) {
      return RoleShell(
        title: 'Reserve ${pet.name}',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.check_circle, size: 48, color: AppColors.trust),
              const SizedBox(height: 16),
              Text(
                'Reservation held',
                style: AppTheme.display(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${pet.name} is on hold for you. Visit ${shop?.name ?? 'the shop'} to complete the remainder at pickup.',
                style: AppTheme.body(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.push('/pets'),
                child: const Text('Browse pets'),
              ),
            ],
          ),
        ),
      );
    }

    return RoleShell(
      title: 'Reserve ${pet.name}',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reserve this pet',
              style: AppTheme.display(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: PetPhotoView(
                      src: pet.photos?.firstOrNull,
                      species: pet.species,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name, style: AppTheme.display(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        '${pet.species} · ${pet.breed}',
                        style: AppTheme.body(color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatPrice(pet.price),
                        style: AppTheme.body(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                          fontSize: 16,
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deposit due now',
                        style: AppTheme.body(color: AppColors.inkSoft),
                      ),
                      Text(
                        formatPrice(deposit),
                        style: AppTheme.display(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reserve with a ${formatPrice(deposit)} deposit — remainder due at pickup',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Remainder at pickup: ${formatPrice(pet.price - deposit)}',
                    style: AppTheme.body(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() => _reserved = true),
              child: const Text('Reserve this pet'),
            ),
          ],
        ),
      ),
    );
  }
}

num _depositFor(num price) {
  final raw = price * 0.2;
  final rounded = raw.round();
  return rounded < 25 ? 25 : rounded;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
