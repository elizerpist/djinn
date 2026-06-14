import '../models/local_extraction.dart';

class LocalChunkBuilder {
  const LocalChunkBuilder();

  static const _minimumParagraphLength = 140;

  List<LocalChunk> build({
    required String documentId,
    required List<LocalDocumentPage> pages,
  }) {
    final chunks = <LocalChunk>[];
    _OpenList? openList;
    _OpenParagraph? openParagraph;
    final pendingHeadings = <String>[];
    var textCounter = 0;
    var tableCounter = 0;
    var flowchartCounter = 0;
    var currentSection = <String>[];

    String? sectionTitle() {
      final title = currentSection.where((line) => line.trim().isNotEmpty).join(' / ');
      return title.isEmpty ? null : title;
    }

    void flushOpenParagraph() {
      final paragraph = openParagraph;
      if (paragraph == null) {
        return;
      }
      final chunk = paragraph.toChunk(documentId: documentId);
      final previousIndex = chunks.length - 1;
      if (chunk.text.length < _minimumParagraphLength &&
          previousIndex >= 0 &&
          chunks[previousIndex].kind == LocalChunkKind.text &&
          chunks[previousIndex].pageNumber == chunk.pageNumber) {
        final previous = chunks.removeLast();
        chunks.add(
          LocalChunk(
            id: previous.id,
            documentId: previous.documentId,
            text: '${previous.text}\n${chunk.text}',
            pageNumber: previous.pageNumber,
            endPageNumber: chunk.endPageNumber ?? previous.endPageNumber,
            sectionTitle: previous.sectionTitle ?? chunk.sectionTitle,
            pipeline: previous.pipeline,
            kind: previous.kind,
            auditState: previous.auditState,
            sourceRectJson: previous.sourceRectJson,
            confidence: previous.confidence,
            sourcePageImagePath: previous.sourcePageImagePath,
          ),
        );
      } else {
        chunks.add(chunk);
      }
      openParagraph = null;
    }

    void flushOpenList() {
      final list = openList;
      if (list == null) {
        return;
      }
      chunks.add(list.toChunk(documentId: documentId));
      openList = null;
    }

    void flushTextBuffers() {
      flushOpenParagraph();
      flushOpenList();
    }

    List<String> consumeHeadings() {
      final headings = List<String>.from(pendingHeadings);
      pendingHeadings.clear();
      return headings;
    }

    for (final page in pages) {
      final lines = _lines(page.bestText);
      if (lines.isEmpty) {
        flushTextBuffers();
        pendingHeadings.clear();
        continue;
      }

      if (_looksLikeFlowchartBlock(lines)) {
        flushTextBuffers();
        pendingHeadings.clear();
        currentSection = _deriveFlowchartTitle(lines);
        flowchartCounter += 1;
        chunks.add(
          LocalChunk(
            id: 'local-flowchart-p${page.pageNumber}-$flowchartCounter',
            documentId: documentId,
            text: lines.join('\n'),
            pageNumber: page.pageNumber,
            sectionTitle: sectionTitle(),
            pipeline: LocalExtractionPipeline.localFlowchart,
            kind: LocalChunkKind.flowchart,
            auditState: LocalAuditState.unreviewed,
            sourcePageImagePath: page.sourceImagePath,
            confidence: page.confidence,
          ),
        );
        continue;
      }

      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (_isHeading(line, index, lines)) {
          flushOpenParagraph();
          flushOpenList();
          final heading = _normalizeHeading(line);
          if (heading.isNotEmpty) {
            currentSection = [...currentSection, heading].takeLast(3).toList();
            pendingHeadings.add(heading);
          }
          continue;
        }
        if (_isListLine(line)) {
          flushOpenParagraph();
          final headingPrefix = consumeHeadings();
          final itemText = _stripListMarker(line);
          openList ??= _OpenList(
            id: 'local-list-p${page.pageNumber}-${chunks.length + 1}',
            pageNumber: page.pageNumber,
            sectionTitle: sectionTitle(),
            pipeline: page.textPipeline,
            sourcePageImagePath: page.sourceImagePath,
            confidence: page.confidence,
            leadingLines: headingPrefix,
          );
          openList!.add(itemText, page.pageNumber);
          continue;
        }
        if (_looksLikeTableLine(line) || _looksLikeScoreLine(line)) {
          flushTextBuffers();
          final headingPrefix = consumeHeadings();
          final block = _collectTableBlock(lines, index);
          index += block.length - 1;
          tableCounter += 1;
          final text = [...headingPrefix, ...block].join('\n');
          chunks.add(
            LocalChunk(
              id: 'local-table-p${page.pageNumber}-$tableCounter',
              documentId: documentId,
              text: text,
              pageNumber: page.pageNumber,
              sectionTitle: sectionTitle(),
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
        final headingPrefix = consumeHeadings();
        openParagraph ??= _OpenParagraph(
          id: 'local-text-p${page.pageNumber}-${++textCounter}',
          pageNumber: page.pageNumber,
          sectionTitle: sectionTitle(),
          pipeline: page.textPipeline,
          sourcePageImagePath: page.sourceImagePath,
          confidence: page.confidence,
        );
        for (final heading in headingPrefix) {
          openParagraph!.add(heading, page.pageNumber);
        }
        openParagraph!.add(line, page.pageNumber);
      }
    }
    flushTextBuffers();
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
    final value = line.trim();
    if (value.endsWith(':')) {
      return true;
    }
    if (_isListLine(value) || _looksLikeTableLine(value)) {
      return false;
    }
    if (index + 1 >= lines.length) {
      return false;
    }
    final next = lines[index + 1];
    if (_isListLine(next)) {
      return value.length <= 90;
    }
    final shortLine = value.length <= 72;
    final hasSentenceEnd = RegExp(r'[.!?]$').hasMatch(value);
    final nextLooksBody = next.length > 72 || RegExp(r'[.!?]$').hasMatch(next);
    return shortLine && !hasSentenceEnd && nextLooksBody;
  }

  String _normalizeHeading(String line) {
    return line.trim().replaceFirst(RegExp(r':\s*$'), '').trim();
  }

  bool _isListLine(String line) {
    return RegExp(r'^([-*•]|\d+[.)])\s+').hasMatch(line.trim());
  }

  String _stripListMarker(String line) {
    return line
        .trim()
        .replaceFirst(RegExp(r'^([-*•]|\d+[.)])\s+'), '')
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

  bool _looksLikeFlowchartBlock(List<String> lines) {
    if (lines.length < 4) {
      return false;
    }
    var branchLabels = 0;
    var arrows = 0;
    var decisions = 0;
    for (final raw in lines) {
      final line = raw.toLowerCase();
      if (RegExp(r'\b(igen|nem|yes|no)\b').hasMatch(line)) {
        branchLabels += 1;
      }
      if (line.contains('->') || line.contains('→') || line.contains('=>')) {
        arrows += 1;
      }
      if (raw.trim().endsWith('?')) {
        decisions += 1;
      }
    }
    return decisions >= 1 && (branchLabels >= 2 || arrows >= 2);
  }

  List<String> _deriveFlowchartTitle(List<String> lines) {
    final first = lines.first.trim();
    if (first.length <= 90 && !first.contains('->') && !first.contains('→')) {
      return [first];
    }
    return const ['Flowchart'];
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

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final values = toList(growable: false);
    if (values.length <= count) {
      return values;
    }
    return values.sublist(values.length - count);
  }
}

class _OpenParagraph {
  _OpenParagraph({
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
  final List<String> _lines = [];
  int? _endPageNumber;

  void add(String line, int page) {
    _lines.add(line);
    if (page != pageNumber) {
      _endPageNumber = page;
    }
  }

  LocalChunk toChunk({required String documentId}) {
    return LocalChunk(
      id: id,
      documentId: documentId,
      text: _lines.join('\n'),
      pageNumber: pageNumber,
      endPageNumber: _endPageNumber,
      sectionTitle: sectionTitle,
      pipeline: pipeline,
      kind: LocalChunkKind.text,
      auditState: LocalAuditState.unreviewed,
      sourcePageImagePath: sourcePageImagePath,
      confidence: confidence,
    );
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
    List<String> leadingLines = const [],
  }) : _leadingLines = List<String>.from(leadingLines);

  final String id;
  final int pageNumber;
  final String? sectionTitle;
  final LocalExtractionPipeline pipeline;
  final String? sourcePageImagePath;
  final double? confidence;
  final List<String> _leadingLines;
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
      text: [..._leadingLines, ..._items].join('\n'),
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
