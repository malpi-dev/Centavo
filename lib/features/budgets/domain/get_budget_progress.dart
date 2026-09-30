import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_budget_progress.freezed.dart';

enum BudgetStatus { onTrack, warning, exceeded }

@freezed
abstract class BudgetLine with _$BudgetLine {
  const factory BudgetLine({
    required Budget budget,
    required Category category,
    required Money limit,
    required Money spent,

    /// May be negative.
    required Money remaining,

    /// spent / limit, 10000 = 100 %.
    required int basisPoints,
    required BudgetStatus status,
  }) = _BudgetLine;
}

@freezed
abstract class BudgetProgressReport with _$BudgetProgressReport {
  const factory BudgetProgressReport({
    /// Sorted by basisPoints desc, then category name.
    required List<BudgetLine> lines,
    required Money totalLimit,

    /// Spent in budgeted categories only.
    required Money totalSpent,

    /// Expenses in categories without a budget this month.
    required Money unbudgetedSpent,

    /// ACTIVE expense categories without budget (for "Set budget").
    required List<Category> categoriesWithoutBudget,
  }) = _BudgetProgressReport;
}

class GetBudgetProgress {
  const GetBudgetProgress();

  BudgetProgressReport call({
    required YearMonth month,
    required List<Budget> budgets,
    required List<MoneyTransaction> transactions,
    required List<Category> categories,
    required String currencyCode,
  }) {
    final categoriesById = {
      for (final c in categories)
        if (!c.isDeleted) c.id: c,
    };
    final spentByCategory = <String, int>{};
    for (final t in transactions) {
      if (t.deletedAt != null ||
          t.type != TransactionType.expense ||
          !month.contains(t.occurredOn)) {
        continue;
      }
      spentByCategory.update(
        t.categoryId,
        (v) => v + t.amountMinor,
        ifAbsent: () => t.amountMinor,
      );
    }

    final lines = <BudgetLine>[];
    final budgetedIds = <String>{};
    for (final b in budgets) {
      if (b.deletedAt != null || b.month != month) continue;
      final category = categoriesById[b.categoryId];
      if (category == null) continue;
      budgetedIds.add(b.categoryId);
      final spentMinor = spentByCategory[b.categoryId] ?? 0;
      final limit = Money(b.limitMinor, currencyCode);
      final spent = Money(spentMinor, currencyCode);
      lines.add(
        BudgetLine(
          budget: b,
          category: category,
          limit: limit,
          spent: spent,
          remaining: limit - spent,
          basisPoints: spent.basisPointsOf(limit),
          status: _statusOf(spentMinor, b.limitMinor),
        ),
      );
    }
    lines.sort((a, b) {
      final byPct = b.basisPoints.compareTo(a.basisPoints);
      if (byPct != 0) return byPct;
      return a.category.name.toLowerCase().compareTo(
        b.category.name.toLowerCase(),
      );
    });

    var totalLimit = Money.zero(currencyCode);
    var totalSpent = Money.zero(currencyCode);
    for (final line in lines) {
      totalLimit += line.limit;
      totalSpent += line.spent;
    }
    var unbudgeted = 0;
    spentByCategory.forEach((id, amount) {
      if (!budgetedIds.contains(id)) unbudgeted += amount;
    });

    final withoutBudget =
        categories
            .where(
              (c) =>
                  c.isActive &&
                  c.type == TransactionType.expense &&
                  !budgetedIds.contains(c.id),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return BudgetProgressReport(
      lines: lines,
      totalLimit: totalLimit,
      totalSpent: totalSpent,
      unbudgetedSpent: Money(unbudgeted, currencyCode),
      categoriesWithoutBudget: withoutBudget,
    );
  }

  /// Integer math: exactly 80 % and exactly 100 % are `warning`.
  static BudgetStatus _statusOf(int spent, int limit) {
    if (spent * 100 < limit * 80) return BudgetStatus.onTrack;
    if (spent <= limit) return BudgetStatus.warning;
    return BudgetStatus.exceeded;
  }
}
