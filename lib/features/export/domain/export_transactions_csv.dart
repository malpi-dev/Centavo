import 'package:centavo/core/domain/amount_parser.dart';
import 'package:centavo/core/domain/clock.dart';
import 'package:centavo/core/domain/currency.dart';
import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/categories/domain/category.dart';
import 'package:centavo/features/categories/domain/category_repository.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:centavo/features/transactions/domain/money_transaction.dart';
import 'package:centavo/features/transactions/domain/transaction_repository.dart';

class ExportTransactionsCsv {
  ExportTransactionsCsv({
    required this._transactions,
    required this._categories,
    required this._clock,
  });

  final TransactionRepository _transactions;
  final CategoryRepository _categories;
  final Clock _clock;

  /// Throws ExportError(emptyRange) when there is nothing to export.
  Future<CsvDocument> call(
    ExportRange range, {
    required String currencyCode,
  }) async {
    final (list, fileName) = switch (range) {
      ExportMonth(:final month) => (
        await _transactions.getBetween(
          month.firstDay,
          month.firstDayOfNextMonth,
        ),
        'centavo-transactions-${month.toIso()}.csv',
      ),
      ExportAll() => (
        await _transactions.getBetween(null, null),
        'centavo-transactions-all-${_clock.today().toIso()}.csv',
      ),
    };
    if (list.isEmpty) throw const ExportError(ExportErrorReason.emptyRange);
    final categories = await _categories.getAll();
    return CsvDocument(
      fileName: fileName,
      content: buildTransactionsCsv(
        transactions: list,
        categoriesById: {for (final c in categories) c.id: c},
        currencyCode: currencyCode,
      ),
    );
  }
}

const _bom = '﻿';
const _eol = '\r\n';

/// Pure builder: UTF-8 BOM, header, one row per transaction, every line ends
/// in CRLF (RFC 4180). Rows are ordered by date, then creation time.
String buildTransactionsCsv({
  required List<MoneyTransaction> transactions,
  required Map<String, Category> categoriesById,
  required String currencyCode,
}) {
  final minorUnits = currencyByCode(currencyCode).minorUnits;
  final sorted = [...transactions]
    ..sort((a, b) {
      final byDate = a.occurredOn.compareTo(b.occurredOn);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });
  final buffer = StringBuffer(_bom)
    ..write('date,type,category,amount,currency,note')
    ..write(_eol);
  for (final t in sorted) {
    buffer
      ..writeAll([
        t.occurredOn.toIso(),
        t.type.name,
        _text(categoriesById[t.categoryId]?.name ?? ''),
        formatMinorPlain(t.amountMinor, minorUnits: minorUnits),
        currencyCode,
        _text(t.note ?? ''),
      ], ',')
      ..write(_eol);
  }
  return buffer.toString();
}

/// Neutralizes spreadsheet formulas, then applies RFC 4180 escaping.
String _text(String value) {
  final safe = value.startsWith(RegExp(r'[=+\-@]')) ? "'$value" : value;
  return _escape(safe);
}

String _escape(String value) {
  if (!value.contains(RegExp(r'[,"\r\n]'))) return value;
  return '"${value.replaceAll('"', '""')}"';
}
