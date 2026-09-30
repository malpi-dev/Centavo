@Tags(['supabase'])
library;

import 'dart:io';

import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/utils/uuid_id_generator.dart';
import 'package:centavo/features/backup/data/drift_sync_state_repository.dart';
import 'package:centavo/features/backup/data/supabase_auth_repository.dart';
import 'package:centavo/features/backup/data/supabase_backup_repository.dart';
import 'package:centavo/features/backup/domain/restore_backup.dart';
import 'package:centavo/features/backup/domain/run_backup.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/test_database.dart';

/// Backup on device A, restore on an empty device B, against the LOCAL
/// Supabase. Skipped without SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and
/// SUPABASE_SECRET_KEY (the secret key is never stored in the repo).
void main() {
  final env = Platform.environment;
  final url = env['SUPABASE_URL'];
  final publishable = env['SUPABASE_PUBLISHABLE_KEY'];
  final secret = env['SUPABASE_SECRET_KEY'];
  final configured = url != null && publishable != null && secret != null;

  test(
    'backup then restore reproduces the data',
    () async {
      final admin = SupabaseClient(url!, secret!);
      final email =
          'roundtrip-${DateTime.now().millisecondsSinceEpoch}@centavo.test';
      final created = await admin.auth.admin.createUser(
        AdminUserAttributes(email: email, emailConfirm: true),
      );
      addTearDown(() => admin.auth.admin.deleteUser(created.user!.id));
      final link = await admin.auth.admin.generateLink(
        type: GenerateLinkType.magiclink,
        email: email,
      );

      // The app client: publishable key only, signs in with the OTP.
      final client = SupabaseClient(url, publishable!);
      final auth = SupabaseAuthRepository(client);
      await auth.verifyCode(email: email, code: link.properties.emailOtp);
      expect(auth.currentEmail, email);
      final cloud = SupabaseBackupRepository(client);

      final clock = FixedClock(DateTime.utc(2026, 10, 15, 12));
      _Device build() {
        final db = createTestDatabase();
        addTearDown(db.close);
        return _Device(db, clock);
      }

      // Device A
      final a = build();
      await a.categories.insertIfAbsent(buildDefaultCategories(clock.nowUtc()));
      await a.budgets.setLimit(
        categoryId: DefaultCategoryIds.food,
        month: const YearMonth(2026, 10),
        limitMinor: 50000,
      );
      final kept = await a.transactions.create(
        TransactionDraft(
          type: TransactionType.expense,
          amountMinor: 1234,
          categoryId: DefaultCategoryIds.food,
          occurredOn: LocalDate(2026, 10, 5),
          note: 'lunch',
        ),
      );
      final removed = await a.transactions.create(
        TransactionDraft(
          type: TransactionType.expense,
          amountMinor: 99,
          categoryId: DefaultCategoryIds.food,
          occurredOn: LocalDate(2026, 10, 6),
        ),
      );
      await a.transactions.softDelete(removed.id);

      await RunBackup(
        backup: cloud,
        categories: a.categories,
        budgets: a.budgets,
        transactions: a.transactions,
        syncState: a.syncState,
        clock: clock,
      )(currencyCode: 'EUR');

      // Device B: empty, restores.
      final b = build();
      final result = await RestoreBackup(
        backup: cloud,
        categories: b.categories,
        budgets: b.budgets,
        transactions: b.transactions,
        syncState: b.syncState,
        localStore: DriftLocalStore(b.db),
        clock: clock,
      )();

      expect(result.currencyCode, 'EUR');
      expect(
        await b.categories.changedSince(null),
        await a.categories.changedSince(null),
      );
      expect(
        await b.budgets.changedSince(null),
        await a.budgets.changedSince(null),
      );
      expect(
        await b.transactions.changedSince(null),
        await a.transactions.changedSince(null),
      );
      expect(await b.transactions.findById(kept.id), isNotNull);
      expect(await b.transactions.findById(removed.id), isNull);

      // Delete my backup leaves nothing behind.
      await cloud.deleteAll();
      expect(await cloud.fetchTransactions(), isEmpty);
      expect(await cloud.fetchCategories(), isEmpty);
    },
    skip: configured
        ? false
        : 'Set SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and SUPABASE_SECRET_KEY',
  );
}

class _Device {
  _Device(this.db, Clock clock)
    : categories = DriftCategoryRepository(
        db,
        clock: clock,
        ids: const UuidIdGenerator(),
      ),
      budgets = DriftBudgetRepository(
        db,
        clock: clock,
        ids: const UuidIdGenerator(),
      ),
      transactions = DriftTransactionRepository(
        db,
        clock: clock,
        ids: const UuidIdGenerator(),
      ),
      syncState = DriftSyncStateRepository(db);

  final AppDatabase db;
  final DriftCategoryRepository categories;
  final DriftBudgetRepository budgets;
  final DriftTransactionRepository transactions;
  final DriftSyncStateRepository syncState;
}
