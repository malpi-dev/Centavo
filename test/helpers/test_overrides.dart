import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/export/data/mock_csv_share_service.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/security/data/noop_secure_window_service.dart';
import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/misc.dart';

/// Base overrides for full-app tests.
List<Override> testOverrides({
  AppSettings settings = const AppSettings(),
  Clock? clock,
  MockBiometricRepository? biometric,
  NoopSecureWindowService? secureWindow,
  MockCsvShareService? csvShare,
}) => [
  biometricRepositoryProvider.overrideWithValue(
    biometric ?? MockBiometricRepository(),
  ),
  secureWindowServiceProvider.overrideWithValue(
    secureWindow ?? NoopSecureWindowService(),
  ),
  csvShareServiceProvider.overrideWithValue(csvShare ?? MockCsvShareService()),
  settingsRepositoryProvider.overrideWithValue(
    InMemorySettingsRepository(settings),
  ),
  clockProvider.overrideWithValue(
    clock ?? FixedClock(DateTime.utc(2026, 10, 15, 12)),
  ),
];
