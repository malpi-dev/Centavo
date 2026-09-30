import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';

/// Pure redirect logic, testable without widgets.
String? appRedirect({
  required String location,
  required AppSettings settings,
  required AppMode mode,
}) {
  final onboarded = mode == AppMode.demo || settings.onboardingCompleted;
  final inWelcome = location.startsWith(Routes.welcome);
  final inRestoreAuth =
      location.startsWith(Routes.backupSignIn) ||
      location.startsWith(Routes.backupVerify);
  if (!onboarded && !inWelcome && !inRestoreAuth) return Routes.welcome;
  if (onboarded && inWelcome) return Routes.dashboard;
  return null;
}
