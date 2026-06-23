import 'dart:typed_data';

class NotePdfExportException implements Exception {
  const NotePdfExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotePdfExportResult {
  const NotePdfExportResult({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}

class NotePdfPreviewFile {
  const NotePdfPreviewFile({
    required this.path,
    required this.filename,
    required this.bytes,
  });

  final String path;
  final String filename;
  final Uint8List bytes;
}

enum NotePdfFlowchartPageMode {
  portraitSingle,
  landscapeSingle,
  overviewAndTiles,
}

String safeNotePdfFilename(String title) {
  final trimmed = title.trim();
  final base = trimmed.toLowerCase().endsWith('.pdf')
      ? trimmed.substring(0, trimmed.length - 4)
      : trimmed;
  final safe = base.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final normalized = safe
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return '${normalized.isEmpty ? 'jegyzet' : normalized}.pdf';
}
