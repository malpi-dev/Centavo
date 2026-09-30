import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/settings/presentation/settings_controller.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

Future<ProviderContainer> _openErase(WidgetTester tester) async {
  final app = await pumpCentavo(
    tester,
    settings: const AppSettings(
      onboardingCompleted: true,
    ),
  );
  await runRepo(
    tester,
    () => app.container
        .read(categoryRepositoryProvider)
        .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
  );
  await runRepo(
    tester,
    () => app.container
        .read(transactionRepositoryProvider)
        .create(
          TransactionDraft(
            type: TransactionType.expense,
            amountMinor: 500,
            categoryId: DefaultCategoryIds.food,
            occurredOn: LocalDate(2026, 10, 5),
          ),
        ),
  );
  await tester.tap(find.byKey(const Key('tab-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-erase')));
  await tester.pumpAndSettle();
  return app.container;
}

Future<int> _txCount(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final list = await runRepo(
    tester,
    () => container.read(transactionRepositoryProvider).getBetween(null, null),
  );
  return list!.length;
}

void main() {
  testCentavo('cancelling the first dialog erases nothing', (tester) async {
    final app = await _openErase(tester);
    expect(find.text('Erase all data?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('erase-cancel')));
    await tester.pumpAndSettle();
    expect(await _txCount(tester, app), 1);
    expect(find.text('Erase all data?'), findsNothing);
  });

  testCentavo('cancelling the second dialog erases nothing', (tester) async {
    final app = await _openErase(tester);
    await tester.tap(find.byKey(const Key('erase-continue')));
    await tester.pumpAndSettle();
    expect(find.text("This can't be undone"), findsOneWidget);
    await tester.tap(find.byKey(const Key('erase-final-cancel')));
    await tester.pumpAndSettle();
    expect(await _txCount(tester, app), 1);
    expect(
      app.read(settingsControllerProvider).onboardingCompleted,
      isTrue,
    );
  });

  testCentavo(
    'confirming both empties data, resets settings, goes to Welcome',
    (tester) async {
      final app = await _openErase(tester);
      await tester.tap(find.byKey(const Key('erase-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('erase-confirm')));
      await tester.pumpAndSettle();

      expect(await _txCount(tester, app), 0);
      final settings = app.read(settingsControllerProvider);
      expect(settings.onboardingCompleted, isFalse);

      expect(find.byKey(const Key('welcome-start-fresh')), findsOneWidget);
    },
  );
}
