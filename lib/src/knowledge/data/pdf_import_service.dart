import 'dart:io';

import 'package:path/path.dart' as p;

class PdfImportResult {
  const PdfImportResult({
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
  });

  final String filename;
  final String localPath;
  final int sizeBytes;
}

class PdfImportService {
  const PdfImportService({required this.importDirectory});

  final Directory importDirectory;

  Future<PdfImportResult> copyPdfFromPath(String sourcePath) async {
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    return copyPdfBytes(filename: p.basename(source.path), bytes: bytes);
  }

  Future<PdfImportResult> copyPdfBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    await importDirectory.create(recursive: true);
    final safeFilename = _safePdfFilename(filename);
    final target = await _nextAvailableFile(safeFilename);
    await target.writeAsBytes(bytes, flush: true);
    return PdfImportResult(
      filename: p.basename(target.path),
      localPath: target.path,
      sizeBytes: bytes.length,
    );
  }

  Future<File> _nextAvailableFile(String filename) async {
    final extension = p.extension(filename);
    final basename = p.basenameWithoutExtension(filename);
    var candidate = File(p.join(importDirectory.path, filename));
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File(
        p.join(importDirectory.path, '${basename}_$suffix$extension'),
      );
      suffix += 1;
    }
    return candidate;
  }

  String _safePdfFilename(String filename) {
    final basename = p
        .basename(filename)
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final normalized = basename.isEmpty || basename == '.pdf'
        ? 'document.pdf'
        : basename;
    if (p.extension(normalized).toLowerCase() == '.pdf') {
      return normalized;
    }
    return '$normalized.pdf';
  }
}
