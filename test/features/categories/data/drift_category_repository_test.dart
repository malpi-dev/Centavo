import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftCategoryRepository repo;

  setUp(() {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    repo = DriftCategoryRepository(
      db,
      clock: clock,
      ids: SequentialIdGenerator(),
    );
  });
  tearDown(() => db.close());

  Future<String> make(
    String name, {
    TransactionType type = TransactionType.expense,
  }) async => (await repo.create(
    name: name,
    type: type,
    icon: 'food',
    color: 0xFFE65100,
  )).id;

  test('create emits the new category on watchAll', () async {
    final stream = repo.watchAll();
    final first = expectLater(
      stream,
      emitsInOrder([
        isEmpty,
        predicate<List<dynamic>>((l) => l.length == 1),
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    final created = await repo.create(
      name: '  Eating   out ',
      type: TransactionType.expense,
      icon: 'food',
      color: 0xFFE65100,
    );
    expect(created.name, 'Eating out');
    expect(created.isDefault, isFalse);
    expect(created.createdAt, clock.now);
    await first;
  });

  test('duplicate with different casing throws DuplicateError', () async {
    await make('Food');
    await expectLater(make('fOOd'), throwsA(isA<DuplicateError>()));
  });

  test('same name with another type is allowed', () async {
    await make('Other');
    await make('Other', type: TransactionType.income);
    expect(await repo.getAll(), hasLength(2));
  });

  test('duplicate of an archived category is allowed', () async {
    final id = await make('Food');
    await repo.archive(id);
    await make('Food');
    expect(await repo.getAll(), hasLength(2));
  });

  test('unarchive with a conflicting active category throws', () async {
    final id = await make('Food');
    await repo.archive(id);
    await make('Food');
    await expectLater(repo.unarchive(id), throwsA(isA<DuplicateError>()));
  });

  test('unarchive clears archivedAt', () async {
    final id = await make('Food');
    await repo.archive(id);
    expect((await repo.findById(id))!.isArchived, isTrue);
    await repo.unarchive(id);
    expect((await repo.findById(id))!.isArchived, isFalse);
  });

  test('changing the type is not allowed', () async {
    final created = await repo.create(
      name: 'Food',
      type: TransactionType.expense,
      icon: 'food',
      color: 0xFFE65100,
    );
    await expectLater(
      repo.update(created.copyWith(type: TransactionType.income)),
      throwsA(
        isA<ValidationError>()
            .having((e) => e.field, 'field', 'type')
            .having((e) => e.reason, 'reason', ValidationReason.notAllowed),
      ),
    );
  });

  test('update changes name and bumps updatedAt, keeps createdAt', () async {
    final created = await repo.create(
      name: 'Food',
      type: TransactionType.expense,
      icon: 'food',
      color: 0xFFE65100,
    );
    clock.now = clock.now.add(const Duration(hours: 1));
    final updated = await repo.update(created.copyWith(name: 'Groceries'));
    expect(updated.name, 'Groceries');
    expect(updated.updatedAt, clock.now);
    final stored = (await repo.findById(created.id))!;
    expect(stored.name, 'Groceries');
    expect(stored.createdAt, created.createdAt);
    expect(stored.updatedAt, clock.now);
    expect(stored.updatedAt.isUtc, isTrue);
  });

  test('update of a missing category throws NotFoundError', () async {
    await expectLater(
      repo.update(aCategory(id: 'nope')),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('update to an existing active name throws DuplicateError', () async {
    await make('Food');
    final other = await repo.create(
      name: 'Home',
      type: TransactionType.expense,
      icon: 'home',
      color: 0xFF6D4C41,
    );
    await expectLater(
      repo.update(other.copyWith(name: 'food')),
      throwsA(isA<DuplicateError>()),
    );
  });

  test('invalid input throws ValidationError', () async {
    await expectLater(make('  '), throwsA(isA<ValidationError>()));
  });

  test('softDelete removes it from watchAll and findById', () async {
    final id = await make('Food');
    await repo.softDelete(id);
    expect(await repo.getAll(), isEmpty);
    expect(await repo.findById(id), isNull);
    await expectLater(repo.softDelete(id), throwsA(isA<NotFoundError>()));
  });

  test('ordering: expenses first, then name ignoring case', () async {
    await make('banana');
    await make('Apple');
    await make('Salary', type: TransactionType.income);
    await make('Zed');
    final names = (await repo.getAll()).map((c) => c.name).toList();
    expect(names, ['Apple', 'banana', 'Zed', 'Salary']);
  });

  test('insertIfAbsent twice does not duplicate and keeps ids/dates', () async {
    final t = DateTime.utc(2020, 5, 6, 7, 8, 9);
    final category = aCategory(
      id: 'fixed-id',
      createdAt: t,
      updatedAt: t,
      isDefault: true,
    );
    await repo.insertIfAbsent([category]);
    await repo.insertIfAbsent([category.copyWith(name: 'Changed')]);
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single, category);
  });

  test('insertIfAbsent skips ids that exist even if deleted', () async {
    final id = await make('Food');
    await repo.softDelete(id);
    await repo.insertIfAbsent([aCategory(id: id, name: 'Back')]);
    expect(await repo.getAll(), isEmpty);
  });
}
