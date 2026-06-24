import '../../local_store/entities.dart';
import '../../notes/models/note_document.dart';
import 'local_extraction.dart';

class ExtractedKnowledgeItem implements ChunkComparisonItem {
  const ExtractedKnowledgeItem({
    required this.id,
    required this.documentId,
    required this.sourceType,
    required this.text,
    this.pageNumber,
    this.sectionTitle,
    this.embeddingModel,
    this.flowchartId,
    this.flowchartElementId,
    this.flowchartFromId,
    this.flowchartToId,
    this.flowchartEdgeLabel,
    this.flowchartShape,
    this.flowchartOrder = 0,
    this.sourceRectJson,
    this.pipeline = LocalExtractionPipeline.ai,
    this.chunkKind = LocalChunkKind.text,
    this.auditState = LocalAuditState.accepted,
    this.endPageNumber,
    this.confidence,
    this.sourcePageImagePath,
    this.tags = const [],
  });

  @override
  final String id;
  final String documentId;
  final EvidenceSourceType sourceType;
  @override
  final String text;
  @override
  final int? pageNumber;
  @override
  final String? sectionTitle;
  final String? embeddingModel;
  final String? flowchartId;
  final String? flowchartElementId;
  final String? flowchartFromId;
  final String? flowchartToId;
  final String? flowchartEdgeLabel;
  final String? flowchartShape;
  final int flowchartOrder;
  final String? sourceRectJson;
  final LocalExtractionPipeline pipeline;
  final LocalChunkKind chunkKind;
  @override
  final LocalAuditState auditState;
  final int? endPageNumber;
  final double? confidence;
  final String? sourcePageImagePath;
  final List<NoteKnowledgeTag> tags;

  ExtractedKnowledgeItem copyWith({
    String? text,
    LocalAuditState? auditState,
    String? sectionTitle,
    List<NoteKnowledgeTag>? tags,
  }) {
    return ExtractedKnowledgeItem(
      id: id,
      documentId: documentId,
      sourceType: sourceType,
      text: text ?? this.text,
      pageNumber: pageNumber,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      embeddingModel: embeddingModel,
      flowchartId: flowchartId,
      flowchartElementId: flowchartElementId,
      flowchartFromId: flowchartFromId,
      flowchartToId: flowchartToId,
      flowchartEdgeLabel: flowchartEdgeLabel,
      flowchartShape: flowchartShape,
      flowchartOrder: flowchartOrder,
      sourceRectJson: sourceRectJson,
      pipeline: pipeline,
      chunkKind: chunkKind,
      auditState: auditState ?? this.auditState,
      endPageNumber: endPageNumber,
      confidence: confidence,
      sourcePageImagePath: sourcePageImagePath,
      tags: tags ?? this.tags,
    );
  }

  bool get isLocal => pipeline.isLocal;

  @override
  String get typeLabel {
    return switch (sourceType) {
      EvidenceSourceType.textChunk => 'Szöveg',
      EvidenceSourceType.tableChunk => 'Táblázat',
      EvidenceSourceType.scoreChunk => 'Score',
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => 'Flowchart',
    };
  }

  String get pageLabel {
    final page = pageNumber;
    if (page == null || page <= 0) {
      return typeLabel;
    }
    final endPage = endPageNumber;
    if (endPage != null && endPage > page) {
      return '$typeLabel - $page-$endPage. oldal';
    }
    return '$typeLabel - $page. oldal';
  }

  @override
  String get pipelineLabel {
    return switch (pipeline) {
      LocalExtractionPipeline.ai => 'AI chunk',
      LocalExtractionPipeline.localPdfText ||
      LocalExtractionPipeline.localOcr ||
      LocalExtractionPipeline.localTable ||
      LocalExtractionPipeline.localFlowchart ||
      LocalExtractionPipeline.localVisual ||
      LocalExtractionPipeline.manual => 'Manuális OCR chunk',
    };
  }
}

EvidenceSourceType evidenceSourceTypeFromWireName(String value) {
  return EvidenceSourceType.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => EvidenceSourceType.textChunk,
  );
}
