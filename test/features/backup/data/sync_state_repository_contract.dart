import 'package:centavo/features/backup/domain/sync_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class SyncStateHarness {
  SyncStateHarness({required this.repository, required this.dispose});

  final SyncStateRepository repository;
  final Future<void> Function() dispose;
}

void runSyncStateContract(
  String name,
  Future<SyncStateHarness> Function() create,
) {
  group('$name SyncStateRepository', () {
    late SyncStateHarness harness;
    late SyncStateRepository repo;
    final t = DateTime.utc(2026, 10, 15, 12, 30, 45, 123);

    setUp(() async {
      harness = await create();
      repo = harness.repository;
    });
    tearDown(() => harness.dispose());

    test('starts empty', () async {
      expect(await repo.lastBackupAt(), isNull);
    });

    test('stores lastBackupAt with millisecond precision in UTC', () async {
      await repo.setLastBackupAt(t);
      final read = await repo.lastBackupAt();
      expect(read, t);
      expect(read!.isUtc, isTrue);
    });

    test('clearLastBackupAt forgets it', () async {
      await repo.setLastBackupAt(t);
      await repo.clearLastBackupAt();
      expect(await repo.lastBackupAt(), isNull);
    });

    test('lastRestoreAt is independent of lastBackupAt', () async {
      await repo.setLastRestoreAt(t);
      expect(await repo.lastBackupAt(), isNull);
    });

    test('the stream emits the current value and every change', () async {
      final expectation = expectLater(
        repo.watchLastBackupAt(),
        emitsInOrder([isNull, t, isNull]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.setLastBackupAt(t);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.clearLastBackupAt();
      await expectation;
    });
  });
}
