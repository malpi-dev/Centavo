import 'package:centavo/features/categories/data/drift_category_repository.dart';
import 'package:centavo/features/transactions/data/drift_transaction_repository.dart';

import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';
import 'transaction_repository_contract.dart';

void main() {
  runTransactionRepositoryContract('Drift', (clock) async {
    final db = createTestDatabase();
    final ids = SequentialIdGenerator();
    return TransactionRepositoryHarness(
      repository: DriftTransactionRepository(db, clock: clock, ids: ids),
      categories: DriftCategoryRepository(db, clock: clock, ids: ids),
      dispose: db.close,
    );
  });
}
