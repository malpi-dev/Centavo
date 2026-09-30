import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/data/mock_sync_state_repository.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/backup/domain/run_backup.dart';
import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/demo/data/mock_local_store.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

import '../../../helpers/sequential_id_generator.dart';

/// One "device": a mock local database plus its repositories.
class Device {
  Device(this.clock, {MockBackupRepository? cloud})
    : store = MockDataStore(),
      cloud = cloud ?? MockBackupRepository(latency: Duration.zero) {
    categories = MockCategoryRepository(
      store,
      clock: clock,
      ids: SequentialIdGenerator(),
    );
    budgets = MockBudgetRepository(
      store,
      clock: clock,
      ids: SequentialIdGenerator(),
    );
    transactions = MockTransactionRepository(
      store,
      clock: clock,
      ids: SequentialIdGenerator(),
    );
    syncState = MockSyncStateRepository(store);
    localStore = MockLocalStore(store);
  }

  final FixedClock clock;
  final MockDataStore store;
  final MockBackupRepository cloud;
  late final MockCategoryRepository categories;
  late final MockBudgetRepository budgets;
  late final MockTransactionRepository transactions;
  late final MockSyncStateRepository syncState;
  late final MockLocalStore localStore;
}

/// Records the order and size of every upload.
class RecordingCloud extends MockBackupRepository {
  RecordingCloud({this.onUploadTransactions, this.failTransactions = false})
    : super(latency: Duration.zero);

  final List<String> calls = [];
  final List<List<String>> categoryBatches = [];
  final List<int> transactionBatchSizes = [];
  final List<String> currencies = [];
  final void Function()? onUploadTransactions;
  final bool failTransactions;

  @override
  Future<BackupProfile> ensureProfile(String currencyCode) {
    currencies.add(currencyCode);
    return super.ensureProfile(currencyCode);
  }

  @override
  Future<void> upsertCategories(List<Category> rows) {
    calls.add('categories');
    categoryBatches.add([for (final r in rows) r.id]);
    return super.upsertCategories(rows);
  }

  @override
  Future<void> upsertBudgets(List<Budget> rows) {
    calls.add('budgets');
    return super.upsertBudgets(rows);
  }

  @override
  Future<void> upsertTransactions(List<MoneyTransaction> rows) {
    calls.add('transactions');
    transactionBatchSizes.add(rows.length);
    onUploadTransactions?.call();
    if (failTransactions) throw const NetworkError();
    return super.upsertTransactions(rows);
  }
}

RunBackup runBackupFor(Device d, {int batchSize = 500}) => RunBackup(
  backup: d.cloud,
  categories: d.categories,
  budgets: d.budgets,
  transactions: d.transactions,
  syncState: d.syncState,
  clock: d.clock,
  batchSize: batchSize,
);
