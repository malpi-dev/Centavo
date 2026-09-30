import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:flutter_test/flutter_test.dart';

class LocalStoreHarness {
  LocalStoreHarness({
    required this.store,
    required this.categories,
    required this.dispose,
  });

  final LocalStore store;
  final CategoryRepository categories;
  final Future<void> Function() dispose;
}

typedef LocalStoreFactory = Future<LocalStoreHarness> Function();

/// Behaviour every [LocalStore] implementation must satisfy.
void runLocalStoreContract(
  String implementationName,
  LocalStoreFactory create,
) {
  group('$implementationName LocalStore', () {
    late LocalStoreHarness harness;
    final clock = FixedClock(DateTime.utc(2026, 10, 15));

    setUp(() async => harness = await create());
    tearDown(() => harness.dispose());

    test('runInTransaction rolls back when the action throws', () async {
      await expectLater(
        harness.store.runInTransaction<void>(() async {
          await harness.categories.insertIfAbsent(
            buildDefaultCategories(clock.nowUtc()),
          );
          throw StateError('boom');
        }),
        throwsA(anything),
      );
      expect(await harness.categories.getAll(), isEmpty);
    });

    test('runInTransaction commits and returns the result', () async {
      final result = await harness.store.runInTransaction(() async {
        await harness.categories.insertIfAbsent(
          buildDefaultCategories(clock.nowUtc()),
        );
        return 42;
      });
      expect(result, 42);
      expect(await harness.categories.getAll(), hasLength(10));
    });

    test('eraseAll removes the categories', () async {
      await harness.categories.insertIfAbsent(
        buildDefaultCategories(clock.nowUtc()),
      );
      await harness.store.eraseAll();
      expect(await harness.categories.getAll(), isEmpty);
    });
  });
}
