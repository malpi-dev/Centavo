import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/error_messages.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/month_selector.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/core/presentation/selected_month_provider.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/budgets/domain/get_budget_progress.dart';
import 'package:centavo/features/budgets/presentation/budgets_providers.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _monthName(YearMonth month) =>
    DateFormat.yMMMM('en_US').format(DateTime(month.year, month.month));

/// Month budgets: progress per category, unbudgeted spending and copy.
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    // One month ahead so next month can be planned.
    final maxMonth = YearMonth.fromLocalDate(
      ref.watch(clockProvider).today(),
    ).next;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetsTitle)),
      body: Column(
        children: [
          MonthSelector(
            month: month,
            maxMonth: maxMonth,
            onChanged: ref.read(selectedMonthProvider.notifier).set,
          ),
          Expanded(
            child: AsyncStateView<BudgetProgressReport>(
              value: ref.watch(budgetProgressProvider(month)),
              onRetry: () => ref.invalidate(monthBudgetsProvider(month)),
              loading: const _BudgetsSkeleton(),
              data: (report) => _BudgetsBody(month: month, report: report),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetsSkeleton extends StatelessWidget {
  const _BudgetsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('budgets-skeleton'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 96, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
        SizedBox(height: 12),
        SkeletonBox(height: 72, radius: 16),
      ],
    );
  }
}

class _BudgetsBody extends ConsumerWidget {
  const _BudgetsBody({required this.month, required this.report});

  final YearMonth month;
  final BudgetProgressReport report;

  Future<void> _copy(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = rootScaffoldMessengerKey.currentState;
    final count = await ref
        .read(copyBudgetsControllerProvider.notifier)
        .copy(month);
    if (count != null) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.copiedBudgets(count))));
      return;
    }
    final error = ref.read(copyBudgetsControllerProvider).error;
    if (error != null) {
      messenger?.showSnackBar(SnackBar(content: Text(messageFor(error, l10n))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final hasBudgets = report.lines.isNotEmpty;
    final canCopy =
        !hasBudgets &&
        (ref.watch(canCopyPreviousBudgetsProvider(month)).value ?? false);
    final copying = ref.watch(copyBudgetsControllerProvider).isLoading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (hasBudgets) ...[
          _SummaryCard(report: report),
          for (final line in report.lines) ...[
            const SizedBox(height: 12),
            _BudgetLineCard(line: line, month: month),
          ],
        ] else
          EmptyState(
            icon: Icons.savings,
            title: l10n.noBudgetsInMonth(_monthName(month)),
            actionLabel: canCopy ? l10n.copyFromPreviousMonth : null,
            onAction: canCopy && !copying ? () => _copy(context, ref) : null,
          ),
        if (report.categoriesWithoutBudget.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            l10n.notBudgeted,
            key: const Key('budgets-not-budgeted'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final category in report.categoriesWithoutBudget)
            _NotBudgetedRow(
              category: category,
              month: month,
              label: hasBudgets ? l10n.setBudget : l10n.setABudget,
            ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.report});

  final BudgetProgressReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final basisPoints = report.totalSpent.basisPointsOf(report.totalLimit);
    return Card(
      key: const Key('budgets-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.spentOfLimit(
                formatMoney(report.totalSpent),
                formatMoney(report.totalLimit),
              ),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              basisPoints: basisPoints,
              color:
                  report.totalSpent.amountMinor > report.totalLimit.amountMinor
                  ? context.colors.exceeded
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.unbudgetedSpending(formatMoney(report.unbudgetedSpent)),
              key: const Key('budgets-unbudgeted'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.basisPoints, required this.color});

  final int basisPoints;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: (basisPoints / 10000).clamp(0, 1),
        minHeight: 8,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _BudgetLineCard extends StatelessWidget {
  const _BudgetLineCard({required this.line, required this.month});

  final BudgetLine line;
  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.colors;
    final (color, statusLabel) = switch (line.status) {
      BudgetStatus.onTrack => (colors.onTrack, l10n.statusOnTrack),
      BudgetStatus.warning => (colors.warning, l10n.statusWarning),
      BudgetStatus.exceeded => (colors.exceeded, l10n.statusExceeded),
    };
    final remainingText = line.remaining.isNegative
        ? l10n.overBy(
            formatMoney(
              Money(-line.remaining.amountMinor, line.limit.currencyCode),
            ),
          )
        : l10n.leftAmount(formatMoney(line.remaining));
    return Card(
      key: Key('budget-line-${line.category.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(
          Routes.budgetEditFor(line.category.id, month),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CategoryAvatar(
                    icon: line.category.icon,
                    color: line.category.color,
                    label: line.category.name,
                    size: 36,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.category.name,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          l10n.lineSpentOfLimit(
                            formatMoney(line.spent),
                            formatMoney(line.limit),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    remainingText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: line.remaining.isNegative ? color : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressBar(basisPoints: line.basisPoints, color: color),
              const SizedBox(height: 8),
              Text(
                statusLabel,
                key: Key('budget-status-${line.category.id}'),
                style: theme.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotBudgetedRow extends StatelessWidget {
  const _NotBudgetedRow({
    required this.category,
    required this.month,
    required this.label,
  });

  final Category category;
  final YearMonth month;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('not-budgeted-${category.id}'),
      contentPadding: EdgeInsets.zero,
      leading: CategoryAvatar(
        icon: category.icon,
        color: category.color,
        label: category.name,
      ),
      title: Text(category.name),
      trailing: Semantics(
        identifier: 'budget-set-${category.id}',
        child: TextButton(
          key: Key('budget-set-${category.id}'),
          onPressed: () =>
              context.push(Routes.budgetEditFor(category.id, month)),
          child: Text(label),
        ),
      ),
    );
  }
}
