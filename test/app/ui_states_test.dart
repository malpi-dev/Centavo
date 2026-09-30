// Audit of the loading / empty / error states of definition section 12.1.
// Cells already covered by feature tests are listed in the phase 13 log; this
// file adds the ones that had no test.
import 'dart:async';

import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/presentation/skeleton.dart';
import 'package:centavo/core/router/app_router.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/backup/data/mock_auth_repository.dart';
import 'package:centavo/features/backup/data/mock_backup_repository.dart';
import 'package:centavo/features/backup/domain/backup_repository.dart';
import 'package:centavo/features/budgets/domain/budget.dart';
import 'package:centavo/features/budgets/presentation/budgets_providers.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/categories/presentation/categories_providers.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:centavo/features/export/domain/csv_share_service.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:centavo/features/security/data/mock_biometric_repository.dart';
import 'package:centavo/features/security/presentation/lock_screen.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:centavo/features/transactions/presentation/transactions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/builders.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_centavo.dart';
import '../helpers/test_overrides.dart';

const _onboarded = AppSettings(onboardingCompleted: true);

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Stream<T> _never<T>() => StreamController<T>().stream;

class _MockTransactions extends Mock implements TransactionRepository {}

class _FailingShare implements CsvShareService {
  _FailingShare(this.reason);
  final ExportErrorReason reason;

  @override
  Future<void> share(CsvDocument document) async => throw ExportError(reason);
}

