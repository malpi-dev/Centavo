import 'dart:async';

import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/pump_centavo.dart';
import 'budgets_test_helpers.dart';

Future<void> openFoodForm(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('budget-set-${DefaultCategoryIds.food}')),
  );
  await tester.pumpAndSettle();
}

Future<void> enterLimit(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('budget-limit')), text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('budget-save')));
  await tester.pumpAndSettle();
}

void main() {
  testCentavo('Set budget on Food with 600 adds the line', (tester) async {
    await openBudgets(tester);
    await openFoodForm(tester);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text(r'Spent so far: $0.00'), findsOneWidget);
    expect(find.byKey(const Key('budget-remove')), findsNothing);

    await enterLimit(tester, '600');
    await save(tester);

    expect(find.byKey(const Key('budget-save')), findsNothing);
    expect(
      find.byKey(const Key('budget-line-${DefaultCategoryIds.food}')),
      findsOneWidget,
    );
    expect(find.text(r'$0.00 of $600.00'), findsOneWidget);
  });

  testCentavo('editing keeps the budget id and changes the limit', (
    tester,
  ) async {
    final container = await openBudgets(tester);
    await setLimit(tester, container, DefaultCategoryIds.food, october, 60000);
    final before = await runRepo(
      tester,
      () => container
          .read(budgetRepositoryProvider)
          .findActive(DefaultCategoryIds.food, october),
    );

    await tester.tap(
      find.byKey(const Key('budget-line-${DefaultCategoryIds.food}')),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('budget-limit')))
          .controller!
          .text,
      '600.00',
    );
    await enterLimit(tester, '750.50');
    await save(tester);

    expect(find.text(r'$0.00 of $750.50'), findsOneWidget);
    final after = await runRepo(
      tester,
      () => container
          .read(budgetRepositoryProvider)
          .findActive(DefaultCategoryIds.food, october),
    );
    expect(after!.id, before!.id);
    expect(after.limitMinor, 75050);
  });

  testCentavo('an empty or zero limit shows an error and stays', (
    tester,
  ) async {
    await openBudgets(tester);
    await openFoodForm(tester);

    await save(tester);
    expect(find.text('Required'), findsOneWidget);

    await enterLimit(tester, '0');
    await save(tester);
    expect(find.text('Must be greater than 0'), findsOneWidget);
    expect(find.byKey(const Key('budget-save')), findsOneWidget);
  });

  testCentavo('Remove budget confirms, removes and Food is not budgeted', (
    tester,
  ) async {
    final container = await openBudgets(tester);
    await setLimit(tester, container, DefaultCategoryIds.food, october, 60000);
    await tester.tap(
      find.byKey(const Key('budget-line-${DefaultCategoryIds.food}')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('budget-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove this budget?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('budget-remove-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Budget removed'), findsOneWidget);
    expect(
      find.byKey(const Key('budget-line-${DefaultCategoryIds.food}')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('budget-set-${DefaultCategoryIds.food}')),
      findsOneWidget,
    );
  });

  testCentavo('an invalid month in the URL shows the not found state', (
    tester,
  ) async {
    await openBudgets(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(
      router.push(
        '${Routes.budgetEdit}?category=${DefaultCategoryIds.food}&month=nope',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This item no longer exists.'), findsOneWidget);
    expect(find.byKey(const Key('budget-save')), findsNothing);
  });

  testCentavo('an income category in the URL shows the not found state', (
    tester,
  ) async {
    await openBudgets(tester);
    final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
    unawaited(
      router.push(Routes.budgetEditFor(DefaultCategoryIds.salary, october)),
    );
    await tester.pumpAndSettle();
    expect(find.text('This item no longer exists.'), findsOneWidget);
  });
}
