import 'package:centavo/features/categories/data/mock_category_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

import '../../../helpers/sequential_id_generator.dart';
import 'category_repository_contract.dart';

void main() {
  runCategoryRepositoryContract('Mock', (clock) async {
    final store = MockDataStore();
    return CategoryRepositoryHarness(
      repository: MockCategoryRepository(
        store,
        clock: clock,
        ids: SequentialIdGenerator(),
      ),
      dispose: store.dispose,
    );
  });
}
