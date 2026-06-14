import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../ai/ai_client.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import '../../flowchart/models/editable_flowchart.dart';
import '../models/chunk_package.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';
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
      _documentPageBox = store.box<DocumentPageEntity>(),
      _auditItemBox = store.box<ExtractionAuditItemEntity>(),
      _knowledgeNodeBox = store.box<KnowledgeNodeEntity>(),
      _knowledgeEdgeBox = store.box<KnowledgeEdgeEntity>(),
      _knowledgeEvidenceBox = store.box<KnowledgeEvidenceEntity>(),
      _visualObjectBox = store.box<VisualObjectEntity>(),
      _visualAttributeBox = store.box<VisualAttributeEntity>(),
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
  final Box<DocumentPageEntity> _documentPageBox;
  final Box<ExtractionAuditItemEntity> _auditItemBox;
  final Box<KnowledgeNodeEntity> _knowledgeNodeBox;
  final Box<KnowledgeEdgeEntity> _knowledgeEdgeBox;
  final Box<KnowledgeEvidenceEntity> _knowledgeEvidenceBox;
  final Box<VisualObjectEntity> _visualObjectBox;
  final Box<VisualAttributeEntity> _visualAttributeBox;
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
        _clearGeneratedKnowledgeForDocument(document.publicId, includeLocal: true);
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
        pipeline: LocalExtractionPipeline.ai.wireName,
        chunkKind: _localKindForSourceType(sourceType).wireName,
        auditState: LocalAuditState.accepted.wireName,
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
            shape: node.shape.wireName,
            sortOrder: node.order,
            sourceRectJson: _sourceRectJson(node.sourceRect),
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
            sortOrder: edge.order,
            sourceRectJson: _sourceRectJson(edge.sourceRect),
          ),
        );
      }
    });
  }

  Future<EditableFlowchart?> loadEditableFlowchart({
    required String documentId,
    required String flowchartId,
  }) async {
    final flowchartPublicId = flowchartId.startsWith('$documentId:')
        ? flowchartId
        : '$documentId:$flowchartId';
    FlowchartEntity? flowchart;
    for (final item in _flowchartsForDocument(documentId)) {
      if (item.publicId == flowchartPublicId) {
        flowchart = item;
        break;
      }
    }
    if (flowchart == null) {
      return null;
    }
    final nodes = _flowchartNodeBox
        .getAll()
        .where((node) => node.flowchartPublicId == flowchartPublicId)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final edges = _flowchartEdgeBox
        .getAll()
        .where((edge) => edge.flowchartPublicId == flowchartPublicId)
        .toList(growable: false)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return EditableFlowchart(
      id: flowchart.publicId,
      documentId: documentId,
      pageNumber: flowchart.pageNumber,
      nodes: [
        for (final node in nodes)
          EditableFlowchartNode(
            id: node.publicId,
            label: node.label,
            shape: AiFlowchartNodeShape.fromWireName(node.shape),
            order: node.sortOrder,
          ),
      ],
      edges: [
        for (final edge in edges)
          EditableFlowchartEdge(
            id: edge.publicId,
            fromNodeId: edge.fromNodePublicId,
            toNodeId: edge.toNodePublicId,
            label: edge.label,
            order: edge.sortOrder,
          ),
      ],
    );
  }

  Future<void> saveEditableFlowchart(EditableFlowchart flowchart) async {
    _store.runInTransaction(TxMode.write, () {
      _removeFlowchart(flowchart.id);
      _flowchartBox.put(
        FlowchartEntity(
          publicId: flowchart.id,
          documentPublicId: flowchart.documentId,
          pageNumber: flowchart.pageNumber,
          validationState: ValidationState.unreviewed.wireName,
        ),
      );
      for (final node in flowchart.nodes) {
        _flowchartNodeBox.put(
          FlowchartNodeEntity(
            publicId: node.id,
            flowchartPublicId: flowchart.id,
            label: node.label,
            validationState: ValidationState.unreviewed.wireName,
            shape: node.shape.wireName,
            sortOrder: node.order,
          ),
        );
      }
      for (final edge in flowchart.edges) {
        _flowchartEdgeBox.put(
          FlowchartEdgeEntity(
            publicId: edge.id,
            flowchartPublicId: flowchart.id,
            fromNodePublicId: edge.fromNodeId,
            toNodePublicId: edge.toNodeId,
            label: edge.label,
            validationState: ValidationState.unreviewed.wireName,
            sortOrder: edge.order,
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
    String documentPublicId, {
    LocalExtractionPipeline? pipeline,
  }) async {
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
        _itemFromChunk(documentPublicId, chunk, embeddings[chunk.publicId]),
      for (final flowchart in _flowchartsForDocument(documentPublicId))
        ..._flowchartItems(documentPublicId, flowchart, allEmbeddings),
    ];
    final filtered = pipeline == null
        ? items
        : items.where((item) => item.pipeline == pipeline).toList();
    filtered.sort(_compareExtractedItems);
    return List.unmodifiable(filtered);
  }

  Future<void> saveLocalChunks(
    String documentPublicId,
    List<LocalChunk> chunks, {
    bool replaceExisting = true,
  }) async {
    _store.runInTransaction(TxMode.write, () {
      if (replaceExisting) {
        _clearLocalKnowledgeForDocument(documentPublicId);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      final sectionNodeIds = <String, String>{};
      String? previousNodeId;
      for (final chunk in chunks) {
        final sourceId = '$documentPublicId:${chunk.id}';
        final nodeId = '$sourceId:node';
        _chunkBox.put(
          DocumentChunkEntity(
            publicId: sourceId,
            documentPublicId: documentPublicId,
            text: chunk.text,
            pageNumber: chunk.pageNumber,
            sectionTitle: chunk.sectionTitle,
            sourceRectJson: chunk.sourceRectJson,
            pipeline: chunk.pipeline.wireName,
            chunkKind: chunk.kind.wireName,
            auditState: chunk.auditState.wireName,
            endPageNumber: chunk.endPageNumber,
            confidence: chunk.confidence,
            sourcePageImagePath: chunk.sourcePageImagePath,
          ),
        );
        _auditItemBox.put(
          ExtractionAuditItemEntity(
            publicId: '$sourceId:audit',
            documentPublicId: documentPublicId,
            sourceId: sourceId,
            itemKind: chunk.kind.wireName,
            auditState: chunk.auditState.wireName,
            pageNumber: chunk.pageNumber,
            title: chunk.sectionTitle,
            previewText: chunk.text,
            createdAtMillis: now,
            updatedAtMillis: now,
          ),
        );
        _putKnowledgeNode(
          KnowledgeNodeEntity(
            publicId: nodeId,
            documentPublicId: documentPublicId,
            label: chunk.sectionTitle ?? _shortNodeLabel(chunk.text),
            nodeType: chunk.kind.wireName,
            pageNumber: chunk.pageNumber,
            sourceId: sourceId,
          ),
        );
        _knowledgeEvidenceBox.put(
          KnowledgeEvidenceEntity(
            publicId: '$sourceId:evidence',
            documentPublicId: documentPublicId,
            nodePublicId: nodeId,
            sourceId: sourceId,
            pipeline: chunk.pipeline.wireName,
            pageNumber: chunk.pageNumber,
            quote: chunk.text,
          ),
        );
        final sectionTitle = chunk.sectionTitle?.trim();
        if (sectionTitle != null && sectionTitle.isNotEmpty) {
          final sectionKey = _graphKey(sectionTitle);
          final sectionNodeId = sectionNodeIds.putIfAbsent(
            sectionKey,
            () => '$documentPublicId:section:$sectionKey',
          );
          _putKnowledgeNode(
            KnowledgeNodeEntity(
              publicId: sectionNodeId,
              documentPublicId: documentPublicId,
              label: sectionTitle,
              nodeType: 'section',
              pageNumber: chunk.pageNumber,
            ),
          );
          _knowledgeEdgeBox.put(
            KnowledgeEdgeEntity(
              publicId: '$nodeId:part_of:$sectionNodeId',
              documentPublicId: documentPublicId,
              fromNodePublicId: nodeId,
              toNodePublicId: sectionNodeId,
              relationType: 'part_of',
              sourceId: sourceId,
              weight: 1,
            ),
          );
        }
        if (previousNodeId != null) {
          _knowledgeEdgeBox.put(
            KnowledgeEdgeEntity(
              publicId: '$previousNodeId:continues:$nodeId',
              documentPublicId: documentPublicId,
              fromNodePublicId: previousNodeId,
              toNodePublicId: nodeId,
              relationType: 'continues',
              sourceId: sourceId,
              weight: 0.75,
            ),
          );
        }
        previousNodeId = nodeId;
      }
    });
  }

  Future<void> updateExtractedKnowledgeAuditState(
    String documentPublicId,
    String itemId,
    LocalAuditState auditState, {
    String? text,
    String? reason,
  }) async {
    final sourceId = itemId.startsWith('$documentPublicId:')
        ? itemId
        : '$documentPublicId:$itemId';
    _store.runInTransaction(TxMode.write, () {
      final chunk = _findChunk(sourceId);
      if (chunk != null) {
        chunk.auditState = auditState.wireName;
        if (text != null) {
          chunk.text = text;
        }
        _chunkBox.put(chunk);
        for (final auditItem in _auditItemBox.getAll()) {
          if (auditItem.sourceId == sourceId) {
            auditItem.auditState = auditState.wireName;
            auditItem.previewText = text ?? auditItem.previewText;
            auditItem.reason = reason;
            auditItem.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
            _auditItemBox.put(auditItem);
          }
        }
        return;
      }
      final validationState = _validationStateForAuditState(auditState);
      final node = _findNode(sourceId);
      if (node != null) {
        node.validationState = validationState.wireName;
        if (text != null) {
          node.label = text;
        }
        node.rejectionReason = reason;
        _flowchartNodeBox.put(node);
        return;
      }
      final edge = _findEdge(sourceId);
      if (edge != null) {
        edge.validationState = validationState.wireName;
        edge.rejectionReason = reason;
        _flowchartEdgeBox.put(edge);
      }
    });
  }

  Future<ChunkComparison> compareExtractedChunks(String documentPublicId) async {
    final aiItems = await listExtractedKnowledgeItems(
      documentPublicId,
      pipeline: LocalExtractionPipeline.ai,
    );
    final localItems = (await listExtractedKnowledgeItems(documentPublicId))
        .where((item) => _isGeneratedLocalPipeline(item.pipeline))
        .toList(growable: false);
    return ChunkComparison(
      rows: _compareChunkLists(aiItems: aiItems, localItems: localItems),
    );
  }

  @override
  Future<ChunkPackage> exportChunkPackage(String documentPublicId) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    final chunks = _aiChunksForDocument(documentPublicId);
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
            pipeline: LocalExtractionPipeline.ai.wireName,
            chunkKind: LocalChunkKind.text.wireName,
            auditState: LocalAuditState.accepted.wireName,
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

  DocumentChunkEntity? _findChunk(String publicId) {
    final query = _chunkBox
        .query(DocumentChunkEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  FlowchartNodeEntity? _findNode(String publicId) {
    final query = _flowchartNodeBox
        .query(FlowchartNodeEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  FlowchartEdgeEntity? _findEdge(String publicId) {
    final query = _flowchartEdgeBox
        .query(FlowchartEdgeEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  KnowledgeNodeEntity? _findKnowledgeNode(String publicId) {
    final query = _knowledgeNodeBox
        .query(KnowledgeNodeEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  void _putKnowledgeNode(KnowledgeNodeEntity node) {
    final existing = _findKnowledgeNode(node.publicId);
    if (existing != null) {
      node.id = existing.id;
    }
    _knowledgeNodeBox.put(node);
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

  List<DocumentChunkEntity> _aiChunksForDocument(String documentPublicId) {
    return _chunksForDocument(documentPublicId)
        .where((chunk) => chunk.pipeline == LocalExtractionPipeline.ai.wireName)
        .toList(growable: false);
  }

  void _clearLocalKnowledgeForDocument(String documentPublicId) {
    final localChunks = _chunksForDocument(documentPublicId)
        .where((chunk) => _isGeneratedLocalPipelineName(chunk.pipeline))
        .toList(growable: false);
    final sourceIds = localChunks.map((chunk) => chunk.publicId).toSet();
    final embeddingIds = _embeddingBox
        .getAll()
        .where((embedding) => sourceIds.contains(embedding.sourceId))
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
    }
    if (localChunks.isNotEmpty) {
      _chunkBox.removeMany(localChunks.map((chunk) => chunk.id).toList());
    }
    _removeLocalGraphRowsForSources(documentPublicId, sourceIds);
    final visualObjectIds = _visualObjectBox
        .getAll()
        .where((object) => object.documentPublicId == documentPublicId)
        .map((object) => object.publicId)
        .toSet();
    final visualAttributes = _visualAttributeBox
        .getAll()
        .where(
          (attribute) =>
              visualObjectIds.contains(attribute.visualObjectPublicId),
        )
        .map((attribute) => attribute.id)
        .toList(growable: false);
    if (visualAttributes.isNotEmpty) {
      _visualAttributeBox.removeMany(visualAttributes);
    }
    _removeDocumentRows(_documentPageBox, documentPublicId);
    _removeDocumentRows(_visualObjectBox, documentPublicId);
  }

  void _clearGeneratedKnowledgeForDocument(
    String documentPublicId, {
    bool includeLocal = false,
  }) {
    final chunks = includeLocal
        ? _chunksForDocument(documentPublicId)
        : _aiChunksForDocument(documentPublicId);
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
    if (includeLocal) {
      final visualObjectIds = _visualObjectBox
          .getAll()
          .where((object) => object.documentPublicId == documentPublicId)
          .map((object) => object.publicId)
          .toSet();
      final visualAttributes = _visualAttributeBox
          .getAll()
          .where(
            (attribute) =>
                visualObjectIds.contains(attribute.visualObjectPublicId),
          )
          .map((attribute) => attribute.id)
          .toList(growable: false);
      if (visualAttributes.isNotEmpty) {
        _visualAttributeBox.removeMany(visualAttributes);
      }
      _removeDocumentRows(_documentPageBox, documentPublicId);
      _removeDocumentRows(_auditItemBox, documentPublicId);
      _removeDocumentRows(_knowledgeNodeBox, documentPublicId);
      _removeDocumentRows(_knowledgeEdgeBox, documentPublicId);
      _removeDocumentRows(_knowledgeEvidenceBox, documentPublicId);
      _removeDocumentRows(_visualObjectBox, documentPublicId);
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


  ExtractedKnowledgeItem _itemFromChunk(
    String documentPublicId,
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity? embedding,
  ) {
    final pipeline = LocalExtractionPipeline.fromWireName(chunk.pipeline);
    return ExtractedKnowledgeItem(
      id: _packageChunkId(documentPublicId, chunk.publicId),
      documentId: documentPublicId,
      sourceType: pipeline == LocalExtractionPipeline.ai
          ? evidenceSourceTypeFromWireName(
              embedding?.sourceType ?? EvidenceSourceType.textChunk.wireName,
            )
          : _sourceTypeForLocalKind(LocalChunkKind.fromWireName(chunk.chunkKind)),
      text: chunk.text,
      pageNumber: chunk.pageNumber,
      sectionTitle: chunk.sectionTitle,
      embeddingModel: embedding?.model,
      sourceRectJson: chunk.sourceRectJson,
      pipeline: pipeline,
      chunkKind: LocalChunkKind.fromWireName(chunk.chunkKind),
      auditState: LocalAuditState.fromWireName(chunk.auditState),
      endPageNumber: chunk.endPageNumber,
      confidence: chunk.confidence,
      sourcePageImagePath: chunk.sourcePageImagePath,
    );
  }

  EvidenceSourceType _sourceTypeForLocalKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.table => EvidenceSourceType.tableChunk,
      LocalChunkKind.score => EvidenceSourceType.scoreChunk,
      LocalChunkKind.flowchart => EvidenceSourceType.flowchartNode,
      LocalChunkKind.text ||
      LocalChunkKind.list ||
      LocalChunkKind.imageRegion ||
      LocalChunkKind.visualFact ||
      LocalChunkKind.unknown => EvidenceSourceType.textChunk,
    };
  }

  LocalChunkKind _localKindForSourceType(String sourceType) {
    if (sourceType == EvidenceSourceType.tableChunk.wireName) {
      return LocalChunkKind.table;
    }
    if (sourceType == EvidenceSourceType.scoreChunk.wireName) {
      return LocalChunkKind.score;
    }
    if (sourceType == EvidenceSourceType.flowchartNode.wireName ||
        sourceType == EvidenceSourceType.flowchartEdge.wireName) {
      return LocalChunkKind.flowchart;
    }
    return LocalChunkKind.text;
  }

  List<ChunkComparisonRow> _compareChunkLists({
    required List<ExtractedKnowledgeItem> aiItems,
    required List<ExtractedKnowledgeItem> localItems,
  }) {
    final rows = <ChunkComparisonRow>[];
    final localByKey = <String, List<ExtractedKnowledgeItem>>{};
    for (final local in localItems) {
      localByKey.putIfAbsent(_comparisonKey(local), () => []).add(local);
    }
    final matchedLocalIds = <String>{};
    for (final ai in aiItems) {
      ExtractedKnowledgeItem? local;
      final candidates =
          localByKey[_comparisonKey(ai)] ?? const <ExtractedKnowledgeItem>[];
      for (final candidate in candidates) {
        if (!matchedLocalIds.contains(candidate.id)) {
          local = candidate;
          break;
        }
      }
      if (local == null) {
        rows.add(
          ChunkComparisonRow(
            status: ChunkComparisonStatus.aiOnly,
            aiChunk: ai,
          ),
        );
        continue;
      }
      matchedLocalIds.add(local.id);
      rows.add(
        ChunkComparisonRow(
          status: ChunkComparisonStatus.matched,
          aiChunk: ai,
          localChunk: local,
        ),
      );
    }
    for (final local in localItems) {
      if (matchedLocalIds.contains(local.id)) {
        continue;
      }
      rows.add(
        ChunkComparisonRow(
          status: ChunkComparisonStatus.localOnly,
          localChunk: local,
        ),
      );
    }
    rows.sort((a, b) {
      final page = (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
      if (page != 0) {
        return page;
      }
      return a.sectionTitle.compareTo(b.sectionTitle);
    });
    return rows;
  }

  String _comparisonKey(ExtractedKnowledgeItem item) {
    final section = (item.sectionTitle ?? '').trim().toLowerCase();
    if (section.isNotEmpty) {
      return '${item.pageNumber ?? 0}:$section';
    }
    return '${item.pageNumber ?? 0}:${item.sourceType.wireName}';
  }

  String _graphKey(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'section' : normalized;
  }

  String _shortNodeLabel(String text) {
    final singleLine = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 72) {
      return singleLine;
    }
    return '${singleLine.substring(0, 69)}...';
  }

  void _removeDocumentRows<T extends Object>(
    Box<T> box,
    String documentPublicId,
  ) {
    final ids = box
        .getAll()
        .where((entity) => switch (entity) {
              DocumentPageEntity item => item.documentPublicId == documentPublicId,
              ExtractionAuditItemEntity item => item.documentPublicId == documentPublicId,
              KnowledgeNodeEntity item => item.documentPublicId == documentPublicId,
              KnowledgeEdgeEntity item => item.documentPublicId == documentPublicId,
              KnowledgeEvidenceEntity item => item.documentPublicId == documentPublicId,
              VisualObjectEntity item => item.documentPublicId == documentPublicId,
              _ => false,
            })
        .map((entity) => switch (entity) {
              DocumentPageEntity item => item.id,
              ExtractionAuditItemEntity item => item.id,
              KnowledgeNodeEntity item => item.id,
              KnowledgeEdgeEntity item => item.id,
              KnowledgeEvidenceEntity item => item.id,
              VisualObjectEntity item => item.id,
              _ => 0,
            })
        .where((id) => id > 0)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      box.removeMany(ids);
    }
  }

  void _removeLocalGraphRowsForSources(
    String documentPublicId,
    Set<String> sourceIds,
  ) {
    if (sourceIds.isEmpty) {
      return;
    }
    final auditIds = _auditItemBox
        .getAll()
        .where(
          (item) =>
              item.documentPublicId == documentPublicId &&
              sourceIds.contains(item.sourceId),
        )
        .map((item) => item.id)
        .toList(growable: false);
    if (auditIds.isNotEmpty) {
      _auditItemBox.removeMany(auditIds);
    }
    final nodeIds = _knowledgeNodeBox
        .getAll()
        .where(
          (node) =>
              node.documentPublicId == documentPublicId &&
              node.sourceId != null &&
              sourceIds.contains(node.sourceId),
        )
        .map((node) => node.publicId)
        .toSet();
    final nodeRowIds = _knowledgeNodeBox
        .getAll()
        .where((node) => nodeIds.contains(node.publicId))
        .map((node) => node.id)
        .toList(growable: false);
    if (nodeRowIds.isNotEmpty) {
      _knowledgeNodeBox.removeMany(nodeRowIds);
    }
    final evidenceIds = _knowledgeEvidenceBox
        .getAll()
        .where(
          (evidence) =>
              evidence.documentPublicId == documentPublicId &&
              sourceIds.contains(evidence.sourceId),
        )
        .map((evidence) => evidence.id)
        .toList(growable: false);
    if (evidenceIds.isNotEmpty) {
      _knowledgeEvidenceBox.removeMany(evidenceIds);
    }
    final edgeIds = _knowledgeEdgeBox
        .getAll()
        .where(
          (edge) =>
              edge.documentPublicId == documentPublicId &&
              (sourceIds.contains(edge.sourceId) ||
                  nodeIds.contains(edge.fromNodePublicId) ||
                  nodeIds.contains(edge.toNodePublicId)),
        )
        .map((edge) => edge.id)
        .toList(growable: false);
    if (edgeIds.isNotEmpty) {
      _knowledgeEdgeBox.removeMany(edgeIds);
    }
  }

  bool _isGeneratedLocalPipeline(LocalExtractionPipeline pipeline) {
    return pipeline != LocalExtractionPipeline.ai &&
        pipeline != LocalExtractionPipeline.manual;
  }

  bool _isGeneratedLocalPipelineName(String pipeline) {
    return pipeline != LocalExtractionPipeline.ai.wireName &&
        pipeline != LocalExtractionPipeline.manual.wireName;
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
          flowchartId: flowchart.publicId,
          flowchartElementId: node.publicId,
          flowchartShape: node.shape,
          flowchartOrder: node.sortOrder,
          sourceRectJson: node.sourceRectJson,
          pipeline: LocalExtractionPipeline.ai,
          chunkKind: LocalChunkKind.flowchart,
          auditState: _auditStateForValidationState(node.validationState),
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
          flowchartId: flowchart.publicId,
          flowchartElementId: edge.publicId,
          flowchartFromId: edge.fromNodePublicId,
          flowchartToId: edge.toNodePublicId,
          flowchartEdgeLabel: edge.label,
          flowchartOrder: edge.sortOrder,
          sourceRectJson: edge.sourceRectJson,
          pipeline: LocalExtractionPipeline.ai,
          chunkKind: LocalChunkKind.flowchart,
          auditState: _auditStateForValidationState(edge.validationState),
        ),
    ];
  }

  String? _sourceRectJson(Map<String, Object?>? sourceRect) {
    if (sourceRect == null) {
      return null;
    }
    return jsonEncode(sourceRect);
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

  LocalAuditState _auditStateForValidationState(String value) {
    return switch (value) {
      'validated' || 'partially_validated' => LocalAuditState.accepted,
      'rejected' => LocalAuditState.rejected,
      _ => LocalAuditState.unreviewed,
    };
  }

  ValidationState _validationStateForAuditState(LocalAuditState state) {
    return switch (state) {
      LocalAuditState.accepted || LocalAuditState.edited => ValidationState.validated,
      LocalAuditState.rejected => ValidationState.rejected,
      LocalAuditState.unreviewed => ValidationState.unreviewed,
    };
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
