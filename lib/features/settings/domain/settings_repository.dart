import 'package:centavo/features/settings/domain/app_settings.dart';

abstract interface class SettingsRepository {
  /// Synchronous: the router needs it before the first frame.
  AppSettings load();
  Future<void> save(AppSettings settings);

  /// Back to defaults (used by "Erase all local data").
  Future<void> clear();
}
