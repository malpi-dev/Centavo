import 'package:centavo/core/domain/category_palette.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/category_validator.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10);
  final categories = buildDefaultCategories(now);

  test('has 7 expense and 3 income categories', () {
    expect(categories, hasLength(10));
    expect(
      categories.where((c) => c.type == TransactionType.expense),
      hasLength(7),
    );
    expect(
      categories.where((c) => c.type == TransactionType.income),
      hasLength(3),
    );
  });

  test('ids are unique and fixed', () {
    expect(categories.map((c) => c.id).toSet(), hasLength(10));
    expect(categories.first.id, DefaultCategoryIds.food);
    expect(
      buildDefaultCategories(DateTime.utc(2030)).map((c) => c.id),
      categories.map((c) => c.id),
    );
  });

  test('icons, colors and names are valid; timestamps come from the clock', () {
    for (final c in categories) {
      expect(categoryIconKeys, contains(c.icon));
      expect(categoryColorPalette, contains(c.color));
      expect(
        validateCategoryForm(name: c.name, icon: c.icon, color: c.color),
        isEmpty,
      );
      expect(c.isDefault, isTrue);
      expect(c.createdAt, now);
      expect(c.updatedAt, now);
      expect(c.isActive, isTrue);
    }
  });
}
