import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';

abstract interface class BudgetRepository {
  /// Non-deleted budgets of [month].
  Stream<List<Budget>> watchMonth(YearMonth month);

  Future<List<Budget>> getMonth(YearMonth month);

  Future<Budget?> findActive(String categoryId, YearMonth month);

  /// Creates or updates THE active budget of (category, month).
  /// limitMinor <= 0 -> ValidationError('limit', mustBePositive). Category
  /// missing/deleted -> NotFoundError('category'); income category ->
  /// CategoryTypeMismatchError.
  Future<Budget> setLimit({
    required String categoryId,
    required YearMonth month,
    required int limitMinor,
  });

  Future<void> softDelete(String id);

  Future<void> softDeleteByCategory(String categoryId);

  /// Rows with updatedAt > [sinceUtc] (all rows when null), INCLUDING
  /// archived and deleted ones, ordered by updatedAt.
  Future<List<Budget>> changedSince(DateTime? sinceUtc);

  /// Merges rows downloaded from the backup (last-write-wins by id). Never
  /// deletes local rows that are not in [incoming].
  /// An active incoming budget that clashes by (category, month) with another
  /// active local one: the most recently updated wins and the loser is
  /// tombstoned.
  Future<void> mergeFromBackup(List<Budget> incoming);
}
