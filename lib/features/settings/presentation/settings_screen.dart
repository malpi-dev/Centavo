import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Provisional: the full settings screen arrives in phase 10.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabSettings)),
      body: ListView(
        children: [
          ListTile(
            key: const Key('settings-categories'),
            leading: const Icon(Icons.category),
            title: Text(l10n.categoriesTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.categories),
          ),
        ],
      ),
    );
  }
}
