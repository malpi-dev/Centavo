import 'package:centavo/core/di/repository_providers.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/core/theme/centavo_colors.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/dashboard/domain/get_monthly_trend.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:centavo/features/dashboard/presentation/trend_bar_chart.dart';
import 'package:centavo/features/settings/domain/app_settings.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import '../../transactions/presentation/transactions_test_helpers.dart';
import 'dashboard_test_helpers.dart';

void main() {
  testCentavo('an empty month shows the Add transaction call to action', (
    tester,
  ) async {
    await openDashboard(tester);
    expect(find.text('No transactions in October 2026'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-donut')), findsNothing);
    await tester.tap(find.byKey(const Key('dashboard-add-first')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tx-amount')), findsOneWidget);
  });

  testCentavo('cards show the exact sum of the month (F5 CA1)', (tester) async {
    final container = await openDashboard(tester);
    await addTransaction(tester, container, amountMinor: 1250);
    await addTransaction(tester, container, amountMinor: 725);
    await addTransaction(
      tester,
      container,
      categoryId: DefaultCategoryIds.salary,
      type: TransactionType.income,
      amountMinor: 300000,
    );

    expect(amountText(tester, 'dashboard-expense').data, r'$19.75');
    expect(amountText(tester, 'dashboard-income').data, r'$3,000.00');
    expect(amountText(tester, 'dashboard-balance').data, r'$2,980.25');
    expect(find.byKey(const Key('dashboard-donut')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-donut-total')), findsOneWidget);
  });

  testCentavo('a negative balance is drawn in the expense color', (
    tester,
  ) async {
    final container = await openDashboard(tester);
    await addTransaction(tester, container, amountMinor: 5000);
    final context = tester.element(find.byKey(const Key('dashboard-balance')));
    expect(amountText(tester, 'dashboard-balance').data, r'−$50.00');
    expect(
      amountText(tester, 'dashboard-balance').style?.color,
      context.colors.expense,
    );
  });

  testCentavo('income without expenses shows "No expenses this month"', (
    tester,
  ) async {
    final container = await openDashboard(tester);
    await addTransaction(
      tester,
      container,
      categoryId: DefaultCategoryIds.salary,
      type: TransactionType.income,
      amountMinor: 100000,
    );
    expect(find.text('No expenses this month'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-donut')), findsNothing);
    expect(
      amountText(tester, 'dashboard-balance').style?.color,
      tester.element(find.byKey(const Key('dashboard-balance'))).colors.income,
    );
  });

  testCentavo('the month selector stops at the current month', (tester) async {
    await openDashboard(tester);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('month-next'))).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('month-prev')));
    await tester.pumpAndSettle();
    expect(find.text('No transactions in September 2026'), findsOneWidget);
  });

  testCentavo('without budgets, the card offers Set up budgets', (
    tester,
  ) async {
    await openDashboard(tester);
    expect(find.text('No budgets this month'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dashboard-set-up-budgets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('budgets-summary')), findsNothing);
    expect(find.text('No budgets for October 2026'), findsOneWidget);
  });

  testCentavo('See all goes to the Budgets tab', (tester) async {
    final container = await openDashboard(tester);
    await addTransaction(tester, container);
    await tester.tap(find.byKey(const Key('dashboard-see-budgets')));
    await tester.pumpAndSettle();
    expect(find.text('No budgets for October 2026'), findsOneWidget);
  });

  testCentavo('a failing section shows Retry and the others keep working', (
    tester,
  ) async {
    final app = await pumpCentavo(
      tester,
      settings: const AppSettings(onboardingCompleted: true),
      overrides: [
        rangeTransactionsProvider.overrideWith(
          (ref, args) =>
              Stream<List<MoneyTransaction>>.error(const StorageError()),
        ),
      ],
    );
    await runRepo(
      tester,
      () => app.container
          .read(categoryRepositoryProvider)
          .insertIfAbsent(buildDefaultCategories(DateTime.utc(2026))),
    );
    await addTransaction(tester, app.container, amountMinor: 1250);
    expect(find.byKey(const Key('error-retry')), findsOneWidget);
    expect(amountText(tester, 'dashboard-expense').data, r'$12.50');
  });

  testCentavo('the chart tooltip reads Month, Income and Expenses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            final item = TrendChart.tooltipFor(
              context,
              const MonthTotals(
                month: october,
                income: Money(365000, 'USD'),
                expense: Money(182035, 'USD'),
              ),
            );
            return Text(item.text);
          },
        ),
      ),
    );
    expect(
      find.text(r'Oct · Income $3,650.00 · Expenses $1,820.35'),
      findsOneWidget,
    );
  });
}
