import 'dart:math' as math;

import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/dashboard/domain/get_monthly_trend.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Income vs. expenses of the six months ending at [month].
class TrendBarChart extends ConsumerWidget {
  const TrendBarChart({required this.month, super.key});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.lastSixMonths,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: AsyncStateView<List<MonthTotals>>(
                value: ref.watch(monthlyTrendProvider(month)),
                onRetry: () => ref.invalidate(monthlyTrendProvider(month)),
                loading: const SkeletonBox(
                  key: Key('dashboard-trend-skeleton'),
                  height: 220,
                  radius: 12,
                ),
                data: (trend) => _isAllZero(trend)
                    ? Center(
                        child: Text(
                          l10n.notEnoughData,
                          key: const Key('dashboard-trend-empty'),
                        ),
                      )
                    : TrendChart(trend: trend, selected: month),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isAllZero(List<MonthTotals> trend) => trend.every(
  (t) => t.income.amountMinor == 0 && t.expense.amountMinor == 0,
);

/// Rounds up to 1, 2 or 5 times a power of ten.
double _niceStep(double raw) {
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
  final normalized = raw / magnitude;
  final nice = normalized <= 1
      ? 1
      : normalized <= 2
      ? 2
      : normalized <= 5
      ? 5
      : 10;
  return nice * magnitude.toDouble();
}

/// The chart itself. Amounts are converted to major units only to draw.
class TrendChart extends StatelessWidget {
  const TrendChart({required this.trend, required this.selected, super.key});

  final List<MonthTotals> trend;
  final YearMonth selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final currencyCode = trend.first.income.currencyCode;
    final minorUnits = currencyByCode(currencyCode).minorUnits;
    final divisor = math.pow(10, minorUnits).toDouble();
    double major(Money m) => m.amountMinor / divisor;

    final rawMax = trend
        .expand((t) => [major(t.income), major(t.expense)])
        .reduce(math.max);
    final step = _niceStep(rawMax / 3);
    final maxY = step * (rawMax / step).ceil();
    final compact = NumberFormat.compactSimpleCurrency(
      locale: 'en_US',
      name: currencyCode,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: l10n.incomeVsExpensesSemantics,
      child: ExcludeSemantics(
        child: BarChart(
          key: const Key('dashboard-trend'),
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: colors.chartGrid, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: step,
                  getTitlesWidget: (value, meta) => SideTitleWidget(
                    meta: meta,
                    child: Text(
                      compact.format(value),
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= trend.length) {
                      return const SizedBox.shrink();
                    }
                    final month = trend[index].month;
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(
                        DateFormat.MMM(
                          'en_US',
                        ).format(DateTime(month.year, month.month)),
                        style: labelStyle?.copyWith(
                          fontWeight: month == selected
                              ? FontWeight.w800
                              : FontWeight.w400,
                          color: month == selected
                              ? theme.colorScheme.onSurface
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                fitInsideHorizontally: true,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    tooltipFor(context, trend[groupIndex]),
              ),
            ),
            barGroups: [
              for (var i = 0; i < trend.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    _rod(major(trend[i].income), colors.income),
                    _rod(major(trend[i].expense), colors.expense),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: 8,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );

  /// "Oct · Income $3,650.00 · Expenses $1,820.35".
  static BarTooltipItem tooltipFor(BuildContext context, MonthTotals totals) {
    final month = totals.month;
    final text = context.l10n.chartTooltip(
      DateFormat.MMM('en_US').format(DateTime(month.year, month.month)),
      formatMoney(totals.income),
      formatMoney(totals.expense),
    );
    return BarTooltipItem(
      text,
      TextStyle(
        color: Theme.of(context).colorScheme.onInverseSurface,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
