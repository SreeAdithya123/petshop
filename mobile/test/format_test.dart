import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/utils/format.dart';

void main() {
  group('formatPrice (INR, Indian digit grouping)', () {
    test('formats whole rupees with the rupee sign', () {
      expect(formatPrice(499), '₹499');
      expect(formatPrice(30000), '₹30,000');
    });

    test('uses lakh grouping', () {
      expect(formatPrice(125000), '₹1,25,000');
      expect(formatPrice(1234567), '₹12,34,567');
    });

    test('drops paise and handles zero', () {
      expect(formatPrice(0), '₹0');
      expect(formatPrice(1499.4), '₹1,499');
    });
  });

  group('formatAge', () {
    test('handles null and tiny ages', () {
      expect(formatAge(null), '');
      expect(formatAge(0), 'Under 1 month');
    });

    test('months, years and mixed', () {
      expect(formatAge(1), '1 month');
      expect(formatAge(5), '5 months');
      expect(formatAge(12), '1 year');
      expect(formatAge(24), '2 years');
      expect(formatAge(14), '1 yr 2 mo');
    });
  });

  group('formatClock', () {
    test('converts 24h Postgres times to 12h', () {
      expect(formatClock('14:30:00'), '2:30 PM');
      expect(formatClock('09:05'), '9:05 AM');
      expect(formatClock('00:05'), '12:05 AM');
      expect(formatClock('12:00:00'), '12:00 PM');
    });

    test('passes free text through and tolerates null', () {
      expect(formatClock('Morning'), 'Morning');
      expect(formatClock(null), '');
      expect(formatClock(''), '');
    });
  });

  group('dates', () {
    test('formatDate and formatDateString', () {
      expect(formatDate(DateTime(2026, 10, 5)), '5 Oct 2026');
      expect(formatDateString('2026-10-05'), '5 Oct 2026');
      expect(formatDateString(null), '');
      expect(formatDateString(''), '');
    });

    test('toDateParam is zero-padded yyyy-MM-dd', () {
      expect(toDateParam(DateTime(2026, 1, 5)), '2026-01-05');
      expect(toDateParam(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });

  group('small helpers', () {
    test('formatDuration', () {
      expect(formatDuration(null), '');
      expect(formatDuration(0), '');
      expect(formatDuration(45), '45 min');
      expect(formatDuration(60), '1 hr');
      expect(formatDuration(90), '1 hr 30 min');
    });

    test('titleCase turns snake_case into a sentence', () {
      expect(titleCase('pet_reservation'), 'Pet reservation');
      expect(titleCase('open'), 'Open');
      expect(titleCase(''), '');
    });

    test('shortId is lowercase and 8 chars after #', () {
      expect(shortId('1A2B3C4D-5E6F-7890-ABCD-EF1234567890'), '#1a2b3c4d');
      expect(shortId('abc'), '#abc');
    });
  });
}
