import 'package:centavo/features/budgets/data/mock_budget_repository.dart';
import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

import '../../../helpers/sequential_id_generator.dart';
import 'budget_repository_contract.dart';

void main() {
  runBudgetRepositoryContract('Mock', (clock) async {
    final store = MockDataStore();
    final ids = SequentialIdGenerator();
    return BudgetRepositoryHarness(
      repository: MockBudgetRepository(store, clock: clock, ids: ids),
      categories: MockCategoryRepository(store, clock: clock, ids: ids),
      dispose: store.dispose,
    );
  });
}
