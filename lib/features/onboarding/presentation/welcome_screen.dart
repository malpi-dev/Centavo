import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/icon/splash_logo.png',
                  height: 96,
                  width: 96,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.welcomeTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.welcomeSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Semantics(
                  identifier: 'welcome-start-fresh',
                  child: FilledButton(
                    key: const Key('welcome-start-fresh'),
                    onPressed: () => context.push(Routes.welcomeCurrency),
                    child: Text(l10n.startFresh),
                  ),
                ),
                const SizedBox(height: 12),
                if (ref.watch(isBackupAvailableProvider)) ...[
                  Semantics(
                    identifier: 'welcome-restore',
                    child: OutlinedButton(
                      key: const Key('welcome-restore'),
                      onPressed: () => context.push(
                        '${Routes.backupSignIn}?from=welcome',
                      ),
                      child: Text(l10n.restoreFromBackup),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Semantics(
                  identifier: 'welcome-explore-demo',
                  child: OutlinedButton(
                    key: const Key('welcome-explore-demo'),
                    onPressed: () => ref
                        .read(appModeControllerProvider.notifier)
                        .enterDemo(),
                    child: Text(l10n.exploreDemo),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
