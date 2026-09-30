import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';

/// Pure redirect logic, testable without widgets.
///
/// [location] is the path only; [fullLocation] (path + query) is what the lock
/// screen returns to; [lockFrom] is the decoded `from` query parameter of
/// `/lock`.
String? appRedirect({
  required String location,
  required AppSettings settings,
  required AppMode mode,
  bool isLocked = false,
  String? fullLocation,
  String? lockFrom,
  bool isBackupAvailable = true,
}) {
  final onboarded = mode == AppMode.demo || settings.onboardingCompleted;
  final inWelcome = location.startsWith(Routes.welcome);
  final inRestoreAuth =
      location.startsWith(Routes.backupSignIn) ||
      location.startsWith(Routes.backupVerify);
  // Without a Supabase configuration the backup module is hidden.
  if (!isBackupAvailable && location.startsWith(Routes.backup)) {
    return onboarded ? Routes.settings : Routes.welcome;
  }
  if (!onboarded && !inWelcome && !inRestoreAuth) return Routes.welcome;
  if (onboarded && inWelcome) return Routes.dashboard;
  final atLock = location == Routes.lock;
  if (onboarded && isLocked && !atLock) {
    final from = Uri.encodeComponent(fullLocation ?? location);
    return '${Routes.lock}?from=$from';
  }
  if (atLock && !isLocked) return _safeFrom(lockFrom) ?? Routes.dashboard;
  return null;
}

String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (from.startsWith(Routes.lock) || from.startsWith(Routes.welcome)) {
    return null;
  }
  return from;
}
