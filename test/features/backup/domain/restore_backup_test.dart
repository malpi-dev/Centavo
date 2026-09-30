import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/backup/domain/restore_backup.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import 'backup_fixture.dart';

class _FailingTransactions extends MockTransactionRepository {
  // ignore: matching_super_parameters, the base class names it _store
  _FailingTransactions(super.store, {required super.clock})
    : super(ids: SequentialIdGenerator());

  @override
  Future<void> mergeFromBackup(List<MoneyTransaction> incoming) async =>
      throw const StorageError();
}

RestoreBackup restoreFor(Device d) => RestoreBackup(
  backup: d.cloud,
  categories: d.categories,
  budgets: d.budgets,
  transactions: d.transactions,
  syncState: d.syncState,
  localStore: d.localStore,
  clock: d.clock,
);

void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(DateTime.utc(2026, 10, 15, 12)));

  test('an empty cloud throws NotFoundError(backup)', () async {
    final d = Device(clock);
    await expectLater(
      restoreFor(d)(),
      throwsA(isA<NotFoundError>().having((e) => e.entity, 'entity', 'backup')),
    );
  });

  test('restoring into an empty device reproduces the data (CA2)', () async {
    final a = Device(clock);
    a.store.categories.add(aCategory(id: 'exp'));
    a.store.budgets.add(aBudget(categoryId: 'exp'));
    a.store.transactions.addAll([
      aTransaction(categoryId: 'exp'),
      aTransaction(id: 'tx-2', categoryId: 'exp', amountMinor: 2500),
    ]);
    await runBackupFor(a)(currencyCode: 'EUR');

    final b = Device(clock, cloud: a.cloud);
    final result = await restoreFor(b)();

    expect(result.currencyCode, 'EUR');
    expect((result.categories, result.budgets, result.transactions), (1, 1, 2));
    expect(b.store.categories, a.store.categories);
    expect(b.store.budgets, a.store.budgets);
    expect(b.store.transactions, a.store.transactions);
  });

  test(
    'last write wins in both directions and nothing local is deleted',
    () async {
      final a = Device(clock);
      final older = DateTime.utc(2026, 10);
      final newer = DateTime.utc(2026, 10, 2);
      a.cloud.seed(
        profile: const BackupProfile(currencyCode: 'USD'),
        categories: [aCategory(id: 'exp')],
        transactions: [
          aTransaction(id: 'cloud-wins', amountMinor: 200, updatedAt: newer),
          aTransaction(id: 'local-wins', amountMinor: 200, updatedAt: older),
        ],
      );
      a.store.categories.add(aCategory(id: 'exp'));
      a.store.transactions.addAll([
        aTransaction(id: 'cloud-wins', amountMinor: 100, updatedAt: older),
        aTransaction(id: 'local-wins', amountMinor: 100, updatedAt: newer),
        aTransaction(id: 'local-only', amountMinor: 100),
      ]);

      await restoreFor(a)();

      final byId = {for (final t in a.store.transactions) t.id: t.amountMinor};
      expect(byId, {'cloud-wins': 200, 'local-wins': 100, 'local-only': 100});
    },
  );

  test('a failure in the middle rolls everything back', () async {
    final source = Device(clock);
    source.store.categories.add(aCategory(id: 'exp'));
    source.store.transactions.add(aTransaction(categoryId: 'exp'));
    await runBackupFor(source)(currencyCode: 'USD');

    final d = Device(clock, cloud: source.cloud);
    final restore = RestoreBackup(
      backup: d.cloud,
      categories: d.categories,
      budgets: d.budgets,
      transactions: _FailingTransactions(d.store, clock: clock),
      syncState: d.syncState,
      localStore: d.localStore,
      clock: clock,
    );

    await expectLater(restore(), throwsA(isA<StorageError>()));

    expect(d.store.categories, isEmpty);
    expect(d.store.transactions, isEmpty);
  });

  test('does not modify lastBackupAt', () async {
    final d = Device(clock);
    d.cloud.seed(profile: const BackupProfile(currencyCode: 'USD'));
    final marker = DateTime.utc(2026, 10, 3);
    await d.syncState.setLastBackupAt(marker);

    await restoreFor(d)();

    expect(await d.syncState.lastBackupAt(), marker);
    expect(d.store.syncState['lastRestoreAt'], isNotNull);
  });
}
