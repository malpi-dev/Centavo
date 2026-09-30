import 'package:centavo/features/backup/data/drift_sync_state_repository.dart';

import '../../../helpers/test_database.dart';
import 'sync_state_repository_contract.dart';

void main() {
  runSyncStateContract('Drift', () async {
    final db = createTestDatabase();
    return SyncStateHarness(
      repository: DriftSyncStateRepository(db),
      dispose: db.close,
    );
  });
}
