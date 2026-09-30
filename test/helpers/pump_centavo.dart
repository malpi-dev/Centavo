import 'package:centavo/app.dart';
import 'package:centavo/core/database/app_database.dart';
import 'package:centavo/core/di/provider_retry.dart';
import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';
import 'test_overrides.dart';

/// Pumps the whole app on an in-memory database.
Future<({AppDatabase db, ProviderContainer container})> pumpCentavo(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(),
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = const Size(800, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final db = createTestDatabase();
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [
        ...testOverrides(settings: settings),
        appDatabaseProvider.overrideWithValue(db),
        ...overrides,
      ],
      child: const CentavoApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(CentavoApp)),
  );
  return (db: db, container: container);
}

/// Unmounts the app so Drift's stream-cancel timers fire before the test's
/// pending-timer check.
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// `testWidgets` that always unmounts the app at the end.
void testCentavo(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await disposeApp(tester);
  });
}

/// Runs [action] (repository calls against the in-memory database) outside the
/// fake-async zone and lets Drift deliver stream updates.
Future<T?> runRepo<T>(WidgetTester tester, Future<T> Function() action) async {
  final result = await tester.runAsync(() async {
    final value = await action();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return value;
  });
  await tester.pumpAndSettle();
  return result;
}
