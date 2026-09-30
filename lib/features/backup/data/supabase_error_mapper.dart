import 'dart:async';
import 'dart:io';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates SDK exceptions into [DomainError]s. Nothing from Supabase may
/// reach the UI.
DomainError mapSupabaseError(Object error) {
  if (error is DomainError) return error;
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException ||
      error is AuthRetryableFetchException) {
    return NetworkError(error);
  }
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final numeric = int.tryParse(code);
    // 540 = paused project.
    if (numeric != null && numeric >= 500) {
      return BackendUnavailableError(error);
    }
    if (code == 'PGRST301' ||
        code == 'PGRST302' ||
        error.message.toLowerCase().contains('jwt')) {
      return const AuthError(AuthErrorKind.notSignedIn);
    }
    if (code == '23505') return const DuplicateError('backup');
    return UnknownError(error);
  }
  if (error is AuthException) {
    final status = int.tryParse(error.statusCode ?? '');
    final code = error.code;
    if (status == 429 ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return const AuthError(AuthErrorKind.rateLimited);
    }
    if (status != null && status >= 500) return BackendUnavailableError(error);
    // GoTrue uses the same code for wrong and expired codes.
    if (code == 'otp_expired') {
      return const AuthError(AuthErrorKind.invalidCode);
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return const AuthError(AuthErrorKind.invalidEmail);
    }
    if (status == 401) return const AuthError(AuthErrorKind.notSignedIn);
    return UnknownError(error);
  }
  return UnknownError(error);
}
