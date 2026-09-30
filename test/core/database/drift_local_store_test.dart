import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/sequential_id_generator.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DriftLocalStore store;
  late CategoryRepository categories;
  final clock = FixedClock(DateTime.utc(2026, 10, 15));

  setUp(() {
    db = createTestDatabase();
    store = DriftLocalStore(db);
    categories = DriftCategoryRepository(
      db,
      clock: clock,
      ids: SequentialIdGenerator(),
    );
  });
  tearDown(() => db.close());

  test('runInTransaction rolls back when the action throws', () async {
    await expectLater(
      store.runInTransaction<void>(() async {
        await categories.insertIfAbsent(buildDefaultCategories(clock.nowUtc()));
        throw StateError('boom');
      }),
      throwsA(anything),
    );
    expect(await categories.getAll(), isEmpty);
  });

  test('runInTransaction commits and returns the result', () async {
    final result = await store.runInTransaction(() async {
      await categories.insertIfAbsent(buildDefaultCategories(clock.nowUtc()));
      return 42;
    });
    expect(result, 42);
    expect(await categories.getAll(), hasLength(10));
  });

  test('eraseAll empties the four tables', () async {
    await categories.insertIfAbsent(buildDefaultCategories(clock.nowUtc()));
    await db
        .into(db.syncState)
        .insert(SyncStateCompanion.insert(key: 'lastBackupAt', value: 'x'));
    await store.eraseAll();
    expect(await db.select(db.categories).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.syncState).get(), isEmpty);
  });
}
