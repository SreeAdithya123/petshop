import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/models.dart';
import '../../state/cart_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../ui_kit.dart';

/// Bottom-sheet version of src/components/pets/EmiModal.jsx: an
/// informational EMI calculator for [pet]. Nothing is charged or saved; the
/// only action is adding the pet to the cart. [shopName] is accepted for
/// symmetry with the other pet action sheets (the web modal doesn't show it).
Future<void> showEmiSheet(
  BuildContext context, {
  required Pet pet,
  String? shopName,
}) {
  return showFormSheet<void>(
    context,
    title: 'EMI options',
    description: '${pet.displayName} · ${formatPrice(pet.price)}',
    builder: (sheetContext) => _EmiContent(pet: pet),
  );
}

/// Indicative annual interest rate (%) per tenure in months. Illustration
/// only -- real terms come from the shop / the customer's lender.
const Map<int, double> _emiAnnualRates = {3: 0.0, 6: 12.0, 9: 13.0, 12: 14.0};

const _defaultMonths = 6;
const _maxDownPaymentPercent = 50;

final List<int> _tenures = _emiAnnualRates.keys.toList()..sort();

class _EmiPlan {
  final int months;
  final double annualRate;
  final int emi;
  final int interest;
  final int total;

  const _EmiPlan({
    required this.months,
    required this.annualRate,
    required this.emi,
    required this.interest,
    required this.total,
  });

  String get rateLabel {
    if (annualRate == 0) return 'No-cost EMI';
    final text = annualRate % 1 == 0 ? annualRate.toInt().toString() : annualRate.toString();
    return '$text% p.a.';
  }
}

/// Standard reducing-balance EMI; every figure is rounded to the rupee.
_EmiPlan _calculatePlan({
  required double price,
  required int downPayment,
  required int months,
  required double annualRate,
}) {
  final loan = price - downPayment;
  final monthlyRate = annualRate / 12 / 100;

  double emi = 0;
  if (loan > 0) {
    emi = monthlyRate == 0
        ? loan / months
        : (loan * monthlyRate * math.pow(1 + monthlyRate, months)) / (math.pow(1 + monthlyRate, months) - 1);
  }
  final interest = loan > 0 ? math.max(0.0, emi * months - loan) : 0.0;

  return _EmiPlan(
    months: months,
    annualRate: annualRate,
    emi: emi.round(),
    interest: interest.round(),
    total: (price + interest).round(),
  );
}

class _EmiContent extends ConsumerStatefulWidget {
  final Pet pet;
  const _EmiContent({required this.pet});

  @override
  ConsumerState<_EmiContent> createState() => _EmiContentState();
}

class _EmiContentState extends ConsumerState<_EmiContent> {
  int _months = _defaultMonths;
  int _downPercent = 0;

  void _handleCart() {
    final pet = widget.pet;
    final cart = ref.read(cartControllerProvider);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);

    if (cart.isInCart('pet', pet.id)) {
      navigator.pop();
      router.push('/cart');
      return;
    }
    unawaited(cart.addToCart('pet', pet.id));
    showSnack(context, '${pet.displayName} added to your cart.');
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final price = pet.price.toDouble();
    final downPayment = (price * _downPercent / 100).round();
    final plans = <_EmiPlan>[
      for (final months in _tenures)
        _calculatePlan(
          price: price,
          downPayment: downPayment,
          months: months,
          annualRate: _emiAnnualRates[months] ?? 0,
        ),
    ];
    final selected = plans.firstWhere((plan) => plan.months == _months, orElse: () => plans.first);
    final inCart = ref.watch(cartControllerProvider).isInCart('pet', pet.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NoticeBox.warning(
          message: 'Indicative figures for illustration only. PETSTA shops take payment in person; EMI '
              'availability and final terms depend on the shop and your lender.',
        ),
        const SizedBox(height: 18),
        Text('Tenure', style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
        const SizedBox(height: 6),
        _buildTenureGrid(plans),
        const SizedBox(height: 18),
        Text(
          'Down payment: $_downPercent% (${formatPrice(downPayment)})',
          style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
        ),
        Slider(
          value: _downPercent.toDouble(),
          min: 0,
          max: _maxDownPaymentPercent.toDouble(),
          divisions: _maxDownPaymentPercent ~/ 5,
          label: '$_downPercent%',
          onChanged: (value) => setState(() => _downPercent = value.round()),
        ),
        Text(
          'Optional — up to $_maxDownPaymentPercent% of the price.',
          style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        _buildSummary(selected, downPayment),
        const SizedBox(height: 16),
        _buildComparison(plans, selected),
        const SizedBox(height: 12),
        Text(
          'This is a calculator only. No payment is taken and nothing you enter here is saved.',
          style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _handleCart,
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text(inCart ? 'View cart' : 'Add to cart'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Tenure picker as a 2 x 2 grid of selectable tiles.
  Widget _buildTenureGrid(List<_EmiPlan> plans) {
    Widget tile(_EmiPlan plan) => _TenureTile(
          plan: plan,
          selected: plan.months == _months,
          onTap: () => setState(() => _months = plan.months),
        );

    return Column(
      children: [
        for (var i = 0; i < plans.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              children: [
                Expanded(child: tile(plans[i])),
                const SizedBox(width: 8),
                Expanded(child: i + 1 < plans.length ? tile(plans[i + 1]) : const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }

  /// The highlighted "Your plan" card for the selected tenure.
  Widget _buildSummary(_EmiPlan selected, int downPayment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR PLAN · ${selected.months} MONTHS · ${selected.rateLabel.toUpperCase()}',
            style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSoft)
                .copyWith(letterSpacing: 0.4),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: formatPrice(selected.emi),
                  style: AppTheme.display(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' / month',
                  style: AppTheme.body(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Stat(label: 'Down payment', value: formatPrice(downPayment))),
              Expanded(child: _Stat(label: 'Total interest', value: formatPrice(selected.interest))),
              Expanded(child: _Stat(label: 'Total payable', value: formatPrice(selected.total))),
            ],
          ),
        ],
      ),
    );
  }

  /// Side-by-side comparison of every tenure.
  Widget _buildComparison(List<_EmiPlan> plans, _EmiPlan selected) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: AppColors.paper,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final entry in const [('Tenure', 4), ('Monthly EMI', 3), ('Interest', 3), ('Total', 3)])
                  Expanded(
                    flex: entry.$2,
                    child: Text(
                      entry.$1,
                      style: AppTheme.body(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
          for (final plan in plans) _ComparisonRow(plan: plan, highlighted: plan.months == selected.months),
        ],
      ),
    );
  }
}

class _TenureTile extends StatelessWidget {
  final _EmiPlan plan;
  final bool selected;
  final VoidCallback onTap;
  const _TenureTile({required this.plan, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              children: [
                Text(
                  '${plan.months} months',
                  style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.rateLabel,
                  textAlign: TextAlign.center,
                  style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTheme.body(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final _EmiPlan plan;
  final bool highlighted;
  const _ComparisonRow({required this.plan, required this.highlighted});

  Widget _cell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: AppTheme.body(
            fontSize: 12.5,
            fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            color: highlighted ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.primary.withValues(alpha: 0.05) : null,
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${plan.months} months', style: AppTheme.body(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(plan.rateLabel, style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft)),
              ],
            ),
          ),
          _cell(formatPrice(plan.emi), 3),
          _cell(formatPrice(plan.interest), 3),
          _cell(formatPrice(plan.total), 3),
        ],
      ),
    );
  }
}
