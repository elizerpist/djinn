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

class AiExtractedFlowchartNode {
  const AiExtractedFlowchartNode({
    required this.id,
    required this.label,
    this.positionX = 0,
    this.positionY = 0,
  });

  final String id;
  final String label;
  final double positionX;
  final double positionY;
}

class AiExtractedFlowchartEdge {
  const AiExtractedFlowchartEdge({
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

class AiExtractedFlowchart {
  const AiExtractedFlowchart({
    required this.id,
    required this.pageNumber,
    required this.nodes,
    required this.edges,
    this.title,
    this.confidence,
  });

  final String id;
  final String? title;
  final int pageNumber;
  final double? confidence;
  final List<AiExtractedFlowchartNode> nodes;
  final List<AiExtractedFlowchartEdge> edges;
}

class AiExtractionResult {
  const AiExtractionResult({required this.chunks, this.flowcharts = const []});

  final List<AiExtractedChunk> chunks;
  final List<AiExtractedFlowchart> flowcharts;
}

class AiException implements Exception {
  const AiException(this.message);

  final String message;

  @override
  String toString() => 'AiException: $message';
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
