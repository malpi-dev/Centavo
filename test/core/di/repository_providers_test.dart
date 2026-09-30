import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/demo/data/demo_dataset.dart';
import 'package:centavo/features/demo/data/mock_local_store.dart';
import 'package:centavo/features/settings/data/prefs_settings_repository.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late AppDatabase db;
  var databaseBuilt = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    databaseBuilt = false;
    db = createTestDatabase();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWith((ref) {
          databaseBuilt = true;
          return db;
        }),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 10, 15, 12)),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  AppModeController mode() =>
      container.read(appModeControllerProvider.notifier);

  test('local mode uses the Drift and prefs implementations', () {
    expect(
      container.read(categoryRepositoryProvider),
      isA<DriftCategoryRepository>(),
    );
    expect(
      container.read(transactionRepositoryProvider),
      isA<DriftTransactionRepository>(),
    );
    expect(
      container.read(budgetRepositoryProvider),
      isA<DriftBudgetRepository>(),
    );
    expect(
      container.read(settingsRepositoryProvider),
      isA<PrefsSettingsRepository>(),
    );
    expect(databaseBuilt, isTrue);
  });

  test(
    'demo mode swaps every repository for its mock without opening Drift',
    () {
      mode().enterDemo();
      expect(
        container.read(categoryRepositoryProvider),
        isA<MockCategoryRepository>(),
      );
      expect(
        container.read(transactionRepositoryProvider),
        isA<MockTransactionRepository>(),
      );
      expect(
        container.read(budgetRepositoryProvider),
        isA<MockBudgetRepository>(),
      );
      expect(container.read(localStoreProvider), isA<MockLocalStore>());
      expect(databaseBuilt, isFalse);
      expect(container.exists(appDatabaseProvider), isFalse);
    },
  );

  test('demo settings are onboarded and in USD', () {
    mode().enterDemo();
    final settings = container.read(settingsControllerProvider);
    expect(settings.onboardingCompleted, isTrue);
    expect(settings.currencyCode, DemoDataset.currencyCode);
  });

  test(
    'demo data is preloaded and goes back to real settings on exit',
    () async {
      mode().enterDemo();
      final categories = await container
          .read(categoryRepositoryProvider)
          .getAll();
      expect(categories, hasLength(13));
      mode().exitDemo();
      expect(
        container.read(settingsControllerProvider).onboardingCompleted,
        isFalse,
      );
      expect(
        await container.read(categoryRepositoryProvider).getAll(),
        isEmpty,
      );
    },
  );

  test('changes made in demo vanish after exit and re-enter', () async {
    mode().enterDemo();
    final transactions = container.read(transactionRepositoryProvider);
    final before = await transactions.getBetween(null, null);
    final created = await transactions.create(
      TransactionDraft(
        type: TransactionType.expense,
        amountMinor: 999,
        categoryId: DefaultCategoryIds.food,
        occurredOn: LocalDate(2026, 10, 15),
      ),
    );
    expect(await transactions.findById(created.id), isNotNull);

    mode()
      ..exitDemo()
      ..enterDemo();
    final fresh = container.read(transactionRepositoryProvider);
    expect(await fresh.findById(created.id), isNull);
    expect(await fresh.getBetween(null, null), hasLength(before.length));
  });
}
