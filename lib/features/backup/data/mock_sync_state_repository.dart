import 'dart:async';

import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

class MockSyncStateRepository implements SyncStateRepository {
  MockSyncStateRepository(this._store);

  static const _lastBackupKey = 'lastBackupAt';
  static const _lastRestoreKey = 'lastRestoreAt';

  final MockDataStore _store;
  final _changes = StreamController<void>.broadcast();

  DateTime? get _lastBackup {
    final value = _store.syncState[_lastBackupKey];
    return value == null ? null : DateTime.parse(value).toUtc();
  }

  @override
  Future<DateTime?> lastBackupAt() async => _lastBackup;

  @override
  Stream<DateTime?> watchLastBackupAt() {
    late StreamController<DateTime?> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<DateTime?>(
      onListen: () {
        controller.add(_lastBackup);
        subscription = _changes.stream.listen(
          (_) => controller.add(_lastBackup),
        );
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  @override
  Future<void> setLastBackupAt(DateTime valueUtc) async {
    _store.syncState[_lastBackupKey] = valueUtc.toUtc().toIso8601String();
    _changes.add(null);
  }

  @override
  Future<void> setLastRestoreAt(DateTime valueUtc) async {
    _store.syncState[_lastRestoreKey] = valueUtc.toUtc().toIso8601String();
  }

  @override
  Future<void> clearLastBackupAt() async {
    _store.syncState.remove(_lastBackupKey);
    _changes.add(null);
  }
}
