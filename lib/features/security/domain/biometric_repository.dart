abstract interface class BiometricRepository {
  /// True when the device has a screen lock (PIN/pattern/password) or
  /// biometrics configured.
  Future<bool> isDeviceSecure();

  /// Shows the system prompt (biometrics with device-credential fallback).
  /// Throws BiometricError(cancelled | notAvailable | notEnrolled | lockedOut).
  Future<void> authenticate({required String reason});
}
