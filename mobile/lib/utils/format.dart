import 'package:intl/intl.dart';

/// Mirrors src/lib/format.js. Prices are Indian rupees, whole-rupee, with
/// lakh/crore grouping (en_IN), e.g. 1,25,000.
final _priceFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _dateFormat = DateFormat('d MMM yyyy');
final _dateTimeFormat = DateFormat('d MMM, h:mm a');
final _paramFormat = DateFormat('yyyy-MM-dd');

String formatPrice(num value) => _priceFormat.format(value);

String formatOrderDate(DateTime value) => _dateFormat.format(value.toLocal());

String formatDate(DateTime value) => _dateFormat.format(value);

String formatDateTime(DateTime value) => _dateTimeFormat.format(value.toLocal());

/// Formats a Postgres `date` ("2026-10-05") or timestamp string as "5 Oct 2026".
/// Returns an empty string for null/unparseable input.
String formatDateString(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  // A bare date has no timezone; keep it as the calendar day it names.
  return raw.length <= 10 ? _dateFormat.format(parsed) : _dateFormat.format(parsed.toLocal());
}

/// "yyyy-MM-dd" for sending a date to a Postgres `date` column.
String toDateParam(DateTime value) => _paramFormat.format(value);

/// Formats a Postgres `time` ("14:30" or "14:30:00") as "2:30 PM".
/// Anything that isn't HH:MM[:SS] (e.g. "Morning") is returned unchanged.
String formatClock(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw);
  if (match == null) return raw;
  final hour = int.parse(match.group(1)!);
  final minute = match.group(2)!;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final twelve = hour % 12 == 0 ? 12 : hour % 12;
  return '$twelve:$minute $suffix';
}

/// Mirrors formatAge in src/store/catalogStore.js.
String formatAge(int? months) {
  if (months == null) return '';
  if (months < 1) return 'Under 1 month';
  if (months < 12) return '$months ${months == 1 ? 'month' : 'months'}';
  final years = months ~/ 12;
  final rest = months % 12;
  if (rest == 0) return '$years ${years == 1 ? 'year' : 'years'}';
  return '$years yr $rest mo';
}

/// "pet_reservation" -> "Pet reservation".
String titleCase(String value) {
  final text = value.replaceAll('_', ' ').trim();
  if (text.isEmpty) return text;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

/// "1 hr 30 min" style label for a service duration.
String formatDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '';
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours hr' : '$hours hr $rest min';
}

/// First 8 characters of an id, as shown on orders/refunds ("#1a2b3c4d").
String shortId(String id) => '#${id.length > 8 ? id.substring(0, 8) : id}'.toLowerCase();
