import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/get_budget_progress.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final todays = [
    LocalDate(2026, 10, 1),
    LocalDate(2026, 10, 15),
    LocalDate(2026, 10, 31),
    LocalDate(2027, 2, 28),
  ];

  for (final today in todays) {
    group('DemoDataset on $today', () {
      final clock = FixedClock(
        DateTime.utc(today.year, today.month, today.day, 12),
      );
      final data = DemoDataset.build(clock);
      final m0 = YearMonth.fromLocalDate(today);
      final byId = {for (final c in data.categories) c.id: c};

      test('has 13 categories, one archived', () {
        expect(data.categories, hasLength(13));
        expect(data.categories.where((c) => c.isArchived), hasLength(1));
        expect(byId[DemoDataset.oldCarId]!.isArchived, isTrue);
      });

      test('has no future transactions and none before M2', () {
        final first = m0.addMonths(-2).firstDay;
        for (final t in data.transactions) {
          expect(t.occurredOn.isAfter(today), isFalse, reason: t.id);
          expect(t.occurredOn.isBefore(first), isFalse, reason: t.id);
        }
        expect(
          data.transactions.any((t) => t.occurredOn == m0.firstDay),
          isTrue,
        );
      });

      test('every transaction points to a category of the same type', () {
        for (final t in data.transactions) {
          expect(byId[t.categoryId]?.type, t.type, reason: t.id);
        }
      });

      test('complete months have 35-60 transactions', () {
        for (final month in [m0.addMonths(-1), m0.addMonths(-2)]) {
          final count = data.transactions
              .where((t) => month.contains(t.occurredOn))
              .length;
          expect(count, inInclusiveRange(35, 60), reason: '$month');
        }
      });

      test('current month has an exceeded and a warning budget', () {
        final report = const GetBudgetProgress()(
          month: m0,
          budgets: data.budgets,
          transactions: data.transactions,
          categories: data.categories,
          currencyCode: DemoDataset.currencyCode,
        );
        BudgetStatus? statusOf(String name) => report.lines
            .where((l) => l.category.name == name)
            .map((l) => l.status)
            .firstOrNull;
        expect(statusOf('Coffee'), BudgetStatus.exceeded);
        expect(statusOf('Entertainment'), BudgetStatus.warning);
        expect(report.lines, hasLength(5));
      });

      test('budgets only cover expense categories; ids are unique', () {
        for (final b in data.budgets) {
          expect(byId[b.categoryId]!.type, TransactionType.expense);
        }
        expect(data.budgets, hasLength(15));
        expect(data.budgets.map((b) => b.id).toSet(), hasLength(15));
        expect(
          data.transactions.map((t) => t.id).toSet(),
          hasLength(data.transactions.length),
        );
        expect(data.categories.map((c) => c.id).toSet(), hasLength(13));
      });
    });
  }

  test('follows the documented pattern', () {
    final data = DemoDataset.build(FixedClock(DateTime.utc(2026, 10, 15, 12)));
    final first = data.transactions.first;
    expect(first.id, 'demo-tx-202608-001');
    expect(first.amountMinor, 320000);
    expect(first.createdAt, DateTime.utc(2026, 8, 1, 12, 0, 1));
    final oct = data.transactions.where(
      (t) => t.id.startsWith('demo-tx-202610'),
    );
    expect(oct.map((t) => t.note).take(4), [
      'Monthly salary',
      'Rent',
      'Latte',
      'Streaming subscription',
    ]);
    expect(
      data.transactions.where((t) => t.note == 'Car service'),
      hasLength(1),
    );
    expect(
      data.transactions.where((t) => t.note == 'Logo design'),
      hasLength(1),
    );
  });
}
