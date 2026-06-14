import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../models/local_extraction.dart';
import 'document_processing_service.dart';
import 'knowledge_document_repository.dart';
import 'local_chunk_builder.dart';

abstract class LocalPageExtractor {
  Future<List<LocalDocumentPage>> extractPages({
    required String documentId,
    required String path,
  });
}

class LocalDocumentProcessingService {
  const LocalDocumentProcessingService({
    required this.repository,
    required this.pageExtractor,
    this.chunkBuilder = const LocalChunkBuilder(),
    this.onProgress,
  });

  final KnowledgeDocumentRepository repository;
  final LocalPageExtractor pageExtractor;
  final LocalChunkBuilder chunkBuilder;
  final void Function(ProcessingProgress progress)? onProgress;

  Future<ProcessingResult> processDocument(
    String documentPublicId, {
    bool forceReprocess = false,
    void Function(ProcessingProgress progress)? onProgress,
  }) async {
    void emit(
      ProcessingPhase phase, {
      int? current,
      int? total,
      String? label,
    }) {
      final progress = ProcessingProgress(
        documentId: documentPublicId,
        phase: phase,
        current: current,
        total: total,
        label: label,
      );
      this.onProgress?.call(progress);
      onProgress?.call(progress);
    }

    try {
      DebugConsole.log('[Local OCR] start document=$documentPublicId');
      await repository.markState(
        documentPublicId,
        ProcessingState.processing,
        activeProvider: 'local',
        activeModel: 'google_mlkit_text_recognition',
        retryable: false,
        clearLastErrorCode: true,
      );
      emit(ProcessingPhase.extracting, label: 'Lokális OCR...');
      final path = await repository.localPathForDocument(documentPublicId);
      final pages = await pageExtractor.extractPages(
        documentId: documentPublicId,
        path: path,
      );
      DebugConsole.log(
        '[Local OCR] pages=${pages.length} document=$documentPublicId',
      );
      emit(ProcessingPhase.embedding, label: 'Lokális chunkolás...');
      final chunks = chunkBuilder.build(
        documentId: documentPublicId,
        pages: pages,
      );
      await repository.saveLocalChunks(documentPublicId, chunks);
      final state = chunks.any(
        (chunk) => chunk.auditState == LocalAuditState.unreviewed,
      )
          ? ProcessingState.needsReview
          : ProcessingState.ready;
      await repository.markState(
        documentPublicId,
        state,
        activeProvider: 'local',
        activeModel: 'google_mlkit_text_recognition',
        clearLastErrorCode: true,
        retryable: false,
      );
      emit(ProcessingPhase.complete, current: chunks.length, total: chunks.length);
      DebugConsole.log(
        '[Local OCR] complete document=$documentPublicId chunks=${chunks.length}',
      );
      return ProcessingResult(state: state.wireName);
    } catch (error) {
      final message = error.toString();
      DebugConsole.log(
        '[Local OCR] failed document=$documentPublicId error=$message',
      );
      await repository.markState(
        documentPublicId,
        ProcessingState.failed,
        errorMessage: message,
        activeProvider: 'local',
        activeModel: 'google_mlkit_text_recognition',
        lastErrorCode: 'local_ocr_failed',
        retryable: true,
      );
      emit(ProcessingPhase.failed, label: message);
      return const ProcessingResult(
        state: 'failed',
        errorCode: 'local_ocr_failed',
        retryable: true,
      );
    }
  }
}
