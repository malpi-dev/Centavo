import 'package:centavo/features/export/domain/csv_share_service.dart';
import 'package:centavo/features/export/domain/export_models.dart';

/// Keeps the last shared document (tests).
class MockCsvShareService implements CsvShareService {
  final List<CsvDocument> shared = [];

  CsvDocument? get last => shared.isEmpty ? null : shared.last;

  @override
  Future<void> share(CsvDocument document) async => shared.add(document);
}
