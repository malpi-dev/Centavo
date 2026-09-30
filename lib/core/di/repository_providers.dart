import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/utils/uuid_id_generator.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/settings/data/prefs_settings_repository.dart';
import 'package:centavo/features/settings/domain/settings_repository.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'repository_providers.g.dart';

/// Composition root: the only place (with `main.dart` and the router) that
/// wires `data/` implementations.
@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => const UuidIdGenerator();

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) => throw UnimplementedError(
  'sharedPreferencesProvider must be overridden in main()',
);

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    PrefsSettingsRepository(ref.watch(sharedPreferencesProvider));

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

// Phase 05 adds the switch to mock repositories according to AppMode.
@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) => DriftCategoryRepository(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(clockProvider),
  ids: ref.watch(idGeneratorProvider),
);

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    DriftTransactionRepository(
      ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
      ids: ref.watch(idGeneratorProvider),
    );

@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) => DriftBudgetRepository(
  ref.watch(appDatabaseProvider),
  clock: ref.watch(clockProvider),
  ids: ref.watch(idGeneratorProvider),
);

@Riverpod(keepAlive: true)
LocalStore localStore(Ref ref) =>
    DriftLocalStore(ref.watch(appDatabaseProvider));
