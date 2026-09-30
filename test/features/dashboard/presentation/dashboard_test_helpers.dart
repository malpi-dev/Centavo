import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import '../../transactions/presentation/transactions_test_helpers.dart';

/// Test clock is 2026-10-15.
const october = YearMonth(2026, 10);
const september = YearMonth(2026, 9);

/// Pumps the app past onboarding with default categories; Dashboard is the
/// initial tab.
Future<ProviderContainer> openDashboard(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingCompleted: true),
}) async {
  final container = await openTransactions(tester, settings: settings);
  await tester.tap(find.byKey(const Key('tab-dashboard')));
  await tester.pumpAndSettle();
  return container;
}

Text amountText(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(Key('$id-amount')));

Future<ProviderContainer> pumpDemo(WidgetTester tester) async {
  final app = await pumpCentavo(tester);
  await tester.tap(find.byKey(const Key('welcome-explore-demo')));
  await tester.pumpAndSettle();
  return app.container;
}
