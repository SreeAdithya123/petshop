import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';

/// Small helpers shared by the "My account" screens (the Flutter counterparts
/// of AccountPage.jsx and accountHelpers.js on the web).

const _orderTypeLabels = {
  'pet_reservation': 'Pet reservation',
  'gift': 'Gift',
  'product_purchase': 'Product purchase',
  'service_booking': 'Service booking',
  'event_ticket': 'Event ticket',
  'insurance_purchase': 'Insurance purchase',
  'wallet_topup': 'Wallet top-up',
};

String orderTypeLabel(String type) => _orderTypeLabels[type] ?? titleCase(type);

/// Orders in these states can still have a refund requested against them.
const _refundableOrderStatuses = ['pending', 'paid', 'fulfilled'];

bool isRefundableStatus(String status) => _refundableOrderStatuses.contains(status);

/// "#1A2B3C4D" -- the first block of the order uuid, upper-cased like the web.
String orderRef(String id) => shortId(id).toUpperCase();

/// Returns the link only when it is a plain http(s) URL, so stored text can
/// never turn into some other kind of link.
Uri? safeExternalUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.host.isEmpty) return null;
  return (uri.scheme == 'https' || uri.scheme == 'http') ? uri : null;
}

/// Opens [uri] in the browser / matching app, telling the user if it can't.
Future<void> openExternalUri(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showSnack(context, "Couldn't open that link.", error: true);
  }
}

// Server rows are parsed defensively: optional columns may be missing or null.
num asNum(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

DateTime? asDate(Object? value) {
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

/// Section heading ("Orders", "Your details", ...).
class SectionTitle extends StatelessWidget {
  final String title;
  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTheme.display(fontSize: 20, fontWeight: FontWeight.w600));
  }
}

/// Inline "Loading..." line for data that loads inside an account screen.
class AccountLoadingNote extends StatelessWidget {
  final String label;
  const AccountLoadingNote({super.key, this.label = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(label, style: AppTheme.body(color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

/// Load failure with the server's message and an optional retry
/// (the ErrorNote of AccountPage.jsx).
class AccountErrorNote extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AccountErrorNote({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoticeBox.error(message: message),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}

/// Section heading with a small refresh button on the right. Stands in for
/// pull-to-refresh, which AccountScaffold's scrolling body can't host.
class RefreshHeading extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final Widget? trailing;
  const RefreshHeading({super.key, required this.title, this.onRefresh, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        if (trailing != null) ...[trailing!, const SizedBox(width: 4)],
        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 22, color: AppColors.inkSoft),
          ),
      ],
    );
  }
}

/// Label shown above an input; [optional] adds the "(optional)" tag.
class FormLabel extends StatelessWidget {
  final String label;
  final bool optional;
  const FormLabel(this.label, {super.key, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: label,
          style: AppTheme.body(fontSize: 13.5, fontWeight: FontWeight.w600),
          children: [
            if (optional)
              TextSpan(
                text: '  (optional)',
                style: AppTheme.body(fontSize: 12.5, color: AppColors.inkSoft),
              ),
          ],
        ),
      ),
    );
  }
}

/// Drop-down styled like the app's text fields. A controlled [DropdownButton]
/// inside an [InputDecorator], so the shown value always follows [value]
/// (including resets after a submit).
class DropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String hint;
  final String? errorText;
  final List<Widget> Function(BuildContext context)? selectedItemBuilder;
  final double? itemHeight;

  const DropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    this.errorText,
    this.selectedItemBuilder,
    this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: AppTheme.body(color: AppColors.inkSoft)),
          items: items,
          onChanged: onChanged,
          selectedItemBuilder: selectedItemBuilder,
          itemHeight: itemHeight ?? kMinInteractiveDimension,
          style: AppTheme.body(),
          borderRadius: BorderRadius.circular(12),
          dropdownColor: AppColors.surface,
        ),
      ),
    );
  }
}
