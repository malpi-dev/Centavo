import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category.dart';

/// Fixed ids of the default categories, so restoring a backup merges them by
/// id instead of duplicating them. Also used by the demo dataset.
abstract final class DefaultCategoryIds {
  static const food = '00000000-0000-4000-8000-000000000001';
  static const transport = '00000000-0000-4000-8000-000000000002';
  static const home = '00000000-0000-4000-8000-000000000003';
  static const health = '00000000-0000-4000-8000-000000000004';
  static const entertainment = '00000000-0000-4000-8000-000000000005';
  static const shopping = '00000000-0000-4000-8000-000000000006';
  static const other = '00000000-0000-4000-8000-000000000007';
  static const salary = '00000000-0000-4000-8000-000000000101';
  static const freelance = '00000000-0000-4000-8000-000000000102';
  static const otherIncome = '00000000-0000-4000-8000-000000000103';
}

List<Category> buildDefaultCategories(DateTime nowUtc) {
  Category make(
    String id,
    String name,
    TransactionType type,
    String icon,
    int color,
  ) => Category(
    id: id,
    name: name,
    type: type,
    icon: icon,
    color: color,
    isDefault: true,
    createdAt: nowUtc,
    updatedAt: nowUtc,
  );
  const expense = TransactionType.expense;
  const income = TransactionType.income;
  return [
    make(DefaultCategoryIds.food, 'Food', expense, 'food', 0xFFE65100),
    make(
      DefaultCategoryIds.transport,
      'Transport',
      expense,
      'transport',
      0xFF1565C0,
    ),
    make(DefaultCategoryIds.home, 'Home', expense, 'home', 0xFF6D4C41),
    make(DefaultCategoryIds.health, 'Health', expense, 'health', 0xFFC62828),
    make(
      DefaultCategoryIds.entertainment,
      'Entertainment',
      expense,
      'entertainment',
      0xFF7B1FA2,
    ),
    make(
      DefaultCategoryIds.shopping,
      'Shopping',
      expense,
      'shopping',
      0xFFC2185B,
    ),
    make(DefaultCategoryIds.other, 'Other', expense, 'other', 0xFF546E7A),
    make(DefaultCategoryIds.salary, 'Salary', income, 'salary', 0xFF2E7D32),
    make(
      DefaultCategoryIds.freelance,
      'Freelance',
      income,
      'freelance',
      0xFF00796B,
    ),
    make(
      DefaultCategoryIds.otherIncome,
      'Other income',
      income,
      'investments',
      0xFF3949AB,
    ),
  ];
}
