import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

Future<ProviderContainer> openCategories(WidgetTester tester) async {
  final app = await pumpCentavo(
    tester,
    settings: const AppSettings(onboardingCompleted: true),
  );
  await runRepo(
    tester,
    () => app.container
        .read(categoryRepositoryProvider)
        .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
  );
  await tester.tap(find.byKey(const Key('tab-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-categories')));
  await tester.pumpAndSettle();
  return app.container;
}

Future<void> openNewExpenseForm(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('categories-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('categories-add-expense')));
  await tester.pumpAndSettle();
}

Future<void> openMenuAction(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(const Key('category-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

final Finder _foodRow = find.byKey(
  const Key('category-${DefaultCategoryIds.food}'),
);

void main() {
  testCentavo('creating a category adds it to the list', (tester) async {
    await openCategories(tester);
    await openNewExpenseForm(tester);
    await tester.enterText(find.byKey(const Key('category-name')), 'Coffee');
    await tester.tap(find.byKey(const Key('category-icon-coffee')));
    await tester.tap(find.byKey(const Key('category-color-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('category-save')));
    await tester.pumpAndSettle();

    expect(find.text('New category'), findsNothing);
    expect(find.text('Coffee'), findsOneWidget);
  });

  testCentavo('an empty name shows Required', (tester) async {
    await openCategories(tester);
    await openNewExpenseForm(tester);
    await tester.tap(find.byKey(const Key('category-save')));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(find.text('New category'), findsOneWidget);
  });

  testCentavo('a duplicate name shows the error on the name field', (
    tester,
  ) async {
    await openCategories(tester);
    await openNewExpenseForm(tester);
    await tester.enterText(find.byKey(const Key('category-name')), 'food');
    await tester.tap(find.byKey(const Key('category-save')));
    await tester.pumpAndSettle();
    expect(
      find.text('An item with that name already exists.'),
      findsOneWidget,
    );
    expect(find.text('New category'), findsOneWidget);
  });

  testCentavo('the type selector is disabled when editing', (tester) async {
    await openCategories(tester);
    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    final selector = tester.widget<SegmentedButton<TransactionType>>(
      find.byKey(const Key('category-type')),
    );
    expect(selector.onSelectionChanged, isNull);
    expect(find.text("The type can't be changed"), findsOneWidget);
  });

  testCentavo('editing a category renames it', (tester) async {
    await openCategories(tester);
    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('category-name')), 'Meals');
    await tester.tap(find.byKey(const Key('category-save')));
    await tester.pumpAndSettle();
    expect(find.text('Meals'), findsOneWidget);
    expect(find.text('Food'), findsNothing);
  });

  testCentavo('deleting a category without transactions removes it', (
    tester,
  ) async {
    await openCategories(tester);
    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    await openMenuAction(tester, 'category-delete');
    await tester.tap(find.byKey(const Key('category-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Category deleted'), findsOneWidget);
    expect(_foodRow, findsNothing);
    expect(find.text('Archived'), findsNothing);
  });

  testCentavo('deleting a category with transactions archives it', (
    tester,
  ) async {
    final container = await openCategories(tester);
    await runRepo(
      tester,
      () => container
          .read(transactionRepositoryProvider)
          .create(
            TransactionDraft(
              type: TransactionType.expense,
              amountMinor: 1000,
              categoryId: DefaultCategoryIds.food,
              occurredOn: LocalDate(2026, 10, 5),
            ),
          ),
    );
    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    await openMenuAction(tester, 'category-delete');
    await tester.tap(find.byKey(const Key('category-delete-confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text('Category archived because it has transactions.'),
      findsOneWidget,
    );
    expect(find.text('Archived'), findsOneWidget);
    expect(_foodRow, findsOneWidget);
  });

  testCentavo('archiving then unarchiving returns it to its section', (
    tester,
  ) async {
    await openCategories(tester);
    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    await openMenuAction(tester, 'category-archive');
    expect(find.text('Category archived'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    // Let the first SnackBar go away so the next one shows immediately.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    await tester.tap(_foodRow);
    await tester.pumpAndSettle();
    await openMenuAction(tester, 'category-archive');
    expect(find.text('Category unarchived'), findsOneWidget);
    expect(find.text('Archived'), findsNothing);
    expect(_foodRow, findsOneWidget);
  });
}
