import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_format.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/dashboard/domain/get_month_summary.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Income / Expenses / Balance of the month, or the empty state (F5 CA2).
class SummaryCards extends ConsumerWidget {
  const SummaryCards({required this.month, super.key});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncStateView<MonthSummary>(
      value: ref.watch(monthSummaryProvider(month)),
      onRetry: () => ref.invalidate(monthSummaryProvider(month)),
      loading: const _SummarySkeleton(),
      data: (summary) => summary.isEmpty
          ? _EmptyMonth(month: month)
          : _Cards(summary: summary),
    );
  }
}

class _SummarySkeleton extends StatelessWidget {
  const _SummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('dashboard-summary-skeleton'),
      children: [
        Expanded(child: SkeletonBox(height: 84, radius: 16)),
        SizedBox(width: 8),
        Expanded(child: SkeletonBox(height: 84, radius: 16)),
        SizedBox(width: 8),
        Expanded(child: SkeletonBox(height: 84, radius: 16)),
      ],
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = DateFormat.yMMMM(
      'en_US',
    ).format(DateTime(month.year, month.month));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: EmptyState(
        icon: Icons.receipt_long,
        title: l10n.noTransactionsInMonth(name),
        actionLabel: l10n.addTransaction,
        actionKey: const Key('dashboard-add-first'),
        onAction: () => context.push('${Routes.transactionNew}?type=expense'),
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _AmountCard(
            id: 'dashboard-income',
            label: l10n.incomeLabel,
            money: summary.income,
            color: colors.income,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AmountCard(
            id: 'dashboard-expense',
            label: l10n.expensesLabel,
            money: summary.expense,
            color: colors.expense,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AmountCard(
            id: 'dashboard-balance',
            label: l10n.balanceLabel,
            money: summary.balance,
            color: summary.balance.isNegative ? colors.expense : colors.income,
          ),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.id,
    required this.label,
    required this.money,
    required this.color,
  });

  final String id;
  final String label;
  final Money money;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: id,
      child: Card(
        key: Key(id),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(money),
                    key: Key('$id-amount'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
