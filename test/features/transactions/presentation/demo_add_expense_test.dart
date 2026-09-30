import 'package:centavo/app.dart';
import 'package:centavo/core/di/provider_retry.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_overrides.dart';

void main() {
  testWidgets('in demo, the FAB adds an expense to the current month', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(800, 1600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: noAutomaticRetry,
        overrides: testOverrides(),
        child: const CentavoApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('welcome-explore-demo')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fab-add-transaction')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tx-amount')), '12.50');
    await tester.tap(
      find.byKey(const Key('tx-category-${DemoDataset.coffeeId}')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('tx-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('tab-transactions')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(inRow(r'−$12.50'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
  });
}

/// Amount text inside a list row (the day header repeats the net).
Finder inRow(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));
