import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/dashboard/domain/get_month_summary.dart';
import 'package:centavo/features/dashboard/domain/get_monthly_trend.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dashboard_providers.g.dart';

@riverpod
Future<MonthSummary> monthSummary(Ref ref, YearMonth month) async {
  final transactions = await ref.watch(monthTransactionsProvider(month).future);
  final categories = await ref.watch(categoriesProvider.future);
  return const GetMonthSummary()(
    month: month,
    transactions: transactions,
    categories: categories,
    currencyCode: ref.watch(settingsControllerProvider).currencyCode,
  );
}

@riverpod
Stream<List<MoneyTransaction>> rangeTransactions(
  Ref ref,
  LocalDate from,
  LocalDate toExclusive,
) => ref.watch(transactionRepositoryProvider).watchBetween(from, toExclusive);

/// The six months ending at [endMonth], oldest first.
@riverpod
Future<List<MonthTotals>> monthlyTrend(Ref ref, YearMonth endMonth) async {
  final start = endMonth.addMonths(-5);
  final transactions = await ref.watch(
    rangeTransactionsProvider(
      start.firstDay,
      endMonth.firstDayOfNextMonth,
    ).future,
  );
  return const GetMonthlyTrend()(
    endMonth: endMonth,
    transactions: transactions,
    currencyCode: ref.watch(settingsControllerProvider).currencyCode,
  );
}
