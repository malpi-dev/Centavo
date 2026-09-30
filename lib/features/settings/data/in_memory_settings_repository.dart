import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/domain/settings_repository.dart';

class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([AppSettings initial = const AppSettings()])
    : _settings = initial;

  AppSettings _settings;

  @override
  AppSettings load() => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  Future<void> clear() async => _settings = const AppSettings();
}
