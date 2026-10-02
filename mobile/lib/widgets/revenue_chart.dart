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

/// Revenue tracker with a week/month/year range toggle, shared by the
/// seller and admin dashboards. Mirrors src/components/ui/RevenueChart.jsx.
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue', style: AppTheme.display(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(total),
                      style: AppTheme.display(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RangeButton(label: 'Week', selected: _range == RevenueRange.week, onTap: () => setState(() => _range = RevenueRange.week)),
                    _RangeButton(label: 'Month', selected: _range == RevenueRange.month, onTap: () => setState(() => _range = RevenueRange.month)),
                    _RangeButton(label: 'Year', selected: _range == RevenueRange.year, onTap: () => setState(() => _range = RevenueRange.year)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: maxY <= 0
                ? Center(
                    child: Text('No revenue in this period', style: AppTheme.body(color: AppColors.inkSoft)),
                  )
                : BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxY * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => AppColors.ink,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                            formatPrice(rod.toY),
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
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              value >= 1000 ? '${(value / 1000).round()}k' : value.round().toString(),
                              style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, meta) {
                              final i = value.toInt();
                              if (i < 0 || i >= buckets.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  buckets[i].label,
                                  style: AppTheme.body(fontSize: 11, color: AppColors.inkSoft),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 1,
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
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
    );
  }
}
