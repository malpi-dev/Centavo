import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:drift/drift.dart';

class DriftSyncStateRepository implements SyncStateRepository {
  DriftSyncStateRepository(this._db);

  static const _entity = 'syncState';
  static const lastBackupKey = 'lastBackupAt';
  static const lastRestoreKey = 'lastRestoreAt';

  final AppDatabase _db;

  $SyncStateTable get _table => _db.syncState;

  DateTime? _parse(SyncStateRow? row) =>
      row == null ? null : DateTime.parse(row.value).toUtc();

  SimpleSelectStatement<$SyncStateTable, SyncStateRow> _select(String key) =>
      _db.select(_table)..where((s) => s.key.equals(key));

  @override
  Future<DateTime?> lastBackupAt() => guardStorage(
    () async => _parse(await _select(lastBackupKey).getSingleOrNull()),
    entity: _entity,
  );

  @override
  Stream<DateTime?> watchLastBackupAt() => guardStorageStream(
    _select(lastBackupKey).watchSingleOrNull().map(_parse),
    entity: _entity,
  );

  Future<void> _set(String key, DateTime valueUtc) => guardStorage(
    () => _db
        .into(_table)
        .insertOnConflictUpdate(
          SyncStateCompanion.insert(
            key: key,
            value: valueUtc.toUtc().toIso8601String(),
          ),
        ),
    entity: _entity,
  );

  @override
  Future<void> setLastBackupAt(DateTime valueUtc) =>
      _set(lastBackupKey, valueUtc);

  @override
  Future<void> setLastRestoreAt(DateTime valueUtc) =>
      _set(lastRestoreKey, valueUtc);

  @override
  Future<void> clearLastBackupAt() => guardStorage(
    () => (_db.delete(_table)..where((s) => s.key.equals(lastBackupKey))).go(),
    entity: _entity,
  );
}
