import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/budgets/domain/copy_budgets_from_previous_month.dart';
import 'package:centavo/features/categories/domain/delete_or_archive_category.dart';
import 'package:centavo/features/categories/domain/seed_default_categories.dart';
import 'package:centavo/features/export/domain/export_transactions_csv.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'use_case_providers.g.dart';

// Pure use cases without dependencies (GetMonthSummary, GetMonthlyTrend,
// GetBudgetProgress) are instantiated with `const` where they are used.

@Riverpod(keepAlive: true)
SeedDefaultCategories seedDefaultCategories(Ref ref) => SeedDefaultCategories(
  ref.watch(categoryRepositoryProvider),
  ref.watch(clockProvider),
);

@Riverpod(keepAlive: true)
DeleteOrArchiveCategory deleteOrArchiveCategory(Ref ref) =>
    DeleteOrArchiveCategory(
      categories: ref.watch(categoryRepositoryProvider),
      transactions: ref.watch(transactionRepositoryProvider),
      budgets: ref.watch(budgetRepositoryProvider),
      localStore: ref.watch(localStoreProvider),
    );

@Riverpod(keepAlive: true)
CopyBudgetsFromPreviousMonth copyBudgetsFromPreviousMonth(Ref ref) =>
    CopyBudgetsFromPreviousMonth(
      budgets: ref.watch(budgetRepositoryProvider),
      categories: ref.watch(categoryRepositoryProvider),
      localStore: ref.watch(localStoreProvider),
    );

@Riverpod(keepAlive: true)
ExportTransactionsCsv exportTransactionsCsv(Ref ref) => ExportTransactionsCsv(
  transactions: ref.watch(transactionRepositoryProvider),
  categories: ref.watch(categoryRepositoryProvider),
  clock: ref.watch(clockProvider),
);
