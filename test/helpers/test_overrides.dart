import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/misc.dart';

/// Base overrides for full-app tests.
List<Override> testOverrides({
  AppSettings settings = const AppSettings(),
  Clock? clock,
}) => [
  settingsRepositoryProvider.overrideWithValue(
    InMemorySettingsRepository(settings),
  ),
  clockProvider.overrideWithValue(
    clock ?? FixedClock(DateTime.utc(2026, 10, 15, 12)),
  ),
];
