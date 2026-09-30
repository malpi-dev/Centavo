import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  test('foreign keys are enabled', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);
  });

  test('inserting a transaction with an unknown category fails', () async {
    final now = DateTime.utc(2026);
    expect(
      db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              id: 't1',
              type: TransactionType.expense,
              amountMinor: 100,
              categoryId: 'missing',
              occurredOn: LocalDate(2026, 1, 1),
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(anything),
    );
  });

  test('the four tables and the partial indexes exist', () async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type IN ('table', 'index')",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'categories',
        'transactions',
        'budgets',
        'sync_state',
        'categories_active_name_type',
        'budgets_active_category_month',
        'transactions_occurred_on',
      ]),
    );
  });

  test('dates are stored as ISO text', () async {
    final now = DateTime.utc(2026, 3, 4, 5, 6, 7);
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'c',
            name: 'Food',
            type: TransactionType.expense,
            icon: 'food',
            color: 0xFFE65100,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final row = await db
        .customSelect('SELECT created_at, typeof(created_at) t FROM categories')
        .getSingle();
    expect(row.read<String>('t'), 'text');
    expect(row.read<String>('created_at'), startsWith('2026-03-04T05:06:07'));
  });
}