void main() {
  setUpAll(() {
    registerFallbackValue(LocalDate(2026, 1, 1));
    registerFallbackValue(
      TransactionDraft(
        type: TransactionType.expense,
        amountMinor: 1,
        categoryId: 'c',
        occurredOn: LocalDate(2026, 1, 1),
      ),
    );
  });

  group('Dashboard', () {
    testCentavo('loading shows skeletons', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          rangeTransactionsProvider.overrideWith(
            (ref, args) => _never<List<MoneyTransaction>>(),
          ),
        ],
      );
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });

  group('Transactions', () {
    testCentavo('loading shows the skeleton list', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          monthTransactionsProvider.overrideWith(
            (ref, month) => _never<List<MoneyTransaction>>(),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('tab-transactions')));
      await tester.pump();
      expect(find.byKey(const Key('skeleton-list')), findsOneWidget);
    });
  });

  group('Transaction form', () {
    testCentavo('editing shows a spinner while the transaction loads', (
      tester,
    ) async {
      final completer = Completer<MoneyTransaction?>();
      final app = await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          transactionByIdProvider('tx-1').overrideWith(
            (ref) => completer.future,
          ),
        ],
      );
      app.container
          .read(appRouterProvider)
          .push(Routes.transactionEdit('tx-1'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      completer.complete();
      await tester.pumpAndSettle();
      expect(find.text('This item no longer exists.'), findsOneWidget);
    });

    testCentavo('a StorageError on save shows a SnackBar', (tester) async {
      final repo = _MockTransactions();
      when(() => repo.watchBetween(any(), any())).thenAnswer(
        (_) => Stream.value(const <MoneyTransaction>[]),
      );
      when(() => repo.getBetween(any(), any())).thenAnswer((_) async => []);
      when(() => repo.create(any())).thenThrow(const StorageError());
      final app = await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [transactionRepositoryProvider.overrideWithValue(repo)],
      );
      await runRepo(
        tester,
        () => app.container
            .read(categoryRepositoryProvider)
            .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
      );
      await _tap(tester, 'fab-add-transaction');
      await tester.enterText(find.byKey(const Key('tx-amount')), '5');
      await tester.tap(
        find.byKey(const Key('tx-category-${DefaultCategoryIds.food}')),
      );
      await tester.pump();
      await _tap(tester, 'tx-save');
      expect(
        find.text(
          'Something went wrong saving on this device. Please try again.',
        ),
        findsOneWidget,
      );
      // Stays on the form.
      expect(find.byKey(const Key('tx-save')), findsOneWidget);
    });
  });

  group('Budgets', () {
    testCentavo('loading shows a skeleton', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          monthBudgetsProvider.overrideWith(
            (ref, month) => _never<List<Budget>>(),
          ),
        ],
      );
      await tester.tap(find.byKey(const Key('tab-budgets')));
      await tester.pump();
      expect(find.byType(SkeletonBox), findsWidgets);
    });

    testCentavo('a stream error shows Retry', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          monthBudgetsProvider.overrideWith(
            (ref, month) => Stream<List<Budget>>.error(const StorageError()),
          ),
        ],
      );
      await _tap(tester, 'tab-budgets');
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
    });
  });

  group('Categories', () {
    testCentavo('loading shows the skeleton list', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          categoriesProvider.overrideWith((ref) => _never<List<Category>>()),
        ],
      );
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-categories');
      expect(find.byKey(const Key('skeleton-list')), findsOneWidget);
    });

    testCentavo('a stream error shows Retry', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        overrides: [
          categoriesProvider.overrideWith(
            (ref) => Stream<List<Category>>.error(const StorageError()),
          ),
        ],
      );
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-categories');
      expect(find.byKey(const Key('error-retry')), findsOneWidget);
    });
  });

  group('Lock', () {
    for (final (kind, message) in [
      (
        BiometricErrorKind.lockedOut,
        'Too many attempts. Unlock your device and try again.',
      ),
      (
        BiometricErrorKind.notAvailable,
        'Set up a screen lock on this device to use app lock.',
      ),
    ]) {
      testCentavo('${kind.name} shows an instruction', (tester) async {
        await pumpCentavo(
          tester,
          settings: const AppSettings(
            onboardingCompleted: true,
            biometricLockEnabled: true,
          ),
          biometric: MockBiometricRepository(nextError: BiometricError(kind)),
        );
        expect(find.byKey(const Key('lock-error')), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.byKey(const Key('lock-unlock')), findsOneWidget);
      });
    }
  });

  group('Lock waiting', () {
    testWidgets('shows a spinner while the prompt is open', (tester) async {
      final gate = Completer<void>();
      await pumpApp(
        tester,
        const LockScreen(),
        overrides: testOverrides(biometric: _GatedBiometric(gate.future)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('lock-waiting')), findsOneWidget);
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('lock-waiting')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Backup', () {
    testCentavo('signed out lists the benefits', (tester) async {
      await pumpCentavo(
        tester,
        settings: _onboarded,
        backupAvailable: true,
      );
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-backup');
      expect(find.text('Not signed in'), findsWidgets);
      expect(
        find.text('Keep your data when you change phones'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('backup-sign-in')), findsOneWidget);
    });

    testCentavo('progress shows the current step', (tester) async {
      final auth = MockAuthRepository(latency: Duration.zero);
      final cloud = MockBackupRepository(
        latency: const Duration(milliseconds: 200),
      );
      await pumpCentavo(
        tester,
        settings: _onboarded,
        backupAvailable: true,
        auth: auth,
        cloud: cloud,
      );
      await auth.verifyCode(email: 'me@test.dev', code: '123456');
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-backup');
      await tester.tap(find.byKey(const Key('backup-now')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('backup-progress')), findsOneWidget);
      expect(find.text('Preparing…'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('backup-progress')), findsNothing);
    });

    testCentavo('a paused backend shows a clear message', (tester) async {
      final auth = MockAuthRepository(latency: Duration.zero);
      final cloud = MockBackupRepository(latency: Duration.zero);
      await pumpCentavo(
        tester,
        settings: _onboarded,
        backupAvailable: true,
        auth: auth,
        cloud: cloud,
      );
      await auth.verifyCode(email: 'me@test.dev', code: '123456');
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-backup');
      cloud.failNextWith(const BackendUnavailableError());
      await _tap(tester, 'backup-now');
      expect(find.byKey(const Key('backup-error')), findsOneWidget);
      expect(
        find.textContaining('The backup service is unavailable'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('backup-retry')), findsOneWidget);
    });
  });

  group('Export', () {
    for (final (reason, message) in [
      (ExportErrorReason.writeFailed, "Couldn't create the file."),
      (ExportErrorReason.shareFailed, "Couldn't open the share sheet."),
    ]) {
      testCentavo('${reason.name} shows a SnackBar', (tester) async {
        final app = await pumpCentavo(
          tester,
          settings: _onboarded,
          csvShare: _FailingShare(reason),
        );
        await runRepo(
          tester,
          () => app.container
              .read(categoryRepositoryProvider)
              .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
        );
        await runRepo(
          tester,
          () => app.container
              .read(transactionRepositoryProvider)
              .create(
                TransactionDraft(
                  type: TransactionType.expense,
                  amountMinor: 1250,
                  categoryId: DefaultCategoryIds.food,
                  occurredOn: LocalDate(2026, 10, 5),
                ),
              ),
        );
        await _tap(tester, 'tab-settings');
        await _tap(tester, 'settings-export');
        await _tap(tester, 'export-run');
        expect(find.text(message), findsOneWidget);
      });
    }

    testCentavo('the button shows progress while generating', (tester) async {
      final gate = Completer<void>();
      final app = await pumpCentavo(
        tester,
        settings: _onboarded,
        csvShare: _SlowShare(gate.future),
      );
      await runRepo(
        tester,
        () => app.container
            .read(categoryRepositoryProvider)
            .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
      );
      await runRepo(
        tester,
        () => app.container
            .read(transactionRepositoryProvider)
            .create(
              TransactionDraft(
                type: TransactionType.expense,
                amountMinor: 1250,
                categoryId: DefaultCategoryIds.food,
                occurredOn: LocalDate(2026, 10, 5),
              ),
            ),
      );
      await _tap(tester, 'tab-settings');
      await _tap(tester, 'settings-export');
      await tester.tap(find.byKey(const Key('export-run')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.descendant(
          of: find.byKey(const Key('export-run')),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('Welcome / Restore', () {
    testCentavo('restoring shows a spinner', (tester) async {
      final cloud =
          MockBackupRepository(
            latency: const Duration(milliseconds: 200),
          )..seed(
            profile: const BackupProfile(currencyCode: 'USD'),
            categories: buildDefaultCategories(DateTime.utc(2026)),
          );
      await pumpCentavo(
        tester,
        backupAvailable: true,
        auth: MockAuthRepository(latency: Duration.zero),
        cloud: cloud,
      );
      await _tap(tester, 'welcome-restore');
      await tester.enterText(
        find.byKey(const Key('backup-email')),
        'me@test.dev',
      );
      await _tap(tester, 'backup-send-code');
      await tester.enterText(find.byKey(const Key('backup-code')), '123456');
      await tester.tap(find.byKey(const Key('backup-verify')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('restoring')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('restoring')), findsNothing);
    });
  });
}

class _GatedBiometric extends MockBiometricRepository {
  _GatedBiometric(this.gate);
  final Future<void> gate;

  @override
  Future<void> authenticate({required String reason}) => gate;
}

class _SlowShare implements CsvShareService {
  _SlowShare(this.gate);
  final Future<void> gate;

  @override
  Future<void> share(CsvDocument document) => gate;
}
