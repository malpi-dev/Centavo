import 'package:centavo/core/domain/local_store.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/budgets/domain/budget_repository.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/categories/domain/delete_or_archive_category.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/builders.dart';

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

class FakeLocalStore implements LocalStore {
  int transactions = 0;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    transactions++;
    return action();
  }

  @override
  Future<void> eraseAll() async {}
}

void main() {
  late MockCategoryRepository categories;
  late MockTransactionRepository transactions;
  late MockBudgetRepository budgets;
  late FakeLocalStore store;
  late DeleteOrArchiveCategory useCase;

  setUp(() {
    categories = MockCategoryRepository();
    transactions = MockTransactionRepository();
    budgets = MockBudgetRepository();
    store = FakeLocalStore();
    useCase = DeleteOrArchiveCategory(
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      localStore: store,
    );
    when(() => categories.archive(any())).thenAnswer((_) async {});
    when(() => categories.softDelete(any())).thenAnswer((_) async {});
    when(() => budgets.softDeleteByCategory(any())).thenAnswer((_) async {});
  });

  test('archives when the category has transactions', () async {
    when(() => categories.findById('cat-1')).thenAnswer(
      (_) async => aCategory(),
    );
    when(
      () => transactions.countByCategory('cat-1'),
    ).thenAnswer((_) async => 3);

    expect(await useCase('cat-1'), CategoryRemoval.archived);

    verify(() => categories.archive('cat-1')).called(1);
    verifyNever(() => categories.softDelete(any()));
    verifyNever(() => budgets.softDeleteByCategory(any()));
    expect(store.transactions, 0);
  });

  test('deletes budgets and category inside one transaction', () async {
    when(() => categories.findById('cat-1')).thenAnswer(
      (_) async => aCategory(),
    );
    when(
      () => transactions.countByCategory('cat-1'),
    ).thenAnswer((_) async => 0);

    expect(await useCase('cat-1'), CategoryRemoval.deleted);

    verifyInOrder([
      () => budgets.softDeleteByCategory('cat-1'),
      () => categories.softDelete('cat-1'),
    ]);
    verifyNever(() => categories.archive(any()));
    expect(store.transactions, 1);
  });

  test('throws NotFoundError when the category is missing', () async {
    when(() => categories.findById('nope')).thenAnswer((_) async => null);

    await expectLater(useCase('nope'), throwsA(isA<NotFoundError>()));
    verifyNever(() => categories.softDelete(any()));
    verifyNever(() => categories.archive(any()));
  });
}
