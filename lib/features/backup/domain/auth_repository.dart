/// The code the demo (mock) authentication accepts.
const demoOtpCode = '123456';

abstract interface class AuthRepository {
  /// Emits the signed-in email, or null when signed out. Emits the current
  /// value first.
  Stream<String?> watchSignedInEmail();

  String? get currentEmail;

  /// AuthError(invalidEmail | rateLimited), NetworkError,
  /// BackendUnavailableError.
  Future<void> sendCode(String email);

  /// AuthError(invalidCode | codeExpired | rateLimited), NetworkError,
  /// BackendUnavailableError.
  Future<void> verifyCode({required String email, required String code});

  /// Local sign-out; never deletes local data and never fails because of the
  /// network.
  Future<void> signOut();
}
