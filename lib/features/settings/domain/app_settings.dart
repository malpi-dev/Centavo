import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';

enum AppThemePreference { system, light, dark }

@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('USD') String currencyCode,
    @Default(AppThemePreference.system) AppThemePreference themePreference,
    @Default(false) bool biometricLockEnabled,
    @Default(false) bool onboardingCompleted,
    @Default(true) bool autoBackupEnabled,
  }) = _AppSettings;
}
