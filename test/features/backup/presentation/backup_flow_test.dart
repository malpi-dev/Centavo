import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/backup/data/mock_auth_repository.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

/// Enters demo and opens Settings -> Backup -> Sign in -> email -> code screen.
Future<ProviderContainer> _openVerify(
  WidgetTester tester, {
  MockBackupRepository? cloud,
}) async {
  final app = await pumpCentavo(tester, cloud: cloud);
  app.container.read(appModeControllerProvider.notifier).enterDemo();
  await tester.pumpAndSettle();
  await _tap(tester, 'tab-settings');
  await _tap(tester, 'settings-backup');
  expect(find.text('Not signed in'), findsWidgets);
  await _tap(tester, 'backup-sign-in');
  await tester.enterText(find.byKey(const Key('backup-email')), 'me@test.dev');
  await _tap(tester, 'backup-send-code');
  expect(find.text('Demo code: 123456'), findsOneWidget);
  return app.container;
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('backup-code')), '123456');
  await _tap(tester, 'backup-verify');
}

void main() {
  testCentavo('demo: a wrong code shows an error, the right one backs up', (
    tester,
  ) async {
    final cloud = MockBackupRepository(latency: Duration.zero);
    await _openVerify(tester, cloud: cloud);

    await tester.enterText(find.byKey(const Key('backup-code')), '000000');
    await _tap(tester, 'backup-verify');
    expect(find.text('The code is invalid or has expired.'), findsOneWidget);

    await _signIn(tester);

    expect(find.text('Last backup: just now'), findsOneWidget);
    expect(find.text('Signed in as me@test.dev'), findsOneWidget);
    expect(cloud.transactionCount, greaterThan(0));
    expect(cloud.categoryCount, greaterThan(0));
  });

  testCentavo('demo: sign out keeps the local transactions', (tester) async {
    final container = await _openVerify(tester);
    await _signIn(tester);

    await _tap(tester, 'backup-sign-out');
    await _tap(tester, 'sign-out-confirm');

    expect(find.byKey(const Key('backup-sign-in')), findsOneWidget);
    final store = container.read(demoDataStoreProvider);
    expect(store.transactions, isNotEmpty);
  });

  testCentavo('demo: delete my backup asks twice and empties the cloud', (
    tester,
  ) async {
    final cloud = MockBackupRepository(latency: Duration.zero);
    await _openVerify(tester, cloud: cloud);
    await _signIn(tester);
    expect(cloud.transactionCount, greaterThan(0));

    await _tap(tester, 'backup-delete');
    await _tap(tester, 'backup-delete-first-cancel');
    expect(cloud.transactionCount, greaterThan(0));

    await _tap(tester, 'backup-delete');
    await _tap(tester, 'backup-delete-first-confirm');
    expect(cloud.transactionCount, greaterThan(0));
    await _tap(tester, 'backup-delete-final-confirm');

    expect(cloud.transactionCount, 0);
    expect(cloud.categoryCount, 0);
    expect(find.text('Last backup: never'), findsOneWidget);
  });

  testCentavo('demo: restore asks for confirmation and reports totals', (
    tester,
  ) async {
    await _openVerify(tester);
    await _signIn(tester);

    await _tap(tester, 'backup-restore');
    expect(
      find.textContaining('Nothing on this device is deleted'),
      findsOneWidget,
    );
    await _tap(tester, 'restore-confirm');

    expect(find.textContaining('Restored'), findsOneWidget);
  });

  testCentavo('a network failure shows a clear message with Retry', (
    tester,
  ) async {
    final cloud = MockBackupRepository(latency: Duration.zero);
    await _openVerify(tester, cloud: cloud);
    await _signIn(tester);

    cloud.failNextWith(const NetworkError());
    await _tap(tester, 'backup-now');
    expect(find.textContaining("You're offline"), findsOneWidget);

    await _tap(tester, 'backup-retry');
    expect(find.byKey(const Key('backup-error')), findsNothing);
  });

  test('the mock auth accepts only the demo code', () async {
    final auth = MockAuthRepository(latency: Duration.zero);
    await expectLater(
      auth.verifyCode(email: 'a@b.co', code: '654321'),
      throwsA(anything),
    );
    await auth.verifyCode(email: 'a@b.co', code: '123456');
    expect(auth.currentEmail, 'a@b.co');
  });
}
