import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'get_month_summary.freezed.dart';

@freezed
abstract class CategorySlice with _$CategorySlice {
  const factory CategorySlice({
    required Money amount,

    /// Share of total expenses, 10000 = 100 %.
    required int basisPoints,

    /// Null = "Others" (or a deleted category).
    String? categoryId,
    String? name,
    String? icon,
    int? color,
  }) = _CategorySlice;
}

@freezed
abstract class MonthSummary with _$MonthSummary {
  const factory MonthSummary({
    required Money income,
    required Money expense,
    required Money balance,

    /// Top N by amount desc (+ "Others" if there are more).
    required List<CategorySlice> expenseSlices,
    required int transactionCount,
  }) = _MonthSummary;
  const MonthSummary._();

  bool get isEmpty => transactionCount == 0;
}

class GetMonthSummary {
  const GetMonthSummary();

  MonthSummary call({
    required YearMonth month,
    required List<MoneyTransaction> transactions,
    required List<Category> categories,
    required String currencyCode,
    int topN = 5,
  }) {
    final categoriesById = {for (final c in categories) c.id: c};
    var income = 0;
    var expense = 0;
    var count = 0;
    final byCategory = <String, int>{};
    for (final t in transactions) {
      if (t.deletedAt != null || !month.contains(t.occurredOn)) continue;
      count++;
      if (t.type == TransactionType.income) {
        income += t.amountMinor;
      } else {
        expense += t.amountMinor;
        byCategory.update(
          t.categoryId,
          (v) => v + t.amountMinor,
          ifAbsent: () => t.amountMinor,
        );
      }
    }

    String nameOf(String id) => categoriesById[id]?.name ?? '';
    final ordered = byCategory.entries.toList()
      ..sort((a, b) {
        final byAmount = b.value.compareTo(a.value);
        if (byAmount != 0) return byAmount;
        return nameOf(
          a.key,
        ).toLowerCase().compareTo(nameOf(b.key).toLowerCase());
      });

    final total = Money(expense, currencyCode);
    CategorySlice slice(Money amount, {Category? category}) => CategorySlice(
      categoryId: category?.id,
      name: category?.name,
      icon: category?.icon,
      color: category?.color,
      amount: amount,
      basisPoints: amount.basisPointsOf(total),
    );

    final slices = <CategorySlice>[];
    var rest = 0;
    for (var i = 0; i < ordered.length; i++) {
      final entry = ordered[i];
      if (i < topN) {
        slices.add(
          slice(
            Money(entry.value, currencyCode),
            category: categoriesById[entry.key],
          ),
        );
      } else {
        rest += entry.value;
      }
    }
    if (rest > 0) slices.add(slice(Money(rest, currencyCode)));

    return MonthSummary(
      income: Money(income, currencyCode),
      expense: total,
      balance: Money(income - expense, currencyCode),
      expenseSlices: slices,
      transactionCount: count,
    );
  }
}
