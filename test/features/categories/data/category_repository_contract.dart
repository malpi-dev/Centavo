import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

class CategoryRepositoryHarness {
  CategoryRepositoryHarness({required this.repository, required this.dispose});

  final CategoryRepository repository;
  final Future<void> Function() dispose;
}

typedef CategoryRepositoryFactory =
    Future<CategoryRepositoryHarness> Function(FixedClock clock);

/// Behaviour every [CategoryRepository] implementation must satisfy.
void runCategoryRepositoryContract(
  String implementationName,
  CategoryRepositoryFactory create,
) {
  group('$implementationName CategoryRepository', () {
    late FixedClock clock;
    late CategoryRepositoryHarness harness;
    late CategoryRepository repo;

    setUp(() async {
      clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
      harness = await create(clock);
      repo = harness.repository;
    });
    tearDown(() => harness.dispose());

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

    test(
      'insertIfAbsent twice does not duplicate and keeps ids/dates',
      () async {
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
      },
    );

    test('insertIfAbsent skips ids that exist even if deleted', () async {
      final id = await make('Food');
      await repo.softDelete(id);
      await repo.insertIfAbsent([aCategory(id: id, name: 'Back')]);
      expect(await repo.getAll(), isEmpty);
    });

    group('backup sync', () {
      final t0 = DateTime.utc(2026, 10, 1, 8);
      final t1 = t0.add(const Duration(milliseconds: 1));
      final later = DateTime.utc(2026, 10, 2);

      test(
        'changedSince(null) returns everything, even archived and deleted',
        () async {
          await repo.mergeFromBackup([
            aCategory(id: 'a', name: 'A', updatedAt: t0),
            aCategory(id: 'b', name: 'B', updatedAt: t1, archivedAt: t1),
            aCategory(id: 'c', name: 'C', updatedAt: later, deletedAt: later),
          ]);
          final all = await repo.changedSince(null);
          expect(all.map((c) => c.id), ['a', 'b', 'c']);
          expect(all.last.isDeleted, isTrue);
        },
      );

      test('changedSince is strict and keeps millisecond precision', () async {
        await repo.mergeFromBackup([
          aCategory(id: 'a', name: 'A', updatedAt: t0),
          aCategory(id: 'b', name: 'B', updatedAt: t1),
        ]);
        expect((await repo.changedSince(t0)).map((c) => c.id), ['b']);
        expect(await repo.changedSince(t1), isEmpty);
      });

      test(
        'mergeFromBackup inserts unknown rows keeping their dates',
        () async {
          await repo.mergeFromBackup([
            aCategory(id: 'a', name: 'A', createdAt: t0, updatedAt: later),
          ]);
          final stored = (await repo.changedSince(null)).single;
          expect(stored.createdAt, t0);
          expect(stored.updatedAt, later);
        },
      );

      test('last write wins: the newer side is kept', () async {
        await repo.mergeFromBackup([
          aCategory(id: 'a', name: 'Old name', updatedAt: t0),
          aCategory(id: 'keep', name: 'Keep local', updatedAt: later),
        ]);
        await repo.mergeFromBackup([
          aCategory(id: 'a', name: 'New name', updatedAt: later),
          aCategory(id: 'keep', name: 'Stale cloud', updatedAt: t0),
        ]);
        final byId = {
          for (final c in await repo.changedSince(null)) c.id: c,
        };
        expect(byId['a']!.name, 'New name');
        expect(byId['keep']!.name, 'Keep local');
      });

      test(
        'mergeFromBackup never deletes rows that are not incoming',
        () async {
          final local = await make('Local only');
          await repo.mergeFromBackup([aCategory(id: 'a', name: 'A')]);
          expect(await repo.findById(local), isNotNull);
        },
      );

      test('a name clash with another active category gets a suffix', () async {
        await repo.mergeFromBackup([
          aCategory(id: 'a', updatedAt: t0),
          aCategory(id: 'b', name: 'food', updatedAt: t0),
          aCategory(id: 'c', name: 'FOOD', updatedAt: t0),
        ]);
        final names = (await repo.changedSince(null)).map((c) => c.name);
        expect(names, unorderedEquals(['Food', 'food 2', 'FOOD 3']));
      });

      test('the suffix fits in 30 characters', () async {
        final long = 'A' * 30;
        await repo.mergeFromBackup([
          aCategory(id: 'a', name: long, updatedAt: t0),
          aCategory(id: 'b', name: long, updatedAt: t0),
        ]);
        final names = (await repo.changedSince(null)).map((c) => c.name);
        expect(names, contains('${'A' * 28} 2'));
      });

      test('a clash is ignored when the incoming row is archived', () async {
        await repo.mergeFromBackup([
          aCategory(id: 'a'),
          aCategory(id: 'b', archivedAt: t0),
        ]);
        final byId = {
          for (final c in await repo.changedSince(null)) c.id: c.name,
        };
        expect(byId['b'], 'Food');
      });
    });
  });
}
