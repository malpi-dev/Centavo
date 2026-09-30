import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

const _locked = AppSettings(
  onboardingCompleted: true,
  biometricLockEnabled: true,
);

void main() {
  testCentavo('cold start prompts automatically and opens the dashboard', (
    tester,
  ) async {
    final biometric = MockBiometricRepository();
    await pumpCentavo(
      tester,
      settings: _locked,
      biometric: biometric,
    );
    expect(biometric.reasons, hasLength(1));
    expect(find.byKey(const Key('lock-unlock')), findsNothing);
    expect(find.byKey(const Key('tab-dashboard')), findsOneWidget);
  });

  testCentavo('cancelled prompt stays on the lock screen until Unlock works', (
    tester,
  ) async {
    final biometric = MockBiometricRepository(
      nextError: const BiometricError(BiometricErrorKind.cancelled),
    );
    await pumpCentavo(
      tester,
      settings: _locked,
      biometric: biometric,
    );
    expect(find.text('Centavo is locked'), findsOneWidget);
    expect(find.text('Authentication cancelled.'), findsOneWidget);
    expect(find.byKey(const Key('tab-dashboard')), findsNothing);

    biometric.nextError = null;
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab-dashboard')), findsOneWidget);
  });
}
