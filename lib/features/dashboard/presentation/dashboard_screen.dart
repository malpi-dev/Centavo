import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Placeholder until its phase replaces it.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabDashboard)),
      body: EmptyState(icon: Icons.space_dashboard, title: l10n.comingSoon),
    );
  }
}
