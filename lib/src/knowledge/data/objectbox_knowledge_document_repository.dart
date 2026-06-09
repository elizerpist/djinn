import '../../local_store/entities.dart' as local;
import '../../openai/openai_client.dart';
import '../models/knowledge_document.dart';
import 'document_processing_service.dart';
import 'knowledge_document_repository.dart';
import 'objectbox_knowledge_repository.dart';

class ObjectBoxKnowledgeDocumentRepository extends KnowledgeDocumentRepository
    implements ProcessingRepository {
  ObjectBoxKnowledgeDocumentRepository({
    required ObjectBoxKnowledgeRepository repository,
  }) : _repository = repository;

  final ObjectBoxKnowledgeRepository _repository;

  @override
  Future<void> load() async {}

  @override
  Future<List<KnowledgeDocument>> listDocuments() async {
    final entities = await _repository.listDocuments();
    entities.sort((a, b) => b.importedAtMillis.compareTo(a.importedAtMillis));
    return entities.map(_fromEntity).toList(growable: false);
  }

  @override
  Future<KnowledgeBaseState> state() async {
    return KnowledgeBaseState.fromDocuments(await listDocuments());
  }

  @override
  Future<KnowledgeDocument> addDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    required DateTime importedAt,
    String? contentHash,
    String ocrStatus = 'unknown',
    String collectionName = 'Alap',
    bool ragEnabled = true,
  }) async {
    final entity = await _repository.addImportedDocument(
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      contentHash: contentHash,
      ocrStatus: ocrStatus,
      collectionName: collectionName,
      ragEnabled: ragEnabled,
    );
    return _fromEntity(entity);
  }

  @override
  Future<KnowledgeDocument?> findByContentHash(String contentHash) async {
    final entity = await _repository.findDocumentByContentHash(contentHash);
    return entity == null ? null : _fromEntity(entity);
  }

  @override
  Future<KnowledgeDocument> updateRagEnabled(
    String documentId,
    bool enabled,
  ) async {
    await _repository.updateRagEnabled(documentId, enabled);
    final updated = await _repository.findDocumentByPublicId(documentId);
    if (updated == null) {
      throw StateError('knowledge document not found: $documentId');
    }
    return _fromEntity(updated);
  }

  @override
  Future<KnowledgeDocument> updateCollection(
    String documentId,
    String collectionName,
  ) async {
    await _repository.updateCollection(documentId, collectionName);
    final updated = await _repository.findDocumentByPublicId(documentId);
    if (updated == null) {
      throw StateError('knowledge document not found: $documentId');
    }
    return _fromEntity(updated);
  }

  @override
  Future<KnowledgeDocument> updateStatus(
    String documentId,
    KnowledgeDocumentStatus status, {
    String? backendDocumentId,
    String? errorMessage,
  }) async {
    await _repository.updateProcessingState(
      documentId,
      _processingStateFromStatus(status),
      errorMessage: errorMessage,
    );
    final updated = (await listDocuments()).firstWhere(
      (document) => document.id == documentId,
      orElse: () =>
          throw StateError('knowledge document not found: $documentId'),
    );
    return updated;
  }

  @override
  Future<String> localPathForDocument(String documentPublicId) {
    return _repository.localPathForDocument(documentPublicId);
  }

  @override
  Future<void> markState(
    String documentPublicId,
    local.ProcessingState state, {
    String? errorMessage,
  }) {
    return _repository.markState(
      documentPublicId,
      state,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> clearEvidence(String documentPublicId) {
    return _repository.clearEvidence(documentPublicId);
  }

  @override
  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  }) {
    return _repository.saveExtractedChunk(
      documentPublicId: documentPublicId,
      chunk: chunk,
      embedding: embedding,
      embeddingModel: embeddingModel,
    );
  }

  @override
  Future<void> saveExtractedFlowchart({
    required String documentPublicId,
    required OpenAiExtractedFlowchart flowchart,
    required Map<String, List<double>> embeddingsBySourceId,
    required String embeddingModel,
  }) {
    return _repository.saveExtractedFlowchart(
      documentPublicId: documentPublicId,
      flowchart: flowchart,
      embeddingsBySourceId: embeddingsBySourceId,
      embeddingModel: embeddingModel,
    );
  }

  KnowledgeDocument _fromEntity(local.KnowledgeDocumentEntity entity) {
    return KnowledgeDocument(
      id: entity.publicId,
      filename: entity.filename,
      localPath: entity.localPath,
      sizeBytes: entity.sizeBytes,
      importedAt: DateTime.fromMillisecondsSinceEpoch(entity.importedAtMillis),
      status: KnowledgeDocumentStatus.fromWireName(entity.processingState),
      errorMessage: entity.errorMessage,
      contentHash: entity.contentHash,
      ragEnabled: entity.ragEnabled,
      collectionName: entity.collectionName,
      ocrStatus: entity.ocrStatus,
      trainedAt: entity.trainedAtMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(entity.trainedAtMillis!),
      packVersion: entity.packVersion,
    );
  }

  local.ProcessingState _processingStateFromStatus(
    KnowledgeDocumentStatus status,
  ) {
    return switch (status) {
      KnowledgeDocumentStatus.imported ||
      KnowledgeDocumentStatus.pendingIngest => local.ProcessingState.imported,
      KnowledgeDocumentStatus.blockedMissingApiKey =>
        local.ProcessingState.blockedMissingApiKey,
      KnowledgeDocumentStatus.blockedPaidAi =>
        local.ProcessingState.blockedPaidAi,
      KnowledgeDocumentStatus.blockedOffline =>
        local.ProcessingState.blockedOffline,
      KnowledgeDocumentStatus.uploading => local.ProcessingState.uploading,
      KnowledgeDocumentStatus.processing => local.ProcessingState.processing,
      KnowledgeDocumentStatus.embedded => local.ProcessingState.embedded,
      KnowledgeDocumentStatus.ready ||
      KnowledgeDocumentStatus.processed => local.ProcessingState.ready,
      KnowledgeDocumentStatus.needsReview => local.ProcessingState.needsReview,
      KnowledgeDocumentStatus.failed => local.ProcessingState.failed,
    };
  }
}
