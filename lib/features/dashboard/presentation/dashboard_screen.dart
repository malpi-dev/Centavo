import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/month_selector.dart';
import 'package:centavo/core/presentation/selected_month_provider.dart';
import 'package:centavo/features/dashboard/presentation/budget_summary_card.dart';
import 'package:centavo/features/dashboard/presentation/expense_donut.dart';
import 'package:centavo/features/dashboard/presentation/summary_cards.dart';
import 'package:centavo/features/dashboard/presentation/trend_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Month overview: totals, expenses by category, 6-month trend and budgets.
/// Every section loads and fails on its own.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final currentMonth = YearMonth.fromLocalDate(
      ref.watch(clockProvider).today(),
    );
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dashboardTitle)),
      body: Column(
        children: [
          MonthSelector(
            month: month,
            maxMonth: currentMonth,
            onChanged: ref.read(selectedMonthProvider.notifier).set,
          ),
          Expanded(
            child: ListView(
              key: const Key('dashboard-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                SummaryCards(month: month),
                ExpenseDonut(month: month),
                const SizedBox(height: 16),
                TrendBarChart(month: month),
                const SizedBox(height: 16),
                BudgetSummaryCard(month: month),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
