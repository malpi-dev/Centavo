import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'backup_repository.freezed.dart';

@freezed
abstract class BackupProfile with _$BackupProfile {
  const factory BackupProfile({required String currencyCode}) = _BackupProfile;
}

abstract interface class BackupRepository {
  /// All methods throw AuthError(notSignedIn) without a session.
  /// RPC `centavo.ensure_profile`.
  Future<BackupProfile> ensureProfile(String currencyCode);

  Future<void> updateCurrency(String currencyCode);

  Future<BackupProfile?> fetchProfile();

  /// The caller sends batches of at most 500 rows.
  Future<void> upsertCategories(List<Category> rows);

  Future<void> upsertBudgets(List<Budget> rows);

  Future<void> upsertTransactions(List<MoneyTransaction> rows);

  /// Every row of the user, tombstones included.
  Future<List<Category>> fetchCategories();

  Future<List<Budget>> fetchBudgets();

  Future<List<MoneyTransaction>> fetchTransactions();

  /// "Delete my backup": transactions, budgets and categories of the user.
  /// The profile stays (implementation log).
  Future<void> deleteAll();
}
