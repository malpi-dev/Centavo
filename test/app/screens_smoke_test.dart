// Visual smoke test: every main screen builds without exceptions or overflow
// in light and dark, on a small and a regular phone, at 1.0x and 1.3x text.
import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/router/app_router.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_centavo.dart';

const _sizes = {'360x640': Size(360, 640), '411x891': Size(411, 891)};

void main() {
  for (final theme in AppThemePreference.values.where(
    (t) => t != AppThemePreference.system,
  )) {
    for (final size in _sizes.entries) {
      for (final scale in [1.0, 1.3]) {
        final label = '${theme.name} ${size.key} x$scale';

        testCentavo('Welcome, $label', (tester) async {
          await pumpCentavo(
            tester,
            settings: AppSettings(themePreference: theme),
            size: size.value,
            textScale: scale,
          );
          expect(find.byKey(const Key('welcome-start-fresh')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testCentavo('Lock, $label', (tester) async {
          await pumpCentavo(
            tester,
            settings: AppSettings(
              onboardingCompleted: true,
              biometricLockEnabled: true,
              themePreference: theme,
            ),
            biometric: MockBiometricRepository(
              nextError: const BiometricError(BiometricErrorKind.lockedOut),
            ),
            size: size.value,
            textScale: scale,
          );
          expect(find.byKey(const Key('lock-error')), findsOneWidget);
          expect(tester.takeException(), isNull);
        });

        testCentavo('demo screens, $label', (tester) async {
          final app = await pumpCentavo(
            tester,
            settings: AppSettings(themePreference: theme),
            size: size.value,
            textScale: scale,
          );
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
            'Export': Routes.export,
            'Backup': Routes.backup,
          };
          for (final entry in routes.entries) {
            router.go(entry.value);
            await tester.pumpAndSettle();
            expect(
              router.routerDelegate.currentConfiguration.uri.path,
              Uri.parse(entry.value).path,
              reason: 'navigated to ${entry.key}',
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} at $label',
            );
          }
        });
      }
    }
  }
}
