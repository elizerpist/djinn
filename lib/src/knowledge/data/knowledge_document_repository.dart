import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../ai/ai_client.dart';
import '../../core/storage/json_file_store.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import '../models/chunk_package.dart';
import '../models/knowledge_document.dart';
import '../models/knowledge_folder.dart';
import 'chunk_package_service.dart';
import 'document_processing_service.dart';

class KnowledgeDocumentRepository implements ProcessingRepository {
  KnowledgeDocumentRepository({
    JsonFileStore? store,
    JsonFileStore? folderStore,
    Uuid? uuid,
  }) : _store = store,
       _folderStore = folderStore ?? _defaultFolderStore(store),
       _uuid = uuid ?? const Uuid();

  final JsonFileStore? _store;
  final JsonFileStore? _folderStore;
  final Uuid _uuid;
  List<KnowledgeDocument> _documents = [];
  final List<KnowledgeFolder> _folders = [];
  final Map<String, List<ChunkPackageItem>> _chunksByDocument = {};
  final Map<String, String> _embeddingModelByDocument = {};
  final Map<String, List<AiFlowchartCandidate>> _flowchartsByDocument = {};
  int _nextDocumentId = 1;

  static JsonFileStore? _defaultFolderStore(JsonFileStore? store) {
    if (store == null) {
      return null;
    }
    return JsonFileStore(File('${store.file.parent.path}/folders.json'));
  }

  Future<void> load() async {
    final store = _store;
    if (store != null) {
      final items = await store.readList();
      _documents
        ..clear()
        ..addAll(items.map(KnowledgeDocument.fromJson));
      _nextDocumentId =
          _nextNumericSuffix(
            _documents.map((document) => document.id),
            'document-',
          ) +
          1;
    }
    final folderStore = _folderStore;
    if (folderStore != null) {
      final items = await folderStore.readList();
      _folders
        ..clear()
        ..addAll(items.map(KnowledgeFolder.fromJson));
    }
  }

  Future<List<KnowledgeDocument>> listDocuments({String? folderId}) async {
    final documents = folderId == null
        ? _documents
        : _documents.where((document) => document.folderId == folderId);
    return List.unmodifiable(documents);
  }

  Future<List<KnowledgeFolder>> listFolders() async {
    return List.unmodifiable(_folders);
  }

  Future<KnowledgeFolder> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    final now = DateTime.now();
    final folder = KnowledgeFolder(
      id: _uuid.v4(),
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
    _folders.add(folder);
    await _persistFolders();
    return folder;
  }

  Future<KnowledgeFolder> renameFolder(String folderId, String name) async {
    final index = _folders.indexWhere((folder) => folder.id == folderId);
    if (index == -1) {
      throw StateError('knowledge folder not found: $folderId');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    final updated = _folders[index].copyWith(
      name: trimmed,
      updatedAt: DateTime.now(),
    );
    _folders[index] = updated;
    await _persistFolders();
    return updated;
  }

  Future<void> deleteFolder(String folderId) async {
    _folders.removeWhere((folder) => folder.id == folderId);
    await _persistFolders();
    await moveDocumentsToFolder(
      _documents
          .where((document) => document.folderId == folderId)
          .map((document) => document.id)
          .toList(growable: false),
      null,
    );
  }

  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  ) async {
    final idSet = documentIds.toSet();
    _documents = [
      for (final document in _documents)
        if (idSet.contains(document.id))
          document.copyWith(folderId: folderId, clearFolderId: folderId == null)
        else
          document,
    ];
    await _persist();
  }

  Future<void> deleteDocuments(List<String> documentIds) async {
    final idSet = documentIds.toSet();
    final documentsToDelete = _documents
        .where((document) => idSet.contains(document.id))
        .toList(growable: false);
    _documents = [
      for (final document in _documents)
        if (!idSet.contains(document.id)) document,
    ];
    for (final document in documentsToDelete) {
      _chunksByDocument.remove(document.id);
      _embeddingModelByDocument.remove(document.id);
      _flowchartsByDocument.remove(document.id);
      await _deleteLocalFileIfPresent(document.localPath);
    }
    await _persist();
  }

  Future<KnowledgeBaseState> state() async {
    return KnowledgeBaseState.fromDocuments(_documents);
  }

