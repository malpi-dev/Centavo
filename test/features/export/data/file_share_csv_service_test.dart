import 'dart:io';

import 'package:centavo/core/errors/domain_error.dart';
import 'package:centavo/features/export/data/file_share_csv_service.dart';
import 'package:centavo/features/export/domain/export_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  late Directory dir;
  const doc = CsvDocument(
    fileName: 'centavo-transactions-2026-10.csv',
    content: '﻿date,type\r\n2026-10-01,expense\r\n',
  );

  setUp(() => dir = Directory.systemTemp.createTempSync('centavo_csv_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes the file with BOM and shares it as text/csv', () async {
    XFile? shared;
    String? subject;
    final service = FileShareCsvService(
      tempDirectory: () async => dir,
      shareFile: (file, s) async {
        shared = file;
        subject = s;
      },
    );
    await service.share(doc);

    final bytes = File('${dir.path}/${doc.fileName}').readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    expect(String.fromCharCodes(bytes.sublist(3, 7)), 'date');
    expect(shared!.path, '${dir.path}/${doc.fileName}');
    expect(shared!.mimeType, 'text/csv');
    expect(subject, doc.fileName);
  });

  test('write failure maps to ExportError(writeFailed)', () async {
    final service = FileShareCsvService(
      tempDirectory: () async => Directory('${dir.path}/missing/deeper'),
      shareFile: (_, _) async {},
    );
    await expectLater(
      service.share(doc),
      throwsA(
        isA<ExportError>().having(
          (e) => e.reason,
          'reason',
          ExportErrorReason.writeFailed,
        ),
      ),
    );
  });

  test('share failure maps to ExportError(shareFailed)', () async {
    final service = FileShareCsvService(
      tempDirectory: () async => dir,
      shareFile: (_, _) async => throw Exception('boom'),
    );
    await expectLater(
      service.share(doc),
      throwsA(
        isA<ExportError>().having(
          (e) => e.reason,
          'reason',
          ExportErrorReason.shareFailed,
        ),
      ),
    );
  });
}
