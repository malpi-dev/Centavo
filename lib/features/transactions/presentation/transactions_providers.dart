import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/presentation/selected_month_provider.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/presentation/transaction_grouping.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transactions_providers.freezed.dart';
part 'transactions_providers.g.dart';

@riverpod
Stream<List<MoneyTransaction>> monthTransactions(Ref ref, YearMonth month) =>
    ref
        .watch(transactionRepositoryProvider)
        .watchBetween(month.firstDay, month.firstDayOfNextMonth);

@freezed
abstract class TransactionFilter with _$TransactionFilter {
  const factory TransactionFilter({TransactionType? type, String? categoryId}) =
      _TransactionFilter;
  const TransactionFilter._();

  bool get isActive => type != null || categoryId != null;
}

@Riverpod(keepAlive: true)
class TransactionFilterController extends _$TransactionFilterController {
  @override
  TransactionFilter build() => const TransactionFilter();

  /// Changing the type resets the category.
  void setType(TransactionType? type) => state = TransactionFilter(type: type);

  void setCategory(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId);

  void clear() => state = const TransactionFilter();
}

@riverpod
Future<List<TransactionDayGroup>> transactionGroups(Ref ref) async {
  final month = ref.watch(selectedMonthProvider);
  final filter = ref.watch(transactionFilterControllerProvider);
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return groupTransactionsByDay(
    transactions: transactions,
    categories: categories,
    filter: filter,
    currencyCode: ref.watch(settingsControllerProvider).currencyCode,
  );
}

@riverpod
Future<MoneyTransaction?> transactionById(Ref ref, String id) =>
    ref.watch(transactionRepositoryProvider).findById(id);
