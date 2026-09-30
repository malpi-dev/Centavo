import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/get_budget_progress.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  const month = YearMonth(2026, 10);
  const useCase = GetBudgetProgress();

  BudgetProgressReport run({
    List<Budget>? budgets,
    List<MoneyTransaction> transactions = const [],
    List<Category>? categories,
  }) => useCase(
    month: month,
    budgets: budgets ?? [aBudget()],
    transactions: transactions,
    categories: categories ?? [aCategory()],
    currencyCode: 'USD',
  );

  BudgetStatus statusFor(int spent, {int limit = 10000}) => run(
    budgets: [aBudget(limitMinor: limit)],
    transactions: [aTransaction(amountMinor: spent)],
  ).lines.single.status;

  group('status thresholds (integer math)', () {
    test('79.99 % is onTrack', () {
      expect(statusFor(7999), BudgetStatus.onTrack);
    });
    test('exactly 80 % is warning', () {
      expect(statusFor(8000), BudgetStatus.warning);
    });
    test('exactly 100 % is warning', () {
      expect(statusFor(10000), BudgetStatus.warning);
    });
    test('100.01 % is exceeded', () {
      expect(statusFor(10001), BudgetStatus.exceeded);
      expect(statusFor(100001, limit: 100000), BudgetStatus.exceeded);
    });
    test('no spending is onTrack', () {
      expect(run().lines.single.status, BudgetStatus.onTrack);
    });
  });

  test('computes limit, spent, remaining and basis points', () {
    final line = run(
      transactions: [aTransaction(amountMinor: 2500)],
    ).lines.single;
    expect(line.limit, const Money(10000, 'USD'));
    expect(line.spent, const Money(2500, 'USD'));
    expect(line.remaining, const Money(7500, 'USD'));
    expect(line.basisPoints, 2500);
  });

  test('remaining can be negative', () {
    final line = run(
      transactions: [aTransaction(amountMinor: 12000)],
    ).lines.single;
    expect(line.remaining, const Money(-2000, 'USD'));
    expect(line.basisPoints, 12000);
  });

  test('income and other months and deleted rows do not count', () {
    final report = run(
      transactions: [
        aTransaction(id: 'a', type: TransactionType.income, amountMinor: 5000),
        aTransaction(
          id: 'b',
          amountMinor: 5000,
          occurredOn: LocalDate(2026, 9, 30),
        ),
        aTransaction(
          id: 'c',
          amountMinor: 5000,
          occurredOn: LocalDate(2026, 11, 1),
        ),
        aTransaction(
          id: 'd',
          amountMinor: 5000,
          deletedAt: DateTime.utc(2026, 10, 6),
        ),
        aTransaction(id: 'e', amountMinor: 300),
      ],
    );
    expect(report.lines.single.spent, const Money(300, 'USD'));
    expect(report.totalSpent, const Money(300, 'USD'));
  });

  test('unbudgetedSpent sums expenses of categories without budget', () {
    final report = run(
      categories: [
        aCategory(),
        aCategory(id: 'cat-2', name: 'Fun'),
      ],
      transactions: [
        aTransaction(amountMinor: 100),
        aTransaction(id: 'x', categoryId: 'cat-2', amountMinor: 700),
        aTransaction(id: 'y', categoryId: 'cat-2', amountMinor: 50),
      ],
    );
    expect(report.unbudgetedSpent, const Money(750, 'USD'));
    expect(report.totalSpent, const Money(100, 'USD'));
    expect(report.totalLimit, const Money(10000, 'USD'));
  });

  test('categoriesWithoutBudget excludes archived, income and budgeted', () {
    final report = run(
      categories: [
        aCategory(),
        aCategory(id: 'free', name: 'Zeta'),
        aCategory(id: 'free2', name: 'Alpha'),
        aCategory(id: 'arch', name: 'Old', archivedAt: DateTime.utc(2026)),
        aCategory(id: 'del', name: 'Gone', deletedAt: DateTime.utc(2026)),
        aCategory(
          id: 'inc',
          name: 'Salary',
          type: TransactionType.income,
        ),
      ],
    );
    expect(report.categoriesWithoutBudget.map((c) => c.id), ['free2', 'free']);
  });

  test('lines sorted by basisPoints desc, then category name', () {
    final report = run(
      budgets: [
        aBudget(id: 'b1'),
        aBudget(id: 'b2', categoryId: 'cat-2'),
        aBudget(id: 'b3', categoryId: 'cat-3'),
      ],
      categories: [
        aCategory(name: 'Zed'),
        aCategory(id: 'cat-2', name: 'Bravo'),
        aCategory(id: 'cat-3', name: 'Alpha'),
      ],
      transactions: [
        aTransaction(amountMinor: 5000),
        aTransaction(id: 'x', categoryId: 'cat-2', amountMinor: 9000),
        aTransaction(id: 'y', categoryId: 'cat-3', amountMinor: 5000),
      ],
    );
    expect(report.lines.map((l) => l.category.name), ['Bravo', 'Alpha', 'Zed']);
  });

  test('budget of a deleted or missing category is ignored', () {
    final report = run(
      budgets: [
        aBudget(),
        aBudget(id: 'b2', categoryId: 'ghost'),
      ],
      categories: [aCategory(deletedAt: DateTime.utc(2026))],
    );
    expect(report.lines, isEmpty);
    expect(report.totalLimit, const Money.zero('USD'));
  });

  test('budget of an archived category is still shown', () {
    final report = run(
      categories: [aCategory(archivedAt: DateTime.utc(2026))],
    );
    expect(report.lines, hasLength(1));
  });

  test('budgets of other months are ignored', () {
    final report = run(
      budgets: [aBudget(month: const YearMonth(2026, 9))],
    );
    expect(report.lines, isEmpty);
  });
}
