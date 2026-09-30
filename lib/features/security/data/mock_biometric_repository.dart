import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/security/domain/biometric_repository.dart';

/// Always succeeds unless configured otherwise (tests and demo mode).
class MockBiometricRepository implements BiometricRepository {
  MockBiometricRepository({this.deviceSecure = true, this.nextError});

  bool deviceSecure;

  /// When set, the next [authenticate] throws it.
  BiometricError? nextError;

  final List<String> reasons = [];

  @override
  Future<bool> isDeviceSecure() async => deviceSecure;

  @override
  Future<void> authenticate({required String reason}) async {
    reasons.add(reason);
    final error = nextError;
    if (error != null) throw error;
  }
}
