import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import 'shared_widgets.dart';

/// Shared building blocks for the account / services / health / seller
/// screens (the Flutter counterparts of Modal, Field, StatusBadge and
/// LoginPrompt in src/components/ui).

/// Human-readable message for any thrown error (Postgrest/Auth exceptions
/// expose their server message; everything else is stringified).
String errorText(Object error) {
  if (error is PostgrestException) return error.message;
  if (error is AuthException) return error.message;
  final text = error.toString();
  return text.startsWith('Exception: ') ? text.substring('Exception: '.length) : text;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Yes/No confirmation. Resolves to true only when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title, style: AppTheme.display(fontSize: 18)),
      content: Text(message, style: AppTheme.body(color: AppColors.inkSoft)),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(cancelLabel)),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(foregroundColor: destructive ? AppColors.error : AppColors.primary),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Bottom-sheet "modal" used for booking / request / edit forms. The
/// [builder] content is scrollable and lifts above the keyboard. Pop the
/// sheet with `Navigator.of(sheetContext).pop(result)`.
Future<T?> showFormSheet<T>(
  BuildContext context, {
  required String title,
  String? description,
  required Widget Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: DraggableScrollableSheetBody(
          title: title,
          description: description,
          child: builder(sheetContext),
        ),
      );
    },
  );
}

class DraggableScrollableSheetBody extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  const DraggableScrollableSheetBody({super.key, required this.title, this.description, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.display(fontSize: 18)),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(description!, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: child,
          ),
        ),
      ],
    );
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'approved':
    case 'confirmed':
    case 'accepted':
    case 'completed':
    case 'resolved':
    case 'paid':
    case 'fulfilled':
    case 'available':
      return AppColors.trust;
    case 'rejected':
    case 'declined':
    case 'cancelled':
    case 'suspended':
      return AppColors.error;
    case 'open':
    case 'quoted':
    case 'in_progress':
      return AppColors.primary;
    case 'pending':
    case 'reserved':
      return const Color(0xFFB45309); // amber-700, readable on white
    default:
      return AppColors.inkSoft; // closed, sold, unknown
  }
}

/// Coloured pill for any status string. [label] overrides the text.
class StatusBadge extends StatelessWidget {
  final String status;
  final String? label;
  const StatusBadge({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    return StatusPill(status: label ?? status, color: statusColor(status));
  }
}

/// "Log in to continue" card shown in place of a form/list for signed-out
/// visitors. After signing in the user is returned to the current screen.
class LoginPromptCard extends StatelessWidget {
  final String title;
  final String? description;
  final bool compact;

  const LoginPromptCard({
    super.key,
    this.title = 'Log in to continue',
    this.description,
    this.compact = false,
  });

  String _loginLocation(BuildContext context) {
    try {
      final here = GoRouter.of(context).routeInformationProvider.value.uri.toString();
      if (here.isEmpty || here == '/login' || here == '/signup') return '/login';
      return '/login?from=${Uri.encodeComponent(here)}';
    } catch (_) {
      return '/login';
    }
  }

  /// When shown inside a bottom sheet, close the sheet first so it doesn't
  /// linger on the navigator under the login screen.
  void _open(BuildContext context, String location) {
    final router = GoRouter.of(context);
    if (ModalRoute.of(context) is PopupRoute) Navigator.of(context).pop();
    router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppTheme.display(fontSize: compact ? 16 : 18), textAlign: TextAlign.center),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!, style: AppTheme.body(color: AppColors.inkSoft), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(onPressed: () => _open(context, _loginLocation(context)), child: const Text('Log in')),
              OutlinedButton(onPressed: () => _open(context, '/signup'), child: const Text('Sign up')),
            ],
          ),
        ],
      ),
    );
  }
}

class FilterOption<T> {
  final T value;
  final String label;
  final int? count;
  const FilterOption(this.value, this.label, {this.count});
}

/// Horizontally scrolling single-select chip row (the "filter chips" used on
/// demo / refund / booking lists).
class FilterChipBar<T> extends StatelessWidget {
  final List<FilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  const FilterChipBar({super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(option.count == null ? option.label : '${option.label} (${option.count})'),
                selected: option.value == selected,
                onSelected: (_) => onSelected(option.value),
                selectedColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: AppTheme.body(
                  fontSize: 13,
                  fontWeight: option.value == selected ? FontWeight.w600 : FontWeight.w400,
                  color: option.value == selected ? AppColors.primary : AppColors.ink,
                ),
                side: BorderSide(color: option.value == selected ? AppColors.primary : AppColors.border),
                backgroundColor: AppColors.surface,
                showCheckmark: false,
              ),
            ),
        ],
      ),
    );
  }
}

/// ElevatedButton / OutlinedButton that shows a spinner and ignores taps
/// while [loading], to prevent double submits.
class LoadingButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final bool expand;

  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? AppColors.primary : Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );
    final handler = loading ? null : onPressed;
    final button = outlined
        ? OutlinedButton(onPressed: handler, child: child)
        : ElevatedButton(onPressed: handler, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Green confirmation panel shown after a successful submit.
class SuccessPanel extends StatelessWidget {
  final String title;
  final String message;
  final List<Widget> actions;

  const SuccessPanel({super.key, required this.title, required this.message, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.trust.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.trust.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.trust, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: AppTheme.display(fontSize: 17))),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppTheme.body(color: AppColors.inkSoft)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Inline notice (info / warning / error) used for "awaiting approval" and
/// privacy hints.
class NoticeBox extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;

  const NoticeBox({super.key, required this.message, this.color = AppColors.primary, this.icon = Icons.info_outline});

  const NoticeBox.warning({super.key, required this.message})
      : color = const Color(0xFFB45309),
        icon = Icons.warning_amber_rounded;

  const NoticeBox.error({super.key, required this.message})
      : color = AppColors.error,
        icon = Icons.error_outline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTheme.body(fontSize: 13.5, color: AppColors.ink))),
        ],
      ),
    );
  }
}

/// Label/value line used in detail cards.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft))),
          Expanded(child: Text(value, style: AppTheme.body(fontSize: 14))),
        ],
      ),
    );
  }
}

/// White rounded container used for list cards.
class CardBox extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
