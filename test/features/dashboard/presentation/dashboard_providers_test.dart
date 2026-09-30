import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/features/categories/domain/default_categories.dart';
import 'package:centavo/features/dashboard/presentation/dashboard_providers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_centavo.dart';
import '../../transactions/presentation/transactions_test_helpers.dart';
import 'dashboard_test_helpers.dart';

void main() {
  testCentavo('monthSummary and monthlyTrend have exact totals', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    final summarySub = container.listen(
      monthSummaryProvider(october),
      (_, _) {},
    );
    final trendSub = container.listen(monthlyTrendProvider(october), (_, _) {});
    addTearDown(summarySub.close);
    addTearDown(trendSub.close);

    await addTransaction(tester, container, amountMinor: 1250);
    await addTransaction(tester, container, amountMinor: 725);
    await addTransaction(
      tester,
      container,
      categoryId: DefaultCategoryIds.salary,
      type: TransactionType.income,
      amountMinor: 300000,
    );

    final summary = container.read(monthSummaryProvider(october)).requireValue;
    expect(summary.expense.amountMinor, 1975);
    expect(summary.income.amountMinor, 300000);
    expect(summary.balance.amountMinor, 300000 - 1975);
    expect(summary.transactionCount, 3);

    final trend = container.read(monthlyTrendProvider(october)).requireValue;
    expect(trend, hasLength(6));
    expect(trend.last.month, october);
    expect(trend.last.expense.amountMinor, 1975);
    expect(trend.first.month, october.addMonths(-5));
    expect(trend.first.expense.amountMinor, 0);
  });

  testCentavo('the trend changes after creating an earlier transaction', (
    tester,
  ) async {
    final container = await openTransactions(tester);
    final sub = container.listen(monthlyTrendProvider(october), (_, _) {});
    addTearDown(sub.close);
    await tester.pumpAndSettle();
    var trend = container.read(monthlyTrendProvider(october)).requireValue;
    expect(trend[4].expense.amountMinor, 0);

    await addTransaction(
      tester,
      container,
      amountMinor: 4321,
      occurredOn: LocalDate(2026, 9, 20),
    );

    trend = container.read(monthlyTrendProvider(october)).requireValue;
    expect(trend[4].month, september);
    expect(trend[4].expense.amountMinor, 4321);
    expect(trend[5].expense.amountMinor, 0);
  });
}
