import 'dart:async';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/domain/auth_repository.dart';
import 'package:centavo/features/backup/domain/email_validator.dart';

/// Demo and tests. Accepts any valid email; the right code is [demoOtpCode].
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;
  String? _email;
  DomainError? _nextError;
  final _controller = StreamController<String?>.broadcast();

  /// The next call that can fail throws [error] once.
  // ignore: use_setters_to_change_properties, reads better in tests
  void failNextWith(DomainError error) => _nextError = error;

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final error = _nextError;
    if (error != null) {
      _nextError = null;
      throw error;
    }
  }

  @override
  String? get currentEmail => _email;

  @override
  Stream<String?> watchSignedInEmail() async* {
    yield _email;
    yield* _controller.stream;
  }

  @override
  Future<void> sendCode(String email) async {
    if (!isValidEmail(email)) {
      throw const AuthError(AuthErrorKind.invalidEmail);
    }
    await _wait();
  }

  @override
  Future<void> verifyCode({
    required String email,
    required String code,
  }) async {
    if (!isValidOtpCode(code)) {
      throw const AuthError(AuthErrorKind.invalidCode);
    }
    await _wait();
    if (code != demoOtpCode) throw const AuthError(AuthErrorKind.invalidCode);
    _email = email;
    _controller.add(_email);
  }

  @override
  Future<void> signOut() async {
    _email = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
