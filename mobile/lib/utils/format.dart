import 'package:intl/intl.dart';

/// Mirrors src/lib/format.js. Same $-prefixed formatting as the web app
/// (see docs/decisions.md: no currency field in the schema, so display
/// currency is a known pre-existing ambiguity, not a mobile-only bug).
final _priceFormat = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);
final _dateFormat = DateFormat('MMM d, yyyy');
final _dateTimeFormat = DateFormat('MMM d, h:mm a');

String formatPrice(num value) => _priceFormat.format(value);

String formatOrderDate(DateTime value) => _dateFormat.format(value);

String formatDateTime(DateTime value) => _dateTimeFormat.format(value);
