import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/budgets/domain/get_budget_progress.dart';
import 'package:centavo/features/budgets/presentation/budgets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The three budgets closest to their limit, with a link to the Budgets tab.
class BudgetSummaryCard extends ConsumerWidget {
  const BudgetSummaryCard({required this.month, super.key});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Card(
      key: const Key('dashboard-budgets'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.budgetsCardTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  identifier: 'dashboard-see-budgets',
                  child: TextButton(
                    key: const Key('dashboard-see-budgets'),
                    onPressed: () => context.go(Routes.budgets),
                    child: Text(l10n.seeAll),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AsyncStateView<BudgetProgressReport>(
              value: ref.watch(budgetProgressProvider(month)),
              onRetry: () => ref.invalidate(monthBudgetsProvider(month)),
              loading: const Column(
                key: Key('dashboard-budgets-skeleton'),
                children: [
                  SkeletonBox(height: 40, radius: 12),
                  SizedBox(height: 12),
                  SkeletonBox(height: 40, radius: 12),
                  SizedBox(height: 12),
                  SkeletonBox(height: 40, radius: 12),
                ],
              ),
              data: (report) => report.lines.isEmpty
                  ? const _NoBudgets()
                  : Column(
                      children: [
                        for (final line in report.lines.take(3))
                          _BudgetRow(line: line),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBudgets extends StatelessWidget {
  const _NoBudgets();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Text(
          l10n.noBudgetsThisMonth,
          key: const Key('dashboard-no-budgets'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('dashboard-set-up-budgets'),
          onPressed: () => context.go(Routes.budgets),
          child: Text(l10n.setUpBudgets),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.line});

  final BudgetLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final color = switch (line.status) {
      BudgetStatus.onTrack => colors.onTrack,
      BudgetStatus.warning => colors.warning,
      BudgetStatus.exceeded => colors.exceeded,
    };
    return Padding(
      key: Key('dashboard-budget-${line.category.id}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CategoryAvatar(
            icon: line.category.icon,
            color: line.category.color,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.category.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      context.l10n.lineSpentOfLimit(
                        formatMoney(line.spent),
                        formatMoney(line.limit),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (line.basisPoints / 10000).clamp(0, 1),
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
