import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/knowledge/data/document_processing_service.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  setUp(DebugConsole.clear);

  test('blocks processing when API key is missing', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: FakeOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => false,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'blocked_missing_api_key');
    expect(repository.states, [ProcessingState.blockedMissingApiKey]);
    expect(
      DebugConsole.allText,
      contains('[AI Training] blocked missing_api_key'),
    );
  });

  test('stores extracted chunks and embeddings', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _ExtractingOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'ready');
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.embedded,
      ProcessingState.ready,
    ]);
    expect(repository.savedChunks, hasLength(1));
    expect(repository.savedEmbeddings.single.vector, hasLength(3072));
    expect(repository.savedEmbeddings.single.model, 'text-embedding-3-large');
    expect(
      DebugConsole.allText,
      contains('[AI Training] start document=doc-1'),
    );
    expect(DebugConsole.allText, contains('[AI Training] extraction chunks=1'));
    expect(
      DebugConsole.allText,
      contains(
        '[AI Training] embedding chunk=c1 model=text-embedding-3-large dim=3072',
      ),
    );
    expect(
      DebugConsole.allText,
      contains('[AI Training] complete document=doc-1'),
    );
  });

  test('marks document failed when OpenAI extraction fails', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _FailingExtractionOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'failed');
    expect(result.errorMessage, 'extract failed');
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.failed,
    ]);
    expect(repository.errorMessages, ['extract failed']);
    expect(
      DebugConsole.allText,
      contains('[AI Training] failed document=doc-1 error=extract failed'),
    );
  });

  test('uses Gemini key and client when Gemini provider is active', () async {
    final repository = MemoryProcessingRepository();
    final usedProviders = <AiProvider>[];
    final service = DocumentProcessingService(
      clientForProvider: (AiProvider provider) {
        usedProviders.add(provider);
        return _ExtractingOpenAiClient();
      },
      loadSettings: () async =>
          AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini),
      hasApiKeyForProvider: (provider) async => provider == AiProvider.gemini,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'ready');
    expect(usedProviders, [AiProvider.gemini]);
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.embedded,
      ProcessingState.ready,
    ]);
    expect(repository.savedEmbeddings.single.model, 'gemini-embedding-001');
    expect(DebugConsole.allText, contains('provider=gemini'));
    expect(DebugConsole.allText, isNot(contains('blocked missing_api_key')));
  });

  test('provider missing key log includes provider name', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      clientForProvider: (AiProvider provider) => FakeOpenAiClient(),
      loadSettings: () async =>
          AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini),
      hasApiKeyForProvider: (provider) async => false,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'blocked_missing_api_key');
    expect(repository.states, [ProcessingState.blockedMissingApiKey]);
    expect(
      DebugConsole.allText,
      contains(
        '[AI Training] blocked missing_api_key provider=gemini document=doc-1',
      ),
    );
  });

  test('transient provider failure remains retryable', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      clientForProvider: (AiProvider provider) => _FailingProviderAiClient(),
      loadSettings: () async =>
          AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini),
      hasApiKeyForProvider: (provider) async => true,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'failed');
    expect(result.errorCode, 'networkAbort');
    expect(result.retryable, isTrue);
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.failed,
    ]);
    expect(repository.errorMessages, [
      'Halozati kapcsolat megszakadt. Ujraprobalhato.',
    ]);
    expect(DebugConsole.allText, contains('provider=gemini'));
    expect(DebugConsole.allText, contains('code=networkAbort'));
    expect(DebugConsole.allText, contains('retryable=true'));
  });
}

class MemoryProcessingRepository implements ProcessingRepository {
  final states = <ProcessingState>[];
  final savedChunks = <OpenAiExtractedChunk>[];
  final savedEmbeddings = <ChunkEmbeddingEntity>[];
  final errorMessages = <String?>[];

  @override
  Future<String> localPathForDocument(String documentPublicId) async {
    return '/tmp/$documentPublicId.pdf';
  }

  @override
  Future<void> markState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
  }) async {
    states.add(state);
    if (errorMessage != null) {
      errorMessages.add(errorMessage);
    }
  }

  @override
  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    savedChunks.add(chunk);
    savedEmbeddings.add(
      ChunkEmbeddingEntity(
        sourceId: chunk.id,
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: embedding,
        model: embeddingModel,
        createdAtMillis: 1760000000000,
      ),
    );
  }
}

class _ExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }
}

class _FailingExtractionOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    throw const OpenAiException('extract failed');
  }
}

class _FailingProviderAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    throw AiProviderException(
      AiFailure.networkAbort(AiProvider.gemini, 'socket closed'),
    );
  }
}
