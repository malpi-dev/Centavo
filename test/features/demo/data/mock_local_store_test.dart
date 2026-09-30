import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/demo/data/mock_local_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/domain/local_store_contract.dart';
import '../../../helpers/sequential_id_generator.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 10, 15, 12));

  runLocalStoreContract('Mock', () async {
    final store = MockDataStore();
    return LocalStoreHarness(
      store: MockLocalStore(store),
      categories: MockCategoryRepository(
        store,
        clock: clock,
        ids: SequentialIdGenerator(),
      ),
      dispose: store.dispose,
    );
  });

  group('Mock only', () {
    late MockDataStore store;
    late MockLocalStore local;

    setUp(() {
      final data = DemoDataset.build(clock);
      store = MockDataStore(
        categories: data.categories,
        transactions: data.transactions,
        budgets: data.budgets,
      );
      local = MockLocalStore(store);
    });
    tearDown(() => store.dispose());

    test('rollback restores the three lists and notifies', () async {
      final counts = (
        store.categories.length,
        store.transactions.length,
        store.budgets.length,
      );
      final notified = <MockTable>[];
      final sub = store.watch(MockTable.budgets, () => 0).listen((_) {
        notified.add(MockTable.budgets);
      });
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        local.runInTransaction<void>(() async {
          store.categories.clear();
          store.transactions.removeLast();
          store.budgets.clear();
          throw StateError('boom');
        }),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.categories, hasLength(counts.$1));
      expect(store.transactions, hasLength(counts.$2));
      expect(store.budgets, hasLength(counts.$3));
      expect(notified, hasLength(2)); // initial value + rollback
      await sub.cancel();
    });

    test('eraseAll empties every list and the sync state', () async {
      store.syncState['lastBackupAt'] = 'x';
      await local.eraseAll();
      expect(store.categories, isEmpty);
      expect(store.transactions, isEmpty);
      expect(store.budgets, isEmpty);
      expect(store.syncState, isEmpty);
    });
  });
}
