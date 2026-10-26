import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../seller/seller_common.dart';
import '../ui_kit.dart';

// Presentation pieces for the seller analytics screen (StatCard, Card,
// EmptyText and BarList in src/pages/seller/Analytics.jsx).

/// One KPI tile: label, a big figure and an optional hint underneath.
class AnalyticsStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? hint;

  const AnalyticsStatTile({super.key, required this.label, required this.value, this.hint});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700)),
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(hint!, style: AppTheme.body(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Titled section card that holds a bar list, a ranking or an empty note.
class AnalyticsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const AnalyticsCard({super.key, required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return CardBox(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Muted one-line note shown inside a card that has nothing to chart.
class AnalyticsEmptyText extends StatelessWidget {
  final String message;
  const AnalyticsEmptyText(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(message, style: AppTheme.body(color: AppColors.inkSoft));
  }
}

class BarRowData {
  final String label;
  final num value;
  final Color tone;

  const BarRowData({required this.label, required this.value, required this.tone});
}

/// Horizontal bars with a readable figure beside each. Bar widths are
/// relative to the largest row (or [max]); the percentage shown is each
/// row's share of [total].
class AnalyticsBarList extends StatelessWidget {
  final List<BarRowData> rows;
  final num total;
  final num? max;
  final String Function(num value) formatValue;

  const AnalyticsBarList({
    super.key,
    required this.rows,
    required this.total,
    this.max,
    this.formatValue = _plainNumber,
  });

  static String _plainNumber(num value) => value.toString();

  int _share(num value) => total > 0 ? ((value / total) * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    var scale = max ?? 0;
    if (max == null) {
      for (final row in rows) {
        if (row.value > scale) scale = row.value;
      }
    }

    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BarRow(
            label: rows[i].label,
            figure: '${formatValue(rows[i].value)} · ${_share(rows[i].value)}%',
            fraction: scale > 0 && rows[i].value > 0 ? ((rows[i].value / scale).clamp(0.02, 1.0)).toDouble() : 0,
            tone: rows[i].tone,
          ),
        ],
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String figure;
  final double fraction;
  final Color tone;

  const _BarRow({required this.label, required this.figure, required this.fraction, required this.tone});

  @override
  Widget build(BuildContext context) {
    // The bar is decorative: screen readers get "Label: figure" instead.
    return Semantics(
      container: true,
      label: '$label: $figure',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: AppTheme.body(fontSize: 14))),
              const SizedBox(width: 12),
              Text(figure, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(color: tone, borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Couldn't load analytics" card with a retry button.
class AnalyticsErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AnalyticsErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SellerLoadError(what: 'analytics', message: message, onRetry: onRetry);
  }
}
