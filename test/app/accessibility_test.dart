// Tap targets (>= 48 dp) and text contrast on the key screens, in both themes.
import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/router/app_router.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_centavo.dart';

void main() {
  for (final theme in [AppThemePreference.light, AppThemePreference.dark]) {
    testCentavo('key screens meet the a11y guidelines, ${theme.name}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final app = await pumpCentavo(
        tester,
        settings: AppSettings(themePreference: theme),
        size: const Size(411, 891),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      app.container.read(appModeControllerProvider.notifier).enterDemo();
      await tester.pumpAndSettle();
      final router = app.container.read(appRouterProvider);
      final routes = {
        'Dashboard': Routes.dashboard,
        'Transactions': Routes.transactions,
        'Transaction form': Routes.transactionNew,
        'Budgets': Routes.budgets,
        'Budget form': Routes.budgetEditFor(
          DefaultCategoryIds.food,
          const YearMonth(2026, 10),
        ),
        'Settings': Routes.settings,
        'Categories': Routes.categories,
        'Category form': Routes.categoryNew,
        'Backup': Routes.backup,
      };
      for (final entry in routes.entries) {
        router.go(entry.value);
        await tester.pumpAndSettle();
        await expectLater(
          tester,
          meetsGuideline(androidTapTargetGuideline),
          reason: '${entry.key} tap targets',
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: '${entry.key} contrast',
        );
      }
      semantics.dispose();
    });
  }
}
