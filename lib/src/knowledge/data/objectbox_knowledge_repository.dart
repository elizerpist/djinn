import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../ai/ai_client.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import '../models/chunk_package.dart';
import '../models/extracted_knowledge_item.dart';
import 'chunk_package_service.dart';
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

  Future<void> deleteDocuments(List<String> documentIds);

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

  Future<ChunkPackage> exportChunkPackage(String documentPublicId);

  Future<void> importChunkPackage(
    String documentPublicId,
    ChunkPackage package,
  );

  Future<bool> hasReadyDocuments();
}

class ObjectBoxKnowledgeRepository
    implements KnowledgeRepository, ProcessingRepository {
  ObjectBoxKnowledgeRepository({required Store store, Uuid? uuid})
    : _store = store,
      _documentBox = store.box<KnowledgeDocumentEntity>(),
      _folderBox = store.box<KnowledgeFolderEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _flowchartBox = store.box<FlowchartEntity>(),
      _flowchartNodeBox = store.box<FlowchartNodeEntity>(),
      _flowchartEdgeBox = store.box<FlowchartEdgeEntity>(),
      _uuid = uuid ?? const Uuid();

  static const _vectorEmbeddingDimension = 3072;
  static const _generatedEmbeddingSourceTypes = {
    'text_chunk',
    'table_chunk',
    'score_chunk',
  };

  final Store _store;
  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<KnowledgeFolderEntity> _folderBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _flowchartNodeBox;
  final Box<FlowchartEdgeEntity> _flowchartEdgeBox;
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
  Future<void> deleteDocuments(List<String> documentIds) async {
    final documents = documentIds
        .map(_findDocument)
        .whereType<KnowledgeDocumentEntity>()
        .toList(growable: false);
    _store.runInTransaction(TxMode.write, () {
      for (final document in documents) {
        _clearGeneratedKnowledgeForDocument(document.publicId);
        _documentBox.remove(document.id);
      }
    });
    for (final document in documents) {
      await _deleteLocalFileIfPresent(document.localPath);
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
    _store.runInTransaction(TxMode.write, () {
      _clearGeneratedKnowledgeForDocument(documentPublicId);
    });
  }

  @override
  Future<void> saveExtractedEvidence({
    required String documentPublicId,
    required AiExtractedEvidence evidence,
    required List<double> embedding,
    required String embeddingModel,
  }) async {
    final sourceId = '$documentPublicId:${evidence.id}';
    final sourceType = _evidenceSourceTypeWireName(evidence.sourceType);
    final embeddingEntity = ChunkEmbeddingEntity(
      sourceId: sourceId,
      sourceType: sourceType,
      vector: embedding,
      model: embeddingModel,
      createdAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    if (_isFlowchartSourceType(sourceType)) {
      _embeddingBox.put(embeddingEntity);
      return;
    }
    await saveChunk(
      DocumentChunkEntity(
        publicId: sourceId,
        documentPublicId: documentPublicId,
        text: evidence.text,
        pageNumber: evidence.pageNumber,
        sectionTitle: evidence.sectionTitle,
      ),
      embeddingEntity,
    );
  }

  @override
  Future<void> saveFlowchartCandidate({
    required String documentPublicId,
    required AiFlowchartCandidate flowchart,
  }) async {
    final flowchartPublicId = '$documentPublicId:${flowchart.id}';
    _store.runInTransaction(TxMode.write, () {
      _removeFlowchart(flowchartPublicId);
      _flowchartBox.put(
        FlowchartEntity(
          publicId: flowchartPublicId,
          documentPublicId: documentPublicId,
          pageNumber: flowchart.pageNumber,
          validationState: ValidationState.unreviewed.wireName,
          extractionConfidence: flowchart.confidence,
        ),
      );
      for (final node in flowchart.nodes) {
        _flowchartNodeBox.put(
          FlowchartNodeEntity(
            publicId: '$flowchartPublicId:${node.id}',
            flowchartPublicId: flowchartPublicId,
            label: node.label,
            validationState: ValidationState.unreviewed.wireName,
          ),
        );
      }
      for (final edge in flowchart.edges) {
        _flowchartEdgeBox.put(
          FlowchartEdgeEntity(
            publicId: '$flowchartPublicId:${edge.id}',
            flowchartPublicId: flowchartPublicId,
            fromNodePublicId: '$flowchartPublicId:${edge.fromNodeId}',
            toNodePublicId: '$flowchartPublicId:${edge.toNodeId}',
            label: edge.label,
            validationState: ValidationState.unreviewed.wireName,
          ),
        );
      }
    });
  }

  @override
  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  ) async {
    _chunkBox.put(chunk);
    _embeddingBox.put(embedding);
  }

  Future<List<ExtractedKnowledgeItem>> listExtractedKnowledgeItems(
    String documentPublicId,
  ) async {
    final allEmbeddings = {
      for (final embedding in _embeddingBox.getAll())
        embedding.sourceId: embedding,
    };
    final embeddings = {
      for (final embedding in allEmbeddings.values)
        if (_generatedEmbeddingSourceTypes.contains(embedding.sourceType))
          embedding.sourceId: embedding,
    };
    final items = <ExtractedKnowledgeItem>[
      for (final chunk in _chunksForDocument(documentPublicId))
        ExtractedKnowledgeItem(
          id: _packageChunkId(documentPublicId, chunk.publicId),
          documentId: documentPublicId,
          sourceType: evidenceSourceTypeFromWireName(
            embeddings[chunk.publicId]?.sourceType ??
                EvidenceSourceType.textChunk.wireName,
          ),
          text: chunk.text,
          pageNumber: chunk.pageNumber,
          sectionTitle: chunk.sectionTitle,
          embeddingModel: embeddings[chunk.publicId]?.model,
        ),
      for (final flowchart in _flowchartsForDocument(documentPublicId))
        ..._flowchartItems(documentPublicId, flowchart, allEmbeddings),
    ];
    items.sort(_compareExtractedItems);
    return List.unmodifiable(items);
  }

  @override
  Future<ChunkPackage> exportChunkPackage(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    final chunks = _chunksForDocument(documentPublicId);
    final embeddings = {
      for (final embedding in _embeddingBox.getAll())
        if (_generatedEmbeddingSourceTypes.contains(embedding.sourceType))
          embedding.sourceId: embedding,
    };
    final items = <ChunkPackageItem>[];
    String? embeddingModel;
    for (final chunk in chunks) {
      final embedding = embeddings[chunk.publicId];
      embeddingModel ??= embedding?.model;
      items.add(
        ChunkPackageItem(
          id: _packageChunkId(documentPublicId, chunk.publicId),
          text: chunk.text,
          pageNumber: chunk.pageNumber,
          sectionTitle: chunk.sectionTitle,
          embedding: embedding?.vector ?? const [],
        ),
      );
    }
    final embeddingDimension = _firstEmbeddingDimension(items);
    return ChunkPackage(
      schemaVersion: 1,
      documentHash: document.sha256 ?? '',
      filename: document.filename,
      provider: document.activeProvider ?? '',
      extractionModel: document.activeModel ?? '',
      embeddingModel: embeddingModel ?? '',
      embeddingDimension: embeddingDimension,
      chunks: items,
    );
  }

  @override
  Future<void> importChunkPackage(
    String documentPublicId,
    ChunkPackage package,
  ) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    const service = ChunkPackageService();
    service.validateForImport(
      package,
      documentHash: document.sha256 ?? '',
      expectedDimension: _vectorEmbeddingDimension,
    );
    _store.runInTransaction(TxMode.write, () {
      _clearGeneratedKnowledgeForDocument(documentPublicId);
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final item in package.chunks) {
        final sourceId = '$documentPublicId:${item.id}';
        _chunkBox.put(
          DocumentChunkEntity(
            publicId: sourceId,
            documentPublicId: documentPublicId,
            text: item.text,
            pageNumber: item.pageNumber,
            sectionTitle: item.sectionTitle,
          ),
        );
        _embeddingBox.put(
          ChunkEmbeddingEntity(
            sourceId: sourceId,
            sourceType: EvidenceSourceType.textChunk.wireName,
            vector: item.embedding,
            model: package.embeddingModel,
            createdAtMillis: now,
          ),
        );
      }
      document.processingState = ProcessingState.ready.wireName;
      document.errorMessage = null;
      document.activeProvider = package.provider.isEmpty
          ? null
          : package.provider;
      document.activeModel = package.extractionModel.isEmpty
          ? null
          : package.extractionModel;
      document.lastErrorCode = null;
      document.retryable = false;
      _documentBox.put(document);
    });
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

  List<DocumentChunkEntity> _chunksForDocument(String documentPublicId) {
    final query = _chunkBox
        .query(DocumentChunkEntity_.documentPublicId.equals(documentPublicId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  void _clearGeneratedKnowledgeForDocument(String documentPublicId) {
    final chunks = _chunksForDocument(documentPublicId);
    final sourceIds = chunks.map((chunk) => chunk.publicId).toSet();
    final embeddingIds = _embeddingBox
        .getAll()
        .where(
          (embedding) =>
              _generatedEmbeddingSourceTypes.contains(embedding.sourceType) &&
              sourceIds.contains(embedding.sourceId),
        )
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
    }
    if (chunks.isNotEmpty) {
      _chunkBox.removeMany(chunks.map((chunk) => chunk.id).toList());
    }

    final flowcharts = _flowchartsForDocument(documentPublicId);
    for (final flowchart in flowcharts) {
      _removeFlowchart(flowchart.publicId);
    }
  }

  List<FlowchartEntity> _flowchartsForDocument(String documentPublicId) {
    final query = _flowchartBox
        .query(FlowchartEntity_.documentPublicId.equals(documentPublicId))
        .build();
    try {
      return query.find();
    } finally {
      query.close();
    }
  }

  void _removeFlowchart(String flowchartPublicId) {
    final nodes = _flowchartNodeBox
        .getAll()
        .where((node) => node.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
    final edges = _flowchartEdgeBox
        .getAll()
        .where((edge) => edge.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
    final flowcharts = _flowchartBox
        .getAll()
        .where((flowchart) => flowchart.publicId == flowchartPublicId)
        .toList(growable: false);
    final flowchartSourceIds = {
      ...nodes.map((node) => node.publicId),
      ...edges.map((edge) => edge.publicId),
    };
    final embeddingIds = _embeddingBox
        .getAll()
        .where(
          (embedding) =>
              flowchartSourceIds.contains(embedding.sourceId) &&
              (embedding.sourceType ==
                      EvidenceSourceType.flowchartNode.wireName ||
                  embedding.sourceType ==
                      EvidenceSourceType.flowchartEdge.wireName),
        )
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
    }
    if (nodes.isNotEmpty) {
      _flowchartNodeBox.removeMany(nodes.map((node) => node.id).toList());
    }
    if (edges.isNotEmpty) {
      _flowchartEdgeBox.removeMany(edges.map((edge) => edge.id).toList());
    }
    if (flowcharts.isNotEmpty) {
      _flowchartBox.removeMany(
        flowcharts.map((flowchart) => flowchart.id).toList(),
      );
    }
  }

  int _compareExtractedItems(
    ExtractedKnowledgeItem a,
    ExtractedKnowledgeItem b,
  ) {
    final page = (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
    if (page != 0) {
      return page;
    }
    final type = a.sourceType.index.compareTo(b.sourceType.index);
    if (type != 0) {
      return type;
    }
    return a.id.compareTo(b.id);
  }

  List<ExtractedKnowledgeItem> _flowchartItems(
    String documentPublicId,
    FlowchartEntity flowchart,
    Map<String, ChunkEmbeddingEntity> embeddings,
  ) {
    final nodes =
        _flowchartNodeBox
            .getAll()
            .where((node) => node.flowchartPublicId == flowchart.publicId)
            .toList(growable: false)
          ..sort((a, b) => a.publicId.compareTo(b.publicId));
    final edges =
        _flowchartEdgeBox
            .getAll()
            .where((edge) => edge.flowchartPublicId == flowchart.publicId)
            .toList(growable: false)
          ..sort((a, b) => a.publicId.compareTo(b.publicId));
    final nodeLabels = {for (final node in nodes) node.publicId: node.label};
    return [
      for (final node in nodes)
        ExtractedKnowledgeItem(
          id: _packageChunkId(documentPublicId, node.publicId),
          documentId: documentPublicId,
          sourceType: EvidenceSourceType.flowchartNode,
          text: node.label,
          pageNumber: flowchart.pageNumber,
          sectionTitle: 'Flowchart lépés',
          embeddingModel: embeddings[node.publicId]?.model,
        ),
      for (final edge in edges)
        ExtractedKnowledgeItem(
          id: _packageChunkId(documentPublicId, edge.publicId),
          documentId: documentPublicId,
          sourceType: EvidenceSourceType.flowchartEdge,
          text: _edgeRelation(edge, nodeLabels),
          pageNumber: flowchart.pageNumber,
          sectionTitle: 'Flowchart kapcsolat',
          embeddingModel: embeddings[edge.publicId]?.model,
        ),
    ];
  }

  String _edgeRelation(
    FlowchartEdgeEntity edge,
    Map<String, String> nodeLabels,
  ) {
    final from = nodeLabels[edge.fromNodePublicId] ?? edge.fromNodePublicId;
    final to = nodeLabels[edge.toNodePublicId] ?? edge.toNodePublicId;
    final label = edge.label.trim();
    return label.isEmpty ? '$from -> $to' : '$from -> $to [$label]';
  }

  bool _isFlowchartSourceType(String sourceType) {
    return sourceType == EvidenceSourceType.flowchartNode.wireName ||
        sourceType == EvidenceSourceType.flowchartEdge.wireName;
  }

  String _evidenceSourceTypeWireName(AiEvidenceSourceType sourceType) {
    return switch (sourceType) {
      AiEvidenceSourceType.textChunk => EvidenceSourceType.textChunk.wireName,
      AiEvidenceSourceType.table => EvidenceSourceType.tableChunk.wireName,
      AiEvidenceSourceType.score => EvidenceSourceType.scoreChunk.wireName,
      AiEvidenceSourceType.flowchartNode =>
        EvidenceSourceType.flowchartNode.wireName,
      AiEvidenceSourceType.flowchartEdge =>
        EvidenceSourceType.flowchartEdge.wireName,
    };
  }

  String _packageChunkId(String documentPublicId, String publicId) {
    final prefix = '$documentPublicId:';
    if (publicId.startsWith(prefix)) {
      return publicId.substring(prefix.length);
    }
    return publicId;
  }

  int _firstEmbeddingDimension(List<ChunkPackageItem> items) {
    for (final item in items) {
      if (item.embedding.isNotEmpty) {
        return item.embedding.length;
      }
    }
    return 0;
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
      // A missing or SAF-owned file should not block database cleanup.
    }
  }
}
