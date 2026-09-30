import 'package:centavo/core/config/env.dart';
import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/supabase/supabase_client_provider.dart';
import 'package:centavo/core/utils/uuid_id_generator.dart';
import 'package:centavo/features/backup/data/drift_sync_state_repository.dart';
import 'package:centavo/features/backup/data/mock_auth_repository.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/data/mock_sync_state_repository.dart';
import 'package:centavo/features/backup/data/supabase_auth_repository.dart';
import 'package:centavo/features/backup/data/supabase_backup_repository.dart';
import 'package:centavo/features/backup/domain/auth_repository.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/demo/data/mock_local_store.dart';
import 'package:centavo/features/export/data/file_share_csv_service.dart';
import 'package:centavo/features/export/domain/csv_share_service.dart';
import 'package:centavo/features/security/data/local_auth_biometric_repository.dart';
import 'package:centavo/features/security/data/method_channel_secure_window_service.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/security/domain/biometric_repository.dart';
import 'package:centavo/features/security/domain/secure_window_service.dart';
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

@Riverpod(keepAlive: true)
BiometricRepository biometricRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => LocalAuthBiometricRepository(),
      AppMode.demo => MockBiometricRepository(),
    };

/// Same in every mode: FLAG_SECURE belongs to the real window, so demo mode
/// must not leave it stuck when the settings are swapped. Tests override it
/// with `NoopSecureWindowService`.
@Riverpod(keepAlive: true)
SecureWindowService secureWindowService(Ref ref) =>
    MethodChannelSecureWindowService();

/// Real implementation in every mode: exporting the sample data is harmless
/// and shows the feature. Tests override it with the mock.
@Riverpod(keepAlive: true)
CsvShareService csvShareService(Ref ref) => FileShareCsvService();

/// In-memory "cloud" of the demo: fresh per demo session, no latency in tests
/// (overridden there).
@Riverpod(keepAlive: true)
MockAuthRepository demoAuthRepository(Ref ref) {
  final repo = MockAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
}

@Riverpod(keepAlive: true)
MockBackupRepository demoBackupRepository(Ref ref) => MockBackupRepository();

/// Real implementation only when the app was built with a backup
/// configuration; the UI never reads this provider otherwise (guarded by
/// `isBackupAvailableProvider`).
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local =>
        Env.isBackupEnabled
            ? SupabaseAuthRepository(ref.watch(supabaseClientProvider))
            : throw StateError('Backup is disabled'),
      AppMode.demo => ref.watch(demoAuthRepositoryProvider),
    };

@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local =>
        Env.isBackupEnabled
            ? SupabaseBackupRepository(ref.watch(supabaseClientProvider))
            : throw StateError('Backup is disabled'),
      AppMode.demo => ref.watch(demoBackupRepositoryProvider),
    };

@Riverpod(keepAlive: true)
SyncStateRepository syncStateRepository(Ref ref) =>
    switch (ref.watch(appModeControllerProvider)) {
      AppMode.local => DriftSyncStateRepository(ref.watch(appDatabaseProvider)),
      AppMode.demo => MockSyncStateRepository(ref.watch(demoDataStoreProvider)),
    };

/// Backup is visible in demo (simulated) and in local mode only when the app
/// has a Supabase configuration.
@Riverpod(keepAlive: true)
bool isBackupAvailable(Ref ref) =>
    ref.watch(appModeControllerProvider) == AppMode.demo || Env.isBackupEnabled;
