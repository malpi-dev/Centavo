import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/domain/biometric_repository.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class LocalAuthBiometricRepository implements BiometricRepository {
  LocalAuthBiometricRepository([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> isDeviceSecure() async {
    try {
      return await _auth.isDeviceSupported();
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> authenticate({required String reason}) async {
    final bool ok;
    try {
      ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException catch (e) {
      throw BiometricError(_kindFor(e.code));
    } on PlatformException {
      throw const BiometricError(BiometricErrorKind.cancelled);
    }
    if (!ok) throw const BiometricError(BiometricErrorKind.cancelled);
  }

  static BiometricErrorKind _kindFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.uiUnavailable ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          BiometricErrorKind.notAvailable,
        LocalAuthExceptionCode.noBiometricsEnrolled =>
          BiometricErrorKind.notEnrolled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout => BiometricErrorKind.lockedOut,
        _ => BiometricErrorKind.cancelled,
      };
}
