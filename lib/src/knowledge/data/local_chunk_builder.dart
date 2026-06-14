import '../models/local_extraction.dart';

class LocalChunkBuilder {
  const LocalChunkBuilder();

  List<LocalChunk> build({
    required String documentId,
    required List<LocalDocumentPage> pages,
  }) {
    final chunks = <LocalChunk>[];
    _OpenList? openList;
    var textCounter = 0;
    var tableCounter = 0;
    String? currentSection;

    void flushOpenList() {
      final list = openList;
      if (list == null) {
        return;
      }
      chunks.add(list.toChunk(documentId: documentId));
      openList = null;
    }

    for (final page in pages) {
      final lines = _lines(page.bestText);
      if (lines.isEmpty) {
        flushOpenList();
        continue;
      }
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_isHeading(line, index, lines)) {
          flushOpenList();
          currentSection = _normalizeHeading(line);
          continue;
        }
        if (_isListLine(line)) {
          final itemText = _stripListMarker(line);
          openList ??= _OpenList(
            id: 'local-list-p${page.pageNumber}-${chunks.length + 1}',
            pageNumber: page.pageNumber,
            sectionTitle: currentSection,
            pipeline: page.textPipeline,
            sourcePageImagePath: page.sourceImagePath,
            confidence: page.confidence,
          );
          openList!.add(itemText, page.pageNumber);
          continue;
        }
        if (_looksLikeTableLine(line) || _looksLikeScoreLine(line)) {
          flushOpenList();
          final block = _collectTableBlock(lines, index);
          index += block.length - 1;
          tableCounter += 1;
          chunks.add(
            LocalChunk(
              id: 'local-table-p${page.pageNumber}-$tableCounter',
              documentId: documentId,
              text: block.join('\n'),
              pageNumber: page.pageNumber,
              sectionTitle: currentSection,
              pipeline: page.textPipeline == LocalExtractionPipeline.localOcr
                  ? LocalExtractionPipeline.localOcr
                  : LocalExtractionPipeline.localTable,
              kind: block.any(_looksLikeTableLine)
                  ? LocalChunkKind.table
                  : _looksLikeScoreLine(block.join(' '))
                      ? LocalChunkKind.score
                      : LocalChunkKind.table,
              auditState: LocalAuditState.unreviewed,
              sourcePageImagePath: page.sourceImagePath,
              confidence: page.confidence,
            ),
          );
          continue;
        }
        flushOpenList();
        textCounter += 1;
        chunks.add(
          LocalChunk(
            id: 'local-text-p${page.pageNumber}-$textCounter',
            documentId: documentId,
            text: line,
            pageNumber: page.pageNumber,
            sectionTitle: currentSection,
            pipeline: page.textPipeline,
            kind: LocalChunkKind.text,
            auditState: LocalAuditState.unreviewed,
            sourcePageImagePath: page.sourceImagePath,
            confidence: page.confidence,
          ),
        );
      }
    }
    flushOpenList();
    return chunks;
  }

  List<String> _lines(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  bool _isHeading(String line, int index, List<String> lines) {
    if (line.endsWith(':')) {
      return true;
    }
    if (index + 1 >= lines.length) {
      return false;
    }
    final next = lines[index + 1];
    final shortLine = line.length <= 72;
    return shortLine && !_isListLine(line) && _isListLine(next);
  }

  String _normalizeHeading(String line) {
    return line.trim().replaceFirst(RegExp(r':\s*$'), '').trim();
  }

  bool _isListLine(String line) {
    return RegExp(r'^([-*\u2022]|\d+[.)])\s+').hasMatch(line.trim());
  }

  String _stripListMarker(String line) {
    return line
        .trim()
        .replaceFirst(RegExp(r'^([-*\u2022]|\d+[.)])\s+'), '')
        .trim();
  }

  bool _looksLikeTableLine(String line) {
    final value = line.trim();
    if (value.contains('|') || value.contains('\t')) {
      return true;
    }
    return RegExp(r'\S\s{2,}\S').hasMatch(value);
  }

  bool _looksLikeScoreLine(String line) {
    final lower = line.toLowerCase();
    return lower.contains('score') || lower.contains('pont');
  }

  List<String> _collectTableBlock(List<String> lines, int startIndex) {
    final block = <String>[];
    for (var i = startIndex; i < lines.length; i++) {
      final line = lines[i];
      if (block.isNotEmpty &&
          !_looksLikeTableLine(line) &&
          !_looksLikeScoreLine(line)) {
        break;
      }
      block.add(line);
    }
    return block.isEmpty ? [lines[startIndex]] : block;
  }
}

class _OpenList {
  _OpenList({
    required this.id,
    required this.pageNumber,
    required this.sectionTitle,
    required this.pipeline,
    this.sourcePageImagePath,
    this.confidence,
  });

  final String id;
  final int pageNumber;
  final String? sectionTitle;
  final LocalExtractionPipeline pipeline;
  final String? sourcePageImagePath;
  final double? confidence;
  final List<String> _items = [];
  int? _endPageNumber;

  void add(String item, int page) {
    _items.add('- $item');
    if (page != pageNumber) {
      _endPageNumber = page;
    }
  }

  LocalChunk toChunk({required String documentId}) {
    return LocalChunk(
      id: id,
      documentId: documentId,
      text: _items.join('\n'),
      pageNumber: pageNumber,
      endPageNumber: _endPageNumber,
      sectionTitle: sectionTitle,
      pipeline: pipeline,
      kind: LocalChunkKind.list,
      auditState: LocalAuditState.unreviewed,
      sourcePageImagePath: sourcePageImagePath,
      confidence: confidence,
    );
  }
}
