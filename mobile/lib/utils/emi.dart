import 'dart:math' as math;

/// EMI maths for the pet "EMI options" calculator (see
/// widgets/pet_actions/emi_sheet.dart). Pure functions with no Flutter
/// dependency so they can be unit-tested directly.
///
/// Figures are indicative only: PETSTA shops take payment in person and real
/// terms come from the shop or the customer's lender.

/// Indicative annual interest rate (%) per tenure in months.
const Map<int, double> kEmiAnnualRates = {3: 0.0, 6: 12.0, 9: 13.0, 12: 14.0};

/// Tenures (in months) on offer, shortest first.
final List<int> kEmiTenures = List<int>.unmodifiable(kEmiAnnualRates.keys.toList()..sort());

/// Tenure pre-selected when the calculator opens.
const int kEmiDefaultMonths = 6;

/// Largest down payment the calculator allows, as a percentage of the price.
const int kEmiMaxDownPaymentPercent = 50;

/// The result of [emiQuote] for one tenure. Every figure is rounded to the
/// rupee.
class EmiQuote {
  final int months;
  final double annualRatePercent;
  final int downPayment;
  final int emi;
  final int interest;

  /// Price plus total interest.
  final int total;

  const EmiQuote({
    required this.months,
    required this.annualRatePercent,
    required this.downPayment,
    required this.emi,
    required this.interest,
    required this.total,
  });

  /// "No-cost EMI" for a zero rate, otherwise e.g. "12% p.a." / "12.5% p.a.".
  String get rateLabel {
    if (annualRatePercent == 0) return 'No-cost EMI';
    final text = annualRatePercent % 1 == 0 ? annualRatePercent.toInt().toString() : annualRatePercent.toString();
    return '$text% p.a.';
  }
}

/// Standard reducing-balance EMI for [price] paid over [months] at
/// [annualRatePercent], after a [downPaymentPercent]% down payment (rounded to
/// the rupee). Non-finite or negative inputs are treated as zero; a
/// non-positive tenure yields a zero EMI.
EmiQuote emiQuote({
  required num price,
  required num downPaymentPercent,
  required int months,
  required double annualRatePercent,
}) {
  final safePrice = (price.isFinite && price > 0) ? price.toDouble() : 0.0;
  final percent = downPaymentPercent.isFinite ? downPaymentPercent.clamp(0, 100).toDouble() : 0.0;
  final rate = (annualRatePercent.isFinite && annualRatePercent > 0) ? annualRatePercent : 0.0;

  final downPayment = (safePrice * percent / 100).round();
  final loan = safePrice - downPayment;
  final monthlyRate = rate / 12 / 100;
  final hasLoan = loan > 0 && months > 0;

  double emi = 0;
  if (hasLoan) {
    emi = monthlyRate == 0
        ? loan / months
        : (loan * monthlyRate * math.pow(1 + monthlyRate, months)) / (math.pow(1 + monthlyRate, months) - 1);
  }
  final interest = hasLoan ? math.max(0.0, emi * months - loan) : 0.0;

  return EmiQuote(
    months: months,
    annualRatePercent: rate,
    downPayment: downPayment,
    emi: emi.round(),
    interest: interest.round(),
    total: (safePrice + interest).round(),
  );
}

/// One [EmiQuote] per tenure in [kEmiTenures], using the indicative rates in
/// [kEmiAnnualRates].
List<EmiQuote> emiQuotes({required num price, required num downPaymentPercent}) {
  return [
    for (final months in kEmiTenures)
      emiQuote(
        price: price,
        downPaymentPercent: downPaymentPercent,
        months: months,
        annualRatePercent: kEmiAnnualRates[months] ?? 0,
      ),
  ];
}
