import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/Sell.jsx -- a fully local "list your shop" application
/// form. Nothing is sent over the network; a valid submit just swaps in a
/// thank-you view.
class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _licenseController = TextEditingController();
  final _messageController = TextEditingController();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phonePattern = RegExp(r'^[\d\s()+-]{7,}$');

  bool _submitted = false;

  @override
  void dispose() {
    _shopNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _licenseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Sell on PETSTA',
      child: _submitted ? _buildThankYou(context) : _buildForm(context),
    );
  }

  Widget _buildThankYou(BuildContext context) {
    final firstName = _contactNameController.text
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return SingleChildScrollView(
      padding: kScreenPadding,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 56, color: AppColors.primary),
            const SizedBox(height: 20),
            Text(
              'Thanks, $firstName',
              style: AppTheme.display(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "We've received your application for ${_shopNameController.text.trim()} and will follow up "
              'at ${_emailController.text.trim()} within a few business days.',
              style: AppTheme.body(color: AppColors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/'),
                child: const Text('Back to home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: kScreenPadding,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'List your shop',
              style: AppTheme.display(
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "PETSTA connects nearby buyers with real, local pet shops. Tell us a bit about your "
              "shop and we'll reach out to help you get your available pets listed.",
              style: AppTheme.body(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            _BulletItem('You control which pets are listed and their prices.'),
            _BulletItem("No listing fees while we're onboarding early shops."),
            _BulletItem(
              "Buyers already know pickup and payment happen in person, so there's nothing to ship.",
            ),
            const SizedBox(height: 28),
            _Field(
              label: 'Shop name',
              child: TextFormField(
                controller: _shopNameController,
                textInputAction: TextInputAction.next,
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "Enter your shop's name."
                    : null,
              ),
            ),
            _Field(
              label: 'Your name',
              child: TextFormField(
                controller: _contactNameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name.'
                    : null,
              ),
            ),
            _Field(
              label: 'Email',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter your email address.';
                  if (!_emailPattern.hasMatch(trimmed)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ),
            _Field(
              label: 'Phone',
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter your phone number.';
                  if (!_phonePattern.hasMatch(trimmed)) {
                    return 'Enter a valid phone number.';
                  }
                  return null;
                },
              ),
            ),
            _Field(
              label: 'City',
              child: TextFormField(
                controller: _cityController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.addressCity],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your city.'
                    : null,
              ),
            ),
            _Field(
              label: 'License number',
              optional: true,
              child: TextFormField(
                controller: _licenseController,
                textInputAction: TextInputAction.next,
              ),
            ),
            _Field(
              label: 'Message',
              optional: true,
              child: TextFormField(
                controller: _messageController,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                child: const Text('Send application'),
              ),
            ),
          ],
        ),
      ),
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
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: AppColors.inkSoft,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTheme.body(color: AppColors.inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final bool optional;
  final Widget child;
  const _Field({
    required this.label,
    required this.child,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: AppTheme.body(fontWeight: FontWeight.w600, fontSize: 14),
              children: [
                TextSpan(text: label),
                if (optional)
                  TextSpan(
                    text: '  (optional)',
                    style: AppTheme.body(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
