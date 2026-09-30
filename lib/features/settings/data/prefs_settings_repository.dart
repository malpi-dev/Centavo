import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/domain/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsSettingsRepository implements SettingsRepository {
  PrefsSettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _currencyKey = 'settings.currencyCode';
  static const _themeKey = 'settings.themePreference';
  static const _biometricKey = 'settings.biometricLockEnabled';
  static const _onboardingKey = 'settings.onboardingCompleted';
  static const _autoBackupKey = 'settings.autoBackupEnabled';

  @override
  AppSettings load() {
    const defaults = AppSettings();
    final themeName = _prefs.getString(_themeKey);
    return AppSettings(
      currencyCode: _prefs.getString(_currencyKey) ?? defaults.currencyCode,
      themePreference: AppThemePreference.values.firstWhere(
        (p) => p.name == themeName,
        orElse: () => defaults.themePreference,
      ),
      biometricLockEnabled:
          _prefs.getBool(_biometricKey) ?? defaults.biometricLockEnabled,
      onboardingCompleted:
          _prefs.getBool(_onboardingKey) ?? defaults.onboardingCompleted,
      autoBackupEnabled:
          _prefs.getBool(_autoBackupKey) ?? defaults.autoBackupEnabled,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_currencyKey, settings.currencyCode);
    await _prefs.setString(_themeKey, settings.themePreference.name);
    await _prefs.setBool(_biometricKey, settings.biometricLockEnabled);
    await _prefs.setBool(_onboardingKey, settings.onboardingCompleted);
    await _prefs.setBool(_autoBackupKey, settings.autoBackupEnabled);
  }

  @override
  Future<void> clear() async {
    for (final key in const [
      _currencyKey,
      _themeKey,
      _biometricKey,
      _onboardingKey,
      _autoBackupKey,
    ]) {
      await _prefs.remove(key);
    }
  }
}
