import 'package:centavo/core/presentation/l10n_extension.dart';
import 'package:centavo/core/router/app_router.dart';
import 'package:centavo/core/theme/app_theme.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CentavoApp extends ConsumerWidget {
  const CentavoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
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
      debugShowCheckedModeBanner: false,
    );
  }
}
