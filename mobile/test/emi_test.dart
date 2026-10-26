import 'package:flutter_test/flutter_test.dart';
import 'package:pawsnearby/utils/emi.dart';

void main() {
  group('emiQuote', () {
    test('matches the web calculator for 30,000 over 6 months at 12%', () {
      final quote = emiQuote(price: 30000, downPaymentPercent: 0, months: 6, annualRatePercent: 12);
      expect(quote.emi, 5176);
      expect(quote.interest, 1059);
      expect(quote.total, 31059);
      expect(quote.downPayment, 0);
      expect(quote.rateLabel, '12% p.a.');
    });

    test('zero-rate tenure is a plain split with no interest', () {
      final quote = emiQuote(price: 30000, downPaymentPercent: 0, months: 3, annualRatePercent: 0);
      expect(quote.emi, 10000);
      expect(quote.interest, 0);
      expect(quote.total, 30000);
      expect(quote.rateLabel, 'No-cost EMI');
    });

    test('a down payment reduces the financed amount', () {
      final quote = emiQuote(price: 30000, downPaymentPercent: 20, months: 3, annualRatePercent: 0);
      expect(quote.downPayment, 6000);
      expect(quote.emi, 8000);
    });

    test('longer tenures cost more interest at higher rates', () {
      final quotes = emiQuotes(price: 30000, downPaymentPercent: 0);
      expect(quotes.map((q) => q.months), [3, 6, 9, 12]);
      for (var i = 1; i < quotes.length; i++) {
        expect(quotes[i].interest, greaterThanOrEqualTo(quotes[i - 1].interest));
        expect(quotes[i].emi, lessThan(quotes[i - 1].emi));
      }
    });

    test('is safe for zero, negative and non-finite inputs', () {
      final zero = emiQuote(price: 0, downPaymentPercent: 0, months: 6, annualRatePercent: 12);
      expect([zero.emi, zero.interest, zero.total, zero.downPayment], [0, 0, 0, 0]);

      final negative = emiQuote(price: -500, downPaymentPercent: -10, months: 6, annualRatePercent: 12);
      expect(negative.emi, 0);

      final noMonths = emiQuote(price: 30000, downPaymentPercent: 0, months: 0, annualRatePercent: 12);
      expect(noMonths.emi, 0);

      final nan = emiQuote(price: double.nan, downPaymentPercent: double.nan, months: 6, annualRatePercent: double.nan);
      expect(nan.emi, 0);
    });

    test('100% down payment finances nothing', () {
      final quote = emiQuote(price: 30000, downPaymentPercent: 100, months: 6, annualRatePercent: 12);
      expect(quote.downPayment, 30000);
      expect(quote.emi, 0);
      expect(quote.interest, 0);
    });
  });

  test('tenure table is consistent', () {
    expect(kEmiTenures, [3, 6, 9, 12]);
    expect(kEmiAnnualRates[3], 0);
    expect(kEmiTenures, contains(kEmiDefaultMonths));
  });
}
