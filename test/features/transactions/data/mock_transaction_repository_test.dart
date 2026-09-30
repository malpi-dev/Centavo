import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';
import 'package:centavo/features/transactions/data/mock_transaction_repository.dart';

import '../../../helpers/sequential_id_generator.dart';
import 'transaction_repository_contract.dart';

void main() {
  runTransactionRepositoryContract('Mock', (clock) async {
    final store = MockDataStore();
    final ids = SequentialIdGenerator();
    return TransactionRepositoryHarness(
      repository: MockTransactionRepository(store, clock: clock, ids: ids),
      categories: MockCategoryRepository(store, clock: clock, ids: ids),
      dispose: store.dispose,
    );
  });
}
