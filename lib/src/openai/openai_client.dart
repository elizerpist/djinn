class OpenAiEvidence {
  const OpenAiEvidence({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class OpenAiAnswer {
  const OpenAiAnswer({
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

class OpenAiExtractedChunk {
  const OpenAiExtractedChunk({
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

class OpenAiExtractionResult {
  const OpenAiExtractionResult({required this.chunks});

  final List<OpenAiExtractedChunk> chunks;
}

class OpenAiException implements Exception {
  const OpenAiException(this.message);

  final String message;

  @override
  String toString() => 'OpenAiException: $message';
}

abstract class OpenAiClient {
  Future<void> testApiKey({required String apiKey});

  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  });

  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  });

  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  });

  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  });
}

class FakeOpenAiClient implements OpenAiClient {
  FakeOpenAiClient({
    List<double>? embedding,
    this.answerText = 'Valasz.',
    this.extractionResult = const OpenAiExtractionResult(chunks: []),
    this.grounded = true,
  }) : embedding = embedding ?? List<double>.filled(3072, 0.0);

  final List<double> embedding;
  final String answerText;
  final OpenAiExtractionResult extractionResult;
  final bool grounded;

  @override
  Future<void> testApiKey({required String apiKey}) async {
    if (apiKey.trim().isEmpty) {
      throw const OpenAiException('missing api key');
    }
  }

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  }) async {
    return embedding;
  }

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    return extractionResult;
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  }) async {
    return OpenAiAnswer(
      answer: answerText,
      citedSourceIds: evidence.map((item) => item.id).take(1).toList(),
    );
  }

  @override
  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  }) async {
    return grounded;
  }
}