  Future<KnowledgeDocument> addDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    required DateTime importedAt,
    String? sha256,
    String? folderId,
  }) async {
    final document = KnowledgeDocument(
      id: 'document-${_nextDocumentId++}',
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAt: importedAt,
      status: KnowledgeDocumentStatus.imported,
      folderId: folderId,
      sha256: sha256,
    );
    _documents.insert(0, document);
    await _persist();
    return document;
  }

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
    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) {
      throw StateError('knowledge document not found: $documentId');
    }
    final updated = _documents[index].copyWith(
      status: status,
      backendDocumentId: backendDocumentId,
      errorMessage: errorMessage,
      clearErrorMessage: errorMessage == null,
      activeProvider: activeProvider,
      activeModel: activeModel,
      lastErrorCode: lastErrorCode,
      retryable: retryable,
      clearLastErrorCode: clearLastErrorCode,
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  Future<KnowledgeDocument> reconcileBackendDocument({
    required String localDocumentId,
    required KnowledgeDocument backendDocument,
  }) async {
    final index = _documents.indexWhere(
      (document) => document.id == localDocumentId,
    );
    if (index == -1) {
      throw StateError('knowledge document not found: $localDocumentId');
    }
    final current = _documents[index];
    final updated = current.copyWith(
      filename: backendDocument.filename.isEmpty
          ? current.filename
          : backendDocument.filename,
      sizeBytes: backendDocument.sizeBytes == 0
          ? current.sizeBytes
          : backendDocument.sizeBytes,
      status: backendDocument.status,
      backendDocumentId:
          backendDocument.backendDocumentId ?? backendDocument.id,
      errorMessage: backendDocument.errorMessage,
      clearErrorMessage: backendDocument.errorMessage == null,
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  KnowledgeDocument? findByBackendDocumentId(String backendDocumentId) {
    for (final document in _documents) {
      if (document.backendDocumentId == backendDocumentId) {
        return document;
      }
    }
    return null;
  }

  @override
  Future<String> localPathForDocument(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    return document.localPath;
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
    await updateStatus(
      documentPublicId,
      _statusFromProcessingState(state),
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

  @override
  Future<void> clearGeneratedKnowledge(String documentPublicId) async {
    _chunksByDocument.remove(documentPublicId);
    _embeddingModelByDocument.remove(documentPublicId);
    _flowchartsByDocument.remove(documentPublicId);
  }

  @override
  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    final items = _chunksByDocument.putIfAbsent(documentPublicId, () => []);
    items.removeWhere((item) => item.id == evidence.id);
    items.add(
      ChunkPackageItem(
        id: evidence.id,
        text: evidence.text,
        pageNumber: evidence.pageNumber,
        sectionTitle: evidence.sectionTitle,
        embedding: embedding,
      ),
    );
    _embeddingModelByDocument[documentPublicId] = embeddingModel;
  }

  @override
  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
  }) async {
    final items = _flowchartsByDocument.putIfAbsent(documentPublicId, () => []);
    items.removeWhere((item) => item.id == flowchart.id);
    items.add(flowchart);
  }

  Future<ChunkPackage> exportChunkPackage(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    final chunks = _chunksByDocument[documentPublicId] ?? const [];
    final embeddingDimension = chunks.isEmpty
        ? 0
        : chunks.first.embedding.length;
    return ChunkPackage(
      schemaVersion: 1,
      documentHash: document.sha256 ?? '',
      filename: document.filename,
      provider: document.activeProvider ?? '',
      extractionModel: document.activeModel ?? '',
      embeddingModel: _embeddingModelByDocument[documentPublicId] ?? '',
      embeddingDimension: embeddingDimension,
      chunks: List<ChunkPackageItem>.unmodifiable(chunks),
    );
  }

  Future<void> importChunkPackage(
    String documentPublicId,
    ChunkPackage package,
  ) async {
    final document = _findDocument(documentPublicId);
    const service = ChunkPackageService();
    service.validateForImport(
      package,
      documentHash: document.sha256 ?? '',
      expectedDimension: package.embeddingDimension,
    );
    _chunksByDocument[documentPublicId] = package.chunks;
    _embeddingModelByDocument[documentPublicId] = package.embeddingModel;
    await updateStatus(
      document.id,
      KnowledgeDocumentStatus.ready,
      activeProvider: package.provider.isEmpty ? null : package.provider,
      activeModel: package.extractionModel.isEmpty
          ? null
          : package.extractionModel,
      clearLastErrorCode: true,
    );
  }

  KnowledgeDocument _findDocument(String documentId) {
    for (final document in _documents) {
      if (document.id == documentId) {
        return document;
      }
    }
    throw StateError('knowledge document not found: $documentId');
  }

  KnowledgeDocumentStatus _statusFromProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.imported => KnowledgeDocumentStatus.imported,
      ProcessingState.blockedMissingApiKey =>
        KnowledgeDocumentStatus.blockedMissingApiKey,
      ProcessingState.blockedOffline => KnowledgeDocumentStatus.blockedOffline,
      ProcessingState.uploading => KnowledgeDocumentStatus.uploading,
      ProcessingState.processing => KnowledgeDocumentStatus.processing,
      ProcessingState.embedded => KnowledgeDocumentStatus.embedded,
      ProcessingState.ready => KnowledgeDocumentStatus.ready,
      ProcessingState.needsReview => KnowledgeDocumentStatus.needsReview,
      ProcessingState.failed => KnowledgeDocumentStatus.failed,
    };
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.writeList(
      _documents.map((document) => document.toJson()).toList(),
    );
  }

  Future<void> _persistFolders() async {
    final store = _folderStore;
    if (store == null) {
      return;
    }
    await store.writeList(_folders.map((folder) => folder.toJson()).toList());
  }

  Future<void> _deleteLocalFileIfPresent(String path) async {
    if (path.isEmpty) {
      return;
    }
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {
      // A missing or provider-owned file should not block database cleanup.
    }
  }

  int _nextNumericSuffix(Iterable<String> ids, String prefix) {
    var max = 0;
    for (final id in ids) {
      if (!id.startsWith(prefix)) {
        continue;
      }
      final value = int.tryParse(id.substring(prefix.length));
      if (value != null && value > max) {
        max = value;
      }
    }
    return max;
  }
}
