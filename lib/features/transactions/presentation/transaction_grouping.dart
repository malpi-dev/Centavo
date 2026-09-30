import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:meta/meta.dart';

@immutable
class TransactionListItem {
  const TransactionListItem({required this.transaction, this.category});

  final MoneyTransaction transaction;

  /// Null when the category is missing (shown as "Unknown category").
  final Category? category;
}

@immutable
class TransactionDayGroup {
  const TransactionDayGroup({
    required this.day,
    required this.items,
    required this.income,
    required this.expense,
  });

  final LocalDate day;

  /// Same order as the repository (createdAt desc).
  final List<TransactionListItem> items;
  final Money income;
  final Money expense;

  /// Income minus expense of the day.
  Money get net => income - expense;
}

/// Applies [filter], groups by `occurredOn` (most recent day first) and
/// computes the daily totals.
List<TransactionDayGroup> groupTransactionsByDay({
  required List<MoneyTransaction> transactions,
  required List<Category> categories,
  required TransactionFilter filter,
  required String currencyCode,
}) {
  final byId = {for (final c in categories) c.id: c};
  final byDay = <LocalDate, List<TransactionListItem>>{};
  for (final tx in transactions) {
    if (filter.type != null && tx.type != filter.type) continue;
    if (filter.categoryId != null && tx.categoryId != filter.categoryId) {
      continue;
    }
    byDay
        .putIfAbsent(tx.occurredOn, () => [])
        .add(
          TransactionListItem(transaction: tx, category: byId[tx.categoryId]),
        );
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days) _buildGroup(day, byDay[day]!, currencyCode),
  ];
}

TransactionDayGroup _buildGroup(
  LocalDate day,
  List<TransactionListItem> items,
  String currencyCode,
) {
  var income = 0;
  var expense = 0;
  for (final item in items) {
    final tx = item.transaction;
    if (tx.type == TransactionType.income) {
      income += tx.amountMinor;
    } else {
      expense += tx.amountMinor;
    }
  }
  return TransactionDayGroup(
    day: day,
    items: items,
    income: Money(income, currencyCode),
    expense: Money(expense, currencyCode),
  );
}
