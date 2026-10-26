import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../state/auth_provider.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/ui_kit.dart';
import 'auth_widgets.dart';

/// Where the password-reset email lands (via the deep link
/// `io.supabase.petsta://reset-callback/`). Once supabase_flutter has turned
/// the link into a recovery session the user picks a new password here.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  /// How long to wait for the emailed link to be exchanged for a session
  /// before declaring it invalid or expired.
  static const _linkTimeout = Duration(seconds: 12);

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  Timer? _linkTimer;
  bool _linkTimedOut = false;
  bool _submitting = false;
  bool _done = false;
  String _formError = '';

  @override
  void initState() {
    super.initState();
    _linkTimer = Timer(_linkTimeout, () {
      if (mounted) setState(() => _linkTimedOut = true);
    });
  }

  @override
  void dispose() {
    _linkTimer?.cancel();
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
    try {
      await auth.updatePassword(_passwordController.text);
      if (!mounted) return;
      TextInput.finishAutofillContext();
      setState(() => _done = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = friendlyError(error, fallback: "Couldn't update your password. Please try again."));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _continue() {
    final role = ref.read(authControllerProvider).profile?.role;
    context.go(role == null ? '/' : roleHomePath(role));
  }

  /// Abandons the recovery: the temporary session is signed out so nobody is
  /// left logged in without having chosen a password.
  Future<void> _cancel() async {
    final router = GoRouter.of(context);
    final auth = ref.read(authControllerProvider);
    if (auth.passwordRecovery) await auth.signOut();
    router.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final ready = auth.passwordRecovery || auth.session != null;

    final Widget body;
    if (_done) {
      body = _buildDone();
    } else if (ready) {
      body = _buildForm();
    } else if (auth.linkError != null || _linkTimedOut) {
      body = _buildInvalidLink(auth.linkError);
    } else {
      body = _buildChecking();
    }

    return RoleShell(
      title: 'Reset password',
      child: AuthPage(child: body),
    );
  }

  Widget _buildChecking() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Semantics(
        liveRegion: true,
        label: 'Checking your reset link',
        child: const ExcludeSemantics(
          child: Column(
            children: [
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(height: 16),
              Text('Checking your reset link…', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvalidLink(String? reason) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeading(title: 'This link has expired'),
        const SizedBox(height: 16),
        NoticeBox.warning(
          message: reason ??
              'The reset link is invalid, has expired or was already used. Reset links also only work on the device '
                  'that requested them.',
        ),
        const SizedBox(height: 20),
        LoadingButton(
          label: 'Request a new link',
          expand: true,
          onPressed: () => context.go('/forgot-password'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go('/login'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Back to log in'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthHeading(
              title: 'Choose a new password',
              subtitle: "Pick something you haven't used on PETSTA before.",
            ),
            const SizedBox(height: 20),
            PasswordField(
              controller: _passwordController,
              label: 'New password',
              helperText: 'At least 8 characters, with a letter and a number.',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_submitting,
              validator: AuthValidators.newPassword,
            ),
            PasswordField(
              controller: _confirmController,
              label: 'Confirm new password',
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_submitting,
              onFieldSubmitted: (_) => _handleSubmit(),
              validator: AuthValidators.confirmPassword(_passwordController),
            ),
            AuthErrorText(_formError),
            LoadingButton(
              label: 'Update password',
              expand: true,
              loading: _submitting,
              onPressed: _handleSubmit,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _submitting ? null : _cancel,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthHeading(title: 'Password updated'),
        const SizedBox(height: 16),
        const SuccessPanel(
          title: 'All set',
          message: 'Your password has been changed. You can keep using PETSTA right away.',
        ),
        const SizedBox(height: 20),
        LoadingButton(label: 'Continue', expand: true, onPressed: _continue),
      ],
    );
  }
}
