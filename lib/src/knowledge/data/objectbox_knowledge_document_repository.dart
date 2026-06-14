import '../../ai/ai_client.dart';
import '../../local_store/entities.dart' as local;
import '../../openai/openai_client.dart';
import '../models/chunk_package.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/knowledge_document.dart';
import '../models/knowledge_folder.dart';
import '../models/local_extraction.dart';
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
  Future<List<KnowledgeDocument>> listDocuments({String? folderId}) async {
    final entities = await _repository.listDocuments(folderId: folderId);
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
    String? sha256,
    String? folderId,
  }) async {
    final entity = await _repository.addImportedDocument(
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      sha256: sha256,
      folderId: folderId,
    );
    return _fromEntity(entity);
  }

  @override
  Future<List<KnowledgeFolder>> listFolders() async {
    final entities = await _repository.listFolders();
    entities.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return entities.map(_folderFromEntity).toList(growable: false);
  }

  @override
  Future<KnowledgeFolder> createFolder(String name) async {
    return _folderFromEntity(await _repository.createFolder(name));
  }

  @override
  Future<KnowledgeFolder> renameFolder(String folderId, String name) async {
    return _folderFromEntity(await _repository.renameFolder(folderId, name));
  }

  @override
  Future<void> deleteFolder(String folderId) {
    return _repository.deleteFolder(folderId);
  }

  @override
  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  ) {
    return _repository.moveDocumentsToFolder(documentIds, folderId);
  }

  @override
  Future<void> deleteDocuments(List<String> documentIds) {
    return _repository.deleteDocuments(documentIds);
  }

  @override
  Future<KnowledgeDocument> updateStatus(
    String documentId,
    KnowledgeDocumentStatus status, {
    String? backendDocumentId,
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) async {
    await _repository.updateProcessingState(
      documentId,
      _processingStateFromStatus(status),
      errorMessage: errorMessage,
      activeProvider: activeProvider,
      activeModel: activeModel,
      lastErrorCode: lastErrorCode,
      retryable: retryable,
      clearLastErrorCode: clearLastErrorCode,
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
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) {
    return _repository.markState(
      documentPublicId,
      state,
      errorMessage: errorMessage,
      activeProvider: activeProvider,
      activeModel: activeModel,
      lastErrorCode: lastErrorCode,
      retryable: retryable,
      clearLastErrorCode: clearLastErrorCode,
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

  @override
  Future<void> clearGeneratedKnowledge(String documentPublicId) {
    return _repository.clearGeneratedKnowledge(documentPublicId);
  }

  @override
  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  }) {
    return _repository.saveExtractedEvidence(
      documentPublicId: documentPublicId,
      evidence: evidence,
      embedding: embedding,
      embeddingModel: embeddingModel,
    );
  }

  @override
  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
  }) {
    return _repository.saveFlowchartCandidate(
      documentPublicId: documentPublicId,
      flowchart: flowchart,
    );
  }


  @override
  Future<List<ExtractedKnowledgeItem>> listExtractedKnowledgeItems(
    String documentPublicId, {
    LocalExtractionPipeline? pipeline,
  }) {
    return _repository.listExtractedKnowledgeItems(
      documentPublicId,
      pipeline: pipeline,
    );
  }

  @override
  Future<void> saveLocalChunks(
    String documentPublicId,
    List<LocalChunk> chunks,
  ) {
    return _repository.saveLocalChunks(documentPublicId, chunks);
  }

  @override
  Future<void> updateExtractedKnowledgeAuditState(
    String documentPublicId,
    String itemId,
    LocalAuditState auditState, {
    String? text,
  }) {
    return _repository.updateExtractedKnowledgeAuditState(
      documentPublicId,
      itemId,
      auditState,
      text: text,
    );
  }

  @override
  Future<ChunkComparison> compareExtractedChunks(String documentPublicId) {
    return _repository.compareExtractedChunks(documentPublicId);
  }

  @override
  Future<ChunkPackage> exportChunkPackage(String documentPublicId) {
    return _repository.exportChunkPackage(documentPublicId);
  }

  @override
  Future<void> importChunkPackage(
    String documentPublicId,
    ChunkPackage package,
  ) {
    return _repository.importChunkPackage(documentPublicId, package);
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
      folderId: entity.folderPublicId,
      sha256: entity.sha256,
      activeProvider: entity.activeProvider,
      activeModel: entity.activeModel,
      lastErrorCode: entity.lastErrorCode,
      retryable: entity.retryable,
    );
  }

  KnowledgeFolder _folderFromEntity(local.KnowledgeFolderEntity entity) {
    return KnowledgeFolder(
      id: entity.publicId,
      name: entity.name,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entity.createdAtMillis),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entity.updatedAtMillis),
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
