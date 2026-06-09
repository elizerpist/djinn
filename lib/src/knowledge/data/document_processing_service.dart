import 'dart:io';

import '../../debug/debug_console.dart';
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

  Future<void> clearEvidence(String documentPublicId);

  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  });

  Future<void> saveExtractedFlowchart({
    required String documentPublicId,
    required OpenAiExtractedFlowchart flowchart,
    required Map<String, List<double>> embeddingsBySourceId,
    required String embeddingModel,
  });
}

class DocumentProcessingService {
  const DocumentProcessingService({
    required this.openAiClient,
    required this.loadSettings,
    required this.hasApiKey,
    required this.repository,
    this.pdfExists = _defaultPdfExists,
  });

  final OpenAiClient openAiClient;
  final Future<AppSettings> Function() loadSettings;
  final Future<bool> Function() hasApiKey;
  final ProcessingRepository repository;
  final Future<bool> Function(String path) pdfExists;

  Future<ProcessingResult> processDocument(String documentPublicId) async {
    if (!await hasApiKey()) {
      DebugConsole.log(
        '[AI Training] blocked missing_api_key document=$documentPublicId',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.blockedMissingApiKey,
      );
      return ProcessingResult(
        state: ProcessingState.blockedMissingApiKey.wireName,
      );
    }

    final settings = await loadSettings();
    if (!settings.allowPaidAi) {
      DebugConsole.log(
        '[AI Training] blocked paid_ai_disabled document=$documentPublicId',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.blockedPaidAi,
        errorMessage: 'Paid AI processing is disabled in settings.',
      );
      return ProcessingResult(
        state: ProcessingState.blockedPaidAi.wireName,
        errorMessage: 'Paid AI processing is disabled in settings.',
      );
    }

    try {
      DebugConsole.log('[AI Training] start document=$documentPublicId');
      final pdfPath = await repository.localPathForDocument(documentPublicId);
      if (!await pdfExists(pdfPath)) {
        const message = 'PDF file not found for AI processing.';
        DebugConsole.log(
          '[AI Training] failed document=$documentPublicId error=$message',
        );
        await repository.markState(
          documentPublicId,
          ProcessingState.failed,
          errorMessage: message,
        );
        return const ProcessingResult(state: 'failed', errorMessage: message);
      }
      await repository.markState(documentPublicId, ProcessingState.processing);
      await repository.clearEvidence(documentPublicId);

      final extraction = await openAiClient.extractDocument(
        pdfPath: pdfPath,
        model: settings.activeExtractionModel,
      );
      DebugConsole.log(
        '[AI Training] extraction chunks=${extraction.chunks.length} '
        'flowcharts=${extraction.flowcharts.length} '
        'model=${settings.activeExtractionModel}',
      );
      for (final chunk in extraction.chunks) {
        final embedding = await openAiClient.createEmbedding(
          input: chunk.text,
          model: settings.activeEmbeddingModel,
        );
        DebugConsole.log(
          '[AI Training] embedding chunk=${chunk.id} '
          'model=${settings.activeEmbeddingModel} dim=${embedding.length}',
        );
        await repository.saveExtractedChunk(
          documentPublicId: documentPublicId,
          chunk: chunk,
          embedding: embedding,
          embeddingModel: settings.activeEmbeddingModel,
        );
      }
      for (final flowchart in extraction.flowcharts) {
        final flowchartId = '$documentPublicId:${flowchart.id}';
        final embeddingsBySourceId = <String, List<double>>{};
        for (final node in flowchart.nodes) {
          final sourceId = '$flowchartId:node:${node.id}';
          final embedding = await openAiClient.createEmbedding(
            input: node.label,
            model: settings.activeEmbeddingModel,
          );
          DebugConsole.log(
            '[AI Training] embedding flowchart_node=$sourceId '
            'model=${settings.activeEmbeddingModel} dim=${embedding.length}',
          );
          embeddingsBySourceId[sourceId] = embedding;
        }
        for (final edge in flowchart.edges) {
          final sourceId = '$flowchartId:edge:${edge.id}';
          final embedding = await openAiClient.createEmbedding(
            input: edge.label,
            model: settings.activeEmbeddingModel,
          );
          DebugConsole.log(
            '[AI Training] embedding flowchart_edge=$sourceId '
            'model=${settings.activeEmbeddingModel} dim=${embedding.length}',
          );
          embeddingsBySourceId[sourceId] = embedding;
        }
        await repository.saveExtractedFlowchart(
          documentPublicId: documentPublicId,
          flowchart: flowchart,
          embeddingsBySourceId: embeddingsBySourceId,
          embeddingModel: settings.activeEmbeddingModel,
        );
      }

      await repository.markState(documentPublicId, ProcessingState.embedded);
      final finalState = extraction.flowcharts.isEmpty
          ? ProcessingState.ready
          : ProcessingState.needsReview;
      await repository.markState(documentPublicId, finalState);
      DebugConsole.log('[AI Training] complete document=$documentPublicId');
      return ProcessingResult(state: finalState.wireName);
    } on OpenAiException catch (error) {
      DebugConsole.log(
        '[AI Training] failed document=$documentPublicId error=${error.message}',
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
    } catch (error) {
      final message = error.toString();
      DebugConsole.log(
        '[AI Training] failed document=$documentPublicId error=$message',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.failed,
        errorMessage: message,
      );
      return ProcessingResult(
        state: ProcessingState.failed.wireName,
        errorMessage: message,
      );
    }
  }

  static Future<bool> _defaultPdfExists(String path) {
    return File(path).exists();
  }
}
