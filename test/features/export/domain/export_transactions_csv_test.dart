import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/local_date.dart';
import 'package:centavo/core/domain/transaction_type.dart';
import 'package:centavo/core/domain/year_month.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:centavo/features/export/domain/export_transactions_csv.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/builders.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

void main() {
  const header = 'date,type,category,amount,currency,note';
  final cat = aCategory();

  String build(
    List<MoneyTransaction> transactions, {
    String currency = 'USD',
    List<Category>? cats,
  }) => buildTransactionsCsv(
    transactions: transactions,
    categoriesById: {
      for (final c in cats ?? [cat]) c.id: c,
    },
    currencyCode: currency,
  );

  test('starts with BOM and header, every line ends in CRLF', () {
    final csv = build([aTransaction(amountMinor: 1250)]);
    expect(csv.startsWith('﻿$header\r\n'), isTrue);
    expect(csv.endsWith('\r\n'), isTrue);
    expect(csv.replaceAll('\r\n', '').contains('\n'), isFalse);
    expect(csv.split('\r\n'), hasLength(3)); // header, row, trailing empty
  });

  test('formats a row', () {
    final csv = build([aTransaction(amountMinor: 1250, note: 'lunch')]);
    expect(csv.split('\r\n')[1], '2026-10-05,expense,Food,12.50,USD,lunch');
  });

  test('income type and CLP amounts have no decimals', () {
    final csv = build([
      aTransaction(type: TransactionType.income, amountMinor: 5000),
    ], currency: 'CLP');
    expect(csv.split('\r\n')[1], '2026-10-05,income,Food,5000,CLP,');
  });

  test('orders by date then createdAt ascending', () {
    final csv = build([
      aTransaction(id: 'c', occurredOn: LocalDate(2026, 10, 7), note: 'c'),
      aTransaction(
        id: 'b',
        occurredOn: LocalDate(2026, 10, 5),
        createdAt: DateTime.utc(2026, 1, 2),
        note: 'b',
      ),
      aTransaction(id: 'a', occurredOn: LocalDate(2026, 10, 5), note: 'a'),
    ]);
    final rows = csv.split('\r\n');
    expect(rows[1], endsWith(',a'));
    expect(rows[2], endsWith(',b'));
    expect(rows[3], endsWith(',c'));
  });

  test('escapes commas, quotes and newlines (RFC 4180)', () {
    final csv = build([
      aTransaction(id: '1', note: 'a,b'),
      aTransaction(
        id: '2',
        note: 'say "hi"',
        createdAt: DateTime.utc(2026, 1, 2),
      ),
      aTransaction(
        id: '3',
        note: 'line1\nline2',
        createdAt: DateTime.utc(2026, 1, 3),
      ),
    ]);
    expect(csv, contains(',USD,"a,b"\r\n'));
    expect(csv, contains(',USD,"say ""hi"""\r\n'));
    expect(csv, contains(',USD,"line1\nline2"\r\n'));
  });

  test('neutralizes formulas in notes and category names', () {
    final csv = build(
      [
        aTransaction(note: '=SUM(A1)'),
        aTransaction(
          id: '2',
          categoryId: 'evil',
          note: '@cmd',
          createdAt: DateTime.utc(2026, 1, 2),
        ),
      ],
      cats: [
        cat,
        aCategory(id: 'evil', name: '+bad'),
      ],
    );
    expect(csv, contains(",USD,'=SUM(A1)\r\n"));
    expect(csv, contains(",'+bad,10.00,USD,'@cmd\r\n"));
  });

  test('unknown category leaves the field empty', () {
    final csv = build([aTransaction(categoryId: 'ghost')]);
    expect(csv.split('\r\n')[1], '2026-10-05,expense,,10.00,USD,');
  });

  group('use case', () {
    late MockTransactionRepository transactions;
    late MockCategoryRepository categories;
    late ExportTransactionsCsv useCase;

    setUp(() {
      transactions = MockTransactionRepository();
      categories = MockCategoryRepository();
      when(() => categories.getAll()).thenAnswer((_) async => [cat]);
      useCase = ExportTransactionsCsv(
        transactions: transactions,
        categories: categories,
        clock: FixedClock(DateTime.utc(2026, 10, 9)),
      );
    });

    test('month export queries the month bounds and names the file', () async {
      when(
        () => transactions.getBetween(
          LocalDate(2026, 10, 1),
          LocalDate(2026, 11, 1),
        ),
      ).thenAnswer((_) async => [aTransaction()]);

      final doc = await useCase(
        const ExportMonth(YearMonth(2026, 10)),
        currencyCode: 'USD',
      );

      expect(doc.fileName, 'centavo-transactions-2026-10.csv');
      expect(doc.content, contains('2026-10-05,expense,Food,10.00,USD,'));
    });

    test('all export uses open bounds and today in the file name', () async {
      when(
        () => transactions.getBetween(null, null),
      ).thenAnswer((_) async => [aTransaction()]);

      final doc = await useCase(const ExportAll(), currencyCode: 'USD');

      expect(doc.fileName, 'centavo-transactions-all-2026-10-09.csv');
    });

    test('empty range throws ExportError(emptyRange)', () async {
      when(
        () => transactions.getBetween(any(), any()),
      ).thenAnswer((_) async => []);

      await expectLater(
        useCase(const ExportAll(), currencyCode: 'USD'),
        throwsA(
          isA<ExportError>().having(
            (e) => e.reason,
            'reason',
            ExportErrorReason.emptyRange,
          ),
        ),
      );
    });
  });
}
