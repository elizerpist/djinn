import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

class PdfImportResult {
  const PdfImportResult({
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
    required this.sha256,
  });

  final String filename;
  final String localPath;
  final int sizeBytes;
  final String sha256;
}

class PdfImportService {
  const PdfImportService({required this.importDirectory});

  final Directory importDirectory;

  Future<PdfImportResult> copyPdfFromPath(String sourcePath) {
    return copyDocumentFromPath(sourcePath);
  }

  Future<PdfImportResult> copyDocumentFromPath(String sourcePath) async {
    final source = File(sourcePath);
    final bytes = await source.readAsBytes();
    return copyDocumentBytes(filename: p.basename(source.path), bytes: bytes);
  }

  Future<PdfImportResult> copyPdfBytes({
    required String filename,
    required List<int> bytes,
  }) {
    return copyDocumentBytes(filename: filename, bytes: bytes);
  }

  Future<PdfImportResult> copyDocumentBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    await importDirectory.create(recursive: true);
    final safeFilename = _safeDocumentFilename(filename);
    final target = await _nextAvailableFile(safeFilename);
    await target.writeAsBytes(bytes, flush: true);
    return PdfImportResult(
      filename: p.basename(target.path),
      localPath: target.path,
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
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

  String _safeDocumentFilename(String filename) {
    final basename = p
        .basename(filename)
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    final normalized = _defaultDocumentFilenameIfNeeded(basename);
    final extension = p.extension(normalized).toLowerCase();
    if (extension == '.pdf' || extension == '.png') {
      return normalized;
    }
    return '$normalized.pdf';
  }

  String _defaultDocumentFilenameIfNeeded(String basename) {
    if (basename.isEmpty || basename == '.pdf' || basename == '.png') {
      return 'document.pdf';
    }
    return basename;
  }
}
