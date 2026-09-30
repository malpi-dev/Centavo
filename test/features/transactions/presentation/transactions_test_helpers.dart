import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';

/// Pumps the app past onboarding, seeds default categories and opens the
/// Transactions tab.
Future<ProviderContainer> openTransactions(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(onboardingCompleted: true),
}) async {
  final app = await pumpCentavo(tester, settings: settings);
  await runRepo(
    tester,
    () => app.container
        .read(categoryRepositoryProvider)
        .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
  );
  await tester.tap(find.byKey(const Key('tab-transactions')));
  await tester.pumpAndSettle();
  return app.container;
}

Future<MoneyTransaction?> addTransaction(
  WidgetTester tester,
  ProviderContainer container, {
  String categoryId = DefaultCategoryIds.food,
  TransactionType type = TransactionType.expense,
  int amountMinor = 1000,
  LocalDate? occurredOn,
  String? note,
}) => runRepo(
  tester,
  () => container
      .read(transactionRepositoryProvider)
      .create(
        TransactionDraft(
          type: type,
          amountMinor: amountMinor,
          categoryId: categoryId,
          occurredOn: occurredOn ?? LocalDate(2026, 10, 5),
          note: note,
        ),
      ),
);
