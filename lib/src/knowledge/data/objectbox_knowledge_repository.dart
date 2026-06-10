import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import 'document_processing_service.dart';

abstract class KnowledgeRepository {
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    String? sha256,
    String? folderId,
  });

  Future<List<KnowledgeDocumentEntity>> listDocuments({String? folderId});

  Future<KnowledgeFolderEntity> createFolder(String name);

  Future<List<KnowledgeFolderEntity>> listFolders();

  Future<KnowledgeFolderEntity> renameFolder(String folderId, String name);

  Future<void> deleteFolder(String folderId);

  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  );

  Future<void> updateProcessingState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  });

  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  );

  Future<bool> hasReadyDocuments();
}

class ObjectBoxKnowledgeRepository
    implements KnowledgeRepository, ProcessingRepository {
  ObjectBoxKnowledgeRepository({required Store store, Uuid? uuid})
    : _documentBox = store.box<KnowledgeDocumentEntity>(),
      _folderBox = store.box<KnowledgeFolderEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _uuid = uuid ?? const Uuid();

  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<KnowledgeFolderEntity> _folderBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Uuid _uuid;

  @override
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    String? sha256,
    String? folderId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final document = KnowledgeDocumentEntity(
      publicId: _uuid.v4(),
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAtMillis: now,
      processingState: ProcessingState.imported.wireName,
      sha256: sha256,
      folderPublicId: folderId,
    );
    _documentBox.put(document);
    return document;
  }

  @override
  Future<List<KnowledgeDocumentEntity>> listDocuments({
    String? folderId,
  }) async {
    if (folderId == null) {
      return _documentBox.getAll();
    }
    final query = _documentBox
        .query(KnowledgeDocumentEntity_.folderPublicId.equals(folderId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  @override
  Future<KnowledgeFolderEntity> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final folder = KnowledgeFolderEntity(
      publicId: _uuid.v4(),
      name: trimmed,
      createdAtMillis: now,
      updatedAtMillis: now,
    );
    _folderBox.put(folder);
    return folder;
  }

  @override
  Future<List<KnowledgeFolderEntity>> listFolders() async {
    return _folderBox.getAll();
  }

  @override
  Future<KnowledgeFolderEntity> renameFolder(
    String folderId,
    String name,
  ) async {
    final folder = _findFolder(folderId);
    if (folder == null) {
      throw StateError('knowledge folder not found: $folderId');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('folder name must not be blank');
    }
    folder.name = trimmed;
    folder.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    _folderBox.put(folder);
    return folder;
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    final folder = _findFolder(folderId);
    if (folder != null) {
      _folderBox.remove(folder.id);
    }
    await moveDocumentsToFolder(
      (await listDocuments(
        folderId: folderId,
      )).map((document) => document.publicId).toList(growable: false),
      null,
    );
  }

  @override
  Future<void> moveDocumentsToFolder(
    List<String> documentIds,
    String? folderId,
  ) async {
    for (final documentId in documentIds) {
      final document = _findDocument(documentId);
      if (document == null) {
        continue;
      }
      document.folderPublicId = folderId;
      _documentBox.put(document);
    }
  }

  @override
  Future<void> updateProcessingState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
    String? activeProvider,
    String? activeModel,
    String? lastErrorCode,
    bool? retryable,
    bool clearLastErrorCode = false,
  }) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    document.processingState = state.wireName;
    document.errorMessage = errorMessage;
    if (activeProvider != null) {
      document.activeProvider = activeProvider;
    }
    if (activeModel != null) {
      document.activeModel = activeModel;
    }
    if (lastErrorCode != null || clearLastErrorCode) {
      document.lastErrorCode = lastErrorCode;
    }
    if (retryable != null) {
      document.retryable = retryable;
    }
    _documentBox.put(document);
  }

  @override
  Future<String> localPathForDocument(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
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
  }) {
    return updateProcessingState(
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
  }) async {
    final sourceId = '$documentPublicId:${chunk.id}';
    await saveChunk(
      DocumentChunkEntity(
        publicId: sourceId,
        documentPublicId: documentPublicId,
        text: chunk.text,
        pageNumber: chunk.pageNumber,
        sectionTitle: chunk.sectionTitle,
      ),
      ChunkEmbeddingEntity(
        sourceId: sourceId,
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: embedding,
        model: embeddingModel,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  @override
  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  ) async {
    _chunkBox.put(chunk);
    _embeddingBox.put(embedding);
  }

  @override
  Future<bool> hasReadyDocuments() async {
    final query = _documentBox
        .query(
          KnowledgeDocumentEntity_.processingState.equals(
            ProcessingState.ready.wireName,
          ),
        )
        .build();
    try {
      return query.count() > 0;
    } finally {
      query.close();
    }
  }

  KnowledgeDocumentEntity? _findDocument(String publicId) {
    final query = _documentBox
        .query(KnowledgeDocumentEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  KnowledgeFolderEntity? _findFolder(String publicId) {
    final query = _folderBox
        .query(KnowledgeFolderEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }
}
