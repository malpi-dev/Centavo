import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FixedClock clock;
  late DriftTransactionRepository repo;
  late DriftCategoryRepository categories;

  setUp(() async {
    db = createTestDatabase();
    clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
    final ids = SequentialIdGenerator();
    categories = DriftCategoryRepository(db, clock: clock, ids: ids);
    repo = DriftTransactionRepository(db, clock: clock, ids: ids);
    await categories.insertIfAbsent([
      aCategory(id: 'exp'),
      aCategory(id: 'inc', name: 'Salary', type: TransactionType.income),
    ]);
  });
  tearDown(() => db.close());

  TransactionDraft draft({
    int amount = 1000,
    String category = 'exp',
    TransactionType type = TransactionType.expense,
    LocalDate? on,
    String? note,
  }) => TransactionDraft(
    type: type,
    amountMinor: amount,
    categoryId: category,
    occurredOn: on ?? LocalDate(2026, 10, 5),
    note: note,
  );

  test('a category of another type throws CategoryTypeMismatchError', () async {
    await expectLater(
      repo.create(draft(category: 'inc')),
      throwsA(isA<CategoryTypeMismatchError>()),
    );
  });

  test('a missing or deleted category throws NotFoundError', () async {
    await expectLater(
      repo.create(draft(category: 'nope')),
      throwsA(isA<NotFoundError>()),
    );
    await categories.softDelete('exp');
    await expectLater(repo.create(draft()), throwsA(isA<NotFoundError>()));
  });

  test('amount 0 throws ValidationError', () async {
    await expectLater(
      repo.create(draft(amount: 0)),
      throwsA(isA<ValidationError>()),
    );
  });

  test('blank note is stored as null, others trimmed', () async {
    final blank = await repo.create(draft(note: '  '));
    expect(blank.note, isNull);
    final trimmed = await repo.create(draft(note: '  lunch '));
    expect((await repo.findById(trimmed.id))!.note, 'lunch');
    expect((await repo.findById(blank.id))!.note, isNull);
  });

  test('create stores UTC timestamps from the clock', () async {
    final created = await repo.create(draft());
    final stored = (await repo.findById(created.id))!;
    expect(stored, created);
    expect(stored.createdAt, clock.now);
    expect(stored.createdAt.isUtc, isTrue);
  });

  test('watchBetween includes from, excludes toExclusive, ordered', () async {
    final a = await repo.create(draft(on: LocalDate(2026, 10, 1)));
    final b = await repo.create(draft(on: LocalDate(2026, 10, 20)));
    final c = await repo.create(draft(on: LocalDate(2026, 10, 20)));
    await repo.create(draft(on: LocalDate(2026, 11, 1)));
    await repo.create(draft(on: LocalDate(2026, 9, 30)));
    final list = await repo
        .watchBetween(LocalDate(2026, 10, 1), LocalDate(2026, 11, 1))
        .first;
    expect(list.map((t) => t.id), [c.id, b.id, a.id]);
  });

  test('createdAt breaks ties on the same day (newest first)', () async {
    final first = await repo.create(draft());
    clock.now = clock.now.add(const Duration(minutes: 1));
    final second = await repo.create(draft());
    final list = await repo.getBetween(null, null);
    expect(list.map((t) => t.id), [second.id, first.id]);
  });

  test('softDelete hides, restore brings back and bumps updatedAt', () async {
    final t = await repo.create(draft());
    clock.now = clock.now.add(const Duration(hours: 1));
    await repo.softDelete(t.id);
    expect(await repo.getBetween(null, null), isEmpty);
    expect(await repo.findById(t.id), isNull);
    clock.now = clock.now.add(const Duration(hours: 1));
    await repo.restore(t.id);
    final restored = (await repo.findById(t.id))!;
    expect(restored.deletedAt, isNull);
    expect(restored.updatedAt, clock.now);
  });

  test('countByCategory ignores deleted', () async {
    final a = await repo.create(draft());
    await repo.create(draft());
    await repo.create(draft(category: 'inc', type: TransactionType.income));
    expect(await repo.countByCategory('exp'), 2);
    await repo.softDelete(a.id);
    expect(await repo.countByCategory('exp'), 1);
    expect(await repo.countByCategory('none'), 0);
  });

  test('getBetween(null, null) returns everything not deleted', () async {
    await repo.create(draft(on: LocalDate(2020, 1, 1)));
    await repo.create(draft(on: LocalDate(2030, 12, 31)));
    expect(await repo.getBetween(null, null), hasLength(2));
    expect(await repo.getBetween(LocalDate(2025, 1, 1), null), hasLength(1));
    expect(await repo.getBetween(null, LocalDate(2025, 1, 1)), hasLength(1));
  });

  test('update keeps createdAt, bumps updatedAt, checks category', () async {
    final t = await repo.create(draft());
    clock.now = clock.now.add(const Duration(hours: 1));
    final updated = await repo.update(t.copyWith(amountMinor: 2500, note: 'x'));
    expect(updated.amountMinor, 2500);
    expect(updated.createdAt, t.createdAt);
    expect(updated.updatedAt, clock.now);
    expect(await repo.findById(t.id), updated);
    await expectLater(
      repo.update(t.copyWith(categoryId: 'inc')),
      throwsA(isA<CategoryTypeMismatchError>()),
    );
    await expectLater(
      repo.update(aTransaction(id: 'nope', categoryId: 'exp')),
      throwsA(isA<NotFoundError>()),
    );
  });

  test('the stream emits after create, update and softDelete', () async {
    final expectation = expectLater(
      repo.watchBetween(LocalDate(2026, 10, 1), LocalDate(2026, 11, 1)),
      emitsInOrder([
        isEmpty,
        hasLength(1),
        predicate<List<MoneyTransaction>>((l) => l.single.amountMinor == 999),
        isEmpty,
      ]),
    );
    await Future<void>.delayed(Duration.zero);
    final t = await repo.create(draft());
    await Future<void>.delayed(Duration.zero);
    await repo.update(t.copyWith(amountMinor: 999));
    await Future<void>.delayed(Duration.zero);
    await repo.softDelete(t.id);
    await expectation;
  });
}
