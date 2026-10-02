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

/// Mirrors src/pages/Checkout.jsx exactly: a fully local, NO-Supabase flow.
/// The website itself doesn't persist orders here, it just simulates one.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _LocalOrder {
  final String id;
  final List<SeedPet> items;
  final num subtotal;
  final String buyerName;
  final String buyerEmail;
  final String buyerPhone;
  final String paymentMethod;
  final DateTime placedAt;

  _LocalOrder({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.buyerName,
    required this.buyerEmail,
    required this.buyerPhone,
    required this.paymentMethod,
    required this.placedAt,
  });
}

const List<String> _stepLabels = ['Details', 'Payment', 'Review'];

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  int _step = 1;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String _paymentMethod = 'card';
  _LocalOrder? _order;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _validateBuyer() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    String? nameError;
    String? emailError;
    String? phoneError;

    if (name.isEmpty) nameError = 'Enter your name.';

    if (email.isEmpty) {
      emailError = 'Enter an email address.';
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      emailError = 'Enter a valid email address.';
    }

    if (phone.isEmpty) {
      phoneError = 'Enter a phone number.';
    } else if (!RegExp(r'^[\d\s()+-]{7,}$').hasMatch(phone)) {
      phoneError = 'Enter a valid phone number.';
    }

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _phoneError = phoneError;
    });

    return nameError == null && emailError == null && phoneError == null;
  }

  void _handleContinueFromDetails() {
    if (!_validateBuyer()) return;
    setState(() => _step = 2);
  }

  Future<void> _handlePlaceOrder(List<SeedPet> items, num subtotal) async {
    final order = _LocalOrder(
      id: 'PN-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}',
      items: items,
      subtotal: subtotal,
      buyerName: _nameController.text.trim(),
      buyerEmail: _emailController.text.trim(),
      buyerPhone: _phoneController.text.trim(),
      paymentMethod: _paymentMethod,
      placedAt: DateTime.now(),
    );
    await ref.read(cartControllerProvider).clearCart();
    if (!mounted) return;
    setState(() => _order = order);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final pets = cart.items
        .where((line) => line.itemType == 'pet')
        .map((line) => getSeedPetById(line.itemId))
        .whereType<SeedPet>()
        .toList();
    final subtotal = pets.fold<num>(0, (sum, pet) => sum + pet.price);

    if (_order == null && pets.isEmpty) {
      return RoleShell(
        title: 'Checkout',
        child: Padding(
          padding: kScreenPadding,
          child: EmptyState(
            title: 'Your cart is empty',
            description: 'Add a pet to your cart before checking out.',
            action: ElevatedButton(
              onPressed: () => context.push('/pets'),
              child: const Text('Shop pets'),
            ),
          ),
        ),
      );
    }

    if (_order != null) {
      return RoleShell(
        title: 'Order placed',
        child: SingleChildScrollView(
          padding: kScreenPadding,
          child: _ConfirmedView(order: _order!),
        ),
      );
    }

    return RoleShell(
      title: 'Checkout',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Checkout',
              style: AppTheme.display(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _Stepper(current: _step),
            ),
            const SizedBox(height: 24),
            if (_step == 1)
              _DetailsStep(
                nameController: _nameController,
                emailController: _emailController,
                phoneController: _phoneController,
                nameError: _nameError,
                emailError: _emailError,
                phoneError: _phoneError,
                items: pets,
                onContinue: _handleContinueFromDetails,
              ),
            if (_step == 2)
              _PaymentStep(
                paymentMethod: _paymentMethod,
                onChanged: (value) => setState(() => _paymentMethod = value),
                onBack: () => setState(() => _step = 1),
                onContinue: () => setState(() => _step = 3),
              ),
            if (_step == 3)
              _ReviewStep(
                name: _nameController.text.trim(),
                email: _emailController.text.trim(),
                phone: _phoneController.text.trim(),
                paymentMethod: _paymentMethod,
                items: pets,
                onBack: () => setState(() => _step = 2),
                onPlaceOrder: () => _handlePlaceOrder(pets, subtotal),
              ),
            const SizedBox(height: 28),
            _OrderSummary(items: pets, subtotal: subtotal),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int current;
  const _Stepper({required this.current});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < _stepLabels.length; i++) {
      final stepId = i + 1;
      final isDone = stepId < current;
      final isCurrent = stepId == current;
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.trust
                    : (isCurrent ? AppColors.primary : AppColors.border),
                shape: BoxShape.circle,
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '$stepId',
                      style: AppTheme.body(
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Text(
              _stepLabels[i],
              style: AppTheme.body(
                color: isCurrent ? AppColors.ink : AppColors.inkSoft,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (i < _stepLabels.length - 1) ...[
              const SizedBox(width: 12),
              Container(width: 32, height: 1, color: AppColors.border),
              const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }
    return Row(children: children);
  }
}

/// A pet's shop is fixed, never a buyer choice — this shows which shop each
/// item comes from, not a shop picker. Reused read-only in Details and
/// Review steps and in the order summary sidecar.
class _PickupList extends StatelessWidget {
  final List<SeedPet> items;
  const _PickupList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            _PickupListItem(pet: items[i]),
          ],
        ],
      ),
    );
  }
}

