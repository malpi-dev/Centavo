import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

void main() {
  testCentavo(
    'Start fresh preselects the locale currency and seeds categories',
    (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('es', 'MX');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final app = await pumpCentavo(tester);

      expect(find.text('Explore demo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('welcome-start-fresh')));
      await tester.pumpAndSettle();

      expect(find.text('Choose your currency'), findsOneWidget);
      final group = tester.widget<RadioGroup<String>>(
        find.byType(RadioGroup<String>),
      );
      expect(group.groupValue, 'MXN');

      await tester.tap(find.byKey(const Key('currency-EUR')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('currency-continue')));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      final settings = app.container.read(settingsControllerProvider);
      expect(settings.currencyCode, 'EUR');
      expect(settings.onboardingCompleted, isTrue);
      final categories = await tester.runAsync(
        () => app.container.read(categoryRepositoryProvider).getAll(),
      );
      expect(categories, hasLength(10));
    },
  );
}
