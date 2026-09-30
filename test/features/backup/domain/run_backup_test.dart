import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/domain/run_backup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import 'backup_fixture.dart';

void main() {
  late FixedClock clock;

  setUp(() => clock = FixedClock(DateTime.utc(2026, 10, 15, 12)));

  Device deviceWith(MockBackupRepository cloud) {
    final d = Device(clock, cloud: cloud);
    d.store.categories.addAll([
      aCategory(id: 'exp'),
      aCategory(id: 'old', name: 'Old', deletedAt: DateTime.utc(2026, 2)),
    ]);
    d.store.budgets.add(aBudget(categoryId: 'exp'));
    d.store.transactions.add(aTransaction(categoryId: 'exp'));
    return d;
  }

  test('the first backup uploads everything, in FK order', () async {
    final cloud = RecordingCloud();
    final d = deviceWith(cloud);
    final steps = <BackupStep>[];

    final result = await runBackupFor(d)(
      currencyCode: 'EUR',
      onStep: steps.add,
    );

    expect(cloud.calls, ['categories', 'budgets', 'transactions']);
    expect(steps, BackupStep.values);
    expect(
      (result.categories, result.budgets, result.transactions),
      (2, 1, 1),
    );
    expect(cloud.currencies, ['EUR']);
    expect((await cloud.fetchProfile())!.currencyCode, 'EUR');
    expect(await d.syncState.lastBackupAt(), clock.nowUtc());
  });

  test('the second backup only uploads what changed since', () async {
    final cloud = RecordingCloud();
    final d = deviceWith(cloud);
    await runBackupFor(d)(currencyCode: 'USD');
    cloud.calls.clear();
    cloud.transactionBatchSizes.clear();

    clock.now = clock.now.add(const Duration(hours: 1));
    d.store.transactions.add(
      aTransaction(
        id: 'new',
        categoryId: 'exp',
        updatedAt: clock.now.add(const Duration(seconds: 1)),
      ),
    );
    final result = await runBackupFor(d)(currencyCode: 'USD');

    expect(
      (result.categories, result.budgets, result.transactions),
      (0, 0, 1),
    );
    expect(cloud.calls, ['transactions']);
    expect(cloud.transactionBatchSizes, [1]);
  });

  test('tombstones are uploaded before active rows', () async {
    final cloud = RecordingCloud();
    final d = Device(clock, cloud: cloud);
    d.store.categories.addAll([
      aCategory(id: 'a', name: 'A', updatedAt: DateTime.utc(2026)),
      aCategory(
        id: 'b',
        name: 'B',
        updatedAt: DateTime.utc(2026, 1, 2),
        deletedAt: DateTime.utc(2026, 1, 2),
      ),
      aCategory(id: 'c', name: 'C', updatedAt: DateTime.utc(2026, 1, 3)),
    ]);

    await runBackupFor(d)(currencyCode: 'USD');

    expect(cloud.categoryBatches.single, ['b', 'a', 'c']);
  });

  test('1201 transactions go up in batches of 500, 500 and 201', () async {
    final cloud = RecordingCloud();
    final d = Device(clock, cloud: cloud);
    d.store.categories.add(aCategory(id: 'exp'));
    d.store.transactions.addAll([
      for (var i = 0; i < 1201; i++)
        aTransaction(id: 'tx-$i', categoryId: 'exp'),
    ]);

    await runBackupFor(d)(currencyCode: 'USD');

    expect(cloud.transactionBatchSizes, [500, 500, 201]);
    expect(cloud.transactionCount, 1201);
  });

  test('when the upload fails lastBackupAt does not change', () async {
    final cloud = RecordingCloud(failTransactions: true);
    final d = deviceWith(cloud);
    final previous = DateTime.utc(2026, 10);
    await d.syncState.setLastBackupAt(previous);
    d.store.transactions.add(
      aTransaction(id: 'newer', categoryId: 'exp', updatedAt: clock.now),
    );

    await expectLater(
      runBackupFor(d)(currencyCode: 'USD'),
      throwsA(isA<NetworkError>()),
    );

    expect(await d.syncState.lastBackupAt(), previous);
  });

  test('lastBackupAt is the START time even if the upload is slow', () async {
    final start = clock.nowUtc();
    final cloud = RecordingCloud(
      onUploadTransactions: () =>
          clock.now = clock.now.add(const Duration(minutes: 5)),
    );
    final d = deviceWith(cloud);

    final result = await runBackupFor(d)(currencyCode: 'USD');

    expect(result.startedAt, start);
    expect(await d.syncState.lastBackupAt(), start);
  });

  test('edits made while uploading are picked up by the next backup', () async {
    final cloud = RecordingCloud();
    final d = deviceWith(cloud);
    cloud.calls.clear();
    await runBackupFor(d)(currencyCode: 'USD');
    // Edited "during" the backup: after its start time.
    d.store.transactions[0] = d.store.transactions[0].copyWith(
      amountMinor: 777,
      updatedAt: clock.now.add(const Duration(seconds: 2)),
    );
    cloud.transactionBatchSizes.clear();

    await runBackupFor(d)(currencyCode: 'USD');

    expect(cloud.transactionBatchSizes, [1]);
  });
}
