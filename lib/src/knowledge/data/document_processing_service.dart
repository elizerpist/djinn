import '../../ai/ai_client.dart';
import '../../ai/ai_client_resolver.dart';
import '../../ai/ai_error.dart';
import '../../ai/ai_provider.dart';
import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import '../../settings/models/app_settings.dart';

class ProcessingResult {
  const ProcessingResult({
    required this.state,
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
  });

  final String state;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
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
    AiClient? openAiClient,
    AiClientForProvider? clientForProvider,
    required this.loadSettings,
    Future<bool> Function()? hasApiKey,
    HasApiKeyForProvider? hasApiKeyForProvider,
    required this.repository,
  }) : _openAiClient = openAiClient,
       _clientForProvider = clientForProvider,
       _hasApiKey = hasApiKey,
       _hasApiKeyForProvider = hasApiKeyForProvider;

  final AiClient? _openAiClient;
  final AiClientForProvider? _clientForProvider;
  final Future<AppSettings> Function() loadSettings;
  final Future<bool> Function()? _hasApiKey;
  final HasApiKeyForProvider? _hasApiKeyForProvider;
  final ProcessingRepository repository;

  Future<ProcessingResult> processDocument(String documentPublicId) async {
    final settings = await loadSettings();
    final provider = settings.activeProvider;
    if (!await _hasKey(provider)) {
      DebugConsole.log(
        '[AI Training] blocked missing_api_key provider=${provider.wireName} document=$documentPublicId',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.blockedMissingApiKey,
      );
      return ProcessingResult(
        state: ProcessingState.blockedMissingApiKey.wireName,
      );
    }

    try {
      final client = _clientFor(provider);
      DebugConsole.log(
        '[AI Training] start document=$documentPublicId provider=${provider.wireName}',
      );
      final pdfPath = await repository.localPathForDocument(documentPublicId);
      await repository.markState(documentPublicId, ProcessingState.processing);

      final extraction = await client.extractDocument(
        pdfPath: pdfPath,
        model: settings.extractionModel,
      );
      DebugConsole.log(
        '[AI Training] extraction chunks=${extraction.chunks.length} '
        'model=${settings.extractionModel} provider=${provider.wireName}',
      );
      for (final chunk in extraction.chunks) {
        final embedding = await client.createEmbedding(
          input: chunk.text,
          model: settings.embeddingModel,
        );
        DebugConsole.log(
          '[AI Training] embedding chunk=${chunk.id} '
          'model=${settings.embeddingModel} dim=${embedding.length} '
          'provider=${provider.wireName}',
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
      DebugConsole.log(
        '[AI Training] complete document=$documentPublicId provider=${provider.wireName}',
      );
      return ProcessingResult(state: ProcessingState.ready.wireName);
    } on AiProviderException catch (error) {
      final failure = error.failure;
      DebugConsole.log(
        '[AI Training] failed provider=${failure.provider.wireName} '
        'document=$documentPublicId error=${failure.message} '
        'code=${failure.code.name} retryable=${failure.retryable}',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.failed,
        errorMessage: failure.userMessage,
      );
      return ProcessingResult(
        state: ProcessingState.failed.wireName,
        errorMessage: failure.userMessage,
        errorCode: failure.code.name,
        retryable: failure.retryable,
      );
    } on OpenAiException catch (error) {
      DebugConsole.log(
        '[AI Training] failed document=$documentPublicId error=${error.message} '
        'provider=${provider.wireName}',
      );
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

  Future<bool> _hasKey(AiProvider provider) {
    final providerAware = _hasApiKeyForProvider;
    if (providerAware != null) {
      return providerAware(provider);
    }
    final legacy = _hasApiKey;
    if (legacy != null) {
      return legacy();
    }
    throw StateError('No API key checker configured');
  }

  AiClient _clientFor(AiProvider provider) {
    final providerAware = _clientForProvider;
    if (providerAware != null) {
      return providerAware(provider);
    }
    final legacy = _openAiClient;
    if (legacy != null) {
      return legacy;
    }
    throw StateError('No AI client configured');
  }
}
