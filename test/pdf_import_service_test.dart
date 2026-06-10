import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/pdf_import_service.dart';

void main() {
  test('copies selected PDF into the app knowledge directory', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-pdf-import-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/source.pdf');
    await source.writeAsBytes([37, 80, 68, 70]);
    final importDirectory = Directory('${directory.path}/knowledge');
    final service = PdfImportService(importDirectory: importDirectory);

    final result = await service.copyPdfFromPath(source.path);

    expect(result.filename, 'source.pdf');
    expect(result.sizeBytes, 4);
    expect(
      result.sha256,
      '315d429b7714cedb6ad04ac31240145257692630457f3c88253c5beceac76027',
    );
    expect(result.localPath, startsWith(importDirectory.path));
    expect(await File(result.localPath).readAsBytes(), [37, 80, 68, 70]);
  });

  test('copies picked PDF bytes with a safe filename', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-pdf-bytes-');
    addTearDown(() => directory.delete(recursive: true));
    final service = PdfImportService(
      importDirectory: Directory('${directory.path}/knowledge'),
    );

    final result = await service.copyPdfBytes(
      filename: '../OMSZ protocol.pdf',
      bytes: [1, 2, 3],
    );

    expect(result.filename, 'OMSZ_protocol.pdf');
    expect(result.sizeBytes, 3);
    expect(
      result.sha256,
      '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
    );
    expect(await File(result.localPath).exists(), isTrue);
    expect(await File(result.localPath).readAsBytes(), [1, 2, 3]);
  });
}
