import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/data/prefs_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<PrefsSettingsRepository> repo([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return PrefsSettingsRepository(await SharedPreferences.getInstance());
}

void main() {
  test('returns defaults when empty', () async {
    expect((await repo()).load(), const AppSettings());
  });

  test('save and load round trip', () async {
    final r = await repo();
    const settings = AppSettings(
      currencyCode: 'EUR',
      themePreference: AppThemePreference.dark,
      biometricLockEnabled: true,
      onboardingCompleted: true,
      autoBackupEnabled: false,
    );
    await r.save(settings);
    expect(r.load(), settings);
  });

  test('unknown theme value falls back to default', () async {
    final r = await repo({'settings.themePreference': 'sepia'});
    expect(r.load().themePreference, AppThemePreference.system);
  });

  test('clear restores defaults', () async {
    final r = await repo();
    await r.save(
      const AppSettings(currencyCode: 'MXN', onboardingCompleted: true),
    );
    await r.clear();
    expect(r.load(), const AppSettings());
  });

  test('in-memory repository behaves the same', () async {
    final r = InMemorySettingsRepository();
    expect(r.load(), const AppSettings());
    await r.save(const AppSettings(currencyCode: 'CLP'));
    expect(r.load().currencyCode, 'CLP');
    await r.clear();
    expect(r.load(), const AppSettings());
  });
}
