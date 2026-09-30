import 'package:centavo/features/backup/data/mock_sync_state_repository.dart';
import 'package:centavo/features/demo/data/mock_data_store.dart';

import 'sync_state_repository_contract.dart';

void main() {
  runSyncStateContract('Mock', () async {
    final store = MockDataStore();
    return SyncStateHarness(
      repository: MockSyncStateRepository(store),
      dispose: store.dispose,
    );
  });
}
