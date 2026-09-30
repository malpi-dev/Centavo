import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/router/app_redirect.dart';
import 'package:centavo/core/router/app_shell.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/budgets/presentation/budgets_screen.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:centavo/features/onboarding/presentation/welcome_screen.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/settings/presentation/settings_screen.dart';
import 'package:centavo/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(settingsControllerProvider, (_, _) => refresh.value++)
    ..listen(appModeControllerProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(
      location: state.uri.path,
      settings: ref.read(settingsControllerProvider),
      mode: ref.read(appModeControllerProvider),
    ),
    routes: [
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.dashboard,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.transactions,
                builder: (_, _) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budgets,
                builder: (_, _) => const BudgetsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
