import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/dashboard/domain/get_month_summary.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  const month = YearMonth(2026, 10);
  const useCase = GetMonthSummary();

  MonthSummary run(
    List<MoneyTransaction> txs,
    List<Category> cats, {
    int topN = 5,
  }) => useCase(
    month: month,
    transactions: txs,
    categories: cats,
    currencyCode: 'USD',
    topN: topN,
  );

  List<Category> cats(int n) => [
    for (var i = 1; i <= n; i++) aCategory(id: 'c$i', name: 'Cat $i'),
  ];

  test('totals are exact sums in minor units', () {
    final summary = run(
      [
        aTransaction(id: '1', amountMinor: 1001),
        aTransaction(id: '2', amountMinor: 2),
        aTransaction(
          id: '3',
          type: TransactionType.income,
          amountMinor: 500000,
        ),
      ],
      cats(1),
    );
    expect(summary.expense, const Money(1003, 'USD'));
    expect(summary.income, const Money(500000, 'USD'));
    expect(summary.balance, const Money(498997, 'USD'));
    expect(summary.transactionCount, 3);
  });

  test('balance can be negative', () {
    final summary = run([aTransaction(amountMinor: 300)], cats(1));
    expect(summary.balance, const Money(-300, 'USD'));
  });

  test('7 categories give top 5 plus Others', () {
    final summary = run([
      for (var i = 1; i <= 7; i++)
        aTransaction(id: 't$i', categoryId: 'c$i', amountMinor: i * 100),
    ], cats(7));
    expect(summary.expenseSlices, hasLength(6));
    final others = summary.expenseSlices.last;
    expect(others.categoryId, isNull);
    expect(others.name, isNull);
    expect(others.amount, const Money(300, 'USD')); // 100 + 200
    expect(summary.expenseSlices.first.categoryId, 'c7');
  });

  test('5 categories give 5 slices without Others', () {
    final summary = run([
      for (var i = 1; i <= 5; i++)
        aTransaction(id: 't$i', categoryId: 'c$i', amountMinor: i * 100),
    ], cats(5));
    expect(summary.expenseSlices, hasLength(5));
    expect(summary.expenseSlices.every((s) => s.categoryId != null), isTrue);
  });

  test('ties are broken by name ascending', () {
    final summary = run(
      [
        aTransaction(id: '1', categoryId: 'b', amountMinor: 500),
        aTransaction(id: '2', categoryId: 'a', amountMinor: 500),
      ],
      [aCategory(id: 'a', name: 'Alpha'), aCategory(id: 'b', name: 'Beta')],
    );
    expect(summary.expenseSlices.map((s) => s.name), ['Alpha', 'Beta']);
  });

  test('basisPoints are the share of total expenses', () {
    final summary = run(
      [
        aTransaction(id: '1', categoryId: 'a', amountMinor: 7500),
        aTransaction(id: '2', categoryId: 'b', amountMinor: 2500),
      ],
      [aCategory(id: 'a', name: 'A'), aCategory(id: 'b', name: 'B')],
    );
    expect(summary.expenseSlices.map((s) => s.basisPoints), [7500, 2500]);
  });

  test('slice carries category data', () {
    final summary = run([aTransaction(categoryId: 'c1')], cats(1));
    final slice = summary.expenseSlices.single;
    expect(slice.name, 'Cat 1');
    expect(slice.icon, 'food');
    expect(slice.color, 0xFFE65100);
  });

  test('empty month is isEmpty', () {
    final summary = run([], cats(1));
    expect(summary.isEmpty, isTrue);
    expect(summary.expenseSlices, isEmpty);
    expect(summary.balance, const Money.zero('USD'));
  });

  test('ignores deleted transactions and other months', () {
    final summary = run([
      aTransaction(id: '1', amountMinor: 100, deletedAt: DateTime.utc(2026)),
      aTransaction(
        id: '2',
        amountMinor: 100,
        occurredOn: LocalDate(2026, 9, 30),
      ),
      aTransaction(
        id: '3',
        amountMinor: 100,
        occurredOn: LocalDate(2026, 11, 1),
      ),
      aTransaction(id: '4', amountMinor: 7),
    ], cats(1));
    expect(summary.expense, const Money(7, 'USD'));
    expect(summary.transactionCount, 1);
  });
}
