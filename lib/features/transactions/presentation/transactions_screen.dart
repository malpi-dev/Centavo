import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/async_state_view.dart';
import 'package:centavo/core/presentation/category_avatar.dart';
import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/money_text.dart';
import 'package:centavo/core/presentation/month_selector.dart';
import 'package:centavo/core/presentation/selected_month_provider.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/presentation/delete_transaction.dart';
import 'package:centavo/features/transactions/presentation/transaction_grouping.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Month list grouped by day, with type and category filters.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final month = ref.watch(selectedMonthProvider);
    final filter = ref.watch(transactionFilterControllerProvider);
    final maxMonth = YearMonth.fromLocalDate(ref.watch(clockProvider).today());
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactionsTitle)),
      body: Column(
        children: [
          MonthSelector(
            month: month,
            maxMonth: maxMonth,
            onChanged: ref.read(selectedMonthProvider.notifier).set,
          ),
          const _FilterRow(),
          Expanded(
            child: AsyncStateView<List<TransactionDayGroup>>(
              value: ref.watch(transactionGroupsProvider),
              onRetry: () => ref.invalidate(monthTransactionsProvider(month)),
              isEmpty: (groups) => groups.isEmpty,
              empty: filter.isActive
                  ? EmptyState(
                      icon: Icons.filter_alt_off,
                      title: l10n.noResults,
                      actionLabel: l10n.clearFilters,
                      onAction: ref
                          .read(transactionFilterControllerProvider.notifier)
                          .clear,
                    )
                  : EmptyState(
                      icon: Icons.receipt_long,
                      title: l10n.noTransactionsInMonth(
                        DateFormat.yMMMM(
                          'en_US',
                        ).format(DateTime(month.year, month.month)),
                      ),
                      actionLabel: l10n.addFirstTransaction,
                      onAction: () => context.push(
                        '${Routes.transactionNew}?type=expense',
                      ),
                    ),
              data: (groups) => _TransactionList(groups: groups),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(transactionFilterControllerProvider);
    final controller = ref.read(transactionFilterControllerProvider.notifier);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    Category? selected;
    for (final c in categories) {
      if (c.id == filter.categoryId) selected = c;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('filter-type-all'),
            label: Text(l10n.filterAll),
            selected: filter.type == null,
            onSelected: (_) => controller.setType(null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('filter-type-expense'),
            label: Text(l10n.filterExpenses),
            selected: filter.type == TransactionType.expense,
            onSelected: (_) => controller.setType(TransactionType.expense),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            key: const Key('filter-type-income'),
            label: Text(l10n.filterIncome),
            selected: filter.type == TransactionType.income,
            onSelected: (_) => controller.setType(TransactionType.income),
          ),
          const SizedBox(width: 8),
          ActionChip(
            key: const Key('filter-category'),
            avatar: const Icon(Icons.label_outline, size: 18),
            label: Text(selected?.name ?? l10n.allCategories),
            onPressed: () => _pickCategory(context, ref, categories),
          ),
          if (filter.isActive) ...[
            const SizedBox(width: 8),
            ActionChip(
              key: const Key('filter-clear'),
              avatar: const Icon(Icons.close, size: 18),
              label: Text(l10n.clearFilters),
              onPressed: controller.clear,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCategory(
    BuildContext context,
    WidgetRef ref,
    List<Category> categories,
  ) async {
    final l10n = context.l10n;
    final type = ref.read(transactionFilterControllerProvider).type;
    final options = [
      for (final c in categories)
        if (type == null || c.type == type) c,
    ];
    final controller = ref.read(transactionFilterControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              key: const Key('filter-category-all'),
              title: Text(l10n.allCategories),
              onTap: () {
                controller.setCategory(null);
                Navigator.of(sheetContext).pop();
              },
            ),
            for (final c in options)
              ListTile(
                key: Key('filter-category-${c.id}'),
                leading: CategoryAvatar(icon: c.icon, color: c.color, size: 32),
                title: Text(c.name),
                onTap: () {
                  controller.setCategory(c.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({required this.groups});

  final List<TransactionDayGroup> groups;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[
      for (final group in groups) ...[group, ...group.items],
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        final TransactionDayGroup group => _DayHeader(group: group),
        final TransactionListItem item => _TransactionRow(item: item),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group});

  final TransactionDayGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = group.day;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat(
                'EEE, MMM d',
                'en_US',
              ).format(DateTime(day.year, day.month, day.day)),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          MoneyText(
            group.net,
            signed: true,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends ConsumerWidget {
  const _TransactionRow({required this.item});

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tx = item.transaction;
    final category = item.category;
    final isExpense = tx.type == TransactionType.expense;
    final currency = ref.watch(
      settingsControllerProvider.select((s) => s.currencyCode),
    );
    final amount = Money(
      isExpense ? -tx.amountMinor : tx.amountMinor,
      currency,
    );
    return Dismissible(
      key: Key('tx-row-${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      // The stream removes the row once soft-deleted; never let Dismissible
      // remove it by itself.
      confirmDismiss: (_) async {
        await confirmAndDeleteTransaction(context, ref, tx.id);
        return false;
      },
      child: ListTile(
        leading: CategoryAvatar(icon: category?.icon, color: category?.color),
        title: Text(category?.name ?? l10n.unknownCategory),
        subtitle: tx.note == null
            ? null
            : Text(tx.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: MoneyText(
          amount,
          tone: isExpense ? MoneyTone.expense : MoneyTone.income,
          signed: true,
        ),
        onTap: () => context.push(Routes.transactionEdit(tx.id)),
      ),
    );
  }
}
