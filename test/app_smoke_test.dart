import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_centavo.dart';

void main() {
  testCentavo('welcome, then Start fresh reveals the tab bar', (tester) async {
    await pumpCentavo(tester);
    expect(find.text('Start fresh'), findsOneWidget);

    await tester.tap(find.byKey(const Key('welcome-start-fresh')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in [
      'tab-dashboard',
      'tab-transactions',
      'tab-budgets',
      'tab-settings',
    ]) {
      expect(find.byKey(Key(tab)), findsOneWidget, reason: tab);
    }
    await tester.tap(find.byKey(const Key('tab-budgets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budgets-not-budgeted')), findsOneWidget);
  });

  testWidgets('onboarded users land on the dashboard', (tester) async {
    await pumpCentavo(
      tester,
      settings: const AppSettings(onboardingCompleted: true),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Start fresh'), findsNothing);
  });
}
