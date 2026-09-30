import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'budgets_test_helpers.dart';

Finder line(String id) => find.byKey(Key('budget-line-$id'));

Finder status(String id) => find.byKey(Key('budget-status-$id'));

void main() {
  testCentavo('an empty month with no earlier budgets has no Copy button', (
    tester,
  ) async {
    await openBudgets(tester);
    expect(find.text('No budgets for October 2026'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    // Every active expense category can still get a budget.
    expect(
      find.byKey(const Key('budget-set-${DefaultCategoryIds.food}')),
      findsOneWidget,
    );
    expect(find.text('Set a budget'), findsWidgets);
  });

  testCentavo('Copy from previous month creates the budgets', (tester) async {
    final container = await openBudgets(tester);
    await setLimit(
      tester,
      container,
      DefaultCategoryIds.food,
      september,
      60000,
    );
    await setLimit(
      tester,
      container,
      DefaultCategoryIds.transport,
      september,
      20000,
    );
    // Same month is still empty, so Copy appears.
    expect(find.text('Copy from previous month'), findsOneWidget);

    await tester.tap(find.text('Copy from previous month'));
    await tester.pumpAndSettle();

    expect(find.text('Copied 2 budgets'), findsOneWidget);
    expect(line(DefaultCategoryIds.food), findsOneWidget);
    expect(line(DefaultCategoryIds.transport), findsOneWidget);
    expect(find.text('Copy from previous month'), findsNothing);
    expect(find.text(r'Spent $0.00 of $800.00'), findsOneWidget);
  });

  testCentavo('lines show On track, Near limit and Over budget', (
    tester,
  ) async {
    final container = await openBudgets(tester);
    Future<void> spend(String categoryId, int amountMinor) => runRepo(
      tester,
      () => container
          .read(transactionRepositoryProvider)
          .create(
            TransactionDraft(
              type: TransactionType.expense,
              amountMinor: amountMinor,
              categoryId: categoryId,
              occurredOn: LocalDate(2026, 10, 5),
            ),
          ),
    );
    await setLimit(tester, container, DefaultCategoryIds.food, october, 60000);
    await setLimit(
      tester,
      container,
      DefaultCategoryIds.transport,
      october,
      10000,
    );
    await setLimit(
      tester,
      container,
      DefaultCategoryIds.shopping,
      october,
      10000,
    );
    await spend(DefaultCategoryIds.food, 10000);
    await spend(DefaultCategoryIds.transport, 9000);
    await spend(DefaultCategoryIds.shopping, 15000);
    // Not budgeted: counts only in "Unbudgeted spending".
    await spend(DefaultCategoryIds.home, 2500);

    expect(
      tester.widget<Text>(status(DefaultCategoryIds.food)).data,
      'On track',
    );
    expect(
      tester.widget<Text>(status(DefaultCategoryIds.transport)).data,
      'Near limit',
    );
    expect(
      tester.widget<Text>(status(DefaultCategoryIds.shopping)).data,
      'Over budget',
    );
    expect(find.text(r'$500.00 left'), findsOneWidget);
    expect(find.text(r'$10.00 left'), findsOneWidget);
    expect(find.text(r'Over by $50.00'), findsOneWidget);
    expect(find.text(r'Spent $340.00 of $800.00'), findsOneWidget);
    expect(find.text(r'Unbudgeted spending: $25.00'), findsOneWidget);
    // Budgeted categories leave the "Not budgeted" section.
    expect(
      find.byKey(const Key('budget-set-${DefaultCategoryIds.food}')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('budget-set-${DefaultCategoryIds.home}')),
      findsOneWidget,
    );
  });

  testCentavo('income categories never appear', (tester) async {
    await openBudgets(tester);
    expect(find.text('Salary'), findsNothing);
    expect(find.text('Freelance'), findsNothing);
    expect(find.text('Food'), findsOneWidget);
  });

  testCentavo('Next allows the following month but not the one after', (
    tester,
  ) async {
    await openBudgets(tester);
    await tester.tap(find.byKey(const Key('month-next')));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed,
      isNull,
    );
  });
}
