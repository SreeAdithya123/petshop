import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/account/account_widgets.dart';
import '../widgets/account_scaffold.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/ui_kit.dart';

const _roleNames = {'shop_owner': 'shop owner', 'admin': 'admin'};

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _phonePattern = RegExp(r'^[\d\s()+-]{7,}$');

const _perks = [
  'You control which pets are listed and their prices.',
  "No listing fees while we're onboarding early shops.",
  "Buyers already know pickup and payment happen in person, so there's nothing to ship.",
  'Applications are reviewed by the PETSTA team before a shop goes live.',
];

/// Mirrors src/pages/Sell.jsx (now a section of "My account"): the "list your
/// shop" application. As on the web, nothing is saved by this form: a valid
/// submit only shows a thank-you, and the copy says applications are reviewed
/// by the PETSTA team rather than promising a reply.
class SellScreen extends StatelessWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      path: '/account/sell',
      title: 'Sell on PETSTA',
      builder: (context, profile) {
        // Shop owners and admins already have their own dashboards.
        if (profile.role != 'customer') return _AlreadySeller(profile: profile);
        return _SellBody(key: ValueKey(profile.id), profile: profile);
      },
    );
  }
}

class _AlreadySeller extends StatelessWidget {
  final Profile profile;
  const _AlreadySeller({required this.profile});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'You already have a ${_roleNames[profile.role] ?? profile.role} account',
      description: 'Applications to list a shop are for customer accounts.',
      action: ElevatedButton(
        onPressed: () => context.go(roleHomePath(profile.role)),
        child: const Text('Go to your dashboard'),
      ),
    );
  }
}

class _SellBody extends ConsumerStatefulWidget {
  final Profile profile;
  const _SellBody({super.key, required this.profile});

  @override
  ConsumerState<_SellBody> createState() => _SellBodyState();
}

class _SellBodyState extends ConsumerState<_SellBody> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _shopName = TextEditingController();
  late final TextEditingController _contactName = TextEditingController(text: widget.profile.name);
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final TextEditingController _city = TextEditingController();
  late final TextEditingController _license = TextEditingController();
  late final TextEditingController _message = TextEditingController();

  String _thanksName = '';
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill what we already know about the signed-in customer.
    final sessionEmail = ref.read(authControllerProvider).session?.user.email;
    _email.text = widget.profile.email ?? sessionEmail ?? '';
  }

  @override
  void dispose() {
    _shopName.dispose();
    _contactName.dispose();
    _email.dispose();
    _phone.dispose();
    _city.dispose();
    _license.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _required(String? value, String message) => (value == null || value.trim().isEmpty) ? message : null;

  void _handleSubmit() {
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    final contact = _contactName.text.trim();
    setState(() {
      _thanksName = contact.split(RegExp(r'\s+')).first;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThanks(context);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PETSTA connects nearby buyers with real, local pet shops. Tell us about your shop and apply to list '
            'your available pets.',
            style: AppTheme.body(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          for (final perk in _perks) _BulletItem(perk),
          const SizedBox(height: 26),
          const FormLabel('Shop name'),
          TextFormField(
            controller: _shopName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            validator: (value) => _required(value, "Enter your shop's name."),
          ),
          const SizedBox(height: 18),
          const FormLabel('Your name'),
          TextFormField(
            controller: _contactName,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            validator: (value) => _required(value, 'Enter your name.'),
          ),
          const SizedBox(height: 18),
          const FormLabel('Email'),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter your email address.';
              if (!_emailPattern.hasMatch(trimmed)) return 'Enter a valid email address.';
              return null;
            },
          ),
          const SizedBox(height: 18),
          const FormLabel('Phone'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) return 'Enter your phone number.';
              if (!_phonePattern.hasMatch(trimmed)) return 'Enter a valid phone number.';
              return null;
            },
          ),
          const SizedBox(height: 18),
          const FormLabel('City'),
          TextFormField(
            controller: _city,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.addressCity],
            validator: (value) => _required(value, 'Enter your city.'),
          ),
          const SizedBox(height: 18),
          const FormLabel('License number', optional: true),
          TextFormField(
            controller: _license,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 18),
          const FormLabel('Message', optional: true),
          TextFormField(
            controller: _message,
            minLines: 3,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 24),
          LoadingButton(label: 'Send application', onPressed: _handleSubmit, expand: true),
        ],
      ),
    );
  }

  Widget _buildThanks(BuildContext context) {
    return SuccessPanel(
      title: 'Thanks, $_thanksName',
      message: 'Applications are reviewed by the PETSTA team, and a shop is only listed once it has been approved.',
      actions: [
        ElevatedButton(
          onPressed: () => context.go('/account'),
          child: const Text('Back to my account'),
        ),
      ],
    );
  }
}

class _BulletItem extends StatelessWidget {
  final String text;
  const _BulletItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: AppColors.inkSoft, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTheme.body(color: AppColors.inkSoft))),
        ],
      ),
    );
  }
}
