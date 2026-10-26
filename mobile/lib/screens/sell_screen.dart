import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../repositories/repositories.dart';
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
/// shop" application. The web form only shows a thank-you; here the
/// application is actually delivered, as a support request to the PETSTA team
/// (subject "Shop application: <name>" plus a message with the details), so
/// the team can reply in Support.
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
  bool _submitting = false;
  bool _submitted = false;
  bool _detailsSent = true;
  String _error = '';

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

  /// The application, as the first message of the support request.
  String _applicationText() {
    final license = _license.text.trim();
    final note = _message.text.trim();
    return [
      'Shop name: ${_shopName.text.trim()}',
      'Contact name: ${_contactName.text.trim()}',
      'Email: ${_email.text.trim()}',
      'Phone: ${_phone.text.trim()}',
      'City: ${_city.text.trim()}',
      if (license.isNotEmpty) 'License number: $license',
      if (note.isNotEmpty) 'Message: $note',
    ].join('\n');
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final contact = _contactName.text.trim();
    final subject = 'Shop application: ${_shopName.text.trim()}';
    setState(() {
      _submitting = true;
      _error = '';
    });

    final String ticketId;
    try {
      ticketId = await SupportTicketsRepository().insert({
        'customer_id': widget.profile.id,
        'shop_id': null,
        'subject': subject.length > 120 ? subject.substring(0, 120) : subject,
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorText(error);
      });
      return;
    }

    var detailsSent = true;
    try {
      await SupportMessagesRepository().insert({
        'ticket_id': ticketId,
        'sender_id': widget.profile.id,
        'message': _applicationText(),
      });
    } catch (_) {
      // The request exists; tell the customer how to add the details.
      detailsSent = false;
    }
    if (!mounted) return;
    setState(() {
      _thanksName = contact.split(RegExp(r'\s+')).first;
      _detailsSent = detailsSent;
      _submitting = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildThanks(context);

    final enabled = !_submitting;
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            validator: (value) => _required(value, "Enter your shop's name."),
          ),
          const SizedBox(height: 18),
          const FormLabel('Your name'),
          TextFormField(
            controller: _contactName,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            inputFormatters: [LengthLimitingTextInputFormatter(80)],
            validator: (value) => _required(value, 'Enter your name.'),
          ),
          const SizedBox(height: 18),
          const FormLabel('Email'),
          TextFormField(
            controller: _email,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            inputFormatters: [LengthLimitingTextInputFormatter(120)],
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
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [LengthLimitingTextInputFormatter(24)],
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
            enabled: enabled,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.addressCity],
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            validator: (value) => _required(value, 'Enter your city.'),
          ),
          const SizedBox(height: 18),
          const FormLabel('License number', optional: true),
          TextFormField(
            controller: _license,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
          ),
          const SizedBox(height: 18),
          const FormLabel('Message', optional: true),
          TextFormField(
            controller: _message,
            enabled: enabled,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 14),
            NoticeBox.error(message: _error),
          ],
          const SizedBox(height: 24),
          LoadingButton(
            label: 'Send application',
            loading: _submitting,
            onPressed: _handleSubmit,
            expand: true,
          ),
          const SizedBox(height: 10),
          Text(
            'Your application goes to the PETSTA team as a support request. Any replies appear under Support.',
            style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _buildThanks(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SuccessPanel(
          title: 'Thanks, $_thanksName',
          message: 'Your application is with the PETSTA team as a support request. We review every application, '
              'and a shop is only listed once it has been approved. Replies will appear in Support.',
          actions: [
            ElevatedButton(
              onPressed: () => context.push('/support'),
              child: const Text('Open Support'),
            ),
            OutlinedButton(
              onPressed: () => context.go('/account'),
              child: const Text('Back to my account'),
            ),
          ],
        ),
        if (!_detailsSent) ...[
          const SizedBox(height: 14),
          const NoticeBox.warning(
            message: "Your request was created, but we couldn't attach the details of your shop. "
                'Open it in Support and add a message with your shop name, city and phone number.',
          ),
        ],
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
