import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/content_width.dart';
import '../../widgets/shared_widgets.dart';

/// Building blocks shared by the log in / sign up / forgot password / reset
/// password screens.

/// Scrollable, keyboard-friendly page body for a single form, capped at a
/// comfortable width on tablets.
class AuthPage extends StatelessWidget {
  final Widget child;
  const AuthPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: kScreenPadding,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ContentWidth(maxWidth: 480, child: child),
    );
  }
}

/// Page heading plus an optional supporting line.
class AuthHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const AuthHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: AppTheme.body(color: AppColors.inkSoft)),
        ],
      ],
    );
  }
}

/// Space below a form field.
const double kAuthFieldGap = 16;

/// A labelled single-line text field with the shared look and keyboard
/// behaviour of the auth forms.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final String? Function(String? value)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autocorrect;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.maxLength,
    this.autocorrect = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kAuthFieldGap),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        autocorrect: autocorrect,
        enableSuggestions: autocorrect,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        validator: validator,
        onFieldSubmitted: onFieldSubmitted,
        style: AppTheme.body(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          counterText: '',
        ),
      ),
    );
  }
}

/// Password field with a show / hide toggle.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String? value)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.helperText,
    this.textInputAction = TextInputAction.done,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kAuthFieldGap),
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.visiblePassword,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        maxLength: 72,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        style: AppTheme.body(),
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helperText,
          helperMaxLines: 2,
          counterText: '',
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

/// Inline form-level error (server / network problems), announced to screen
/// readers when it appears.
class AuthErrorText extends StatelessWidget {
  final String message;
  const AuthErrorText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_outline, size: 18, color: AppColors.error),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: AppTheme.body(fontSize: 14, color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Validators shared by the forms. Each returns null when the value is fine.
class AuthValidators {
  AuthValidators._();

  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _phoneChars = RegExp(r'^\+?[\d\s().-]+$');

  static String? name(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your name.';
    if (v.length < 2) return 'Your name looks too short.';
    if (v.length > 80) return 'Please use 80 characters or fewer.';
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter your email address.';
    if (v.length > 254 || !_email.hasMatch(v)) return 'Enter a valid email address.';
    return null;
  }

  static String? phone(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Enter a phone number.';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (!_phoneChars.hasMatch(v) || digits.length < 7 || digits.length > 15) {
      return 'Enter a valid phone number, for example +91 98765 43210.';
    }
    return null;
  }

  /// New passwords (sign up, reset): 8+ characters with a letter and a number.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password.';
    if (v.length < 8) return 'Use at least 8 characters.';
    if (v.length > 72) return 'Use 72 characters or fewer.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number.';
    }
    return null;
  }

  static String? Function(String? value) confirmPassword(TextEditingController original) {
    return (value) {
      if ((value ?? '').isEmpty) return 'Re-enter your password.';
      if (value != original.text) return "Passwords don't match.";
      return null;
    };
  }
}

/// Keeps whitespace out of fields such as email.
final List<TextInputFormatter> noSpaceFormatters = [FilteringTextInputFormatter.deny(RegExp(r'\s'))];

/// The `?from=` return path of the log in flow, or null when it isn't a safe
/// in-app location. Only absolute in-app paths are followed, never `//host`,
/// and never back into the auth screens themselves.
String? safeReturnPath(String? from) {
  if (from == null) return null;
  final value = from.trim();
  if (!value.startsWith('/') || value.startsWith('//') || value.contains('\\')) return null;
  const blocked = ['/login', '/signup', '/forgot-password', '/reset-password'];
  final path = value.split('?').first;
  if (blocked.contains(path)) return null;
  return value;
}
