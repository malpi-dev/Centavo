import 'package:centavo/app.dart';
import 'package:centavo/core/di/provider_retry.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const CentavoApp(),
    ),
  );
}
