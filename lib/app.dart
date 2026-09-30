import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class CentavoApp extends StatelessWidget {
  const CentavoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: Text(AppLocalizations.of(context).appTitle)),
        ),
      ),
    );
  }
}
