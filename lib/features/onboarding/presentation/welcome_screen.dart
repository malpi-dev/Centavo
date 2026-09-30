import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder until phase 06 replaces it with the real onboarding flow.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.welcomeTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('welcome-start-fresh'),
              onPressed: () => ref
                  .read(settingsControllerProvider.notifier)
                  .change((s) => s.copyWith(onboardingCompleted: true)),
              child: Text(l10n.startFresh),
            ),
          ],
        ),
      ),
    );
  }
}
