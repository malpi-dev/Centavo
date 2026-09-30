import 'package:centavo/core/domain/id_generator.dart';
import 'package:centavo/features/categories/data/drift_category_repository.dart';

import '../../../helpers/sequential_id_generator.dart';
import '../../../helpers/test_database.dart';
import 'category_repository_contract.dart';

void main() {
  runCategoryRepositoryContract('Drift', (clock) async {
    final db = createTestDatabase();
    final IdGenerator ids = SequentialIdGenerator();
    return CategoryRepositoryHarness(
      repository: DriftCategoryRepository(db, clock: clock, ids: ids),
      dispose: db.close,
    );
  });
}
