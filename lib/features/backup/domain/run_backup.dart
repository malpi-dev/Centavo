import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_backup.freezed.dart';

enum BackupStep {
  preparing,
  uploadingCategories,
  uploadingBudgets,
  uploadingTransactions,
}

@freezed
abstract class BackupResult with _$BackupResult {
  const factory BackupResult({
    required int categories,
    required int budgets,
    required int transactions,
    required DateTime startedAt,
  }) = _BackupResult;
}

/// Uploads every row changed since the last successful backup.
class RunBackup {
  RunBackup({
    required this._backup,
    required this._categories,
    required this._budgets,
    required this._transactions,
    required this._syncState,
    required this._clock,
    this.batchSize = 500,
  });

  final BackupRepository _backup;
  final CategoryRepository _categories;
  final BudgetRepository _budgets;
  final TransactionRepository _transactions;
  final SyncStateRepository _syncState;
  final Clock _clock;
  final int batchSize;

  Future<BackupResult> call({
    required String currencyCode,
    void Function(BackupStep step)? onStep,
  }) async {
    final startedAt = _clock.nowUtc();
    final since = await _syncState.lastBackupAt();

    onStep?.call(BackupStep.preparing);
    await _backup.ensureProfile(currencyCode);
    await _backup.updateCurrency(currencyCode);

    // Parents first (foreign keys). Inside each table the tombstones go first
    // so a replaced budget never collides with its successor in the partial
    // unique index.
    final categories = _tombstonesFirst(
      await _categories.changedSince(since),
      (c) => c.deletedAt != null,
    );
    onStep?.call(BackupStep.uploadingCategories);
    await _inBatches(categories, _backup.upsertCategories);

    final budgets = _tombstonesFirst(
      await _budgets.changedSince(since),
      (b) => b.deletedAt != null,
    );
    onStep?.call(BackupStep.uploadingBudgets);
    await _inBatches(budgets, _backup.upsertBudgets);

    final transactions = _tombstonesFirst(
      await _transactions.changedSince(since),
      (t) => t.deletedAt != null,
    );
    onStep?.call(BackupStep.uploadingTransactions);
    await _inBatches(transactions, _backup.upsertTransactions);

    // The START time, so edits made during the upload are picked up next time.
    await _syncState.setLastBackupAt(startedAt);
    return BackupResult(
      categories: categories.length,
      budgets: budgets.length,
      transactions: transactions.length,
      startedAt: startedAt,
    );
  }

  List<T> _tombstonesFirst<T>(List<T> rows, bool Function(T row) isDeleted) => [
    ...rows.where(isDeleted),
    ...rows.where((r) => !isDeleted(r)),
  ];

  Future<void> _inBatches<T>(
    List<T> rows,
    Future<void> Function(List<T> batch) upload,
  ) async {
    for (var i = 0; i < rows.length; i += batchSize) {
      final end = i + batchSize < rows.length ? i + batchSize : rows.length;
      await upload(rows.sublist(i, end));
    }
  }
}
