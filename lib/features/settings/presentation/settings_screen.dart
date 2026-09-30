import 'package:centavo/core/presentation/empty_state.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Placeholder until its phase replaces it.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: EmptyState(icon: Icons.settings, title: l10n.comingSoon),
    );
  }
}
