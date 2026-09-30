abstract interface class SyncStateRepository {
  Future<DateTime?> lastBackupAt();

  Stream<DateTime?> watchLastBackupAt();

  Future<void> setLastBackupAt(DateTime valueUtc);

  Future<void> setLastRestoreAt(DateTime valueUtc);

  Future<void> clearLastBackupAt();
}
