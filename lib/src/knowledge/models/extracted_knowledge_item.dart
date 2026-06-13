import '../../local_store/entities.dart';

class ExtractedKnowledgeItem {
  const ExtractedKnowledgeItem({
    required this.id,
    required this.documentId,
    required this.sourceType,
    required this.text,
    this.pageNumber,
    this.sectionTitle,
    this.embeddingModel,
  });

  final String id;
  final String documentId;
  final EvidenceSourceType sourceType;
  final String text;
  final int? pageNumber;
  final String? sectionTitle;
  final String? embeddingModel;

  String get typeLabel {
    return switch (sourceType) {
      EvidenceSourceType.textChunk => 'Szöveg',
      EvidenceSourceType.tableChunk => 'Táblázat',
      EvidenceSourceType.scoreChunk => 'Score',
      EvidenceSourceType.flowchartNode || EvidenceSourceType.flowchartEdge =>
        'Flowchart',
    };
  }

  String get pageLabel {
    final page = pageNumber;
    if (page == null || page <= 0) {
      return typeLabel;
    }
    return '$typeLabel - $page. oldal';
  }
}

EvidenceSourceType evidenceSourceTypeFromWireName(String value) {
  return EvidenceSourceType.values.firstWhere(
    (item) => item.wireName == value,
    orElse: () => EvidenceSourceType.textChunk,
  );
}
