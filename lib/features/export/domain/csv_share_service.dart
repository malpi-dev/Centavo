import 'package:centavo/features/export/domain/export_models.dart';

/// Writes the document to a temporary file and opens the system share sheet.
/// Throws ExportError(writeFailed | shareFailed).
// ignore: one_member_abstracts, port implemented by the platform adapter
abstract interface class CsvShareService {
  Future<void> share(CsvDocument document);
}
