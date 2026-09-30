import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'transactions_test_helpers.dart';

void main() {
  testCentavo('empty month without filters offers to add the first one', (
    tester,
  ) async {
    await openTransactions(tester);
    expect(find.text('No transactions in October 2026'), findsOneWidget);
    expect(find.text('Add your first transaction'), findsOneWidget);
    expect(find.text('Clear filters'), findsNothing);
  });

  testCentavo('empty result with filters offers Clear filters', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    await addTransaction(tester, container);
    await tester.tap(find.byKey(const Key('filter-type-income')));
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    expect(find.byKey(const Key('filter-clear')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Clear filters'));
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsWidgets);
    expect(find.text('No results'), findsNothing);
  });

  testCentavo('rows show sign, day header and net; filters narrow the list', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    await addTransaction(tester, container, amountMinor: 1250, note: 'Lunch');
    await addTransaction(
      tester,
      container,
      type: TransactionType.income,
      categoryId: DefaultCategoryIds.salary,
      amountMinor: 300000,
    );

    expect(find.text('Mon, Oct 5'), findsOneWidget);
    expect(inRow(r'−$12.50'), findsOneWidget);
    expect(inRow(r'+$3,000.00'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text(r'+$2,987.50'), findsOneWidget); // day net

    await tester.tap(find.byKey(const Key('filter-type-expense')));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Food'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-category')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('filter-category-${DefaultCategoryIds.food}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Food'), findsWidgets);
    await tester.tap(find.byKey(const Key('filter-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Salary'), findsOneWidget);
  });

  testCentavo('changing month changes the list; Next is disabled now', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    await addTransaction(tester, container, note: 'October');
    await addTransaction(
      tester,
      container,
      note: 'September',
      occurredOn: LocalDate(2026, 9, 20),
    );

    expect(find.text('October'), findsOneWidget);
    final next = tester.widget<IconButton>(find.byKey(const Key('month-next')));
    expect(next.onPressed, isNull);

    await tester.tap(find.byKey(const Key('month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('September'), findsOneWidget);
    expect(find.text('October'), findsNothing);
    final nextNow = tester.widget<IconButton>(
      find.byKey(const Key('month-next')),
    );
    expect(nextNow.onPressed, isNotNull);
  });

  testCentavo('a stream error shows Retry', (tester) async {
    await pumpCentavo(
      tester,
      settings: const AppSettings(onboardingCompleted: true),
      overrides: [
        monthTransactionsProvider.overrideWith(
          (ref, month) =>
              Stream<List<MoneyTransaction>>.error(const StorageError()),
        ),
      ],
    );
    await tester.tap(find.byKey(const Key('tab-transactions')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-retry')), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

/// Amount text inside a list row (the day header repeats the net).
Finder inRow(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));
