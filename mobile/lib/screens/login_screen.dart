import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/role_shell.dart';
import '../widgets/shared_widgets.dart';

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
  late final TapGestureRecognizer _signUpLinkRecognizer;

  bool _submitting = false;
  String _formError = '';

  @override
  void initState() {
    super.initState();
    _signUpLinkRecognizer = TapGestureRecognizer()
      ..onTap = () => context.push('/signup');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signUpLinkRecognizer.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() => _formError = '');
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(authControllerProvider)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted) return;
      final profile = ref.read(authControllerProvider).profile;
      context.go(roleHomePath(profile?.role));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error is AuthException && error.message.isNotEmpty
            ? error.message
            : "Couldn't log you in. Check your details and try again.";
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: 'Log in',
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Log in',
                style: AppTheme.display(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  style: AppTheme.body(color: AppColors.inkSoft),
                  children: [
                    const TextSpan(text: 'New to PETSTA? '),
                    TextSpan(
                      text: 'Create an account',
                      style: AppTheme.body(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      recognizer: _signUpLinkRecognizer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _Field(
                label: 'Email address',
                child: TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your email address.'
                      : null,
                ),
              ),
              _Field(
                label: 'Password',
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _handleSubmit(),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Enter your password.'
                      : null,
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
                  child: Text(_submitting ? 'Logging in…' : 'Log in'),
                ),
              ),
            ],
          ),
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
