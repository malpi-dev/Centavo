import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/export/data/mock_csv_share_service.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

Future<ProviderContainer> _open(
  WidgetTester tester,
  MockCsvShareService share, {
  bool withData = true,
}) async {
  final app = await pumpCentavo(
    tester,
    settings: const AppSettings(onboardingCompleted: true),
    csvShare: share,
  );
  await runRepo(
    tester,
    () => app.container
        .read(categoryRepositoryProvider)
        .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
  );
  if (withData) {
    await runRepo(
      tester,
      () => app.container
          .read(transactionRepositoryProvider)
          .create(
            TransactionDraft(
              type: TransactionType.expense,
              amountMinor: 1250,
              categoryId: DefaultCategoryIds.food,
              occurredOn: LocalDate(2026, 10, 5),
              note: 'Café',
            ),
          ),
    );
  }
  await tester.tap(find.byKey(const Key('tab-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('settings-export')));
  await tester.pumpAndSettle();
  return app.container;
}

Future<void> _run(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('export-run')));
  await tester.pumpAndSettle();
}

void main() {
  testCentavo('empty month shows an inline message and shares nothing', (
    tester,
  ) async {
    final share = MockCsvShareService();
    await _open(tester, share, withData: false);
    await _run(tester);
    expect(find.text('Nothing to export for this range.'), findsOneWidget);
    expect(share.shared, isEmpty);
  });

  testCentavo('This month shares the month file with the header', (
    tester,
  ) async {
    final share = MockCsvShareService();
    await _open(tester, share);
    await _run(tester);
    expect(share.last!.fileName, 'centavo-transactions-2026-10.csv');
    expect(
      share.last!.content,
      startsWith('﻿date,type,category,amount,currency,note\r\n'),
    );
    expect(share.last!.content, contains('2026-10-05,expense,Food,12.50,USD'));
    expect(find.text('Nothing to export for this range.'), findsNothing);
  });

  testCentavo('All time uses the all-time file name', (tester) async {
    final share = MockCsvShareService();
    await _open(tester, share);
    await tester.tap(find.byKey(const Key('export-range-all')));
    await tester.pumpAndSettle();
    await _run(tester);
    expect(share.last!.fileName, 'centavo-transactions-all-2026-10-15.csv');
  });

  testCentavo('Choose a month exports the selected month', (tester) async {
    final share = MockCsvShareService();
    await _open(tester, share);
    await tester.tap(find.byKey(const Key('export-range-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('month-prev')));
    await tester.pumpAndSettle();
    await _run(tester);
    // September 2026 has no data.
    expect(share.shared, isEmpty);
    expect(find.text('Nothing to export for this range.'), findsOneWidget);
  });
}
