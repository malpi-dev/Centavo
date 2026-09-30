import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import 'transactions_test_helpers.dart';

Future<void> swipe(WidgetTester tester, Finder row) async {
  await tester.drag(row, const Offset(-600, 0));
  await tester.pumpAndSettle();
}

void main() {
  testCentavo('swipe, confirm, row disappears, Undo brings it back', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(tester, container, amountMinor: 1250);
    final row = find.byKey(Key('tx-row-${tx!.id}'));
    expect(row, findsOneWidget);

    await swipe(tester, row);
    expect(find.text('Delete transaction?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tx-delete-confirm')));
    await tester.pumpAndSettle();

    expect(row, findsNothing);
    expect(find.text('Transaction deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('tx-row-${tx.id}')), findsOneWidget);
    expect(inRow(r'−$12.50'), findsOneWidget);
  });

  testCentavo('cancelling the dialog does not delete', (tester) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(tester, container);
    final row = find.byKey(Key('tx-row-${tx!.id}'));

    await swipe(tester, row);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(row, findsOneWidget);
    expect(find.text('Transaction deleted'), findsNothing);
  });

  testCentavo('the snack bar disappears after about 4 seconds', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(tester, container);
    await swipe(tester, find.byKey(Key('tx-row-${tx!.id}')));
    await tester.tap(find.byKey(const Key('tx-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Transaction deleted'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Transaction deleted'), findsNothing);
  });

  testCentavo('deleting from the form pops and keeps the Undo snack bar', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    final tx = await addTransaction(tester, container);
    await tester.tap(find.byKey(Key('tx-row-${tx!.id}')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tx-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tx-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Edit transaction'), findsNothing);
    expect(find.byKey(Key('tx-row-${tx.id}')), findsNothing);
    expect(find.text('Transaction deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}

/// Amount text inside a list row (the day header repeats the net).
Finder inRow(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));
