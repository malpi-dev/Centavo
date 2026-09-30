import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';
import 'budget_repository_contract.dart';

void main() {
  runBudgetRepositoryContract('Drift', (clock) async {
    final db = createTestDatabase();
    final ids = SequentialIdGenerator();
    return BudgetRepositoryHarness(
      repository: DriftBudgetRepository(db, clock: clock, ids: ids),
      categories: DriftCategoryRepository(db, clock: clock, ids: ids),
      dispose: db.close,
    );
  });

  group('Drift only', () {
    late AppDatabase db;
    const oct = YearMonth(2026, 10);

    setUp(() async {
      db = createTestDatabase();
      await DriftCategoryRepository(
        db,
        clock: FixedClock(DateTime.utc(2026, 10, 15, 12)),
        ids: SequentialIdGenerator(),
      ).insertIfAbsent([aCategory(id: 'exp')]);
    });
    tearDown(() => db.close());

    test('the partial unique index rejects a second active budget', () async {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: 'first',
              categoryId: 'exp',
              month: oct,
              limitMinor: 1,
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
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
  });
}
