import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

class BudgetRepositoryHarness {
  BudgetRepositoryHarness({
    required this.repository,
    required this.categories,
    required this.dispose,
  });

  final BudgetRepository repository;
  final CategoryRepository categories;
  final Future<void> Function() dispose;
}

typedef BudgetRepositoryFactory =
    Future<BudgetRepositoryHarness> Function(FixedClock clock);

/// Behaviour every [BudgetRepository] implementation must satisfy.
void runBudgetRepositoryContract(
  String implementationName,
  BudgetRepositoryFactory create,
) {
  group('$implementationName BudgetRepository', () {
    late FixedClock clock;
    late BudgetRepositoryHarness harness;
    late BudgetRepository repo;
    late CategoryRepository categories;
    const oct = YearMonth(2026, 10);
    const nov = YearMonth(2026, 11);

    setUp(() async {
      clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
      harness = await create(clock);
      repo = harness.repository;
      categories = harness.categories;
      await categories.insertIfAbsent([
        aCategory(id: 'exp'),
        aCategory(id: 'exp2', name: 'Home'),
        aCategory(id: 'inc', name: 'Salary', type: TransactionType.income),
      ]);
    });
    tearDown(() => harness.dispose());

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
      final a = await repo.setLimit(
        categoryId: 'exp',
        month: oct,
        limitMinor: 1,
      );
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

    group('backup sync', () {
      final t0 = DateTime.utc(2026, 10, 1, 8);
      final t1 = t0.add(const Duration(milliseconds: 1));
      final later = DateTime.utc(2026, 10, 2);

      test('changedSince includes deleted rows, ordered, strict', () async {
        await repo.mergeFromBackup([
          aBudget(categoryId: 'exp', id: 'a', updatedAt: t0),
          aBudget(categoryId: 'exp', id: 'b', month: nov, updatedAt: t1),
          aBudget(
            id: 'c',
            categoryId: 'exp2',
            updatedAt: later,
            deletedAt: later,
          ),
        ]);
        expect((await repo.changedSince(null)).map((b) => b.id), [
          'a',
          'b',
          'c',
        ]);
        expect((await repo.changedSince(t0)).map((b) => b.id), ['b', 'c']);
      });

      test('last write wins by id', () async {
        await repo.mergeFromBackup([
          aBudget(categoryId: 'exp', id: 'a', limitMinor: 100, updatedAt: t0),
          aBudget(
            categoryId: 'exp',
            id: 'b',
            month: nov,
            limitMinor: 100,
            updatedAt: later,
          ),
        ]);
        await repo.mergeFromBackup([
          aBudget(
            categoryId: 'exp',
            id: 'a',
            limitMinor: 200,
            updatedAt: later,
          ),
          aBudget(
            categoryId: 'exp',
            id: 'b',
            month: nov,
            limitMinor: 999,
            updatedAt: t0,
          ),
        ]);
        final byId = {for (final b in await repo.changedSince(null)) b.id: b};
        expect(byId['a']!.limitMinor, 200);
        expect(byId['b']!.limitMinor, 100);
      });

      test(
        'a newer incoming budget replaces the local one of the same month',
        () async {
          await repo.mergeFromBackup([
            aBudget(categoryId: 'exp', id: 'local', updatedAt: t0),
          ]);
          await repo.mergeFromBackup([
            aBudget(
              categoryId: 'exp',
              id: 'cloud',
              limitMinor: 555,
              updatedAt: later,
            ),
          ]);
          final active = await repo.getMonth(oct);
          expect(active.map((b) => b.id), ['cloud']);
          final local = (await repo.changedSince(null)).firstWhere(
            (b) => b.id == 'local',
          );
          expect(local.deletedAt, clock.nowUtc());
          expect(local.updatedAt, clock.nowUtc());
        },
      );

      test('an older incoming budget is stored as a tombstone', () async {
        await repo.mergeFromBackup([
          aBudget(categoryId: 'exp', id: 'local', updatedAt: later),
        ]);
        await repo.mergeFromBackup([
          aBudget(categoryId: 'exp', id: 'cloud', updatedAt: t0),
        ]);
        expect((await repo.getMonth(oct)).map((b) => b.id), ['local']);
        final cloud = (await repo.changedSince(null)).firstWhere(
          (b) => b.id == 'cloud',
        );
        expect(cloud.deletedAt, clock.nowUtc());
      });
    });
  });
}
