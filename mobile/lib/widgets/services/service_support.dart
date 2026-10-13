import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/columns.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../ui_kit.dart';

/// Shared helpers for the services / health widgets. Mirrors the web's
/// src/components/services/{serviceCategories.js, useBookingAccess.js,
/// useApprovedServices.js, AccessNotice.jsx, ListState.jsx}.

/// Who is looking at a booking / request form. Only signed-in customers can
/// book; signed-out visitors get a login prompt and other roles a short note.
class ServiceAccess {
  final bool loading;
  final String? userId;
  final String? role;

  const ServiceAccess({required this.loading, this.userId, this.role});

  factory ServiceAccess.from(AuthController auth) {
    final profile = auth.status == AuthStatus.signedIn ? auth.profile : null;
    return ServiceAccess(
      loading: auth.status == AuthStatus.loading,
      userId: profile?.id,
      role: profile?.role,
    );
  }

  bool get signedIn => userId != null;
  bool get canBook => userId != null && role == 'customer';
  String get roleLabel => (role ?? '').replaceAll('_', ' ');
}

/// Label, icon and hint for a `service_bookings.delivery_mode`.
class DeliveryModeInfo {
  final String label;
  final IconData icon;
  final String hint;
  const DeliveryModeInfo(this.label, this.icon, this.hint);
}

const deliveryModes = <String, DeliveryModeInfo>{
  'in_person': DeliveryModeInfo(
    'In person',
    Icons.storefront_outlined,
    'The shop will confirm the details with you once it accepts your booking.',
  ),
  'video': DeliveryModeInfo(
    'Video call',
    Icons.videocam_outlined,
    'The clinic adds a video link to your booking once it confirms the slot.',
  ),
  'phone': DeliveryModeInfo(
    'Phone call',
    Icons.phone_outlined,
    'The clinic will phone you on the number saved in your account.',
  ),
};

DeliveryModeInfo deliveryModeFor(String? key) => deliveryModes[key] ?? deliveryModes['in_person']!;

/// Only vet services can be delivered remotely.
List<String> modesForCategory(String category) =>
    category == 'vet' ? const ['in_person', 'video', 'phone'] : const ['in_person'];

const petSpeciesOptions = <String>['Dog', 'Cat', 'Bird', 'Rabbit', 'Small pet', 'Other'];

/// 09:00 through 18:00 in 30 minute steps, as 'HH:mm'.
final List<String> bookingTimeSlots = List<String>.generate(19, (index) {
  final minutes = 9 * 60 + index * 30;
  final hours = (minutes ~/ 60).toString().padLeft(2, '0');
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}';
});

DateTime todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime tomorrowDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

/// Video links are typed in by the clinic; only ever open http(s) URLs.
Uri? safeExternalUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  return uri;
}

Future<void> openVideoLink(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    showSnack(context, "Couldn't open the video link. Try again, or ask the clinic to resend it.", error: true);
  }
}

// Customer-facing: the shop embed is name-only, never address / phone / city.
const _approvedServiceColumns = '$servicePublicColumns, shops(name)';

/// Approved services (RLS already hides the rest), optionally for one category.
Future<List<ServiceItem>> fetchApprovedServices({String? category}) async {
  var query = SupabaseService.client.from('services').select(_approvedServiceColumns).eq('status', 'approved');
  if (category != null) query = query.eq('category', category);
  final rows = await query.order('category', ascending: true).order('name', ascending: true);
  return rows.map(ServiceItem.fromJson).toList();
}

/// Shown in place of a booking / request form when the visitor can't submit
/// it: still checking their account, signed out, or signed in as a seller or
/// admin. Mirrors AccessNotice.jsx.
class ServiceAccessNotice extends StatelessWidget {
  final ServiceAccess access;
  final String action;

  const ServiceAccessNotice({super.key, required this.access, this.action = 'book this service'});

  @override
  Widget build(BuildContext context) {
    if (access.loading) {
      return Text('Checking your account…', style: AppTheme.body(color: AppColors.inkSoft));
    }
    if (!access.signedIn) {
      return LoginPromptCard(
        compact: true,
        title: 'Log in to continue',
        description: 'You need a customer account to $action.',
      );
    }
    final role = access.roleLabel;
    final suffix = role.isEmpty ? '' : ' Your account type is $role.';
    return NoticeBox(message: 'Only customer accounts can $action.$suffix');
  }
}

/// Small label above a form field, with an "(optional)" hint.
class SheetFieldLabel extends StatelessWidget {
  final String label;
  final bool optional;

  const SheetFieldLabel(this.label, {super.key, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: label,
          style: AppTheme.body(fontSize: 13, color: AppColors.ink),
          children: optional
              ? [TextSpan(text: ' (optional)', style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft))]
              : null,
        ),
      ),
    );
  }
}

/// Inline error with a retry link (the list-level counterpart of ListState.jsx's
/// error notice). A failed refresh keeps the stale rows and shows this above them.
class InlineErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorNotice({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTheme.body(fontSize: 13.5, color: AppColors.error)),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Try again'),
            ),
        ],
      ),
    );
  }
}

/// "Nothing here yet" box used inside page sections.
class SectionEmptyBox extends StatelessWidget {
  final String message;
  const SectionEmptyBox(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
      ),
    );
  }
}

/// "Pet: Bruno (Dog). Concern: limping since yesterday." Either part may be
/// missing; null when both are. Mirrors composeConsultNotes in BookingModal.jsx.
String? composeConsultNotes({required String petName, String? petSpecies, required String concern}) {
  final name = petName.trim();
  final species = petSpecies ?? '';
  final pet = name.isNotEmpty && species.isNotEmpty ? '$name ($species)' : (name.isNotEmpty ? name : species);
  final parts = <String>[];
  if (pet.isNotEmpty) parts.add('Pet: $pet.');
  if (concern.trim().isNotEmpty) parts.add('Concern: ${concern.trim()}');
  return parts.isEmpty ? null : parts.join(' ');
}
