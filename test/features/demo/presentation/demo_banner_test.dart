import 'package:centavo/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_overrides.dart';

void main() {
  testWidgets('Explore demo shows the banner on every tab; Exit demo leaves', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const CentavoApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-banner')), findsNothing);

    await tester.tap(find.byKey(const Key('welcome-explore-demo')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);

    for (final tab in [
      'tab-dashboard',
      'tab-transactions',
      'tab-budgets',
      'tab-settings',
    ]) {
      await tester.tap(find.byKey(Key(tab)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-banner')), findsOneWidget, reason: tab);
      expect(find.text("Demo mode — changes aren't saved"), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('demo-exit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-banner')), findsNothing);
    expect(find.byKey(const Key('welcome-explore-demo')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
