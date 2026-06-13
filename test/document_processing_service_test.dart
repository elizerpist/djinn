import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/ai/ai_client.dart';
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
    expect(
      DebugConsole.allText,
      contains('[Flowchart] extraction candidates=0 document=doc-1'),
    );
    expect(DebugConsole.allText, isNot(contains('text_chunk_schema_only')));
  });

  test('re-sync clears generated knowledge before extraction', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _ExtractingOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
    );

    await service.processDocument('doc-1', forceReprocess: true);

    expect(repository.clearedDocuments, ['doc-1']);
  });

  test('emits extraction and embedding progress', () async {
    final repository = MemoryProcessingRepository();
    final events = <ProcessingProgress>[];
    final service = DocumentProcessingService(
      openAiClient: _ExtractingTwoChunkClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
      onProgress: events.add,
    );

    await service.processDocument('doc-1');

    expect(
      events.map((event) => event.phase),
      containsAll([
        ProcessingPhase.extracting,
        ProcessingPhase.embedding,
        ProcessingPhase.complete,
      ]),
    );
    final lastEmbedding = events.lastWhere(
      (event) => event.phase == ProcessingPhase.embedding,
    );
    expect(lastEmbedding.current, 2);
    expect(lastEmbedding.total, 2);
    expect(lastEmbedding.label, 'Embedding 2/2');
  });

  test('persists extracted scores and flowchart candidates', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _FlowchartExtractingClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
    );

    await service.processDocument('doc-1');

    expect(repository.savedFlowcharts.single.id, 'flow-1');
    final savedTypes = repository.savedEmbeddings.map(
      (embedding) => embedding.sourceType,
    );
    expect(savedTypes, contains(EvidenceSourceType.scoreChunk.wireName));
    expect(savedTypes, contains(EvidenceSourceType.flowchartNode.wireName));
    expect(savedTypes, contains(EvidenceSourceType.flowchartEdge.wireName));
    expect(
      DebugConsole.allText,
      contains('[Flowchart] extraction candidates=1 document=doc-1'),
    );
    expect(DebugConsole.allText, isNot(contains('text_chunk_schema_only')));
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

  test('passes chunking mode to document extraction', () async {
    final repository = MemoryProcessingRepository();
    final client = _RecordingExtractionClient();
    final service = DocumentProcessingService(
      openAiClient: client,
      loadSettings: () async =>
          AppSettings.defaults().copyWith(chunkingMode: ChunkingModes.compact),
      hasApiKey: () async => true,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'ready');
    expect(client.chunkingModes, [ChunkingModes.compact]);
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
    expect(repository.activeProviders.last, 'gemini');
    expect(repository.activeModels.last, 'gemini-2.5-flash-lite');
    expect(repository.lastErrorCodes.last, 'networkAbort');
    expect(repository.retryableFlags.last, isTrue);
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
  final activeProviders = <String>[];
  final activeModels = <String>[];
  final lastErrorCodes = <String>[];
  final retryableFlags = <bool>[];
  final clearedDocuments = <String>[];
  final savedFlowcharts = <AiFlowchartCandidate>[];

  @override
  Future<String> localPathForDocument(String documentPublicId) async {
    return '/tmp/$documentPublicId.pdf';
  }

  @override
  Future<void> markState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) async {
    states.add(state);
    if (errorMessage != null) {
      errorMessages.add(errorMessage);
    }
    if (activeProvider != null) {
      activeProviders.add(activeProvider);
    }
    if (activeModel != null) {
      activeModels.add(activeModel);
    }
    if (lastErrorCode != null) {
      lastErrorCodes.add(lastErrorCode);
    }
    if (retryable != null) {
      retryableFlags.add(retryable);
    }
  }

  @override
  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    await saveExtractedEvidence(
      documentPublicId: documentPublicId,
      evidence: AiExtractedEvidence(
        id: chunk.id,
        text: chunk.text,
        pageNumber: chunk.pageNumber,
        sectionTitle: chunk.sectionTitle,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
      embedding: embedding,
      embeddingModel: embeddingModel,
    );
  }

  @override
  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    savedChunks.add(
      OpenAiExtractedChunk(
        id: evidence.id,
        text: evidence.text,
        pageNumber: evidence.pageNumber,
        sectionTitle: evidence.sectionTitle,
      ),
    );
    savedEmbeddings.add(
      ChunkEmbeddingEntity(
        sourceId: evidence.id,
        sourceType: _sourceTypeWireName(evidence.sourceType),
        vector: embedding,
        model: embeddingModel,
        createdAtMillis: 1760000000000,
      ),
    );
  }

  @override
  Future<void> clearGeneratedKnowledge(String documentPublicId) async {
    clearedDocuments.add(documentPublicId);
  }

  @override
  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
  }) async {
    savedFlowcharts.add(flowchart);
  }

  String _sourceTypeWireName(AiEvidenceSourceType sourceType) {
    return switch (sourceType) {
      AiEvidenceSourceType.textChunk => EvidenceSourceType.textChunk.wireName,
      AiEvidenceSourceType.table => EvidenceSourceType.tableChunk.wireName,
      AiEvidenceSourceType.score => EvidenceSourceType.scoreChunk.wireName,
      AiEvidenceSourceType.flowchartNode =>
        EvidenceSourceType.flowchartNode.wireName,
      AiEvidenceSourceType.flowchartEdge =>
        EvidenceSourceType.flowchartEdge.wireName,
    };
  }
}

class _ExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }
}

class _ExtractingTwoChunkClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
        OpenAiExtractedChunk(id: 'c2', text: 'RACE score', pageNumber: 2),
      ],
    );
  }
}

class _FlowchartExtractingClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'Stroke ellatas', pageNumber: 1),
      ],
      evidence: [
        AiExtractedEvidence(
          id: 'rave-arc',
          text: 'RAVE: Arcparesis - 1 pont',
          pageNumber: 2,
          sectionTitle: 'RAVE',
          sourceType: AiEvidenceSourceType.score,
        ),
      ],
      flowcharts: [
        AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 3,
          title: 'Stroke dontesi fa',
          confidence: 0.82,
          nodes: [
            AiFlowchartNode(id: 'n1', label: 'FAST pozitiv'),
            AiFlowchartNode(id: 'n2', label: 'Stroke centrum riasztása'),
          ],
          edges: [
            AiFlowchartEdge(
              id: 'e1',
              fromNodeId: 'n1',
              toNodeId: 'n2',
              label: 'igen',
            ),
          ],
        ),
      ],
    );
  }
}

class _FailingExtractionOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    throw const OpenAiException('extract failed');
  }
}

class _FailingProviderAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    throw AiProviderException(
      AiFailure.networkAbort(AiProvider.gemini, 'socket closed'),
    );
  }
}

class _RecordingExtractionClient extends FakeOpenAiClient {
  final chunkingModes = <String>[];

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
  }) async {
    chunkingModes.add(chunkingMode);
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }
}
