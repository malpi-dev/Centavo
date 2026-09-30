import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftBudgetRepository repo;
  late DriftCategoryRepository categories;
  const oct = YearMonth(2026, 10);
  const nov = YearMonth(2026, 11);

  setUp(() async {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final ids = SequentialIdGenerator();
    categories = DriftCategoryRepository(db, clock: clock, ids: ids);
    repo = DriftBudgetRepository(db, clock: clock, ids: ids);
    await categories.insertIfAbsent([
      aCategory(id: 'exp'),
      aCategory(id: 'exp2', name: 'Home'),
      aCategory(id: 'inc', name: 'Salary', type: TransactionType.income),
    ]);
  });
  tearDown(() => db.close());

  test('setLimit creates then updates the same id', () async {
    final first = await repo.setLimit(
      categoryId: 'exp',
      month: oct,
      limitMinor: 5000,
    );
    clock.now = clock.now.add(const Duration(hours: 1));
    final second = await repo.setLimit(
      categoryId: 'exp',
      month: oct,
      limitMinor: 8000,
    );
    expect(second.id, first.id);
    expect(second.limitMinor, 8000);
    expect(second.createdAt, first.createdAt);
    expect(second.updatedAt, clock.now);
    final all = await repo.getMonth(oct);
    expect(all, hasLength(1));
    expect(all.single, second);
    expect(await repo.findActive('exp', oct), second);
    expect(await repo.findActive('exp', nov), isNull);
  });

  test('income category throws CategoryTypeMismatchError', () async {
    await expectLater(
      repo.setLimit(categoryId: 'inc', month: oct, limitMinor: 100),
      throwsA(isA<CategoryTypeMismatchError>()),
    );
  });

  test('limit 0 throws ValidationError', () async {
    await expectLater(
      repo.setLimit(categoryId: 'exp', month: oct, limitMinor: 0),
      throwsA(
        isA<ValidationError>().having((e) => e.field, 'field', 'limit'),
      ),
    );
  });

  test('missing or deleted category throws NotFoundError', () async {
    await expectLater(
      repo.setLimit(categoryId: 'nope', month: oct, limitMinor: 100),
      throwsA(isA<NotFoundError>()),
    );
    await categories.softDelete('exp');
    await expectLater(
      repo.setLimit(categoryId: 'exp', month: oct, limitMinor: 100),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('watchMonth only returns the requested month', () async {
    await repo.setLimit(categoryId: 'exp', month: oct, limitMinor: 100);
    await repo.setLimit(categoryId: 'exp', month: nov, limitMinor: 200);
    final list = await repo.watchMonth(nov).first;
    expect(list.single.limitMinor, 200);
    expect(list.single.month, nov);
  });

  test('softDelete and softDeleteByCategory tombstone budgets', () async {
    final a = await repo.setLimit(categoryId: 'exp', month: oct, limitMinor: 1);
    await repo.setLimit(categoryId: 'exp', month: nov, limitMinor: 1);
    await repo.setLimit(categoryId: 'exp2', month: oct, limitMinor: 1);
    await repo.softDelete(a.id);
    expect(await repo.getMonth(oct), hasLength(1));
    await repo.softDeleteByCategory('exp');
    expect(await repo.getMonth(nov), isEmpty);
    expect((await repo.getMonth(oct)).single.categoryId, 'exp2');
  });

  test(
    'after a delete setLimit creates a new budget without conflict',
    () async {
      final a = await repo.setLimit(
        categoryId: 'exp',
        month: oct,
        limitMinor: 1,
      );
      await repo.softDelete(a.id);
      final b = await repo.setLimit(
        categoryId: 'exp',
        month: oct,
        limitMinor: 2,
      );
      expect(b.id, isNot(a.id));
      expect(await repo.getMonth(oct), [b]);
    },
  );

  test('the partial unique index rejects a second active budget', () async {
    await repo.setLimit(categoryId: 'exp', month: oct, limitMinor: 1);
    final now = DateTime.utc(2026);
    await expectLater(
      db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'dup',
              categoryId: 'exp',
              month: oct,
              limitMinor: 5,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(anything),
    );
  });
}
