import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_monthly_trend.freezed.dart';

@freezed
abstract class MonthTotals with _$MonthTotals {
  const factory MonthTotals({
    required YearMonth month,
    required Money income,
    required Money expense,
  }) = _MonthTotals;
}

class GetMonthlyTrend {
  const GetMonthlyTrend();

  /// Exactly [months] items, oldest first, ending at [endMonth]; months
  /// without data are zero.
  List<MonthTotals> call({
    required YearMonth endMonth,
    required List<MoneyTransaction> transactions,
    required String currencyCode,
    int months = 6,
  }) {
    final income = <YearMonth, int>{};
    final expense = <YearMonth, int>{};
    for (final t in transactions) {
      if (t.deletedAt != null) continue;
      (t.type == TransactionType.income ? income : expense).update(
        YearMonth.fromLocalDate(t.occurredOn),
        (v) => v + t.amountMinor,
        ifAbsent: () => t.amountMinor,
      );
    }
    return [
      for (var i = months - 1; i >= 0; i--)
        MonthTotals(
          month: endMonth.addMonths(-i),
          income: Money(income[endMonth.addMonths(-i)] ?? 0, currencyCode),
          expense: Money(expense[endMonth.addMonths(-i)] ?? 0, currencyCode),
        ),
    ];
  }
}
