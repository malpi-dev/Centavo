import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/utils/uuid_id_generator.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/demo/data/mock_local_store.dart';
import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/data/prefs_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/domain/settings_repository.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';
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
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => PrefsSettingsRepository(
        ref.watch(sharedPreferencesProvider),
      ),
      AppMode.demo => ref.watch(demoSettingsRepositoryProvider),
    };

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
}

/// Fresh in-memory dataset; invalidated when entering and leaving demo mode so
/// nothing persists between demo sessions.
@Riverpod(keepAlive: true)
MockDataStore demoDataStore(Ref ref) {
  final data = DemoDataset.build(ref.watch(clockProvider));
  final store = MockDataStore(
    categories: data.categories,
    transactions: data.transactions,
    budgets: data.budgets,
  );
  ref.onDispose(store.dispose);
  return store;
}

@Riverpod(keepAlive: true)
SettingsRepository demoSettingsRepository(Ref ref) =>
    InMemorySettingsRepository(
      // The default currency already is DemoDataset.currencyCode (USD); a test
      // guards that.
      const AppSettings(onboardingCompleted: true),
    );

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => DriftCategoryRepository(
        ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
      AppMode.demo => MockCategoryRepository(
        ref.watch(demoDataStoreProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
    };

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => DriftTransactionRepository(
        ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
      AppMode.demo => MockTransactionRepository(
        ref.watch(demoDataStoreProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
    };

@Riverpod(keepAlive: true)
BudgetRepository budgetRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => DriftBudgetRepository(
        ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
      AppMode.demo => MockBudgetRepository(
        ref.watch(demoDataStoreProvider),
        clock: ref.watch(clockProvider),
        ids: ref.watch(idGeneratorProvider),
      ),
    };

@Riverpod(keepAlive: true)
LocalStore localStore(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => DriftLocalStore(ref.watch(appDatabaseProvider)),
      AppMode.demo => MockLocalStore(ref.watch(demoDataStoreProvider)),
    };
