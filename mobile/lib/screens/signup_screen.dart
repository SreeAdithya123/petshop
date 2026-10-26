import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_error.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/ui_kit.dart';
import 'auth/auth_widgets.dart';

/// Mirrors src/pages/SignUp.jsx.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  static const _resendCooldownSeconds = 45;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _role = 'customer';
  bool _submitting = false;
  String _formError = '';

  /// Email the confirmation link was sent to; non-null once sign-up succeeded
  /// and the account is waiting for email confirmation.
  String? _confirmEmail;
  bool _resending = false;
  String _resendMessage = '';
  bool _resendFailed = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = '');
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final auth = ref.read(authControllerProvider);
    final router = GoRouter.of(context);
    final email = _emailController.text.trim();
    try {
      final needsEmailConfirmation = await auth.signUp(
        name: _nameController.text.trim(),
        email: email,
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: _role,
      );

      if (!mounted) return;
      TextInput.finishAutofillContext();

      if (needsEmailConfirmation) {
        setState(() => _confirmEmail = email);
        _startCooldown();
        return;
      }
      router.go(auth.profile != null ? roleHomePath(auth.profile!.role) : '/');
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = friendlyError(error, fallback: 'Something went wrong creating your account.'));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    final email = _confirmEmail;
    if (email == null || _resending || _cooldown > 0) return;
    setState(() {
      _resending = true;
      _resendMessage = '';
      _resendFailed = false;
    });
    try {
      await ref.read(authControllerProvider).resendConfirmation(email);
      if (!mounted) return;
      setState(() => _resendMessage = 'We sent the email again. It can take a minute to arrive.');
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resendMessage = friendlyError(error);
        _resendFailed = true;
      });
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Sign up',
      child: AuthPage(
        child: _confirmEmail != null ? _buildConfirmation(context, _confirmEmail!) : _buildForm(context),
      ),
    );
  }

  Widget _buildConfirmation(BuildContext context, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeading(title: 'Check your email'),
        const SizedBox(height: 16),
        SuccessPanel(
          title: 'Almost there',
          message: 'We sent a confirmation link to $email. Open it to confirm your address, then log in to continue. '
              "If you can't find it, check your spam folder.",
        ),
        const SizedBox(height: 20),
        LoadingButton(
          label: 'Go to log in',
          expand: true,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: 12),
        LoadingButton(
          label: _cooldown > 0 ? 'Resend email in ${_cooldown}s' : 'Resend confirmation email',
          outlined: true,
          expand: true,
          loading: _resending,
          onPressed: _cooldown > 0 ? null : _resend,
        ),
        if (_resendMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          _resendFailed ? NoticeBox.error(message: _resendMessage) : NoticeBox(message: _resendMessage),
        ],
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => setState(() {
            _confirmEmail = null;
            _resendMessage = '';
            _cooldownTimer?.cancel();
            _cooldown = 0;
          }),
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Wrong email address? Go back'),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading(title: 'Create your account'),
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Already have an account?', style: AppTheme.body(color: AppColors.inkSoft)),
                TextButton(
                  onPressed: _submitting ? null : () => context.push('/login'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: Text(
                    'Log in',
                    style: AppTheme.body(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthTextField(
              controller: _nameController,
              label: 'Full name',
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              enabled: !_submitting,
              maxLength: 80,
              validator: AuthValidators.name,
            ),
            AuthTextField(
              controller: _emailController,
              label: 'Email address',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              inputFormatters: noSpaceFormatters,
              enabled: !_submitting,
              validator: AuthValidators.email,
            ),
            AuthTextField(
              controller: _phoneController,
              label: 'Phone number',
              hint: '+91 98765 43210',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\s+().-]'))],
              maxLength: 20,
              enabled: !_submitting,
              validator: AuthValidators.phone,
            ),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              helperText: 'At least 8 characters, with a letter and a number.',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_submitting,
              validator: AuthValidators.newPassword,
            ),
            PasswordField(
              controller: _confirmController,
              label: 'Confirm password',
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_submitting,
              onFieldSubmitted: (_) => _handleSubmit(),
              validator: AuthValidators.confirmPassword(_passwordController),
            ),
            _buildRoleChoice(),
            const SizedBox(height: kAuthFieldGap),
            FormField<bool>(
              initialValue: false,
              validator: (value) => value == true ? null : 'Please agree to the Terms and Privacy Policy to continue.',
              builder: (field) => _buildTermsAgreement(field),
            ),
            const SizedBox(height: 8),
            AuthErrorText(_formError),
            LoadingButton(
              label: 'Create account',
              expand: true,
              loading: _submitting,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChoice() {
    final isOwner = _role == 'shop_owner';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('I am a', style: AppTheme.body(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Customer'),
              selected: !isOwner,
              onSelected: _submitting ? null : (_) => setState(() => _role = 'customer'),
            ),
            ChoiceChip(
              label: const Text('Shop owner'),
              selected: isOwner,
              onSelected: _submitting ? null : (_) => setState(() => _role = 'shop_owner'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isOwner
              ? 'List your pets, products and services. Your shop is reviewed and approved before it goes live.'
              : 'Browse and reserve pets, buy supplies and book services and vet video consults.',
          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
        ),
      ],
    );
  }

  Widget _buildTermsAgreement(FormFieldState<bool> field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          value: field.value ?? false,
          onChanged: _submitting ? null : field.didChange,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('I agree to the Terms and Privacy Policy', style: AppTheme.body(fontSize: 14)),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: () => context.push('/legal/terms'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Read the Terms'),
            ),
            TextButton(
              onPressed: () => context.push('/legal/privacy'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Read the Privacy Policy'),
            ),
          ],
        ),
        if (field.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(field.errorText!, style: AppTheme.body(fontSize: 12.5, color: AppColors.error)),
            ),
          ),
      ],
    );
  }
}
