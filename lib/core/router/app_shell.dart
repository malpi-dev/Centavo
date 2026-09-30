import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      // Dashboard, Transactions and Budgets only (not Settings).
      floatingActionButton: navigationShell.currentIndex <= 2
          ? Semantics(
              identifier: 'fab-add-transaction',
              child: FloatingActionButton(
                key: const Key('fab-add-transaction'),
                tooltip: l10n.addTransaction,
                onPressed: () =>
                    context.push('${Routes.transactionNew}?type=expense'),
                child: const Icon(Icons.add),
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            key: const Key('tab-dashboard'),
            icon: const Icon(Icons.space_dashboard),
            label: l10n.tabDashboard,
          ),
          NavigationDestination(
            key: const Key('tab-transactions'),
            icon: const Icon(Icons.receipt_long),
            label: l10n.tabTransactions,
          ),
          NavigationDestination(
            key: const Key('tab-budgets'),
            icon: const Icon(Icons.savings),
            label: l10n.tabBudgets,
          ),
          NavigationDestination(
            key: const Key('tab-settings'),
            icon: const Icon(Icons.settings),
            label: l10n.tabSettings,
          ),
        ],
      ),
    );
  }
}
