/// Compile-time configuration from `--dart-define-from-file=.env.json`.
/// Never throws: without it the app runs in local and demo mode.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _backupFlag = String.fromEnvironment(
    'BACKUP_ENABLED',
    defaultValue: 'true',
  );

  /// Backup is available only when both values exist and the flag is not
  /// 'false' (definition section 15).
  static bool get isBackupEnabled =>
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty &&
      _backupFlag != 'false';
}
