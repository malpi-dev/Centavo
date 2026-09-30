import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/categories/domain/seed_default_categories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  test('inserts the 10 defaults using the clock time', () async {
    final repo = MockCategoryRepository();
    when(() => repo.insertIfAbsent(any())).thenAnswer((_) async {});
    final now = DateTime.utc(2026, 10, 3, 12);

    await SeedDefaultCategories(repo, FixedClock(now))();

    final captured =
        verify(() => repo.insertIfAbsent(captureAny())).captured.single
            as List<Category>;
    expect(captured, buildDefaultCategories(now));
    expect(captured, hasLength(10));
  });
}
