import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/utils/uuid_id_generator.dart';
import 'package:centavo/features/settings/data/prefs_settings_repository.dart';
import 'package:centavo/features/settings/domain/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'repository_providers.g.dart';

/// Composition root: the only place (with `main.dart` and the router) that
/// wires `data/` implementations.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidIdGenerator();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
  'sharedPreferencesProvider must be overridden in main()',
);

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));
