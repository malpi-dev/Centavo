import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/dashboard/domain/get_month_summary.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Expenses by category: top 5 + "Others", with a legend.
class ExpenseDonut extends ConsumerWidget {
  const ExpenseDonut({required this.month, super.key});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthSummaryProvider(month));
    // An empty month is handled by the summary cards' empty state.
    if (summary.value?.isEmpty ?? false) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AsyncStateView<MonthSummary>(
        value: summary,
        onRetry: () => ref.invalidate(monthSummaryProvider(month)),
        loading: const SkeletonBox(
          key: Key('dashboard-donut-skeleton'),
          height: 200,
          radius: 16,
        ),
        data: (data) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: data.expense.amountMinor == 0
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        context.l10n.noExpensesThisMonth,
                        key: const Key('dashboard-no-expenses'),
                      ),
                    ),
                  )
                : _DonutBody(summary: data),
          ),
        ),
      ),
    );
  }
}

String _sliceName(CategorySlice slice, AppLocalizations l10n) =>
    slice.name ?? l10n.others;

int _percent(CategorySlice slice) => slice.basisPoints ~/ 100;

class _DonutBody extends StatelessWidget {
  const _DonutBody({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final slices = summary.expenseSlices;
    final description = l10n.expensesByCategorySemantics(
      slices
          .map(
            (s) => l10n.sliceSemantics(_sliceName(s, l10n), _percent(s)),
          )
          .join(', '),
    );
    Color colorOf(CategorySlice s) {
      final color = s.color;
      return color == null ? theme.colorScheme.outline : colors.category(color);
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Semantics(
            label: description,
            child: ExcludeSemantics(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    key: const Key('dashboard-donut'),
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 56,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        for (final s in slices)
                          PieChartSectionData(
                            value: s.amount.amountMinor.toDouble(),
                            color: colorOf(s),
                            radius: 32,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.spentLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        formatMoney(summary.expense),
                        key: const Key('dashboard-donut-total'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < slices.length; i++)
          Padding(
            key: Key('donut-legend-$i'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CategoryAvatar(
                  icon: slices[i].icon,
                  color: slices[i].color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _sliceName(slices[i], l10n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(slices[i].amount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    l10n.percentValue(_percent(slices[i])),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
