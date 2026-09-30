import 'package:drift/drift.dart';

/// Key/value store used by backup: 'lastBackupAt', 'lastRestoreAt'.
@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
