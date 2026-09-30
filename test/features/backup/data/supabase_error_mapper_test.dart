import 'dart:async';
import 'dart:io';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/supabase_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  Matcher auth(AuthErrorKind kind) =>
      isA<AuthError>().having((e) => e.kind, 'kind', kind);

  group('network', () {
    test('SocketException', () {
      expect(
        mapSupabaseError(const SocketException('down')),
        isA<NetworkError>(),
      );
    });
    test('TimeoutException', () {
      expect(mapSupabaseError(TimeoutException('slow')), isA<NetworkError>());
    });
    test('http.ClientException', () {
      expect(
        mapSupabaseError(http.ClientException('x')),
        isA<NetworkError>(),
      );
    });
    test('AuthRetryableFetchException', () {
      expect(
        mapSupabaseError(AuthRetryableFetchException()),
        isA<NetworkError>(),
      );
    });
  });

  group('backend unavailable', () {
    test('PostgrestException 540 (paused project)', () {
      expect(
        mapSupabaseError(const PostgrestException(message: 'x', code: '540')),
        isA<BackendUnavailableError>(),
      );
    });
    test('PostgrestException 503', () {
      expect(
        mapSupabaseError(const PostgrestException(message: 'x', code: '503')),
        isA<BackendUnavailableError>(),
      );
    });
    test('AuthException 502', () {
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '502')),
        isA<BackendUnavailableError>(),
      );
    });
  });

  group('not signed in', () {
    for (final code in ['PGRST301', 'PGRST302']) {
      test('PostgrestException $code', () {
        expect(
          mapSupabaseError(PostgrestException(message: 'x', code: code)),
          auth(AuthErrorKind.notSignedIn),
        );
      });
    }
    test('JWT expired message', () {
      expect(
        mapSupabaseError(
          const PostgrestException(message: 'JWT expired', code: 'PGRST303'),
        ),
        auth(AuthErrorKind.notSignedIn),
      );
    });
    test('AuthException 401', () {
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '401')),
        auth(AuthErrorKind.notSignedIn),
      );
    });
  });

  group('auth', () {
    test('429', () {
      expect(
        mapSupabaseError(const AuthException('x', statusCode: '429')),
        auth(AuthErrorKind.rateLimited),
      );
    });
    for (final code in [
      'over_email_send_rate_limit',
      'over_request_rate_limit',
    ]) {
      test(code, () {
        expect(
          mapSupabaseError(AuthException('x', code: code)),
          auth(AuthErrorKind.rateLimited),
        );
      });
    }
    test('otp_expired maps to invalidCode', () {
      expect(
        mapSupabaseError(const AuthException('x', code: 'otp_expired')),
        auth(AuthErrorKind.invalidCode),
      );
    });
    for (final code in ['email_address_invalid', 'validation_failed']) {
      test(code, () {
        expect(
          mapSupabaseError(AuthException('x', code: code)),
          auth(AuthErrorKind.invalidEmail),
        );
      });
    }
  });

  test('PostgrestException 23505 is a DuplicateError', () {
    expect(
      mapSupabaseError(const PostgrestException(message: 'x', code: '23505')),
      isA<DuplicateError>().having((e) => e.entity, 'entity', 'backup'),
    );
  });

  test('anything else is an UnknownError', () {
    expect(mapSupabaseError(StateError('?')), isA<UnknownError>());
    expect(
      mapSupabaseError(const PostgrestException(message: 'x', code: '42P01')),
      isA<UnknownError>(),
    );
  });

  test('DomainErrors pass through', () {
    const error = NetworkError();
    expect(mapSupabaseError(error), same(error));
  });
}
