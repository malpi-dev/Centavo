import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/get_budget_progress.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'budgets_providers.g.dart';

@riverpod
Stream<List<Budget>> monthBudgets(Ref ref, YearMonth month) =>
    ref.watch(budgetRepositoryProvider).watchMonth(month);

@riverpod
Future<BudgetProgressReport> budgetProgress(Ref ref, YearMonth month) async {
  final budgets = await ref.watch(monthBudgetsProvider(month).future);
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return const GetBudgetProgress()(
    month: month,
    budgets: budgets,
    transactions: transactions,
    categories: categories,
    currencyCode: ref.watch(settingsControllerProvider).currencyCode,
  );
}

/// F4 CA4: the month has no budgets and the previous one does.
@riverpod
Future<bool> canCopyPreviousBudgets(Ref ref, YearMonth month) async {
  final current = await ref.watch(monthBudgetsProvider(month).future);
  if (current.isNotEmpty) return false;
  final previous = await ref.watch(monthBudgetsProvider(month.previous).future);
  return previous.isNotEmpty;
}

/// The active budget of (category, month), used to prefill the form.
@riverpod
Future<Budget?> activeBudget(Ref ref, String categoryId, YearMonth month) =>
    ref.watch(budgetRepositoryProvider).findActive(categoryId, month);

@riverpod
class BudgetFormController extends _$BudgetFormController {
  @override
  FutureOr<void> build() {}

  Future<void> save({
    required String categoryId,
    required YearMonth month,
    required int limitMinor,
  }) => _run(
    () => ref
        .read(budgetRepositoryProvider)
        .setLimit(
          categoryId: categoryId,
          month: month,
          limitMinor: limitMinor,
        ),
  );

  Future<void> remove(String budgetId) =>
      _run(() => ref.read(budgetRepositoryProvider).softDelete(budgetId));

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
  }
}

@riverpod
class CopyBudgetsController extends _$CopyBudgetsController {
  @override
  FutureOr<void> build() {}

  /// Returns how many budgets were created, or null on failure (state is then
  /// `AsyncError`).
  Future<int?> copy(YearMonth month) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(copyBudgetsFromPreviousMonthProvider).call(month),
    );
    state = result.whenData((_) {});
    return result.value;
  }
}
