import 'dart:io';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/export/domain/csv_share_service.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

typedef TempDirectoryProvider = Future<Directory> Function();
typedef ShareFile = Future<void> Function(XFile file, String subject);

Future<void> _shareWithSystemSheet(XFile file, String subject) async {
  await SharePlus.instance.share(ShareParams(files: [file], subject: subject));
}

/// Writes the CSV to a temporary file and opens the system share sheet.
class FileShareCsvService implements CsvShareService {
  FileShareCsvService({
    this._tempDirectory = getTemporaryDirectory,
    this._shareFile = _shareWithSystemSheet,
  });

  final TempDirectoryProvider _tempDirectory;
  final ShareFile _shareFile;

  @override
  Future<void> share(CsvDocument document) async {
    final String path;
    try {
      final dir = await _tempDirectory();
      final file = File('${dir.path}/${document.fileName}');
      // The BOM is already part of the content.
      await file.writeAsString(document.content, flush: true);
      path = file.path;
    } on FileSystemException {
      throw const ExportError(ExportErrorReason.writeFailed);
    } on PlatformException {
      throw const ExportError(ExportErrorReason.writeFailed);
    } on MissingPluginException {
      throw const ExportError(ExportErrorReason.writeFailed);
    }
    try {
      await _shareFile(
        XFile(path, mimeType: 'text/csv'),
        document.fileName,
      );
    } on Exception {
      // share_plus surfaces platform failures as several exception types.
      throw const ExportError(ExportErrorReason.shareFailed);
    }
  }
}
