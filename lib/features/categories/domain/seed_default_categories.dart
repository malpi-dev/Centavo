import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';

/// Idempotent thanks to the fixed ids of the default categories.
class SeedDefaultCategories {
  SeedDefaultCategories(this._categories, this._clock);

  final CategoryRepository _categories;
  final Clock _clock;

  Future<void> call() =>
      _categories.insertIfAbsent(buildDefaultCategories(_clock.nowUtc()));
}
