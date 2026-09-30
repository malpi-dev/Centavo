import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/di/use_case_providers.dart';
import 'package:centavo/features/backup/domain/restore_backup.dart';
import 'package:centavo/features/backup/presentation/backup_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_controller.g.dart';

/// Runs one backup operation at a time. The error of the last operation stays
/// in [state] so the Backup screen can show it with *Retry*.
@Riverpod(keepAlive: true)
class BackupController extends _$BackupController {
  Future<void> Function()? _retry;

  /// Totals of the last successful restore (for the confirmation message).
  RestoreResult? lastRestore;

  @override
  FutureOr<void> build() {}

  /// Re-runs the operation that failed last.
  Future<void> retry() async => _retry?.call();

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    ref.read(backupStepProvider.notifier).set(null);
    if (state.hasError) {
      _retry = () => _run(action);
      return false;
    }
    _retry = null;
    return true;
  }

  /// Returns whether it succeeded; the failure is in [state].
  Future<bool> backUpNow() => _run(() async {
    final currency = ref.read(settingsControllerProvider).currencyCode;
    await ref
        .read(runBackupProvider)
        .call(
          currencyCode: currency,
          onStep: ref.read(backupStepProvider.notifier).set,
        );
  });

  /// Merges the cloud data into this device. From the welcome screen it also
  /// completes the onboarding.
  Future<bool> restore({required bool fromWelcome}) => _run(() async {
    final result = await ref.read(restoreBackupProvider).call();
    if (result.categories == 0) {
      // A profile without categories: keep the app usable.
      await ref.read(seedDefaultCategoriesProvider).call();
    }
    final currency = result.currencyCode;
    await ref
        .read(settingsControllerProvider.notifier)
        .change(
          (s) => s.copyWith(
            currencyCode: currency ?? s.currencyCode,
            onboardingCompleted: fromWelcome || s.onboardingCompleted,
          ),
        );
    lastRestore = result;
  });

  Future<bool> deleteBackup() => _run(() async {
    await ref.read(backupRepositoryProvider).deleteAll();
    await ref.read(syncStateRepositoryProvider).clearLastBackupAt();
  });

  /// Local sign-out; never touches local data.
  Future<void> signOut() async {
    if (state.isLoading) return;
    await ref.read(authRepositoryProvider).signOut();
    state = const AsyncData(null);
    _retry = null;
  }
}
