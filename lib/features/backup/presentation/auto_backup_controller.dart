import 'dart:async';

import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/features/backup/presentation/backup_controller.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_backup_controller.g.dart';

/// Backs up silently when the app opens or returns to the foreground, at most
/// once every [minInterval]. Never runs with the app closed. Errors stay
/// visible on the Backup screen (no SnackBar).
@Riverpod(keepAlive: true)
class AutoBackupController extends _$AutoBackupController {
  static const minInterval = Duration(hours: 24);

  @override
  void build() {
    final listener = AppLifecycleListener(
      onResume: () => unawaited(maybeRun()),
    );
    ref.onDispose(listener.dispose);
    // Not inside build(): it starts another provider's operation.
    unawaited(Future.microtask(maybeRun));
  }

  Future<void> maybeRun() async {
    if (ref.read(appModeControllerProvider) != AppMode.local) return;
    if (!ref.read(isBackupAvailableProvider)) return;
    if (!ref.read(settingsControllerProvider).autoBackupEnabled) return;
    if (ref.read(authRepositoryProvider).currentEmail == null) return;
    if (ref.read(backupControllerProvider).isLoading) return;
    final last = await ref.read(syncStateRepositoryProvider).lastBackupAt();
    if (!ref.mounted) return;
    final now = ref.read(clockProvider).nowUtc();
    if (last != null && now.difference(last) < minInterval) return;
    await ref.read(backupControllerProvider.notifier).backUpNow();
  }
}
