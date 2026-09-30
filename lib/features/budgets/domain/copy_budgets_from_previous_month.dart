import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';

class CopyBudgetsFromPreviousMonth {
  CopyBudgetsFromPreviousMonth({
    required this._budgets,
    required this._categories,
    required this._localStore,
  });

  final BudgetRepository _budgets;
  final CategoryRepository _categories;
  final LocalStore _localStore;

  /// Copies previous-month limits into [month] without overwriting existing
  /// budgets and skipping categories that are archived, deleted or missing.
  /// Runs inside one local transaction. Returns how many budgets were created.
  Future<int> call(YearMonth month) => _localStore.runInTransaction(() async {
    final previous = await _budgets.getMonth(month.previous);
    if (previous.isEmpty) return 0;
    final current = await _budgets.getMonth(month);
    final existing = {for (final b in current) b.categoryId};
    final activeIds = {
      for (final c in await _categories.getAll())
        if (c.isActive) c.id,
    };
    var created = 0;
    for (final b in previous) {
      if (existing.contains(b.categoryId) ||
          !activeIds.contains(b.categoryId)) {
        continue;
      }
      await _budgets.setLimit(
        categoryId: b.categoryId,
        month: month,
        limitMinor: b.limitMinor,
      );
      existing.add(b.categoryId);
      created++;
    }
    return created;
  });
}
