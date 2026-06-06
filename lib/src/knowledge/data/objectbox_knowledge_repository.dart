import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';

abstract class KnowledgeRepository {
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
  });

  Future<List<KnowledgeDocumentEntity>> listDocuments();

  Future<void> updateProcessingState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
  });

  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  );

  Future<bool> hasReadyDocuments();
}

class ObjectBoxKnowledgeRepository implements KnowledgeRepository {
  ObjectBoxKnowledgeRepository({required Store store, Uuid? uuid})
    : _documentBox = store.box<KnowledgeDocumentEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _uuid = uuid ?? const Uuid();

  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Uuid _uuid;

  @override
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final document = KnowledgeDocumentEntity(
      publicId: _uuid.v4(),
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAtMillis: now,
      processingState: ProcessingState.imported.wireName,
    );
    _documentBox.put(document);
    return document;
  }

  @override
  Future<List<KnowledgeDocumentEntity>> listDocuments() async {
    return _documentBox.getAll();
  }

  @override
  Future<void> updateProcessingState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
  }) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    document.processingState = state.wireName;
    document.errorMessage = errorMessage;
    _documentBox.put(document);
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
}
