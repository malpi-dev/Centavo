import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/budgets/domain/copy_budgets_from_previous_month.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/builders.dart';

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class PassthroughLocalStore implements LocalStore {
  int calls = 0;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    calls++;
    return action();
  }

  @override
  Future<void> eraseAll() async {}
}

void main() {
  const month = YearMonth(2026, 10);
  late MockBudgetRepository budgets;
  late MockCategoryRepository categories;
  late PassthroughLocalStore store;
  late CopyBudgetsFromPreviousMonth useCase;

  setUpAll(() => registerFallbackValue(month));

  setUp(() {
    budgets = MockBudgetRepository();
    categories = MockCategoryRepository();
    store = PassthroughLocalStore();
    useCase = CopyBudgetsFromPreviousMonth(
      budgets: budgets,
      categories: categories,
      localStore: store,
    );
    when(
      () => budgets.setLimit(
        categoryId: any(named: 'categoryId'),
        month: any(named: 'month'),
        limitMinor: any(named: 'limitMinor'),
      ),
    ).thenAnswer((_) async => aBudget());
  });

  void stub({
    required List<Budget> previous,
    required List<Category> cats,
    List<Budget> current = const [],
  }) {
    when(
      () => budgets.getMonth(month.previous),
    ).thenAnswer((_) async => previous);
    when(() => budgets.getMonth(month)).thenAnswer((_) async => current);
    when(() => categories.getAll()).thenAnswer((_) async => cats);
  }

  test('copies missing budgets and returns the count', () async {
    stub(
      previous: [
        aBudget(id: 'p1', month: month.previous, limitMinor: 500),
        aBudget(
          id: 'p2',
          categoryId: 'cat-2',
          month: month.previous,
          limitMinor: 900,
        ),
      ],
      cats: [
        aCategory(),
        aCategory(id: 'cat-2', name: 'Fun'),
      ],
    );

    expect(await useCase(month), 2);

    verify(
      () =>
          budgets.setLimit(categoryId: 'cat-1', month: month, limitMinor: 500),
    ).called(1);
    verify(
      () =>
          budgets.setLimit(categoryId: 'cat-2', month: month, limitMinor: 900),
    ).called(1);
    expect(store.calls, 1);
  });

  test('does not overwrite existing budgets', () async {
    stub(
      previous: [
        aBudget(id: 'p1', month: month.previous, limitMinor: 500),
        aBudget(id: 'p2', categoryId: 'cat-2', month: month.previous),
      ],
      current: [aBudget(id: 'c1', limitMinor: 111)],
      cats: [
        aCategory(),
        aCategory(id: 'cat-2', name: 'Fun'),
      ],
    );

    expect(await useCase(month), 1);

    verifyNever(
      () => budgets.setLimit(
        categoryId: 'cat-1',
        month: any(named: 'month'),
        limitMinor: any(named: 'limitMinor'),
      ),
    );
  });

  test('skips archived, deleted and missing categories', () async {
    stub(
      previous: [
        aBudget(id: 'p1', month: month.previous),
        aBudget(id: 'p2', categoryId: 'arch', month: month.previous),
        aBudget(id: 'p3', categoryId: 'del', month: month.previous),
        aBudget(id: 'p4', categoryId: 'ghost', month: month.previous),
      ],
      cats: [
        aCategory(),
        aCategory(id: 'arch', archivedAt: DateTime.utc(2026)),
        aCategory(id: 'del', deletedAt: DateTime.utc(2026)),
      ],
    );

    expect(await useCase(month), 1);
  });

  test('empty previous month returns 0', () async {
    stub(previous: [], cats: [aCategory()]);

    expect(await useCase(month), 0);
    verifyNever(
      () => budgets.setLimit(
        categoryId: any(named: 'categoryId'),
        month: any(named: 'month'),
        limitMinor: any(named: 'limitMinor'),
      ),
    );
  });
}
