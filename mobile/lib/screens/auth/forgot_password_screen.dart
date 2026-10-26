import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../state/auth_provider.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/ui_kit.dart';
import 'auth_widgets.dart';

/// "Forgot password?": asks for an email address and sends a reset link that
/// opens the app (see AppEnv.authRedirect). The wording never reveals whether
/// an account exists for the address.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  static const _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _prefilled = false;
  bool _submitting = false;
  String _formError = '';

  /// The address the link was requested for; non-null once a request went out.
  String? _sentTo;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled) return;
    _prefilled = true;
    // The log in screen passes whatever the user already typed.
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is String && AuthValidators.email(extra) == null) {
        _emailController.text = extra.trim();
      }
    } catch (_) {
      // Not inside a route builder (previews): start with an empty field.
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
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

  Future<void> _handleSubmit() async {
    if (_submitting || _cooldown > 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _formError = '');
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider).resetPassword(email);
      if (!mounted) return;
      setState(() => _sentTo = email);
      _startCooldown();
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = friendlyError(error, fallback: "Couldn't send the reset link. Please try again."));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return RoleShell(
      title: 'Reset password',
      child: AuthPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeading(
              title: 'Forgot your password?',
              subtitle: sentTo == null
                  ? "Enter the email address you signed up with and we'll send you a link to choose a new password."
                  : null,
            ),
            const SizedBox(height: 20),
            if (sentTo != null) ...[
              SuccessPanel(
                title: 'Check your email',
                message: "If an account exists for $sentTo, we've emailed a reset link. "
                    "It can take a minute to arrive, so check your spam folder too. The link opens PETSTA on this device.",
              ),
              const SizedBox(height: 20),
            ],
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: AutofillGroup(
                child: AuthTextField(
                  controller: _emailController,
                  label: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  inputFormatters: noSpaceFormatters,
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _handleSubmit(),
                  validator: AuthValidators.email,
                ),
              ),
            ),
            AuthErrorText(_formError),
            LoadingButton(
              label: sentTo == null
                  ? 'Send reset link'
                  : (_cooldown > 0 ? 'Send again in ${_cooldown}s' : 'Send the link again'),
              expand: true,
              loading: _submitting,
              onPressed: _cooldown > 0 ? null : _handleSubmit,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Back to log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
