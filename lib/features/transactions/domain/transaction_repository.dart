import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';

abstract interface class TransactionRepository {
  /// Non-deleted transactions with from <= occurredOn < toExclusive, ordered by
  /// occurredOn desc, createdAt desc.
  Stream<List<MoneyTransaction>> watchBetween(
    LocalDate from,
    LocalDate toExclusive,
  );

  /// Same as watchBetween but one-shot; null bounds are open (export "all").
  Future<List<MoneyTransaction>> getBetween(
    LocalDate? from,
    LocalDate? toExclusive,
  );

  Future<MoneyTransaction?> findById(String id);

  /// assertValidDraft + category must exist and not be deleted
  /// (NotFoundError('category')) and have the same type
  /// (CategoryTypeMismatchError). Generates id and timestamps.
  Future<MoneyTransaction> create(TransactionDraft draft);

  /// Same checks. NotFoundError('transaction') if missing/deleted.
  Future<MoneyTransaction> update(MoneyTransaction transaction);

  Future<void> softDelete(String id);

  /// Undo of softDelete: deletedAt = null, updatedAt = now.
  Future<void> restore(String id);

  /// Count of non-deleted transactions in a category.
  Future<int> countByCategory(String categoryId);

  /// Rows with updatedAt > [sinceUtc] (all rows when null), INCLUDING
  /// archived and deleted ones, ordered by updatedAt.
  Future<List<MoneyTransaction>> changedSince(DateTime? sinceUtc);

  /// Merges rows downloaded from the backup (last-write-wins by id). Never
  /// deletes local rows that are not in [incoming].
  Future<void> mergeFromBackup(List<MoneyTransaction> incoming);
}
