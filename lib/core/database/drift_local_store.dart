import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/storage_guard.dart';
import 'package:centavo/core/domain/local_store.dart';

class DriftLocalStore implements LocalStore {
  DriftLocalStore(this._db);

  final AppDatabase _db;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) =>
      guardStorage(() => _db.transaction(action), entity: 'store');

  @override
  Future<void> eraseAll() => guardStorage(
    () => _db.transaction(() async {
      // Children first because of the foreign keys.
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.syncState).go();
    }),
    entity: 'store',
  );
}
