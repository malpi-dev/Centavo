import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'transactions_test_helpers.dart';

Future<void> openNewForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('fab-add-transaction')));
  await tester.pumpAndSettle();
}

Future<void> enterAmount(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('tx-amount')), text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tx-save')));
  await tester.pumpAndSettle();
}

final Finder _food = find.byKey(
  const Key('tx-category-${DefaultCategoryIds.food}'),
);

void main() {
  testCentavo(r'creating an expense of 12.50 in Food lists it as -$12.50', (
    tester,
  ) async {
    await openTransactions(tester);
    await openNewForm(tester);
    expect(find.text('New transaction'), findsOneWidget);
    await enterAmount(tester, '12.50');
    await tester.tap(_food);
    await tester.pump();
    await save(tester);

    expect(find.text('New transaction'), findsNothing);
    expect(inRow(r'−$12.50'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
  });

  testCentavo('invalid amounts show the matching error', (tester) async {
    await openTransactions(tester);
    await openNewForm(tester);
    await tester.tap(_food);
    await tester.pump();

    await save(tester);
    expect(find.text('Required'), findsOneWidget);

    await enterAmount(tester, '0');
    await save(tester);
    expect(find.text('Must be greater than 0'), findsOneWidget);

    await enterAmount(tester, '1.234');
    await save(tester);
    expect(find.text('Too many decimal places'), findsOneWidget);
    expect(find.text('New transaction'), findsOneWidget);
  });

  testCentavo('a missing category shows Required under the chips', (
    tester,
  ) async {
    await openTransactions(tester);
    await openNewForm(tester);
    await enterAmount(tester, '5');
    await save(tester);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('New transaction'), findsOneWidget);
  });

  testCentavo('switching to Income drops the selected expense category', (
    tester,
  ) async {
    await openTransactions(tester);
    await openNewForm(tester);
    await enterAmount(tester, '5');
    await tester.tap(_food);
    await tester.pump();
    expect(tester.widget<ChoiceChip>(_food).selected, isTrue);

    await tester.tap(find.byKey(const Key('tx-type-income')));
    await tester.pumpAndSettle();
    expect(_food, findsNothing);
    expect(
      find.byKey(const Key('tx-category-${DefaultCategoryIds.salary}')),
      findsOneWidget,
    );
    await save(tester);
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('New transaction'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tx-type-expense')));
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(_food).selected, isFalse);
  });

  testCentavo('editing prefills the form and saves the change', (tester) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(
      tester,
      container,
      amountMinor: 1250,
      note: 'Lunch',
    );
    await tester.tap(find.byKey(Key('tx-row-${tx!.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tx-amount')))
          .controller!
          .text,
      '12.50',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('tx-note')))
          .controller!
          .text,
      'Lunch',
    );
    expect(tester.widget<ChoiceChip>(_food).selected, isTrue);

    await enterAmount(tester, '20');
    await save(tester);
    expect(find.text('Edit transaction'), findsNothing);
    expect(inRow(r'−$20.00'), findsOneWidget);
    expect(find.text(r'−$12.50'), findsNothing);
  });

  testCentavo('editing keeps an archived category selectable', (tester) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(tester, container);
    await runRepo(
      tester,
      () => container
          .read(categoryRepositoryProvider)
          .archive(DefaultCategoryIds.food),
    );
    await tester.tap(find.byKey(Key('tx-row-${tx!.id}')));
    await tester.pumpAndSettle();
    expect(_food, findsOneWidget);
    expect(tester.widget<ChoiceChip>(_food).selected, isTrue);
  });

  testCentavo('CLP rejects decimals and accepts whole amounts', (tester) async {
    await openTransactions(
      tester,
      settings: const AppSettings(
        onboardingCompleted: true,
        currencyCode: 'CLP',
      ),
    );
    await openNewForm(tester);
    await tester.tap(_food);
    await tester.pump();

    await enterAmount(tester, '12.5');
    await save(tester);
    expect(find.text('Too many decimal places'), findsOneWidget);

    await enterAmount(tester, '5000');
    await save(tester);
    expect(find.text('New transaction'), findsNothing);
    expect(inRow(r'−$5,000'), findsOneWidget);
  });

  testCentavo('income can be created from the form', (tester) async {
    await openTransactions(tester);
    await openNewForm(tester);
    await tester.tap(find.byKey(const Key('tx-type-income')));
    await tester.pumpAndSettle();
    await enterAmount(tester, '100');
    await tester.tap(
      find.byKey(const Key('tx-category-${DefaultCategoryIds.salary}')),
    );
    await tester.pump();
    await save(tester);
    expect(find.text(r'+$100.00'), findsWidgets);
  });
}

/// Amount text inside a list row (the day header repeats the net).
Finder inRow(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));
