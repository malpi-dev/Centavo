import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'restore_backup.freezed.dart';

@freezed
abstract class RestoreResult with _$RestoreResult {
  const factory RestoreResult({
    required String? currencyCode,
    required int categories,
    required int budgets,
    required int transactions,
  }) = _RestoreResult;
}

/// Merges the cloud backup into the local database (last-write-wins by id).
class RestoreBackup {
  RestoreBackup({
    required this._backup,
    required this._categories,
    required this._budgets,
    required this._transactions,
    required this._syncState,
    required this._localStore,
    required this._clock,
  });

  final BackupRepository _backup;
  final CategoryRepository _categories;
  final BudgetRepository _budgets;
  final TransactionRepository _transactions;
  final SyncStateRepository _syncState;
  final LocalStore _localStore;
  final Clock _clock;

  /// NotFoundError('backup') when there is no profile and no categories in the
  /// cloud ("No backup found").
  Future<RestoreResult> call() async {
    // Downloads happen outside the local transaction.
    final profile = await _backup.fetchProfile();
    final categories = await _backup.fetchCategories();
    if (profile == null && categories.isEmpty) {
      throw const NotFoundError('backup');
    }
    final budgets = await _backup.fetchBudgets();
    final transactions = await _backup.fetchTransactions();

    // Parents first because of the foreign keys.
    await _localStore.runInTransaction(() async {
      await _categories.mergeFromBackup(categories);
      await _budgets.mergeFromBackup(budgets);
      await _transactions.mergeFromBackup(transactions);
    });
    // Does not touch lastBackupAt: the next backup re-uploads everything,
    // which is harmless thanks to last-write-wins.
    await _syncState.setLastRestoreAt(_clock.nowUtc());
    return RestoreResult(
      currencyCode: profile?.currencyCode,
      categories: categories.length,
      budgets: budgets.length,
      transactions: transactions.length,
    );
  }
}
