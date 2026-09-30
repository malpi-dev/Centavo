import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Placeholder until its phase replaces it.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabBudgets)),
      body: EmptyState(icon: Icons.savings, title: l10n.comingSoon),
    );
  }
}
