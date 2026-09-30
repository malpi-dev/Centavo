import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/features/backup/data/mock_auth_repository.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/data/mock_sync_state_repository.dart';
import 'package:centavo/features/backup/presentation/auto_backup_controller.dart';
import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/settings/data/in_memory_settings_repository.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';

final _now = DateTime.utc(2026, 10, 15, 12);

/// Local mode on mock repositories (there is no Supabase in tests).
class _Harness {
  _Harness({
    this.signedIn = true,
    bool available = true,
    bool autoBackup = true,
    this.lastBackup,
  }) {
    container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        isBackupAvailableProvider.overrideWithValue(available),
        authRepositoryProvider.overrideWithValue(auth),
        backupRepositoryProvider.overrideWithValue(cloud),
        syncStateRepositoryProvider.overrideWithValue(sync),
        settingsRepositoryProvider.overrideWithValue(
          InMemorySettingsRepository(
            AppSettings(
              onboardingCompleted: true,
              autoBackupEnabled: autoBackup,
            ),
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          MockCategoryRepository(
            store,
            clock: clock,
            ids: SequentialIdGenerator(),
          ),
        ),
        budgetRepositoryProvider.overrideWithValue(
          MockBudgetRepository(
            store,
            clock: clock,
            ids: SequentialIdGenerator(),
          ),
        ),
        transactionRepositoryProvider.overrideWithValue(
          MockTransactionRepository(
            store,
            clock: clock,
            ids: SequentialIdGenerator(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  final bool signedIn;
  final DateTime? lastBackup;
  final clock = FixedClock(_now);
  final auth = MockAuthRepository(latency: Duration.zero);
  final cloud = MockBackupRepository(latency: Duration.zero);
  final store = MockDataStore(
    categories: [aCategory(id: 'exp')],
    transactions: [aTransaction(categoryId: 'exp')],
  );
  late final sync = MockSyncStateRepository(store);
  late final ProviderContainer container;

  /// Builds the controller (it tries once) and then simulates a resume.
  Future<void> open() async {
    if (signedIn) await auth.verifyCode(email: 'me@test.dev', code: '123456');
    if (lastBackup != null) await sync.setLastBackupAt(lastBackup!);
    container.read(autoBackupControllerProvider);
    await pumpEventQueue();
    await container.read(autoBackupControllerProvider.notifier).maybeRun();
    await pumpEventQueue();
  }

  Future<bool> get didBackUp async => (await cloud.fetchProfile()) != null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backs up when there is no previous backup', () async {
    final h = _Harness();
    await h.open();
    expect(await h.didBackUp, isTrue);
    expect(h.cloud.transactionCount, 1);
    expect(await h.sync.lastBackupAt(), _now);
  });

  test('backs up when the last backup is at least 24 h old', () async {
    final h = _Harness(lastBackup: _now.subtract(const Duration(hours: 24)));
    await h.open();
    expect(await h.didBackUp, isTrue);
    expect(await h.sync.lastBackupAt(), _now);
  });

  test('does not back up when the last backup is under 24 h old', () async {
    final last = _now.subtract(const Duration(hours: 23));
    final h = _Harness(lastBackup: last);
    await h.open();
    expect(await h.didBackUp, isFalse);
    expect(await h.sync.lastBackupAt(), last);
  });

  test('does not back up without a session', () async {
    final h = _Harness(signedIn: false);
    await h.open();
    expect(await h.didBackUp, isFalse);
  });

  test('does not back up when the setting is off', () async {
    final h = _Harness(autoBackup: false);
    await h.open();
    expect(await h.didBackUp, isFalse);
  });

  test('does not back up when backup is unavailable', () async {
    final h = _Harness(available: false);
    await h.open();
    expect(await h.didBackUp, isFalse);
  });

  test('does not back up in demo mode', () async {
    final h = _Harness();
    h.container.read(appModeControllerProvider.notifier).enterDemo();
    await h.open();
    expect(await h.didBackUp, isFalse);
  });
}
