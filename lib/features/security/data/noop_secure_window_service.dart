import 'package:centavo/features/security/domain/secure_window_service.dart';

/// Tests and demo mode. Records the last value for assertions.
class NoopSecureWindowService implements SecureWindowService {
  bool? lastSecure;

  @override
  Future<void> setSecure({required bool secure}) async => lastSecure = secure;
}
