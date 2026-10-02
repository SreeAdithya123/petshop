import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

/// Mirrors src/pages/SignUp.jsx.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _loginLinkRecognizer;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _phonePattern = RegExp(r'^[\d\s()+-]{7,}$');

  String _role = 'customer';
  bool _submitting = false;
  String _formError = '';
  bool _needsEmailConfirmation = false;

  @override
  void initState() {
    super.initState();
    _loginLinkRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/login');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _loginLinkRecognizer.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _formError = '');
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _submitting = true);
    try {
      final needsEmailConfirmation = await ref
          .read(authControllerProvider)
          .signUp(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            role: _role,
          );

      if (!mounted) return;

      if (needsEmailConfirmation) {
        setState(() => _needsEmailConfirmation = true);
        return;
      }

      final profile = ref.read(authControllerProvider).profile;
      context.go(roleHomePath(profile?.role ?? _role));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error is AuthException && error.message.isNotEmpty
            ? error.message
            : 'Something went wrong creating your account.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Sign up',
      child: _needsEmailConfirmation
          ? _buildConfirmation(context)
          : _buildForm(context),
    );
  }

  Widget _buildConfirmation(BuildContext context) {
    return SingleChildScrollView(
      padding: kScreenPadding,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Check your email',
              style: AppTheme.display(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                style: AppTheme.body(color: AppColors.inkSoft),
                children: [
                  const TextSpan(text: 'We sent a confirmation link to '),
                  TextSpan(
                    text: _emailController.text.trim(),
                    style: AppTheme.body(color: AppColors.ink),
                  ),
                  const TextSpan(
                    text: '. Confirm your address, then log in to continue.',
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('Go to login'),
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
              'Create your account',
              style: AppTheme.display(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: AppTheme.body(color: AppColors.inkSoft),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: AppTheme.body(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    recognizer: _loginLinkRecognizer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _Field(
              label: 'Full name',
              child: TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter your name.'
                    : null,
              ),
            ),
            _Field(
              label: 'Email address',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter an email address.';
                  if (!_emailPattern.hasMatch(trimmed)) {
                    return 'Enter a valid email address.';
                  }
                  return null;
                },
              ),
            ),
            _Field(
              label: 'Phone number',
              child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Enter a phone number.';
                  if (!_phonePattern.hasMatch(trimmed)) {
                    return 'Enter a valid phone number.';
                  }
                  return null;
                },
              ),
            ),
            _Field(
              label: 'Password',
              child: TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) {
                  final v = value ?? '';
                  if (v.isEmpty) return 'Create a password.';
                  if (v.length < 6) {
                    return 'Password must be at least 6 characters.';
                  }
                  return null;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I am a',
                    style: AppTheme.body(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    items: const [
                      DropdownMenuItem(
                        value: 'customer',
                        child: Text('Customer'),
                      ),
                      DropdownMenuItem(
                        value: 'shop_owner',
                        child: Text('Shop Owner'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _role = value);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Demo/testing only — a real deployment shouldn't let anyone self-register as Admin.",
                    style: AppTheme.body(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (_formError.isNotEmpty) ...[
              Text(
                _formError,
                style: AppTheme.body(fontSize: 14, color: AppColors.error),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _handleSubmit,
                child: Text(
                  _submitting ? 'Creating account…' : 'Create account',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.body(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
