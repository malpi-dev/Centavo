import 'package:centavo/app.dart';
import 'package:centavo/core/config/env.dart';
import 'package:centavo/core/di/provider_retry.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final font in ['Manrope', 'Inter']) {
      final text = await rootBundle.loadString('assets/fonts/OFL-$font.txt');
      yield LicenseEntryWithLineBreaks([font], text);
    }
  });
  // initialize() makes no network request, so it never blocks offline starts.
  if (Env.isBackupEnabled) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabasePublishableKey,
    );
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CentavoApp(),
    ),
  );
}
