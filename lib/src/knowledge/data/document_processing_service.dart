import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import '../../settings/models/app_settings.dart';

class ProcessingResult {
  const ProcessingResult({required this.state, this.errorMessage});

  final String state;
  final String? errorMessage;
}

abstract class ProcessingRepository {
  Future<String> localPathForDocument(String documentPublicId);

  Future<void> markState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
  });

  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  });
}

class DocumentProcessingService {
  const DocumentProcessingService({
    required this.openAiClient,
    required this.loadSettings,
    required this.hasApiKey,
    required this.repository,
  });

  final OpenAiClient openAiClient;
  final Future<AppSettings> Function() loadSettings;
  final Future<bool> Function() hasApiKey;
  final ProcessingRepository repository;

  Future<ProcessingResult> processDocument(String documentPublicId) async {
    if (!await hasApiKey()) {
      await repository.markState(
        documentPublicId,
        ProcessingState.blockedMissingApiKey,
      );
      return ProcessingResult(
        state: ProcessingState.blockedMissingApiKey.wireName,
      );
    }

    try {
      final settings = await loadSettings();
      final pdfPath = await repository.localPathForDocument(documentPublicId);
      await repository.markState(documentPublicId, ProcessingState.processing);

      final extraction = await openAiClient.extractDocument(
        pdfPath: pdfPath,
        model: settings.extractionModel,
      );
      for (final chunk in extraction.chunks) {
        final embedding = await openAiClient.createEmbedding(
          input: chunk.text,
          model: settings.embeddingModel,
        );
        await repository.saveExtractedChunk(
          documentPublicId: documentPublicId,
          chunk: chunk,
          embedding: embedding,
          embeddingModel: settings.embeddingModel,
        );
      }

      await repository.markState(documentPublicId, ProcessingState.embedded);
      await repository.markState(documentPublicId, ProcessingState.ready);
      return ProcessingResult(state: ProcessingState.ready.wireName);
    } on OpenAiException catch (error) {
      await repository.markState(
        documentPublicId,
        ProcessingState.failed,
        errorMessage: error.message,
      );
      return ProcessingResult(
        state: ProcessingState.failed.wireName,
        errorMessage: error.message,
      );
    }
  }
}
