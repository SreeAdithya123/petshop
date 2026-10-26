import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

enum RevenueRange { week, month, year }

class _Bucket {
  final String label;
  double amount = 0;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String? monthKey;
  _Bucket(this.label, {this.rangeStart, this.rangeEnd, this.monthKey});
}

final _weekdayFormat = DateFormat('EEE');
final _monthFormat = DateFormat('MMM');

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Buckets `orders` (each a record with createdAt/totalAmount) into N points
/// for the selected range, mirroring the web app's RevenueChart bucketing
/// exactly: week = last 7 days (daily), month = last 5 weeks (weekly),
/// year = last 12 months (monthly).
///
/// Callers pass only the orders that count as revenue (cancelled orders are
/// left out before they get here).
List<_Bucket> _bucketize(List<({DateTime createdAt, num totalAmount})> orders, RevenueRange range) {
  final now = DateTime.now();
  final buckets = <_Bucket>[];

  if (range == RevenueRange.week) {
    for (var i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      buckets.add(_Bucket(_weekdayFormat.format(day), rangeStart: _startOfDay(day), rangeEnd: _endOfDay(day)));
    }
    for (final order in orders) {
      for (final bucket in buckets) {
        if (!order.createdAt.isBefore(bucket.rangeStart!) && !order.createdAt.isAfter(bucket.rangeEnd!)) {
          bucket.amount += order.totalAmount;
          break;
        }
      }
    }
  } else if (range == RevenueRange.month) {
    for (var i = 4; i >= 0; i--) {
      final end = now.subtract(Duration(days: i * 7));
      final start = end.subtract(const Duration(days: 6));
      buckets.add(_Bucket(
        '${start.day}/${start.month}',
        rangeStart: _startOfDay(start),
        rangeEnd: _endOfDay(end),
      ));
    }
    for (final order in orders) {
      for (final bucket in buckets) {
        if (!order.createdAt.isBefore(bucket.rangeStart!) && !order.createdAt.isAfter(bucket.rangeEnd!)) {
          bucket.amount += order.totalAmount;
          break;
        }
      }
    }
  } else {
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      buckets.add(_Bucket(_monthFormat.format(month), monthKey: '${month.year}-${month.month}'));
    }
    for (final order in orders) {
      final key = '${order.createdAt.year}-${order.createdAt.month}';
      for (final bucket in buckets) {
        if (bucket.monthKey == key) {
          bucket.amount += order.totalAmount;
          break;
        }
      }
    }
  }

  return buckets;
}

String _periodDescription(RevenueRange range) {
  switch (range) {
    case RevenueRange.week:
      return 'the last 7 days, by day';
    case RevenueRange.month:
      return 'the last 5 weeks, by week';
    case RevenueRange.year:
      return 'the last 12 months, by month';
  }
}

String _trimNumber(double value) => value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);

/// Short axis label in the Indian style: 2.5k, 1L (lakh), 1Cr (crore).
String _axisLabel(double value) {
  if (value >= 10000000) return '${_trimNumber(value / 10000000)}Cr';
  if (value >= 100000) return '${_trimNumber(value / 100000)}L';
  if (value >= 1000) return '${_trimNumber(value / 1000)}k';
  return value.round().toString();
}

/// A round gridline step (1, 2, 5 x 10^n) giving about four divisions.
double _niceInterval(double maxValue) {
  final raw = maxValue / 4;
  if (raw <= 1) return 1;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalized = raw / magnitude;
  final step = normalized <= 1
      ? 1
      : normalized <= 2
          ? 2
          : normalized <= 5
              ? 5
              : 10;
  return step * magnitude;
}

/// Revenue tracker with a week/month/year range toggle, shared by the
/// seller and admin dashboards. Mirrors src/components/ui/RevenueChart.jsx.
///
/// Screen readers get a text summary of every bar instead of the drawing.
class RevenueChart extends StatefulWidget {
  final List<({DateTime createdAt, num totalAmount})> orders;
  const RevenueChart({super.key, required this.orders});

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  RevenueRange _range = RevenueRange.month;

  @override
  Widget build(BuildContext context) {
    final buckets = _bucketize(widget.orders, _range);
    final total = buckets.fold<double>(0, (sum, b) => sum + b.amount);
    final maxY = buckets.fold<double>(0, (m, b) => b.amount > m ? b.amount : m);
    _Bucket? best;
    for (final bucket in buckets) {
      if (bucket.amount > 0 && (best == null || bucket.amount > best.amount)) best = bucket;
    }

    final summary = maxY <= 0
        ? 'Revenue for ${_periodDescription(_range)}: no revenue in this period.'
        : 'Revenue for ${_periodDescription(_range)}: ${formatPrice(total)} in total. '
            '${buckets.map((b) => '${b.label} ${formatPrice(b.amount)}').join(', ')}.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    header: true,
                    child: Text('Revenue', style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(total),
                    style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RangeButton(
                      label: 'Week',
                      selected: _range == RevenueRange.week,
                      onTap: () => setState(() => _range = RevenueRange.week),
                    ),
                    _RangeButton(
                      label: 'Month',
                      selected: _range == RevenueRange.month,
                      onTap: () => setState(() => _range = RevenueRange.month),
                    ),
                    _RangeButton(
                      label: 'Year',
                      selected: _range == RevenueRange.year,
                      onTap: () => setState(() => _range = RevenueRange.year),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            image: true,
            label: summary,
            child: ExcludeSemantics(
              child: SizedBox(
                height: 200,
                child: maxY <= 0
                    ? Center(
                        child: Text('No revenue in this period', style: AppTheme.body(color: AppColors.inkSoft)),
                      )
                    : _buildChart(buckets, maxY),
              ),
            ),
          ),
          if (best != null) ...[
            const SizedBox(height: 12),
            Text(
              'Best ${_range == RevenueRange.week ? 'day' : _range == RevenueRange.month ? 'week' : 'month'}: '
              '${best.label} · ${formatPrice(best.amount)}',
              style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(List<_Bucket> buckets, double maxY) {
    final interval = _niceInterval(maxY);
    final top = (maxY * 1.1 / interval).ceil() * interval;
    return LayoutBuilder(
      builder: (context, constraints) {
        const axisWidth = 44.0;
        final slot = (constraints.maxWidth - axisWidth) / buckets.length;
        final barWidth = (slot * 0.55).clamp(6.0, 22.0).toDouble();
        // Keep x labels from colliding on narrow screens or large text: show
        // every second (or third) label when a slot is too tight for one.
        final labelWidth = MediaQuery.textScalerOf(context).scale(10.5) * 3;
        final labelStep = slot >= labelWidth ? 1 : (slot * 2 >= labelWidth ? 2 : 3);
        return BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: top,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                  '${buckets[groupIndex].label}\n${formatPrice(rod.toY)}',
                  AppTheme.body(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: axisWidth,
                  interval: interval,
                  getTitlesWidget: (value, meta) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _axisLabel(value),
                      textAlign: TextAlign.right,
                      style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= buckets.length || i % labelStep != 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        buckets[i].label,
                        style: AppTheme.body(fontSize: 10.5, color: AppColors.inkSoft),
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (value) => FlLine(color: AppColors.border, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < buckets.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: buckets[i].amount,
                      color: AppColors.primary,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RangeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RangeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label range',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: AppTheme.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}
