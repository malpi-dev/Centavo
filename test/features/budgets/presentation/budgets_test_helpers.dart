import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

/// Test clock is 2026-10-15.
const october = YearMonth(2026, 10);
const september = YearMonth(2026, 9);

/// Pumps the app past onboarding, seeds default categories and opens Budgets.
Future<ProviderContainer> openBudgets(WidgetTester tester) async {
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
  await tester.tap(find.byKey(const Key('tab-budgets')));
  await tester.pumpAndSettle();
  return app.container;
}

Future<void> setLimit(
  WidgetTester tester,
  ProviderContainer container,
  String categoryId,
  YearMonth month,
  int limitMinor,
) => runRepo(
  tester,
  () => container
      .read(budgetRepositoryProvider)
      .setLimit(categoryId: categoryId, month: month, limitMinor: limitMinor),
);
