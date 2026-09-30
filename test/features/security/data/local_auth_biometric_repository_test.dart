import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/data/local_auth_biometric_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockLocalAuth extends Mock implements LocalAuthentication {}

void main() {
  late _MockLocalAuth auth;
  late LocalAuthBiometricRepository repo;

  setUp(() {
    auth = _MockLocalAuth();
    repo = LocalAuthBiometricRepository(auth);
  });

  void stubAuth(Future<bool> Function() answer) => when(
    () => auth.authenticate(
      localizedReason: any(named: 'localizedReason'),
      persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
    ),
  ).thenAnswer((_) => answer());

  test('authenticate succeeds when the plugin returns true', () async {
    stubAuth(() async => true);
    await repo.authenticate(reason: 'r');
  });

  test('false maps to cancelled', () async {
    stubAuth(() async => false);
    await expectLater(
      repo.authenticate(reason: 'r'),
      throwsA(
        isA<BiometricError>().having(
          (e) => e.kind,
          'kind',
          BiometricErrorKind.cancelled,
        ),
      ),
    );
  });

  const expected = {
    LocalAuthExceptionCode.noCredentialsSet: BiometricErrorKind.notAvailable,
    LocalAuthExceptionCode.noBiometricHardware: BiometricErrorKind.notAvailable,
    LocalAuthExceptionCode.uiUnavailable: BiometricErrorKind.notAvailable,
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        BiometricErrorKind.notAvailable,
    LocalAuthExceptionCode.noBiometricsEnrolled: BiometricErrorKind.notEnrolled,
    LocalAuthExceptionCode.temporaryLockout: BiometricErrorKind.lockedOut,
    LocalAuthExceptionCode.biometricLockout: BiometricErrorKind.lockedOut,
    LocalAuthExceptionCode.userCanceled: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.systemCanceled: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.timeout: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.authInProgress: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.userRequestedFallback: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.deviceError: BiometricErrorKind.cancelled,
    LocalAuthExceptionCode.unknownError: BiometricErrorKind.cancelled,
  };

  test('every exception code is covered by the table', () {
    expect(expected.keys.toSet(), LocalAuthExceptionCode.values.toSet());
  });

  for (final entry in expected.entries) {
    test('${entry.key.name} maps to ${entry.value.name}', () async {
      stubAuth(() async => throw LocalAuthException(code: entry.key));
      await expectLater(
        repo.authenticate(reason: 'r'),
        throwsA(
          isA<BiometricError>().having((e) => e.kind, 'kind', entry.value),
        ),
      );
    });
  }

  test('PlatformException never escapes', () async {
    stubAuth(() async => throw PlatformException(code: 'x'));
    await expectLater(
      repo.authenticate(reason: 'r'),
      throwsA(isA<BiometricError>()),
    );
  });

  test('isDeviceSecure delegates and swallows plugin errors', () async {
    when(() => auth.isDeviceSupported()).thenAnswer((_) async => true);
    expect(await repo.isDeviceSecure(), isTrue);
    when(
      () => auth.isDeviceSupported(),
    ).thenThrow(PlatformException(code: 'x'));
    expect(await repo.isDeviceSecure(), isFalse);
  });
}
