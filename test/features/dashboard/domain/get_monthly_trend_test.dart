import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/money.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/features/dashboard/domain/get_monthly_trend.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/builders.dart';

void main() {
  const useCase = GetMonthlyTrend();

  test('returns 6 months oldest first with empty months at zero', () {
    final trend = useCase(
      endMonth: const YearMonth(2026, 10),
      currencyCode: 'USD',
      transactions: [
        aTransaction(id: '1', amountMinor: 100),
        aTransaction(
          id: '2',
          type: TransactionType.income,
          amountMinor: 900,
          occurredOn: LocalDate(2026, 8, 15),
        ),
        aTransaction(
          id: '3',
          amountMinor: 50,
          occurredOn: LocalDate(2026, 8, 20),
        ),
        aTransaction(
          id: '4',
          amountMinor: 25,
          occurredOn: LocalDate(2026, 8, 1),
        ),
      ],
    );
    expect(trend, hasLength(6));
    expect(trend.first.month, const YearMonth(2026, 5));
    expect(trend.last.month, const YearMonth(2026, 10));
    expect(trend.last.expense, const Money(100, 'USD'));
    final august = trend.firstWhere((m) => m.month == const YearMonth(2026, 8));
    expect(august.income, const Money(900, 'USD'));
    expect(august.expense, const Money(75, 'USD'));
    final may = trend.first;
    expect(may.income, const Money.zero('USD'));
    expect(may.expense, const Money.zero('USD'));
  });

  test('crosses the year boundary', () {
    final trend = useCase(
      endMonth: const YearMonth(2026, 2),
      transactions: [],
      currencyCode: 'USD',
    );
    expect(trend.first.month, const YearMonth(2025, 9));
    expect(trend.last.month, const YearMonth(2026, 2));
  });

  test('ignores data outside the range and deleted rows', () {
    final trend = useCase(
      endMonth: const YearMonth(2026, 10),
      currencyCode: 'USD',
      transactions: [
        aTransaction(id: '1', occurredOn: LocalDate(2026, 4, 30)),
        aTransaction(id: '2', occurredOn: LocalDate(2026, 11, 1)),
        aTransaction(id: '3', deletedAt: DateTime.utc(2026)),
      ],
    );
    expect(trend.every((m) => m.expense.isZero && m.income.isZero), isTrue);
  });

  test('honors a custom number of months', () {
    final trend = useCase(
      endMonth: const YearMonth(2026, 10),
      transactions: [],
      currencyCode: 'USD',
      months: 3,
    );
    expect(trend.map((m) => m.month), [
      const YearMonth(2026, 8),
      const YearMonth(2026, 9),
      const YearMonth(2026, 10),
    ]);
  });
}
