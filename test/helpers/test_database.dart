import 'package:centavo/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// In-memory database for repository tests.
AppDatabase createTestDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return AppDatabase(NativeDatabase.memory());
}
