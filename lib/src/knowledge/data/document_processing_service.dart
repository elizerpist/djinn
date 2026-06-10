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

enum ProcessingPhase { queued, extracting, embedding, complete, failed }

class ProcessingProgress {
  const ProcessingProgress({
    required this.documentId,
    required this.phase,
    this.current,
    this.total,
    this.label,
  });

  final String documentId;
  final ProcessingPhase phase;
  final int? current;
  final int? total;
  final String? label;
}

abstract class ProcessingRepository {
  Future<String> localPathForDocument(String documentPublicId);

  Future<void> markState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  });

  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  }) {
    return saveExtractedEvidence(
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

  Future<void> clearGeneratedKnowledge(String documentPublicId);

  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  });

  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
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
    this.onProgress,
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
  final void Function(ProcessingProgress progress)? onProgress;

  Future<ProcessingResult> processDocument(
    String documentPublicId, {
    bool forceReprocess = false,
  }) async {
    final settings = await loadSettings();
    final provider = settings.activeProvider;
    if (!await _hasKey(provider)) {
      DebugConsole.log(
        '[AI Training] blocked missing_api_key provider=${provider.wireName} document=$documentPublicId',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.blockedMissingApiKey,
        activeProvider: provider.wireName,
        activeModel: settings.extractionModel,
        lastErrorCode: AiFailureCode.missingApiKey.name,
        retryable: false,
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
      await repository.markState(
        documentPublicId,
        ProcessingState.processing,
        activeProvider: provider.wireName,
        activeModel: settings.extractionModel,
        retryable: false,
        clearLastErrorCode: true,
      );
      if (forceReprocess) {
        await repository.clearGeneratedKnowledge(documentPublicId);
      }

      _emitProgress(
        documentPublicId,
        ProcessingPhase.extracting,
        label: 'Kinyeres...',
      );
      final extraction = await client.extractDocument(
        pdfPath: pdfPath,
        model: settings.extractionModel,
        chunkingMode: settings.chunkingMode,
      );
      DebugConsole.log(
        '[AI Training] extraction chunks=${extraction.chunks.length} '
        'model=${settings.extractionModel} provider=${provider.wireName}',
      );
      DebugConsole.log(
        '[Flowchart] extraction candidates=${extraction.flowcharts.length} '
        'document=$documentPublicId',
      );
      for (final flowchart in extraction.flowcharts) {
        await repository.saveFlowchartCandidate(
          documentPublicId: documentPublicId,
          flowchart: flowchart,
        );
      }
      final evidence = extraction.allEvidence;
      for (var index = 0; index < evidence.length; index += 1) {
        final item = evidence[index];
        final embedding = await client.createEmbedding(
          input: item.text,
          model: settings.embeddingModel,
        );
        final current = index + 1;
        DebugConsole.log(
          '[AI Training] embedding chunk=${item.id} '
          'model=${settings.embeddingModel} dim=${embedding.length} '
          'provider=${provider.wireName}',
        );
        await repository.saveExtractedEvidence(
          documentPublicId: documentPublicId,
          evidence: item,
          embedding: embedding,
          embeddingModel: settings.embeddingModel,
        );
        _emitProgress(
          documentPublicId,
          ProcessingPhase.embedding,
          current: current,
          total: evidence.length,
          label: 'Embedding $current/${evidence.length}',
        );
      }

      await repository.markState(
        documentPublicId,
        ProcessingState.embedded,
        activeProvider: provider.wireName,
        activeModel: settings.extractionModel,
        retryable: false,
        clearLastErrorCode: true,
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.ready,
        activeProvider: provider.wireName,
        activeModel: settings.extractionModel,
        retryable: false,
        clearLastErrorCode: true,
      );
      DebugConsole.log(
        '[AI Training] complete document=$documentPublicId provider=${provider.wireName}',
      );
      _emitProgress(documentPublicId, ProcessingPhase.complete, label: 'Kesz');
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
        activeProvider: failure.provider.wireName,
        activeModel: settings.extractionModel,
        lastErrorCode: failure.code.name,
        retryable: failure.retryable,
      );
      _emitProgress(
        documentPublicId,
        ProcessingPhase.failed,
        label: failure.userMessage,
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
        activeProvider: provider.wireName,
        activeModel: settings.extractionModel,
        lastErrorCode: AiFailureCode.unknown.name,
        retryable: false,
      );
      _emitProgress(
        documentPublicId,
        ProcessingPhase.failed,
        label: error.message,
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

  void _emitProgress(
    String documentId,
    ProcessingPhase phase, {
    int? current,
    int? total,
    String? label,
  }) {
    onProgress?.call(
      ProcessingProgress(
        documentId: documentId,
        phase: phase,
        current: current,
        total: total,
        label: label,
      ),
    );
  }
}
