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

class AiExtractionResult {
  const AiExtractionResult({required this.chunks});

  final List<AiExtractedChunk> chunks;
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