class _PickupListItem extends StatelessWidget {
  final SeedPet pet;
  const _PickupListItem({required this.pet});

  @override
  Widget build(BuildContext context) {
    final shop = getSeedShopById(pet.shopId);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: PetPhotoView(
                src: pet.photos?.firstOrNull,
                species: pet.species,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: AppTheme.body(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Pickup at ${shop?.name ?? ''}',
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            formatPrice(pet.price),
            style: AppTheme.body(
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final String? nameError;
  final String? emailError;
  final String? phoneError;
  final List<SeedPet> items;
  final VoidCallback onContinue;

  const _DetailsStep({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
    required this.nameError,
    required this.emailError,
    required this.phoneError,
    required this.items,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Your details', style: AppTheme.display(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          "No shipping address needed — these pets don't ship. You'll pick each one up in person.",
          style: AppTheme.body(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        _LabeledField(
          label: 'Full name',
          controller: nameController,
          error: nameError,
          keyboardType: TextInputType.name,
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: 'Email address',
          controller: emailController,
          error: emailError,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: 'Phone number',
          controller: phoneController,
          error: phoneError,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 28),
        Text('Pickup by shop', style: AppTheme.display(fontSize: 16)),
        _PickupList(items: items),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onContinue,
          child: const Text('Continue to payment'),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? error;
  final TextInputType keyboardType;

  const _LabeledField({
    required this.label,
    required this.controller,
    required this.error,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            errorText: error,
            enabledBorder: error != null
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.error),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _PaymentStep extends StatelessWidget {
  final String paymentMethod;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const _PaymentStep({
    required this.paymentMethod,
    required this.onChanged,
    required this.onBack,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final options = const [
      (value: 'card', label: 'Card', icon: Icons.credit_card),
      (value: 'upi', label: 'UPI', icon: Icons.smartphone),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Payment method', style: AppTheme.display(fontSize: 18)),
        const SizedBox(height: 4),
        Text(
          "Choose how you'll pay at pickup. Nothing is charged now, and no payment details are collected on this site.",
          style: AppTheme.body(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 20),
        for (final option in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: paymentMethod == option.value
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  color: paymentMethod == option.value
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : null,
                ),
                child: Row(
                  children: [
                    _RadioDot(selected: paymentMethod == option.value),
                    const SizedBox(width: 12),
                    Icon(option.icon, size: 20, color: AppColors.inkSoft),
                    const SizedBox(width: 10),
                    Text(option.label, style: AppTheme.body()),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onContinue,
                child: const Text('Continue to review'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Simple radio-dot indicator, avoiding Radio's deprecated
/// groupValue/onChanged API (Flutter now prefers a RadioGroup ancestor) --
/// selection is driven entirely by the parent InkWell's onTap.
class _RadioDot extends StatelessWidget {
  final bool selected;
  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.inkSoft,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

class _ReviewStep extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final String paymentMethod;
  final List<SeedPet> items;
  final VoidCallback onBack;
  final VoidCallback onPlaceOrder;

  const _ReviewStep({
    required this.name,
    required this.email,
    required this.phone,
    required this.paymentMethod,
    required this.items,
    required this.onBack,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review your order', style: AppTheme.display(fontSize: 18)),
        const SizedBox(height: 16),
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
              Text('Buyer', style: AppTheme.body(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                '$name · $email · $phone',
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
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
              Text(
                'Payment method',
                style: AppTheme.body(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '${paymentMethod == 'card' ? 'Card' : 'UPI'} — paid in person at pickup, not charged here.',
                style: AppTheme.body(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Items', style: AppTheme.body(fontWeight: FontWeight.w600)),
        _PickupList(items: items),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton(onPressed: onBack, child: const Text('Back')),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onPlaceOrder,
                child: const Text('Place order'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final List<SeedPet> items;
  final num subtotal;
  const _OrderSummary({required this.items, required this.subtotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order summary', style: AppTheme.display(fontSize: 16)),
          const SizedBox(height: 10),
          for (final pet in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pet.name,
                      style: AppTheme.body(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPrice(pet.price),
                    style: AppTheme.body(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTheme.body(color: AppColors.inkSoft)),
              Text(
                formatPrice(subtotal),
                style: AppTheme.display(fontSize: 16),
              ),
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
  final _LocalOrder order;
  const _ConfirmedView({required this.order});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, size: 48, color: AppColors.trust),
        const SizedBox(height: 16),
        Text(
          'Order placed',
          style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(
          "Order #${order.id} is placed and pending pickup. No payment has been charged — you'll pay in person when you collect each pet from its shop.",
          style: AppTheme.body(color: AppColors.inkSoft),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Placed',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  Text(formatOrderDate(order.placedAt), style: AppTheme.body()),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Confirmation sent to',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  Flexible(
                    child: Text(
                      order.buyerEmail,
                      style: AppTheme.body(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 28, color: AppColors.border),
              _PickupList(items: order.items),
              const Divider(height: 28, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Amount due at pickup',
                    style: AppTheme.body(color: AppColors.inkSoft),
                  ),
                  Text(
                    formatPrice(order.subtotal),
                    style: AppTheme.display(fontSize: 17),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.push('/pets'),
          child: const Text('Continue shopping'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
