import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';

enum CategoryRemoval { deleted, archived }

class DeleteOrArchiveCategory {
  DeleteOrArchiveCategory({
    required this._categories,
    required this._transactions,
    required this._budgets,
    required this._localStore,
  });

  final CategoryRepository _categories;
  final TransactionRepository _transactions;
  final BudgetRepository _budgets;
  final LocalStore _localStore;

  /// NotFoundError if missing. With non-deleted transactions -> archive.
  /// Otherwise, inside one local transaction, soft-delete the category's
  /// budgets and then the category.
  Future<CategoryRemoval> call(String categoryId) async {
    final category = await _categories.findById(categoryId);
    if (category == null) throw NotFoundError('category', categoryId);
    if (await _transactions.countByCategory(categoryId) > 0) {
      await _categories.archive(categoryId);
      return CategoryRemoval.archived;
    }
    await _localStore.runInTransaction(() async {
      await _budgets.softDeleteByCategory(categoryId);
      await _categories.softDelete(categoryId);
    });
    return CategoryRemoval.deleted;
  }
}
