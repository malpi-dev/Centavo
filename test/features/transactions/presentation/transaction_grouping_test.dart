import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/transactions/presentation/transaction_grouping.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  final food = aCategory();
  final salary = aCategory(
    id: 'cat-2',
    name: 'Salary',
    type: TransactionType.income,
  );
  final transactions = [
    aTransaction(id: 'a', amountMinor: 500, occurredOn: LocalDate(2026, 10, 9)),
    aTransaction(
      id: 'b',
      type: TransactionType.income,
      amountMinor: 3000,
      categoryId: 'cat-2',
      occurredOn: LocalDate(2026, 10, 9),
    ),
    aTransaction(id: 'c', amountMinor: 700, occurredOn: LocalDate(2026, 10, 3)),
    aTransaction(
      id: 'd',
      amountMinor: 900,
      categoryId: 'gone',
      occurredOn: LocalDate(2026, 10, 12),
    ),
  ];

  List<TransactionDayGroup> group([
    TransactionFilter filter = const TransactionFilter(),
  ]) => groupTransactionsByDay(
    transactions: transactions,
    categories: [food, salary],
    filter: filter,
    currencyCode: 'USD',
  );

  test('groups by day, most recent first, keeping repository order', () {
    final groups = group();
    expect(groups.map((g) => g.day), [
      LocalDate(2026, 10, 12),
      LocalDate(2026, 10, 9),
      LocalDate(2026, 10, 3),
    ]);
    expect(groups[1].items.map((i) => i.transaction.id), ['a', 'b']);
  });

  test('computes income, expense and net per day', () {
    final day = group()[1];
    expect(day.income, const Money(3000, 'USD'));
    expect(day.expense, const Money(500, 'USD'));
    expect(day.net, const Money(2500, 'USD'));
  });

  test('filters by type', () {
    final groups = group(const TransactionFilter(type: TransactionType.income));
    expect(groups, hasLength(1));
    expect(groups.single.items.single.transaction.id, 'b');
  });

  test('filters by category', () {
    final groups = group(const TransactionFilter(categoryId: 'cat-1'));
    expect(
      groups.expand((g) => g.items).map((i) => i.transaction.id),
      ['a', 'c'],
    );
  });

  test('a missing category yields a null category', () {
    final item = group().first.items.single;
    expect(item.transaction.id, 'd');
    expect(item.category, isNull);
  });

  test('an empty result gives no groups', () {
    expect(group(const TransactionFilter(categoryId: 'nope')), isEmpty);
  });
}
