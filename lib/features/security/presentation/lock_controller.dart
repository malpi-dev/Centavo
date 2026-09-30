import 'dart:async';

import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'lock_controller.g.dart';

/// `true` = the app is locked.
@Riverpod(keepAlive: true)
class LockController extends _$LockController {
  static const relockAfter = Duration(seconds: 30);
  DateTime? _backgroundedAt;
  bool _authenticating = false;

  @override
  bool build() {
    // Cold start: locked if the lock is enabled. `read` (not `watch`) so
    // settings changes don't re-lock.
    final enabled = ref.read(settingsControllerProvider).biometricLockEnabled;
    unawaited(_syncSecureWindow(enabled: enabled));
    ref
      ..listen(settingsControllerProvider, (prev, next) {
        final isEnabled = next.biometricLockEnabled;
        if (prev?.biometricLockEnabled == isEnabled) return;
        // FLAG_SECURE follows the setting: hides the recents thumbnail.
        unawaited(_syncSecureWindow(enabled: isEnabled));
        if (!isEnabled) state = false;
      })
      // Entering or leaving demo never locks.
      ..listen(appModeControllerProvider, (_, _) => state = false);
    final listener = AppLifecycleListener(
      onHide: onBackgrounded,
      onShow: onForegrounded,
    );
    ref.onDispose(listener.dispose);
    return enabled;
  }

  Future<void> _syncSecureWindow({required bool enabled}) =>
      ref.read(secureWindowServiceProvider).setSecure(secure: enabled);

  @visibleForTesting
  void onBackgrounded() {
    if (!_authenticating) _backgroundedAt = ref.read(clockProvider).nowUtc();
  }

  @visibleForTesting
  void onForegrounded() {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (_authenticating || since == null) return;
    final enabled = ref.read(settingsControllerProvider).biometricLockEnabled;
    if (enabled &&
        ref.read(clockProvider).nowUtc().difference(since) >= relockAfter) {
      state = true;
    }
  }

  /// Throws BiometricError on failure; the lock screen shows the message.
  Future<void> unlock(String reason) async {
    await confirmIdentity(reason);
    state = false;
  }

  /// Shows the system prompt without touching the lock state (used to confirm
  /// turning the lock on). The prompt pauses the app, so it must not re-lock.
  Future<void> confirmIdentity(String reason) async {
    _authenticating = true;
    try {
      await ref.read(biometricRepositoryProvider).authenticate(reason: reason);
    } finally {
      _authenticating = false;
    }
  }
}
