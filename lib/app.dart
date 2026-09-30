import 'package:centavo/core/di/app_mode_provider.dart';
import 'package:centavo/core/domain/app_mode.dart';
import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/presentation/root_scaffold_messenger.dart';
import 'package:centavo/core/router/app_router.dart';
import 'package:centavo/core/theme/app_theme.dart';
import 'package:centavo/features/backup/presentation/auto_backup_controller.dart';
import 'package:centavo/features/demo/presentation/demo_banner.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CentavoApp extends ConsumerWidget {
  const CentavoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoBackupControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      routerConfig: ref.watch(appRouterProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (ref.watch(
        settingsControllerProvider.select((s) => s.themePreference),
      )) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final isDemo = ref.watch(appModeControllerProvider) == AppMode.demo;
        if (!isDemo) return child!;
        return Column(
          children: [
            const DemoBanner(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child!,
              ),
            ),
          ],
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
