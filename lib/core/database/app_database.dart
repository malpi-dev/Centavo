import 'package:centavo/core/database/converters.dart';
import 'package:centavo/core/database/tables/budgets_table.dart';
import 'package:centavo/core/database/tables/categories_table.dart';
import 'package:centavo/core/database/tables/sync_state_table.dart';
import 'package:centavo/core/database/tables/transactions_table.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Categories, Transactions, Budgets, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database file `centavo.sqlite` in the app documents directory.
  factory AppDatabase.open() => AppDatabase(driftDatabase(name: 'centavo'));

  @override
  int get schemaVersion => 1;

  // Future migrations: bump [schemaVersion], run
  // `dart run drift_dev make-migrations`, implement the step in `onUpgrade`
  // with the generated `stepByStep` helpers and make the generated tests in
  // `test/drift/` pass.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
