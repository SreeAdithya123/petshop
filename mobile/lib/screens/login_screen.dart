import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../core/app_error.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/ui_kit.dart';
import 'auth/auth_widgets.dart';

/// Mirrors src/pages/Login.jsx.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _resending = false;
  bool _needsConfirmation = false;
  String _formError = '';
  String _notice = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _formError = '';
      _notice = '';
      _needsConfirmation = false;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    final auth = ref.read(authControllerProvider);
    // Resolved before the await: the context must not be used after it.
    final router = GoRouter.of(context);
    final from = safeReturnPath(GoRouterState.of(context).uri.queryParameters['from']);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await auth.signIn(email: _emailController.text.trim(), password: _passwordController.text);
      // Let the system offer to save the credentials.
      TextInput.finishAutofillContext();
      final profile = auth.profile;
      if (profile == null) {
        // The credentials worked but the profile couldn't be loaded yet (no
        // connection). The session is kept and loading is retried.
        router.go(from ?? '/');
        messenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text("You're logged in. We're still loading your account."),
              behavior: SnackBarBehavior.floating,
            ),
          );
        return;
      }
      // Come back to where the visitor was (see LoginPromptCard) when they're
      // a customer; shop owners/admins go to their own dashboard.
      if (from != null && profile.role == 'customer') {
        router.go(from);
      } else {
        router.go(postLoginPath(profile.role));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = friendlyError(error, fallback: "Couldn't log you in. Check your details and try again.");
        _needsConfirmation = _isUnconfirmedEmail(error);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  bool _isUnconfirmedEmail(Object error) {
    final cause = error is UserFacingException ? error.cause : error;
    return cause is AuthException && (cause.code == 'email_not_confirmed' || cause.message.toLowerCase().contains('email not confirmed'));
  }

  Future<void> _resendConfirmation() async {
    if (_resending) return;
    final email = _emailController.text.trim();
    if (AuthValidators.email(email) != null) {
      setState(() => _formError = 'Enter your email address first.');
      return;
    }
    setState(() {
      _resending = true;
      _formError = '';
      _notice = '';
    });
    try {
      await ref.read(authControllerProvider).resendConfirmation(email);
      if (!mounted) return;
      setState(() {
        _notice = 'We sent a new confirmation email. Check your inbox (and spam folder).';
        _needsConfirmation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = friendlyError(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Log in',
      child: AuthPage(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeading(title: 'Log in'),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('New to PETSTA?', style: AppTheme.body(color: AppColors.inkSoft)),
                    TextButton(
                      onPressed: _submitting ? null : () => context.push('/signup'),
                      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                      child: Text(
                        'Create an account',
                        style: AppTheme.body(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _emailController,
                  label: 'Email address',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  autocorrect: false,
                  inputFormatters: noSpaceFormatters,
                  enabled: !_submitting,
                  validator: AuthValidators.email,
                ),
                PasswordField(
                  controller: _passwordController,
                  enabled: !_submitting,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _handleSubmit(),
                  validator: (value) => (value == null || value.isEmpty) ? 'Enter your password.' : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => context.push('/forgot-password', extra: _emailController.text.trim()),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 4),
                AuthErrorText(_formError),
                if (_needsConfirmation)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LoadingButton(
                      label: 'Resend confirmation email',
                      outlined: true,
                      loading: _resending,
                      onPressed: _resendConfirmation,
                    ),
                  ),
                if (_notice.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: NoticeBox(message: _notice),
                  ),
                if (_needsConfirmation) const SizedBox(height: 12),
                LoadingButton(
                  label: 'Log in',
                  expand: true,
                  loading: _submitting,
                  onPressed: _handleSubmit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
