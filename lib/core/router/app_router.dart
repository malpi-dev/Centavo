import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/router/app_redirect.dart';
import 'package:centavo/core/router/app_shell.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:centavo/features/budgets/presentation/budget_form_screen.dart';
import 'package:centavo/features/budgets/presentation/budgets_screen.dart';
import 'package:centavo/features/categories/presentation/categories_screen.dart';
import 'package:centavo/features/categories/presentation/category_form_screen.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_screen.dart';
import 'package:centavo/features/onboarding/presentation/currency_screen.dart';
import 'package:centavo/features/onboarding/presentation/welcome_screen.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/settings/presentation/settings_screen.dart';
import 'package:centavo/features/transactions/presentation/transaction_form_screen.dart';
import 'package:centavo/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Null when [value] is missing or malformed (the form then shows "not found").
YearMonth? _tryParseMonth(String? value) {
  if (value == null) return null;
  try {
    return YearMonth.parse(value);
  } on FormatException {
    return null;
  }
}

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
      GoRoute(
        path: Routes.welcome,
        builder: (_, _) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'currency',
            builder: (_, _) => const CurrencyScreen(),
          ),
        ],
      ),
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
                routes: [
                  // Full screen (no bottom bar). `new` before `:id`.
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => TransactionFormScreen(
                      initialType:
                          TransactionType.values
                              .asNameMap()[state.uri.queryParameters['type']] ??
                          TransactionType.expense,
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => TransactionFormScreen(
                      transactionId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budgets,
                builder: (_, _) => const BudgetsScreen(),
                routes: [
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) => BudgetFormScreen(
                      categoryId: state.uri.queryParameters['category'] ?? '',
                      month: _tryParseMonth(state.uri.queryParameters['month']),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (_, _) => const CategoriesScreen(),
                    routes: [
                      // `new` must be declared before `:id`.
                      GoRoute(
                        path: 'new',
                        builder: (_, state) => CategoryFormScreen(
                          initialType: TransactionType.values
                              .asNameMap()[state.uri.queryParameters['type']],
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => CategoryFormScreen(
                          id: state.pathParameters['id'],
                        ),
                      ),
                    ],
                  ),
                ],
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
