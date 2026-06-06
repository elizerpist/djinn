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
  }) async {
    final entity = await _repository.addImportedDocument(
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
    );
    return _fromEntity(entity);
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

  KnowledgeDocument _fromEntity(local.KnowledgeDocumentEntity entity) {
    return KnowledgeDocument(
      id: entity.publicId,
      filename: entity.filename,
      localPath: entity.localPath,
      sizeBytes: entity.sizeBytes,
      importedAt: DateTime.fromMillisecondsSinceEpoch(entity.importedAtMillis),
      status: KnowledgeDocumentStatus.fromWireName(entity.processingState),
      errorMessage: entity.errorMessage,
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
