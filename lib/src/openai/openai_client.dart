import '../ai/ai_client.dart';

typedef OpenAiEvidence = AiEvidence;
typedef OpenAiAnswer = AiAnswer;
typedef OpenAiExtractedChunk = AiExtractedChunk;
typedef OpenAiExtractionResult = AiExtractionResult;

class OpenAiException implements Exception {
  const OpenAiException(this.message);

  final String message;

  @override
  String toString() => 'OpenAiException: $message';
}

abstract class OpenAiClient implements AiClient {
  @override
  Future<void> testApiKey({required String apiKey});

  @override
  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  });

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  });

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  });

  @override
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
