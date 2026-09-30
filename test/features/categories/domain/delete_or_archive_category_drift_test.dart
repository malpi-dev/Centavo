import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/database/drift_local_store.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/budgets/data/drift_budget_repository.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/categories/domain/delete_or_archive_category.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';

/// Integration of the use case with the real Drift repositories.
void main() {
  late AppDatabase db;
  late DriftCategoryRepository categories;
  late DriftTransactionRepository transactions;
  late DriftBudgetRepository budgets;
  late DeleteOrArchiveCategory useCase;
  const month = YearMonth(2026, 10);

  setUp(() async {
    db = createTestDatabase();
    final clock = FixedClock(DateTime.utc(2026, 10, 15));
    final ids = SequentialIdGenerator();
    categories = DriftCategoryRepository(db, clock: clock, ids: ids);
    transactions = DriftTransactionRepository(db, clock: clock, ids: ids);
    budgets = DriftBudgetRepository(db, clock: clock, ids: ids);
    useCase = DeleteOrArchiveCategory(
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      localStore: DriftLocalStore(db),
    );
    await categories.insertIfAbsent([
      aCategory(id: 'used'),
      aCategory(id: 'unused', name: 'Unused'),
    ]);
    await budgets.setLimit(categoryId: 'used', month: month, limitMinor: 100);
    await budgets.setLimit(categoryId: 'unused', month: month, limitMinor: 100);
  });
  tearDown(() => db.close());

  test('with transactions the category is archived', () async {
    await transactions.create(
      TransactionDraft(
        type: TransactionType.expense,
        amountMinor: 500,
        categoryId: 'used',
        occurredOn: LocalDate(2026, 10, 2),
      ),
    );
    expect(await useCase('used'), CategoryRemoval.archived);
    expect((await categories.findById('used'))!.isArchived, isTrue);
    expect(await budgets.getMonth(month), hasLength(2));
  });

  test(
    'without transactions the category and its budgets are deleted',
    () async {
      expect(await useCase('unused'), CategoryRemoval.deleted);
      expect(await categories.findById('unused'), isNull);
      final remaining = await budgets.getMonth(month);
      expect(remaining.map((b) => b.categoryId), ['used']);
    },
  );
}
