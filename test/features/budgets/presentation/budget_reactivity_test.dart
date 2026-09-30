import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'budgets_test_helpers.dart';

void main() {
  testCentavo('a new expense updates the spent amount of its line', (
    tester,
  ) async {
    final container = await openBudgets(tester);
    await setLimit(tester, container, DefaultCategoryIds.food, october, 60000);
    expect(find.text(r'$0.00 of $600.00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('fab-add-transaction')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tx-amount')), '12.50');
    await tester.tap(
      find.byKey(const Key('tx-category-${DefaultCategoryIds.food}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('tx-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tx-save')), findsNothing);
    expect(find.text(r'$12.50 of $600.00'), findsOneWidget);
  });
}
