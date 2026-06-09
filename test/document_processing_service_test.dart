import 'package:flutter_test/flutter_test.dart';
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
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'ready');
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.embedded,
      ProcessingState.ready,
    ]);
    expect(repository.clearedDocuments, ['doc-1']);
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

  test('stores extracted flowcharts and marks document for review', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _FlowchartExtractingOpenAiClient(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'needs_review');
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.embedded,
      ProcessingState.needsReview,
    ]);
    expect(repository.savedFlowcharts, hasLength(1));
    expect(repository.savedFlowcharts.single.nodes, hasLength(2));
    expect(repository.savedFlowcharts.single.edges.single.label, 'then');
    expect(repository.savedEmbeddings, hasLength(4));
    expect(
      DebugConsole.allText,
      contains('[AI Training] extraction chunks=1 flowcharts=1'),
    );
  });

  test('marks document failed when OpenAI extraction fails', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _FailingExtractionOpenAiClient(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
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

  test('blocks paid AI processing before extraction when disabled', () async {
    final repository = MemoryProcessingRepository();
    final openAiClient = _CountingOpenAiClient();
    final service = DocumentProcessingService(
      openAiClient: openAiClient,
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: false,
        confirmBeforeAiProcessing: true,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'blocked_paid_ai');
    expect(openAiClient.extractCalls, 0);
    expect(repository.states, [ProcessingState.blockedPaidAi]);
    expect(
      DebugConsole.allText,
      contains('[AI Training] blocked paid_ai_disabled document=doc-1'),
    );
  });

  test('marks document failed when PDF file is missing', () async {
    final repository = MemoryProcessingRepository();
    final openAiClient = _CountingOpenAiClient();
    final service = DocumentProcessingService(
      openAiClient: openAiClient,
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => false,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'failed');
    expect(result.errorMessage, contains('PDF file not found'));
    expect(openAiClient.extractCalls, 0);
    expect(repository.states, [ProcessingState.failed]);
  });

  test('marks document failed when non-OpenAI extraction throws', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _ThrowingExtractionClient(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'failed');
    expect(result.errorMessage, contains('Bad state: parser failed'));
    expect(repository.states, [
      ProcessingState.processing,
      ProcessingState.failed,
    ]);
  });

  test('clears previous evidence before retrying processing', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _ExtractingOpenAiClient(),
      loadSettings: () async => AppSettings.defaults().copyWith(
        allowPaidAi: true,
        confirmBeforeAiProcessing: false,
      ),
      hasApiKey: () async => true,
      repository: repository,
      pdfExists: (_) async => true,
    );

    await service.processDocument('doc-1');
    await service.processDocument('doc-1');

    expect(repository.clearedDocuments, ['doc-1', 'doc-1']);
    expect(repository.savedChunks.map((chunk) => chunk.id), ['c1', 'c1']);
  });
}

class MemoryProcessingRepository implements ProcessingRepository {
  final states = <ProcessingState>[];
  final savedChunks = <OpenAiExtractedChunk>[];
  final savedFlowcharts = <OpenAiExtractedFlowchart>[];
  final savedEmbeddings = <ChunkEmbeddingEntity>[];
  final errorMessages = <String?>[];
  final clearedDocuments = <String>[];

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
  Future<void> clearEvidence(String documentPublicId) async {
    clearedDocuments.add(documentPublicId);
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

  @override
  Future<void> saveExtractedFlowchart({
    required String documentPublicId,
    required OpenAiExtractedFlowchart flowchart,
    required Map<String, List<double>> embeddingsBySourceId,
    required String embeddingModel,
  }) async {
    savedFlowcharts.add(flowchart);
    for (final entry in embeddingsBySourceId.entries) {
      savedEmbeddings.add(
        ChunkEmbeddingEntity(
          sourceId: entry.key,
          sourceType: entry.key.contains(':edge:')
              ? EvidenceSourceType.flowchartEdge.wireName
              : EvidenceSourceType.flowchartNode.wireName,
          vector: entry.value,
          model: embeddingModel,
          createdAtMillis: 1760000000000,
        ),
      );
    }
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

class _CountingOpenAiClient extends FakeOpenAiClient {
  int extractCalls = 0;

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    extractCalls += 1;
    return const OpenAiExtractionResult(chunks: []);
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

class _ThrowingExtractionClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    throw StateError('parser failed');
  }
}

class _FlowchartExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
      flowcharts: [
        OpenAiExtractedFlowchart(
          id: 'flow-1',
          title: 'ABCDE flow',
          pageNumber: 2,
          confidence: 0.9,
          nodes: [
            OpenAiExtractedFlowchartNode(id: 'a', label: 'Airway'),
            OpenAiExtractedFlowchartNode(id: 'b', label: 'Breathing'),
          ],
          edges: [
            OpenAiExtractedFlowchartEdge(
              id: 'a-b',
              fromNodeId: 'a',
              toNodeId: 'b',
              label: 'then',
            ),
          ],
        ),
      ],
    );
  }
}
