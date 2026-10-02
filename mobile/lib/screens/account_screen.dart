import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Matches src/pages/Account.jsx.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    if (auth.status == AuthStatus.loading) {
      return const RoleShell(title: 'Account', child: LoadingView());
    }

    if (auth.session == null || auth.profile == null) {
      return RoleShell(
        title: 'Account',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'Log in to see your account',
            action: ElevatedButton(
              onPressed: () => context.push('/login'),
              child: const Text('Log in'),
            ),
          ),
        ),
      );
    }

    final profile = auth.profile!;

    return RoleShell(
      title: 'Account',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your account', style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _ProfileSection(profile: profile),
            const SizedBox(height: 32),
            _OrdersSection(userId: profile.id),
            const SizedBox(height: 32),
            _ReservationsSection(userId: profile.id),
            const SizedBox(height: 32),
            _WishlistSection(userId: profile.id),
          ],
        ),
      ),
    );
  }
}

String _titleCase(String value) {
  return value
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w600));
  }
}

class _ProfileSection extends StatelessWidget {
  final Profile profile;
  const _ProfileSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    final role = _titleCase(profile.role.replaceAll('_', ' '));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Profile'),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _GridItem('Name', profile.name)),
            Expanded(child: _GridItem('Email', profile.email ?? '')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _GridItem('Phone', profile.phone ?? '')),
            Expanded(child: _GridItem('Role', role)),
          ],
        ),
      ],
    );
  }
}

class _GridItem extends StatelessWidget {
  final String label;
  final String value;
  const _GridItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 2),
        Text(value, style: AppTheme.body(fontSize: 15)),
      ],
    );
  }
}

const _orderTypeLabels = {
  'product_purchase': 'Product purchase',
  'pet_reservation': 'Pet reservation',
  'gift': 'Gift',
};

const _orderStatusLabels = {
  'pending': 'Pending',
  'paid': 'Paid',
  'fulfilled': 'Fulfilled',
  'cancelled': 'Cancelled',
};

const _reservationStatusLabels = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'expired': 'Expired',
  'cancelled': 'Cancelled',
};

class _RowCard extends StatelessWidget {
  final Widget child;
  const _RowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _OrdersSection extends StatefulWidget {
  final String userId;
  const _OrdersSection({required this.userId});

  @override
  State<_OrdersSection> createState() => _OrdersSectionState();
}

class _OrdersSectionState extends State<_OrdersSection> {
  bool _loading = true;
  List<OrderRow> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await OrdersRepository().listForCustomer(widget.userId);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Orders'),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Loading…'),
          )
        else if (_orders.isNotEmpty)
          Column(
            children: [
              for (final order in _orders) ...[
                _RowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _orderTypeLabels[order.orderType] ?? order.orderType,
                            style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            formatPrice(order.totalAmount),
                            style: AppTheme.display(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _orderStatusLabels[order.status] ?? order.status,
                            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                          ),
                          Text(
                            formatOrderDate(order.createdAt),
                            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          )
        else
          EmptyState(
            title: 'No orders yet',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Browse pets'),
            ),
          ),
      ],
    );
  }
}

class _ReservationsSection extends StatefulWidget {
  final String userId;
  const _ReservationsSection({required this.userId});

  @override
  State<_ReservationsSection> createState() => _ReservationsSectionState();
}

class _ReservationsSectionState extends State<_ReservationsSection> {
  bool _loading = true;
  List<Reservation> _reservations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reservations = await ReservationsRepository().listForCustomer(widget.userId);
    if (!mounted) return;
    setState(() {
      _reservations = reservations;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Reservations'),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Loading…'),
          )
        else if (_reservations.isNotEmpty)
          Column(
            children: [
              for (final reservation in _reservations) ...[
                _RowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reservation.petSpecies != null && reservation.petBreed != null
                                  ? '${reservation.petSpecies} · ${reservation.petBreed}'
                                  : 'Pet',
                              style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            '${formatPrice(reservation.depositAmount)} deposit',
                            style: AppTheme.display(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _reservationStatusLabels[reservation.status] ?? reservation.status,
                            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                          ),
                          Text(
                            'Expires ${formatOrderDate(reservation.expiresAt)}',
                            style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          )
        else
          const EmptyState(title: 'No reservations yet'),
      ],
    );
  }
}

class _WishlistRow {
  final String itemType;
  final String itemId;
  final String label;
  const _WishlistRow({required this.itemType, required this.itemId, required this.label});
}

class _WishlistSection extends StatefulWidget {
  final String userId;
  const _WishlistSection({required this.userId});

  @override
  State<_WishlistSection> createState() => _WishlistSectionState();
}

class _WishlistSectionState extends State<_WishlistSection> {
  bool _loading = true;
  List<_WishlistRow> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await WishlistRepository().listForCustomer(widget.userId);

    final resolved = <_WishlistRow>[];
    for (final row in rows) {
      if (row.itemType == 'pet') {
        String label;
        try {
          final pet = await PetsRepository().getById(row.itemId);
          label = pet != null ? '${pet.species} · ${pet.breed}' : 'Pet no longer listed';
        } catch (_) {
          label = 'Pet no longer listed';
        }
        resolved.add(_WishlistRow(itemType: row.itemType, itemId: row.itemId, label: label));
      } else {
        String label;
        try {
          final product = await ProductsRepository().getById(row.itemId);
          label = product != null ? '${product.name} — ${formatPrice(product.price)}' : 'Product no longer listed';
        } catch (_) {
          label = 'Product no longer listed';
        }
        resolved.add(_WishlistRow(itemType: row.itemType, itemId: row.itemId, label: label));
      }
    }

    if (!mounted) return;
    setState(() {
      _items = resolved;
      _loading = false;
    });
  }

  Future<void> _remove(_WishlistRow row) async {
    await WishlistRepository().remove(
      customerId: widget.userId,
      itemType: row.itemType,
      itemId: row.itemId,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Wishlist'),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Loading…'),
          )
        else if (_items.isNotEmpty)
          Column(
            children: [
              for (final item in _items) ...[
                _RowCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(item.label, style: AppTheme.body(fontSize: 15)),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => _remove(item),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          )
        else
          const EmptyState(title: 'No wishlist items yet'),
      ],
    );
  }
}
