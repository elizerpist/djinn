import '../../notes/models/note_document.dart';

enum LocalExtractionPipeline {
  ai('ai'),
  localPdfText('local_pdf_text'),
  localOcr('local_ocr'),
  localTable('local_table'),
  localFlowchart('local_flowchart'),
  localVisual('local_visual'),
  manual('manual');

  const LocalExtractionPipeline(this.wireName);

  final String wireName;

  static LocalExtractionPipeline fromWireName(String? value) {
    return LocalExtractionPipeline.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => LocalExtractionPipeline.ai,
    );
  }

  bool get isLocal => this != LocalExtractionPipeline.ai;
}

enum LocalChunkKind {
  text('text'),
  list('list'),
  table('table'),
  flowchart('flowchart');

  const LocalChunkKind(this.wireName);

  final String wireName;

  static LocalChunkKind fromWireName(String? value) {
    return switch (value?.trim()) {
      'list' => LocalChunkKind.list,
      'table' || 'score' => LocalChunkKind.table,
      'flowchart' => LocalChunkKind.flowchart,
      'text' ||
      'image_region' ||
      'visual_fact' ||
      'unknown' ||
      null ||
      _ => LocalChunkKind.text,
    };
  }

  String get label {
    return switch (this) {
      LocalChunkKind.text => 'Szöveg',
      LocalChunkKind.list => 'Felsorolás',
      LocalChunkKind.table => 'Táblázat',
      LocalChunkKind.flowchart => 'Flowchart',
    };
  }
}

enum LocalAuditState {
  unreviewed('unreviewed'),
  accepted('accepted'),
  edited('edited'),
  rejected('rejected');

  const LocalAuditState(this.wireName);

  final String wireName;

  static LocalAuditState fromWireName(String? value) {
    return LocalAuditState.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => LocalAuditState.unreviewed,
    );
  }

  String get label {
    return switch (this) {
      LocalAuditState.unreviewed => 'Auditálatlan',
      LocalAuditState.accepted => 'Elfogadott',
      LocalAuditState.edited => 'Szerkesztett',
      LocalAuditState.rejected => 'Elvetett',
    };
  }
}

class LocalDocumentPage {
  const LocalDocumentPage({
    required this.documentId,
    required this.pageNumber,
    required this.pdfText,
    required this.ocrText,
    this.sourceImagePath,
    this.ocrBlocksJson,
    this.confidence,
  });

  final String documentId;
  final int pageNumber;
  final String pdfText;
  final String ocrText;
  final String? sourceImagePath;
  final String? ocrBlocksJson;
  final double? confidence;

  String get bestText {
    final direct = pdfText.trim();
    final ocr = ocrText.trim();
    if (direct.isEmpty) {
      return ocr;
    }
    if (ocr.isEmpty || direct.contains(ocr)) {
      return direct;
    }
    return '$direct\n$ocr';
  }

  LocalExtractionPipeline get textPipeline {
    return pdfText.trim().isNotEmpty
        ? LocalExtractionPipeline.localPdfText
        : LocalExtractionPipeline.localOcr;
  }
}

class LocalChunk {
  const LocalChunk({
    required this.id,
    required this.documentId,
    required this.text,
    required this.pageNumber,
    this.endPageNumber,
    this.sectionTitle,
    this.pipeline = LocalExtractionPipeline.localOcr,
    this.kind = LocalChunkKind.text,
    this.auditState = LocalAuditState.unreviewed,
    this.sourceRectJson,
    this.confidence,
    this.sourcePageImagePath,
    this.tags = const [],
  });

  final String id;
  final String documentId;
  final String text;
  final int pageNumber;
  final int? endPageNumber;
  final String? sectionTitle;
  final LocalExtractionPipeline pipeline;
  final LocalChunkKind kind;
  final LocalAuditState auditState;
  final String? sourceRectJson;
  final double? confidence;
  final String? sourcePageImagePath;
  final List<NoteKnowledgeTag> tags;
}

enum ChunkComparisonStatus { matched, aiOnly, localOnly }

abstract class ChunkComparisonItem {
  String get id;
  String get text;
  int? get pageNumber;
  String? get sectionTitle;
  LocalAuditState get auditState;
  String get typeLabel;
  String get pipelineLabel;
}

class ChunkComparisonRow {
  const ChunkComparisonRow({
    required this.status,
    this.aiChunk,
    this.localChunk,
  });

  final ChunkComparisonStatus status;
  final ChunkComparisonItem? aiChunk;
  final ChunkComparisonItem? localChunk;

  int? get pageNumber => aiChunk?.pageNumber ?? localChunk?.pageNumber;

  String get sectionTitle {
    return aiChunk?.sectionTitle ?? localChunk?.sectionTitle ?? '';
  }
}

class ChunkComparison {
  const ChunkComparison({required this.rows});

  final List<ChunkComparisonRow> rows;
}
