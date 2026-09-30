import 'dart:math' as math;

import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:meta/meta.dart';

@immutable
class DemoData {
  const DemoData({
    required this.categories,
    required this.transactions,
    required this.budgets,
  });

  final List<Category> categories;
  final List<MoneyTransaction> transactions;
  final List<Budget> budgets;
}

/// Deterministic ~3 month dataset (phase 05, section 4.1). `seed.sql`
/// (phase 11) replicates the same pattern.
abstract final class DemoDataset {
  static const currencyCode = 'USD';

  static const coffeeId = '00000000-0000-4000-8000-0000000000c1';
  static const gymId = '00000000-0000-4000-8000-0000000000c2';
  static const oldCarId = '00000000-0000-4000-8000-0000000000c3';

  static const _groceries = [6240, 4815, 7190, 5530];

  static DemoData build(Clock clock) {
    final today = clock.today();
    final m0 = YearMonth.fromLocalDate(today);
    final m1 = m0.previous;
    final m2 = m1.previous;

    final categories = _categories(m1, m2);
    final transactions = <MoneyTransaction>[
      ..._month(m2, m2.daysInMonth, _Slot.oldest),
      ..._month(m1, m1.daysInMonth, _Slot.previous),
      ..._month(m0, today.day, _Slot.current),
    ];
    return DemoData(
      categories: categories,
      transactions: transactions,
      budgets: [
        ..._budgets(m2, transactions, current: false),
        ..._budgets(m1, transactions, current: false),
        ..._budgets(m0, transactions, current: true),
      ],
    );
  }

  static DateTime _at(YearMonth month, int day, int hour) =>
      DateTime.utc(month.year, month.month, day, hour);

  static List<Category> _categories(YearMonth m1, YearMonth m2) {
    final created = _at(m2, 1, 9);
    Category custom(
      String id,
      String name,
      String icon,
      int color, {
      DateTime? archivedAt,
    }) => Category(
      id: id,
      name: name,
      type: TransactionType.expense,
      icon: icon,
      color: color,
      isDefault: false,
      createdAt: created,
      updatedAt: created,
      archivedAt: archivedAt,
    );
    return [
      ...buildDefaultCategories(created),
      custom(coffeeId, 'Coffee', 'coffee', 0xFFB8692E),
      custom(gymId, 'Gym', 'fitness', 0xFFB7791F),
      custom(
        oldCarId,
        'Old car',
        'car',
        0xFF546E7A,
        archivedAt: _at(m1, 1, 12),
      ),
    ];
  }

  static String _tag(YearMonth month) =>
      '${month.year.toString().padLeft(4, '0')}'
      '${month.month.toString().padLeft(2, '0')}';

  static List<MoneyTransaction> _month(
    YearMonth month,
    int lastDay,
    _Slot slot,
  ) {
    final result = <MoneyTransaction>[];
    var sequence = 0;

    void add(
      int day,
      String categoryId,
      TransactionType type,
      int amount,
      String note,
    ) {
      sequence++;
      final stamp = _at(month, day, 12).add(Duration(seconds: sequence));
      result.add(
        MoneyTransaction(
          id: 'demo-tx-${_tag(month)}-${sequence.toString().padLeft(3, '0')}',
          type: type,
          amountMinor: amount,
          categoryId: categoryId,
          occurredOn: LocalDate(month.year, month.month, day),
          note: note,
          createdAt: stamp,
          updatedAt: stamp,
        ),
      );
    }

    void expense(int day, String categoryId, int amount, String note) =>
        add(day, categoryId, TransactionType.expense, amount, note);
    void income(int day, String categoryId, int amount, String note) =>
        add(day, categoryId, TransactionType.income, amount, note);

    for (var d = 1; d <= lastDay; d++) {
      if (d == 1) {
        income(d, DefaultCategoryIds.salary, 320000, 'Monthly salary');
        expense(d, DefaultCategoryIds.home, 95000, 'Rent');
        if (slot == _Slot.current) {
          expense(d, coffeeId, 450, 'Latte');
          expense(
            d,
            DefaultCategoryIds.entertainment,
            1599,
            'Streaming subscription',
          );
        }
      }
      if (const [2, 9, 16, 23, 30].contains(d)) {
        expense(d, DefaultCategoryIds.transport, 3500, 'Transit card top-up');
      }
      final groceryIndex = const [3, 10, 17, 24].indexOf(d);
      if (groceryIndex >= 0) {
        expense(
          d,
          DefaultCategoryIds.food,
          _groceries[groceryIndex],
          'Groceries',
        );
      }
      if (d == 5) expense(d, DefaultCategoryIds.health, 3000, 'Pharmacy');
      if (d == 6 || d == 20) {
        expense(d, DefaultCategoryIds.transport, 4200, 'Fuel');
      }
      if (d == 7) expense(d, DefaultCategoryIds.entertainment, 2400, 'Cinema');
      if (d == 8) expense(d, gymId, 4500, 'Gym membership');
      if (d == 11 && slot == _Slot.oldest) {
        expense(d, oldCarId, 18000, 'Car service');
      }
      if (d == 12) expense(d, DefaultCategoryIds.shopping, 3999, 'Clothes');
      if (d == 15) {
        income(d, DefaultCategoryIds.freelance, 45000, 'Freelance project');
      }
      if (d == 18) expense(d, DefaultCategoryIds.other, 1500, 'Haircut');
      if (d == 21) {
        expense(d, DefaultCategoryIds.entertainment, 5500, 'Concert');
      }
      if (d == 26) {
        expense(d, DefaultCategoryIds.shopping, 2450, 'Home goods');
      }
      if (d == 27 && slot == _Slot.previous) {
        income(d, DefaultCategoryIds.freelance, 28000, 'Logo design');
      }
      final weekday = LocalDate(month.year, month.month, d).weekday;
      if (weekday <= 5) {
        expense(d, coffeeId, d.isOdd ? 420 : 375, 'Morning coffee');
      }
    }
    return result;
  }

  static List<Budget> _budgets(
    YearMonth month,
    List<MoneyTransaction> all, {
    required bool current,
  }) {
    int spentIn(String categoryId) => all
        .where(
          (t) =>
              t.categoryId == categoryId &&
              t.type == TransactionType.expense &&
              month.contains(t.occurredOn),
        )
        .fold(0, (sum, t) => sum + t.amountMinor);

    // Entertainment ~90 % (warning) and Coffee ~125 % (exceeded) in the
    // current month, whatever the day.
    final entertainment = current
        ? (spentIn(DefaultCategoryIds.entertainment) * 100 + 89) ~/ 90
        : 12000;
    final coffee = current
        ? math.max(100, spentIn(coffeeId) * 80 ~/ 100)
        : 8000;
    final stamp = _at(month, 1, 9);
    Budget budget(String key, String categoryId, int limit) => Budget(
      id: 'demo-budget-${_tag(month)}-$key',
      categoryId: categoryId,
      month: month,
      limitMinor: limit,
      createdAt: stamp,
      updatedAt: stamp,
    );
    return [
      budget('food', DefaultCategoryIds.food, 60000),
      budget('transport', DefaultCategoryIds.transport, 15000),
      budget('shopping', DefaultCategoryIds.shopping, 20000),
      budget('entertainment', DefaultCategoryIds.entertainment, entertainment),
      budget('coffee', coffeeId, coffee),
    ];
  }
}

enum _Slot { oldest, previous, current }
