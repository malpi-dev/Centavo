import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/backup/domain/run_backup.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_providers.g.dart';

/// The signed-in email, or null. Always null when backup is unavailable.
@riverpod
Stream<String?> signedInEmail(Ref ref) => ref.watch(isBackupAvailableProvider)
    ? ref.watch(authRepositoryProvider).watchSignedInEmail()
    : Stream.value(null);

@riverpod
Stream<DateTime?> lastBackupAt(Ref ref) =>
    ref.watch(syncStateRepositoryProvider).watchLastBackupAt();

/// The step of the backup in progress (null when idle).
@Riverpod(keepAlive: true)
class BackupStepNotifier extends _$BackupStepNotifier {
  @override
  BackupStep? build() => null;

  // A plain setter would not be visible to `ref.read(...notifier)` callers.
  // ignore: use_setters_to_change_properties
  void set(BackupStep? step) => state = step;
}
