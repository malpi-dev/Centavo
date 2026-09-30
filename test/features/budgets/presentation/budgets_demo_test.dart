import 'package:centavo/app.dart';
import 'package:centavo/core/di/provider_retry.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_overrides.dart';

void main() {
  testWidgets('demo, current month: Coffee is over budget, Entertainment near '
      'its limit', (tester) async {
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
    await tester.tap(find.byKey(const Key('tab-budgets')));
    await tester.pumpAndSettle();

    String statusOf(String id) =>
        tester.widget<Text>(find.byKey(Key('budget-status-$id'))).data!;
    expect(statusOf(DemoDataset.coffeeId), 'Over budget');
    expect(find.byKey(const Key('budgets-summary')), findsOneWidget);
    final entertainment = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'Near limit',
    );
    expect(entertainment, findsOneWidget);
  });
}
