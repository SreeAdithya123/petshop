import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/async_utils.dart';
import '../../data/columns.dart';
import '../../models/service_models.dart';
import '../../services/supabase_service.dart';
import '../../state/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/video_room.dart';
import '../ui_kit.dart';

/// Shared helpers for the services / health widgets. Mirrors the web's
/// src/components/services/{serviceCategories.js, useBookingAccess.js,
/// useApprovedServices.js, AccessNotice.jsx, ListState.jsx}.

/// Shown when a guarded UPDATE changed no rows (RLS or a server trigger
/// refused it, usually because the status moved on in the meantime).
const kStatusChangedMessage = "That didn't go through — its status may have changed.";

/// Copy for confirmed video bookings whose link the clinic has not added yet.
const videoLinkSoonText = 'The clinic will add the video link shortly. Check back soon.';

/// Copy for bookings that will be a video call once confirmed.
const videoLinkAfterConfirmText = 'Once the clinic confirms, a Join video consult button appears here.';

/// What to expect when joining a video consult.
const videoExpectationText =
    "What to expect: join a few minutes early. If you're first in, you may need to wait for the clinic to join. "
    'Calls open in your browser, and Jitsi links need no app or account.';

/// How far ahead a slot can be booked.
const bookingAdvanceDays = 180;

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

/// [date] moved by [days] calendar days, still at local midnight (unlike
/// `date.add(Duration(days: n))`, which drifts by an hour across a DST change).
DateTime addDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

/// [value] limited to the range [first]..[last], so it is always a legal
/// `initialDate` for showDatePicker.
DateTime clampDate(DateTime value, DateTime first, DateTime last) {
  if (value.isBefore(first)) return first;
  if (value.isAfter(last)) return last;
  return value;
}

/// Scrolls the nearest Scrollable so [context]'s widget is on screen (instantly
/// when the system asks for reduced motion).
void scrollIntoView(BuildContext context) {
  final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  Scrollable.ensureVisible(
    context,
    duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
    curve: Curves.easeOut,
  );
}

/// [date] at the clock time [time] ('HH:mm' or 'HH:mm:ss'); null when [time]
/// isn't a clock time.
DateTime? slotDateTime(DateTime date, String time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
  if (match == null) return null;
  return DateTime(date.year, date.month, date.day, int.parse(match.group(1)!), int.parse(match.group(2)!));
}

/// True when the slot at [date] + [time] has already started.
bool isPastSlot(DateTime date, String time) {
  final slot = slotDateTime(date, time);
  return slot != null && !slot.isAfter(DateTime.now());
}

/// Video links are typed in by the clinic; only ever open http(s) URLs.
Uri? safeExternalUri(String? value) {
  if (!isSafeWebLink(value)) return null;
  return Uri.tryParse(value!.trim());
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
  final rows = await withTimeout(query.order('category', ascending: true).order('name', ascending: true));
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

/// Inline error with a Retry button (the list-level counterpart of
/// ListState.jsx's error notice). A failed refresh keeps the stale rows and
/// shows this above them.
class InlineErrorNotice extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorNotice({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.error_outline, size: 18, color: AppColors.error),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(message, style: AppTheme.body(fontSize: 13.5, color: AppColors.error))),
              ],
            ),
            if (onRetry != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    minimumSize: const Size(64, 48),
                    textStyle: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Nothing here yet" box used inside page sections.
class SectionEmptyBox extends StatelessWidget {
  final String message;
  final Widget? action;
  const SectionEmptyBox(this.message, {super.key, this.action});

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
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTheme.body(fontSize: 14, color: AppColors.inkSoft),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Numbered "what happens next" list shown on success panels.
class NextStepsList extends StatelessWidget {
  final String title;
  final List<String> steps;

  const NextStepsList({super.key, this.title = 'What happens next', required this.steps});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i], style: AppTheme.body(fontSize: 13.5, color: AppColors.inkSoft)),
                  ),
                ],
              ),
            ),
        ],
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
