class AiEvidence {
  const AiEvidence({required this.id, required this.label, required this.text});

  final String id;
  final String label;
  final String text;
}

class AiAnswer {
  const AiAnswer({
    required this.answer,
    required this.citedSourceIds,
    this.abstain = false,
    this.refusalReason,
  });

  final String answer;
  final List<String> citedSourceIds;
  final bool abstain;
  final String? refusalReason;
}

class AiExtractedChunk {
  const AiExtractedChunk({
    required this.id,
    required this.text,
    required this.pageNumber,
    this.sectionTitle,
  });

  final String id;
  final String text;
  final int pageNumber;
  final String? sectionTitle;
}

enum AiEvidenceSourceType {
  textChunk('text_chunk'),
  table('table_chunk'),
  score('score_chunk');

  const AiEvidenceSourceType(this.wireName);

  final String wireName;
}

class AiExtractedEvidence {
  const AiExtractedEvidence({
    required this.id,
    required this.text,
    required this.pageNumber,
    required this.sourceType,
    this.sectionTitle,
  });

  final String id;
  final String text;
  final int pageNumber;
  final AiEvidenceSourceType sourceType;
  final String? sectionTitle;
}

class AiFlowchartCandidate {
  const AiFlowchartCandidate({
    required this.id,
    required this.pageNumber,
    required this.nodes,
    required this.edges,
    this.title,
    this.confidence,
  });

  final String id;
  final int pageNumber;
  final String? title;
  final double? confidence;
  final List<AiFlowchartNode> nodes;
  final List<AiFlowchartEdge> edges;
}

class AiFlowchartNode {
  const AiFlowchartNode({required this.id, required this.label});

  final String id;
  final String label;
}

class AiFlowchartEdge {
  const AiFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
}

class AiExtractionResult {
  const AiExtractionResult({
    required this.chunks,
    this.evidence = const [],
    this.flowcharts = const [],
  });

  final List<AiExtractedChunk> chunks;
  final List<AiExtractedEvidence> evidence;
  final List<AiFlowchartCandidate> flowcharts;

  List<AiExtractedEvidence> get allEvidence => [
    for (final chunk in chunks)
      AiExtractedEvidence(
        id: chunk.id,
        text: chunk.text,
        pageNumber: chunk.pageNumber,
        sectionTitle: chunk.sectionTitle,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
    ...evidence,
  ];
}

abstract class AiClient {
  Future<void> testApiKey({required String apiKey});

  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  });

  Future<AiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  });

  Future<AiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<AiEvidence> evidence,
  });

  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<AiEvidence> evidence,
  });
}
