import 'dart:async';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/supabase_error_mapper.dart';
import 'package:centavo/features/backup/domain/auth_repository.dart';
import 'package:centavo/features/backup/domain/email_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Email + 6-digit OTP through Supabase Auth (no passwords, no deep links).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  static const _timeout = Duration(seconds: 20);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  Stream<String?> watchSignedInEmail() async* {
    yield currentEmail;
    yield* _auth.onAuthStateChange
        .map((state) => state.session?.user.email)
        .distinct();
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body().timeout(_timeout);
    } on Object catch (error) {
      throw mapSupabaseError(error);
    }
  }

  @override
  Future<void> sendCode(String email) {
    if (!isValidEmail(email)) {
      throw const AuthError(AuthErrorKind.invalidEmail);
    }
    return _guard(
      () => _auth.signInWithOtp(email: email, shouldCreateUser: true),
    );
  }

  @override
  Future<void> verifyCode({required String email, required String code}) {
    if (!isValidOtpCode(code)) {
      throw const AuthError(AuthErrorKind.invalidCode);
    }
    return _guard(
      () => _auth.verifyOTP(type: OtpType.email, email: email, token: code),
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut().timeout(_timeout);
    } on Object {
      // Local sign-out must never fail because of the network.
    }
  }
}
