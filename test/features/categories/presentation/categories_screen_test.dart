import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

Future<ProviderContainer> openCategories(WidgetTester tester) async {
  final app = await pumpCentavo(
    tester,
    settings: const AppSettings(onboardingCompleted: true),
  );
  await runRepo(
    tester,
    () => app.container
        .read(categoryRepositoryProvider)
        .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
  );
  await tester.tap(find.byKey(const Key('tab-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-categories')));
  await tester.pumpAndSettle();
  return app.container;
}

void main() {
  testCentavo(
    'shows Expenses and Income sections, Archived hidden when empty',
    (
      tester,
    ) async {
      await openCategories(tester);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Archived'), findsNothing);
      expect(
        find.byKey(const Key('category-${DefaultCategoryIds.food}')),
        findsOneWidget,
      );
      expect(find.text('Default'), findsWidgets);
    },
  );

  testCentavo('shows Archived once a category is archived', (tester) async {
    final container = await openCategories(tester);
    await runRepo(
      tester,
      () => container
          .read(categoryRepositoryProvider)
          .archive(DefaultCategoryIds.shopping),
    );
    await tester.pumpAndSettle();
    expect(find.text('Archived'), findsOneWidget);
  });

  testCentavo('tapping a category opens the edit form', (tester) async {
    await openCategories(tester);
    await tester.tap(
      find.byKey(const Key('category-${DefaultCategoryIds.food}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit category'), findsOneWidget);
    expect(find.byKey(const Key('category-name')), findsOneWidget);
  });
}
