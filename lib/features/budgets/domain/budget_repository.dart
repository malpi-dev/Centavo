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
}
