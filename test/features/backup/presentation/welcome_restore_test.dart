import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/pump_centavo.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> _restoreFromWelcome(WidgetTester tester) async {
  await _tap(tester, 'welcome-restore');
  await tester.enterText(find.byKey(const Key('backup-email')), 'me@test.dev');
  await _tap(tester, 'backup-send-code');
  // Not demo: no hint.
  expect(find.text('Demo code: 123456'), findsNothing);
  await tester.enterText(find.byKey(const Key('backup-code')), '123456');
  await _tap(tester, 'backup-verify');
}

void main() {
  testCentavo('Restore from backup is hidden when backup is unavailable', (
    tester,
  ) async {
    await pumpCentavo(tester, backupAvailable: false);
    expect(find.byKey(const Key('welcome-restore')), findsNothing);
    expect(find.byKey(const Key('welcome-explore-demo')), findsOneWidget);
  });

  testCentavo('restoring from Welcome merges the cloud and opens the app', (
    tester,
  ) async {
    final cloud = MockBackupRepository(latency: Duration.zero)
      ..seed(
        profile: const BackupProfile(currencyCode: 'EUR'),
        categories: buildDefaultCategories(DateTime.utc(2026)),
        transactions: [
          aTransaction(
            categoryId: DefaultCategoryIds.food,
          ),
        ],
      );
    final app = await pumpCentavo(
      tester,
      backupAvailable: true,
      cloud: cloud,
    );

    await _restoreFromWelcome(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    final settings = app.container.read(settingsControllerProvider);
    expect(settings.currencyCode, 'EUR');
    expect(settings.onboardingCompleted, isTrue);
    final restored = await tester.runAsync(
      () => app.container.read(transactionRepositoryProvider).findById('tx-1'),
    );
    expect(restored, isNotNull);
    final categories = await tester.runAsync(
      () => app.container.read(categoryRepositoryProvider).getAll(),
    );
    expect(categories, hasLength(10));
  });

  testCentavo('without a backup, a dialog offers to start fresh', (
    tester,
  ) async {
    final app = await pumpCentavo(tester, backupAvailable: true);

    await _restoreFromWelcome(tester);

    expect(find.text('No backup found'), findsOneWidget);
    expect(
      app.container.read(settingsControllerProvider).onboardingCompleted,
      isFalse,
    );
    await _tap(tester, 'no-backup-start-fresh');
    expect(find.text('Choose your currency'), findsOneWidget);
  });

  testCentavo('cancelling the dialog keeps the verify screen', (tester) async {
    await pumpCentavo(tester, backupAvailable: true);
    await _restoreFromWelcome(tester);

    await _tap(tester, 'no-backup-cancel');

    expect(find.byKey(const Key('backup-verify')), findsOneWidget);
  });

  testCentavo('a network error while restoring offers Retry', (tester) async {
    final cloud = MockBackupRepository(latency: Duration.zero)
      ..seed(profile: const BackupProfile(currencyCode: 'USD'));
    final app = await pumpCentavo(
      tester,
      backupAvailable: true,
      cloud: cloud,
    );
    await _tap(tester, 'welcome-restore');
    await tester.enterText(
      find.byKey(const Key('backup-email')),
      'me@test.dev',
    );
    await _tap(tester, 'backup-send-code');
    await tester.enterText(find.byKey(const Key('backup-code')), '123456');
    cloud.failNextWith(const NetworkError());
    await _tap(tester, 'backup-verify');

    expect(find.textContaining("You're offline"), findsOneWidget);
    await _tap(tester, 'restore-retry');

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      app.container.read(settingsControllerProvider).onboardingCompleted,
      isTrue,
    );
  });
}
