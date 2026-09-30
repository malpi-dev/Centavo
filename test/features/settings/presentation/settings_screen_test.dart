import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/security/data/noop_secure_window_service.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

const _onboarded = AppSettings(onboardingCompleted: true);

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('tab-settings')));
  await tester.pumpAndSettle();
}

void main() {
  testCentavo('choosing Dark changes the theme mode', (tester) async {
    final app = await pumpCentavo(tester, settings: _onboarded);
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-theme')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-dark')));
    await tester.pumpAndSettle();

    expect(
      app.container.read(settingsControllerProvider).themePreference,
      AppThemePreference.dark,
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testCentavo('changing currency warns first and then saves', (tester) async {
    final app = await pumpCentavo(tester, settings: _onboarded);
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-EUR')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Amounts are not converted'), findsOneWidget);
    expect(app.container.read(settingsControllerProvider).currencyCode, 'USD');
    await tester.tap(find.byKey(const Key('currency-change-confirm')));
    await tester.pumpAndSettle();
    expect(app.container.read(settingsControllerProvider).currencyCode, 'EUR');
  });

  testCentavo('cancelling the currency warning keeps the currency', (
    tester,
  ) async {
    final app = await pumpCentavo(tester, settings: _onboarded);
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-currency')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-EUR')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('currency-change-cancel')));
    await tester.pumpAndSettle();
    expect(app.container.read(settingsControllerProvider).currencyCode, 'USD');
  });

  testCentavo('App lock is disabled when the device is not secure', (
    tester,
  ) async {
    await pumpCentavo(
      tester,
      settings: _onboarded,
      biometric: MockBiometricRepository(deviceSecure: false),
    );
    await _openSettings(tester);
    expect(find.text('Set up a screen lock on this device first'), findsOne);
    final tile = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings-app-lock')),
    );
    expect(tile.onChanged, isNull);
  });

  testCentavo('enabling App lock authenticates and sets FLAG_SECURE', (
    tester,
  ) async {
    final biometric = MockBiometricRepository();
    final secure = NoopSecureWindowService();
    final app = await pumpCentavo(
      tester,
      settings: _onboarded,
      biometric: biometric,
      secureWindow: secure,
    );
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-app-lock')));
    await tester.pumpAndSettle();

    expect(biometric.reasons, ['Confirm to turn on app lock']);
    expect(
      app.container.read(settingsControllerProvider).biometricLockEnabled,
      isTrue,
    );
    expect(secure.lastSecure, isTrue);
    // Enabling never locks the current session.
    expect(find.byKey(const Key('settings-app-lock')), findsOneWidget);
  });

  testCentavo('failed confirmation leaves App lock off and shows a message', (
    tester,
  ) async {
    final biometric = MockBiometricRepository(
      nextError: const BiometricError(BiometricErrorKind.cancelled),
    );
    final app = await pumpCentavo(
      tester,
      settings: _onboarded,
      biometric: biometric,
    );
    await _openSettings(tester);
    await tester.tap(find.byKey(const Key('settings-app-lock')));
    await tester.pumpAndSettle();

    expect(
      app.container.read(settingsControllerProvider).biometricLockEnabled,
      isFalse,
    );
    expect(find.text('Authentication cancelled.'), findsOneWidget);
  });

  testCentavo('local mode shows Erase and no Exit demo', (tester) async {
    await pumpCentavo(tester, settings: _onboarded);
    await _openSettings(tester);
    expect(find.byKey(const Key('settings-erase')), findsOneWidget);
    expect(find.byKey(const Key('settings-exit-demo')), findsNothing);
    expect(find.byKey(const Key('settings-export')), findsOneWidget);
    expect(find.byKey(const Key('settings-about')), findsOneWidget);
  });

  testCentavo('demo mode shows Exit demo and no Erase', (tester) async {
    await pumpCentavo(tester);
    await tester.tap(find.byKey(const Key('welcome-explore-demo')));
    await tester.pumpAndSettle();
    await _openSettings(tester);
    expect(find.byKey(const Key('settings-erase')), findsNothing);
    expect(find.byKey(const Key('settings-exit-demo')), findsOneWidget);
  });

  testCentavo('the Backup row is hidden without a backup configuration', (
    tester,
  ) async {
    await pumpCentavo(tester, settings: _onboarded, backupAvailable: false);
    await _openSettings(tester);
    expect(find.byKey(const Key('settings-backup')), findsNothing);
  });

  testCentavo('the Backup row shows its state and opens the screen', (
    tester,
  ) async {
    await pumpCentavo(tester, settings: _onboarded, backupAvailable: true);
    await _openSettings(tester);
    expect(find.byKey(const Key('settings-backup')), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-backup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('backup-sign-in')), findsOneWidget);
  });
}
