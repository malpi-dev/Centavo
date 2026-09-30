import 'package:centavo/core/domain/year_month.dart';
import 'package:meta/meta.dart';

sealed class ExportRange {
  const ExportRange();
}

final class ExportMonth extends ExportRange {
  const ExportMonth(this.month);
  final YearMonth month;
}

final class ExportAll extends ExportRange {
  const ExportAll();
}

@immutable
class CsvDocument {
  const CsvDocument({required this.fileName, required this.content});
  final String fileName;
  final String content;
}
