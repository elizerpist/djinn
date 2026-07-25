import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../ai/ai_client.dart';
import '../../chunks/data/chunk_entity_codec.dart';
import '../../chunks/data/objectbox_chunk_derived_data.dart';
import '../../chunks/models/chunk.dart';
import '../../flowchart/data/objectbox_flowchart_projection.dart';
import '../../local_store/entities.dart';
import '../../notes/models/mixed_chunk_parser.dart';
import '../../notes/models/note_document.dart';
import '../../openai/openai_client.dart';
import '../../flowchart/models/editable_flowchart.dart';
import '../models/chunk_package.dart';
import '../models/extracted_knowledge_item.dart';
import '../models/local_extraction.dart';
import 'chunk_package_service.dart';
import 'document_processing_service.dart';

void synchronizeFlowchartParentDocumentRelation({
  required DocumentChunkEntity parent,
  required FlowchartEntity flowchart,
}) {
  parent.documentPublicId = flowchart.documentPublicId;
}

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
  ObjectBoxKnowledgeRepository({
    required Store store,
    Uuid? uuid,
    ChunkEntityCodec chunkCodec = const ChunkEntityCodec(),
  }) : _store = store,
       _documentBox = store.box<KnowledgeDocumentEntity>(),
       _folderBox = store.box<KnowledgeFolderEntity>(),
       _chunkBox = store.box<DocumentChunkEntity>(),
       _chunkNoteLinkBox = store.box<ChunkNoteLinkEntity>(),
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
       _uuid = uuid ?? const Uuid(),
       _chunkCodec = chunkCodec,
       _flowchartProjection = ObjectBoxFlowchartProjection(
         store: store,
         codec: chunkCodec,
       ),
       _chunkDerivedData = ObjectBoxChunkDerivedData(store: store) {
    _migrateUnifiedChunkRows();
  }

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
  final Box<ChunkNoteLinkEntity> _chunkNoteLinkBox;
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
  final ChunkEntityCodec _chunkCodec;
  final ObjectBoxFlowchartProjection _flowchartProjection;
  final ObjectBoxChunkDerivedData _chunkDerivedData;

  void _migrateUnifiedChunkRows() {
    final now = DateTime.now();
    _store.runInTransaction(TxMode.write, () {
      final changed = <DocumentChunkEntity>[];
      final canonicalKindBySource = <String, String>{};
      for (final chunk in _chunkBox.getAll()) {
        if (_chunkCodec.canonicalize(chunk, now: now)) {
          changed.add(chunk);
        }
        canonicalKindBySource[chunk.publicId] = chunk.chunkKind;
      }
      if (changed.isNotEmpty) {
        _chunkBox.putMany(changed);
      }
      final changedAuditItems = <ExtractionAuditItemEntity>[];
      for (final auditItem in _auditItemBox.getAll()) {
        final canonicalKind = canonicalKindBySource[auditItem.sourceId];
        if (canonicalKind != null && auditItem.itemKind != canonicalKind) {
          auditItem.itemKind = canonicalKind;
          auditItem.updatedAtMillis = now.millisecondsSinceEpoch;
          changedAuditItems.add(auditItem);
        }
      }
      if (changedAuditItems.isNotEmpty) {
        _auditItemBox.putMany(changedAuditItems);
      }
      final changedKnowledgeNodes = <KnowledgeNodeEntity>[];
      for (final node in _knowledgeNodeBox.getAll()) {
        final sourceId = node.sourceId;
        final canonicalKind = sourceId == null
            ? null
            : canonicalKindBySource[sourceId];
        if (canonicalKind != null &&
            node.publicId == '$sourceId:node' &&
            node.nodeType != canonicalKind) {
          node.nodeType = canonicalKind;
          changedKnowledgeNodes.add(node);
        }
      }
      if (changedKnowledgeNodes.isNotEmpty) {
        _knowledgeNodeBox.putMany(changedKnowledgeNodes);
      }
      for (final flowchart in _flowchartBox.getAll()) {
        final parent = _findChunk(flowchart.publicId);
        if (parent == null ||
            ChunkKind.fromWireName(parent.chunkKind) !=
                ChunkKind.flowchartChunk) {
          _upsertFlowchartParentChunk(
            flowchart,
            now: now,
            fallbackCreationMethod: ChunkCreationMethod.aiGenerated,
          );
        }
      }
      for (final chunk in _chunkBox.getAll()) {
        if (ChunkKind.fromWireName(chunk.chunkKind) ==
            ChunkKind.flowchartChunk) {
          _flowchartProjection.projectCanonicalChunk(chunk);
        }
      }
    });
  }

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
        _clearGeneratedKnowledgeForDocument(
          document.publicId,
          includeLocal: true,
        );
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
      final stored = _findFlowchart(flowchartPublicId);
      if (stored != null) {
        _upsertFlowchartParentChunk(
          stored,
          now: DateTime.now(),
          fallbackCreationMethod: ChunkCreationMethod.aiGenerated,
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
    final nodes =
        _flowchartNodeBox
            .getAll()
            .where((node) => node.flowchartPublicId == flowchartPublicId)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final edges =
        _flowchartEdgeBox
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
      final stored = _findFlowchart(flowchart.id);
      if (stored != null) {
        _upsertFlowchartParentChunk(
          stored,
          now: DateTime.now(),
          fallbackCreationMethod: ChunkCreationMethod.manualSelection,
        );
      }
    });
  }

  @override
  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  ) async {
    _chunkCodec.canonicalize(chunk, now: DateTime.now());
    _store.runInTransaction(TxMode.write, () {
      final existing = _findChunk(chunk.publicId);
      if (existing != null) {
        chunk.id = existing.id;
      }
      _removeEmbeddingsForSource(chunk.publicId);
      _chunkBox.put(chunk);
      _flowchartProjection.projectCanonicalChunk(chunk);
      _embeddingBox.put(embedding);
    });
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
    final chunks = _chunksForDocument(documentPublicId);
    final canonicalFlowchartIds = {
      for (final chunk in chunks)
        if (ChunkKind.fromWireName(chunk.chunkKind) == ChunkKind.flowchartChunk)
          chunk.publicId,
    };
    final items = <ExtractedKnowledgeItem>[
      for (final chunk in chunks)
        _itemFromChunk(documentPublicId, chunk, embeddings[chunk.publicId]),
      for (final flowchart in _flowchartsForDocument(documentPublicId))
        if (!canonicalFlowchartIds.contains(flowchart.publicId))
          _flowchartItem(documentPublicId, flowchart, allEmbeddings),
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
        // A replacement with the same stable source ID must never retain an
        // embedding for the previous text.
        _removeEmbeddingsForSource(sourceId);
        final nodeId = '$sourceId:node';
        final chunkEntity = DocumentChunkEntity(
          id: _findChunk(sourceId)?.id ?? 0,
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
          tagsJson: _tagsToJson(chunk.tags),
          structuredContentJson: chunk.structuredContentJson,
        );
        _chunkCodec.canonicalize(
          chunkEntity,
          now: DateTime.fromMillisecondsSinceEpoch(now),
        );
        _chunkBox.put(chunkEntity);
        _flowchartProjection.projectCanonicalChunk(chunkEntity);
        final canonicalKind = ChunkKind.fromWireName(
          chunkEntity.chunkKind,
        ).wireName;
        _auditItemBox.put(
          ExtractionAuditItemEntity(
            publicId: '$sourceId:audit',
            documentPublicId: documentPublicId,
            sourceId: sourceId,
            itemKind: canonicalKind,
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
            nodeType: canonicalKind,
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

  Future<void> reorderExtractedKnowledgeItems(
    String documentPublicId,
    List<String> orderedItemIds,
  ) async {
    final position = {
      for (var index = 0; index < orderedItemIds.length; index += 1)
        _sourceIdForItem(documentPublicId, orderedItemIds[index]): index,
    };
    _store.runInTransaction(TxMode.write, () {
      for (final chunk in _chunksForDocument(documentPublicId)) {
        final order = position[chunk.publicId];
        if (order == null) {
          continue;
        }
        chunk.sortOrder = order;
        _chunkBox.put(chunk);
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
    if (_findChunk(sourceId) != null) {
      await updateExtractedKnowledgeItem(
        documentPublicId,
        itemId,
        text: text,
        auditState: auditState,
      );
      _store.runInTransaction(TxMode.write, () {
        for (final auditItem in _auditItemBox.getAll()) {
          if (auditItem.sourceId == sourceId) {
            auditItem.reason = reason;
            auditItem.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
            _auditItemBox.put(auditItem);
          }
        }
      });
      return;
    }
    _store.runInTransaction(TxMode.write, () {
      final validationState = _validationStateForAuditState(auditState);
      final node = _findNode(sourceId);
      if (node != null) {
        node.validationState = validationState.wireName;
        if (text != null) {
          node.label = text;
        }
        node.rejectionReason = reason;
        _flowchartNodeBox.put(node);
        _synchronizeFlowchartParent(node.flowchartPublicId);
        return;
      }
      final edge = _findEdge(sourceId);
      if (edge != null) {
        edge.validationState = validationState.wireName;
        edge.rejectionReason = reason;
        _flowchartEdgeBox.put(edge);
        _synchronizeFlowchartParent(edge.flowchartPublicId);
      }
    });
  }

  Future<void> updateExtractedKnowledgeItem(
    String documentPublicId,
    String itemId, {
    String? text,
    String? sectionTitle,
    LocalChunkKind? chunkKind,
    LocalAuditState? auditState,
    List<NoteKnowledgeTag>? tags,
    String? structuredContentJson,
    bool clearStructuredContent = false,
  }) async {
    final sourceId = itemId.startsWith('$documentPublicId:')
        ? itemId
        : '$documentPublicId:$itemId';
    _store.runInTransaction(TxMode.write, () {
      final chunk = _findChunk(sourceId);
      if (chunk == null) {
        return;
      }
      final decoded = _chunkCodec.decode(chunk);
      var content = _contentForCanonicalUpdate(
        sourceId: sourceId,
        decoded: decoded,
        text: text,
        sectionTitle: sectionTitle,
        tags: tags,
        structuredContentJson: structuredContentJson,
        clearStructuredContent: clearStructuredContent,
        requestedKind: chunkKind,
      );
      final targetKind = chunkKind == null
          ? (content.type == NoteBlockType.flowchart
                ? ChunkKind.flowchartChunk
                : decoded.kind)
          : ChunkKind.fromWireName(chunkKind.wireName);
      if (targetKind == ChunkKind.noteChunk &&
          content.type == NoteBlockType.flowchart) {
        content = mixedBlockFromPlainText(
          id: sourceId,
          title: content.title,
          text: content.plainText,
          tags: content.tags,
        );
      } else if (targetKind == ChunkKind.flowchartChunk &&
          content.type != NoteBlockType.flowchart) {
        content = NoteBlock(
          id: sourceId,
          type: NoteBlockType.flowchart,
          title: content.title,
          text: content.plainText,
          tags: content.tags,
        );
      }
      final now = DateTime.now();
      final updated = targetKind == ChunkKind.flowchartChunk
          ? FlowchartChunk(
              id: decoded.id,
              creationMethod: decoded.creationMethod,
              validationState: auditState ?? decoded.validationState,
              source: decoded.source,
              createdAt: decoded.createdAt,
              updatedAt: now,
              content: content.copyWith(id: sourceId, clearIndex: true),
            )
          : NoteChunk(
              id: decoded.id,
              creationMethod: decoded.creationMethod,
              validationState: auditState ?? decoded.validationState,
              source: decoded.source,
              createdAt: decoded.createdAt,
              updatedAt: now,
              content: normalizeLegacyNoteBlock(
                content.copyWith(id: sourceId, clearIndex: true),
              ),
            );
      _chunkCodec.write(chunk, updated, now: now);
      _chunkBox.put(chunk);
      _chunkDerivedData.synchronizeMutation(
        before: decoded,
        after: updated,
        entity: chunk,
      );
      _flowchartProjection.projectCanonicalChunk(chunk);
    });
  }

  Future<void> updateExtractedKnowledgeTags(
    String documentPublicId,
    String itemId,
    List<NoteKnowledgeTag> tags,
  ) async {
    final sourceId = itemId.startsWith('$documentPublicId:')
        ? itemId
        : '$documentPublicId:$itemId';
    _store.runInTransaction(TxMode.write, () {
      final chunk = _findChunk(sourceId);
      if (chunk == null) {
        return;
      }
      final decoded = _chunkCodec.decode(chunk);
      final content = decoded.content.copyWith(tags: tags, clearIndex: true);
      final updated = decoded.kind == ChunkKind.flowchartChunk
          ? FlowchartChunk(
              id: decoded.id,
              creationMethod: decoded.creationMethod,
              validationState: decoded.validationState,
              source: decoded.source,
              createdAt: decoded.createdAt,
              updatedAt: DateTime.now(),
              content: content,
            )
          : NoteChunk(
              id: decoded.id,
              creationMethod: decoded.creationMethod,
              validationState: decoded.validationState,
              source: decoded.source,
              createdAt: decoded.createdAt,
              updatedAt: DateTime.now(),
              content: normalizeLegacyNoteBlock(content),
            );
      _chunkCodec.write(chunk, updated, now: DateTime.now());
      _chunkBox.put(chunk);
    });
  }

  Future<ChunkComparison> compareExtractedChunks(
    String documentPublicId,
  ) async {
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
    final chunks = _chunksForDocument(documentPublicId);
    final embeddings = _embeddingBox.getAll();
    final items = <ChunkPackageItem>[];
    final embeddingModels = <String>{};
    for (final entity in chunks) {
      final chunk = _chunkCodec.decode(entity);
      final packageChunkId = _packageChunkId(documentPublicId, chunk.id);
      final chunkEmbeddings = embeddings
          .where(
            (embedding) =>
                embedding.sourceId == entity.publicId ||
                embedding.sourceId.startsWith('${entity.publicId}:'),
          )
          .where((embedding) => embedding.vector?.isNotEmpty == true)
          .toList(growable: false);
      embeddingModels.addAll(chunkEmbeddings.map((item) => item.model));
      final parentEmbedding = chunkEmbeddings
          .where((embedding) => embedding.sourceId == entity.publicId)
          .firstOrNull;
      items.add(
        ChunkPackageItem(
          id: packageChunkId,
          text: chunk.plainText,
          pageNumber: chunk.source.pageStart ?? entity.pageNumber,
          sectionTitle: chunk.content.title ?? entity.sectionTitle,
          embedding: parentEmbedding?.vector ?? const [],
          kind: chunk.kind,
          creationMethod: chunk.creationMethod,
          validationState: chunk.validationState,
          source: chunk.source,
          content: chunk.content,
          embeddingRecords: [
            for (final embedding in chunkEmbeddings)
              ChunkPackageEmbedding(
                sourceId: embedding.sourceId == entity.publicId
                    ? packageChunkId
                    : embedding.sourceId,
                sourceType: embedding.sourceType,
                vector: embedding.vector!,
                model: embedding.model,
              ),
          ],
        ),
      );
    }
    final embeddingDimension = _firstEmbeddingDimension(items);
    return ChunkPackage(
      schemaVersion: 2,
      documentHash: document.sha256 ?? '',
      filename: document.filename,
      provider: document.activeProvider ?? '',
      extractionModel: document.activeModel ?? '',
      embeddingModel: embeddingModels.length == 1 ? embeddingModels.single : '',
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
      _clearGeneratedKnowledgeForDocument(documentPublicId, includeLocal: true);
      final importedAt = DateTime.now();
      final now = importedAt.millisecondsSinceEpoch;
      for (final item in package.chunks) {
        final sourceId = '$documentPublicId:${item.id}';
        // The clear step deliberately preserves linked chunks and their search
        // vectors. Importing a replacement for that ID must replace, rather
        // than accidentally reuse, the old vector.
        _removeEmbeddingsForSource(sourceId);
        final source = ChunkSource(
          sourceType: ChunkSourceType.pdf,
          sourceId: documentPublicId,
          pageStart: item.source.pageStart ?? item.pageNumber,
          pageEnd: item.source.pageEnd,
          sourceRectJson: item.source.sourceRectJson,
          originalText: item.source.originalText ?? item.text,
        );
        final portableContent = item.canonicalContent;
        final flowchartImport = item.kind == ChunkKind.flowchartChunk
            ? _remapImportedFlowchartContent(portableContent, sourceId)
            : null;
        final content =
            flowchartImport?.content ??
            normalizeLegacyNoteBlock(portableContent.copyWith(id: sourceId));
        final canonical = item.kind == ChunkKind.flowchartChunk
            ? FlowchartChunk(
                id: sourceId,
                creationMethod: item.creationMethod,
                validationState: item.validationState,
                source: source,
                createdAt: importedAt,
                updatedAt: importedAt,
                content: content,
              )
            : NoteChunk(
                id: sourceId,
                creationMethod: item.creationMethod,
                validationState: item.validationState,
                source: source,
                createdAt: importedAt,
                updatedAt: importedAt,
                content: content,
              );
        final chunkEntity = DocumentChunkEntity(
          id: _findChunk(sourceId)?.id ?? 0,
          publicId: sourceId,
          documentPublicId: documentPublicId,
          text: canonical.plainText,
          pageNumber: source.pageStart ?? 0,
          sectionTitle: canonical.content.title ?? item.sectionTitle,
          sourceRectJson: source.sourceRectJson,
          pipeline: _pipelineForCreationMethod(item.creationMethod).wireName,
          chunkKind: canonical.kind.wireName,
          auditState: canonical.validationState.wireName,
        );
        _chunkCodec.write(
          chunkEntity,
          canonical,
          now: importedAt,
          keepExistingOriginalText: false,
          keepExistingCreatedAt: false,
        );
        _chunkBox.put(chunkEntity);
        if (canonical.kind == ChunkKind.flowchartChunk) {
          _writeImportedFlowchartRows(
            documentPublicId: documentPublicId,
            flowchartPublicId: sourceId,
            pageNumber: source.pageStart ?? 0,
            sourceRectJson: source.sourceRectJson,
            auditState: canonical.validationState,
            content: content,
          );
        }
        final embeddingRecords = item.embeddingRecords.isNotEmpty
            ? item.embeddingRecords
            : item.embedding.isNotEmpty
            ? [
                ChunkPackageEmbedding(
                  sourceId: item.id,
                  sourceType: canonical.kind == ChunkKind.flowchartChunk
                      ? EvidenceSourceType.flowchartNode.wireName
                      : EvidenceSourceType.textChunk.wireName,
                  vector: item.embedding,
                  model: package.embeddingModel,
                ),
              ]
            : const <ChunkPackageEmbedding>[];
        for (final embedding in embeddingRecords) {
          final importedSourceId = embedding.sourceId == item.id
              ? sourceId
              : flowchartImport?.elementIds[embedding.sourceId] ??
                    _importedEmbeddingSourceId(sourceId, embedding.sourceId);
          _embeddingBox.put(
            ChunkEmbeddingEntity(
              sourceId: importedSourceId,
              sourceType: embedding.sourceType,
              vector: embedding.vector,
              model: embedding.model,
              createdAtMillis: now,
            ),
          );
        }
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

  ({NoteBlock content, Map<String, String> elementIds})
  _remapImportedFlowchartContent(NoteBlock content, String flowchartPublicId) {
    final nodeIds = <String, String>{};
    final portIdsByNode = <String, Map<String, String>>{};
    final usedNodeIds = <String>{};
    final usedPortIds = <String>{};
    final nodes = <NoteFlowchartNode>[];
    for (var index = 0; index < content.nodes.length; index += 1) {
      final node = content.nodes[index];
      final mappedId = _importedFlowchartElementId(
        flowchartPublicId: flowchartPublicId,
        originalId: node.id,
        fallback: 'node-${index + 1}',
        usedIds: usedNodeIds,
      );
      nodeIds[node.id] = mappedId;
      final portIds = <String, String>{};
      final ports = <NoteFlowchartPort>[];
      for (var portIndex = 0; portIndex < node.ports.length; portIndex += 1) {
        final port = node.ports[portIndex];
        final mappedPortId = _importedFlowchartElementId(
          flowchartPublicId: mappedId,
          originalId: port.id,
          fallback: 'port-${portIndex + 1}',
          usedIds: usedPortIds,
        );
        portIds[port.id] = mappedPortId;
        ports.add(port.copyWith(id: mappedPortId));
      }
      portIdsByNode[node.id] = portIds;
      nodes.add(node.copyWith(id: mappedId, ports: ports));
    }
    final edgeIds = <String, String>{};
    final usedEdgeIds = <String>{};
    final edges = <NoteFlowchartEdge>[];
    for (var index = 0; index < content.edges.length; index += 1) {
      final edge = content.edges[index];
      final mappedId = _importedFlowchartElementId(
        flowchartPublicId: flowchartPublicId,
        originalId: edge.id,
        fallback: 'edge-${index + 1}',
        usedIds: usedEdgeIds,
      );
      edgeIds[edge.id] = mappedId;
      edges.add(
        edge.copyWith(
          id: mappedId,
          fromNodeId: nodeIds[edge.fromNodeId] ?? edge.fromNodeId,
          toNodeId: nodeIds[edge.toNodeId] ?? edge.toNodeId,
          fromPortId: edge.fromPortId == null
              ? null
              : portIdsByNode[edge.fromNodeId]?[edge.fromPortId] ??
                    edge.fromPortId,
          toPortId: edge.toPortId == null
              ? null
              : portIdsByNode[edge.toNodeId]?[edge.toPortId] ?? edge.toPortId,
        ),
      );
    }
    final scopedTags = [
      for (final assignment in content.scopedTags)
        assignment.copyWith(
          target: switch (assignment.target.kind) {
            NoteTagTargetKind.flowchartNode => assignment.target.copyWith(
              elementId:
                  nodeIds[assignment.target.elementId] ??
                  assignment.target.elementId,
            ),
            NoteTagTargetKind.flowchartEdge => assignment.target.copyWith(
              elementId:
                  edgeIds[assignment.target.elementId] ??
                  assignment.target.elementId,
            ),
            _ => assignment.target,
          },
        ),
    ];
    return (
      content: content.copyWith(
        id: flowchartPublicId,
        nodes: nodes,
        edges: edges,
        scopedTags: scopedTags,
      ),
      elementIds: {...nodeIds, ...edgeIds},
    );
  }

  String _importedEmbeddingSourceId(
    String chunkPublicId,
    String portableSourceId,
  ) {
    final trimmed = portableSourceId.trim();
    final separator = trimmed.lastIndexOf(':');
    final localId =
        (separator >= 0 ? trimmed.substring(separator + 1) : trimmed).trim();
    return localId.isEmpty ? chunkPublicId : '$chunkPublicId:$localId';
  }

  String _importedFlowchartElementId({
    required String flowchartPublicId,
    required String originalId,
    required String fallback,
    required Set<String> usedIds,
  }) {
    final trimmed = originalId.trim();
    final separator = trimmed.lastIndexOf(':');
    final localId =
        (separator >= 0 ? trimmed.substring(separator + 1) : trimmed).trim();
    final base = localId.isEmpty ? fallback : localId;
    var candidate = '$flowchartPublicId:$base';
    var suffix = 2;
    while (!usedIds.add(candidate)) {
      candidate = '$flowchartPublicId:$base-$suffix';
      suffix += 1;
    }
    return candidate;
  }

  void _writeImportedFlowchartRows({
    required String documentPublicId,
    required String flowchartPublicId,
    required int pageNumber,
    required String? sourceRectJson,
    required LocalAuditState auditState,
    required NoteBlock content,
  }) {
    final validation = _validationStateForAuditState(auditState).wireName;
    _flowchartBox.put(
      FlowchartEntity(
        publicId: flowchartPublicId,
        documentPublicId: documentPublicId,
        pageNumber: pageNumber,
        validationState: validation,
        sourceRectJson: sourceRectJson,
      ),
    );
    for (final node in content.nodes) {
      _flowchartNodeBox.put(
        FlowchartNodeEntity(
          publicId: node.id,
          flowchartPublicId: flowchartPublicId,
          label: node.label,
          validationState: validation,
          positionX: node.x,
          positionY: node.y,
          shape: node.shape.wireName,
          sortOrder: node.order,
        ),
      );
    }
    for (final edge in content.edges) {
      _flowchartEdgeBox.put(
        FlowchartEdgeEntity(
          publicId: edge.id,
          flowchartPublicId: flowchartPublicId,
          fromNodePublicId: edge.fromNodeId,
          toNodePublicId: edge.toNodeId,
          label: edge.label,
          validationState: validation,
          sortOrder: edge.order,
        ),
      );
    }
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

  FlowchartEntity? _findFlowchart(String publicId) {
    final query = _flowchartBox
        .query(FlowchartEntity_.publicId.equals(publicId))
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

  NoteBlock _contentForCanonicalUpdate({
    required String sourceId,
    required Chunk decoded,
    required String? text,
    required String? sectionTitle,
    required List<NoteKnowledgeTag>? tags,
    required String? structuredContentJson,
    required bool clearStructuredContent,
    required LocalChunkKind? requestedKind,
  }) {
    NoteBlock? suppliedContent;
    final raw = structuredContentJson?.trim();
    if (raw != null && raw.isNotEmpty) {
      final json = jsonDecode(raw);
      if (json is! Map) {
        throw const FormatException(
          'Structured chunk content must be a JSON object.',
        );
      }
      final map = Map<String, Object?>.from(json);
      suppliedContent = map.containsKey('kind') && map['content'] is Map
          ? Chunk.fromJson(map).content
          : NoteBlock.fromJson(map);
    }
    var content = suppliedContent ?? decoded.content;
    final wantsFlowchart =
        requestedKind == LocalChunkKind.flowchart ||
        (requestedKind == null && decoded.kind == ChunkKind.flowchartChunk);
    if (suppliedContent == null && (text != null || clearStructuredContent)) {
      final projectionText = text ?? decoded.plainText;
      content = wantsFlowchart
          ? NoteBlock(
              id: sourceId,
              type: NoteBlockType.flowchart,
              title: sectionTitle ?? decoded.content.title,
              text: projectionText,
              tags: tags ?? decoded.content.tags,
            )
          : mixedBlockFromPlainText(
              id: sourceId,
              title: sectionTitle ?? decoded.content.title,
              text: projectionText,
              tags: tags ?? decoded.content.tags,
            );
    } else {
      if (sectionTitle != null) {
        content = content.copyWith(title: sectionTitle);
      }
      if (tags != null) {
        content = content.copyWith(tags: tags);
      }
    }
    return content.copyWith(id: sourceId);
  }

  void _removeEmbeddingsForSource(String sourceId) {
    final embeddingIds = _embeddingBox
        .getAll()
        .where(
          (embedding) =>
              embedding.sourceId == sourceId ||
              embedding.sourceId.startsWith('$sourceId:'),
        )
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
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
    final linkedSourceIds = _linkedSourceIds(sourceIds);
    final deletedSourceIds = sourceIds.difference(linkedSourceIds);
    final embeddingIds = _embeddingBox
        .getAll()
        .where((embedding) => deletedSourceIds.contains(embedding.sourceId))
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
    }
    _deleteOrDetachChunks(localChunks, linkedSourceIds: linkedSourceIds);
    for (final chunk in localChunks) {
      if (ChunkKind.fromWireName(chunk.chunkKind) == ChunkKind.flowchartChunk) {
        _removeFlowchart(
          chunk.publicId,
          preserveCanonicalEmbedding: linkedSourceIds.contains(chunk.publicId),
        );
      }
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
    final linkedSourceIds = _linkedSourceIds(sourceIds);
    final deletedSourceIds = sourceIds.difference(linkedSourceIds);
    final embeddingIds = _embeddingBox
        .getAll()
        .where(
          (embedding) =>
              _generatedEmbeddingSourceTypes.contains(embedding.sourceType) &&
              deletedSourceIds.contains(embedding.sourceId),
        )
        .map((embedding) => embedding.id)
        .toList(growable: false);
    if (embeddingIds.isNotEmpty) {
      _embeddingBox.removeMany(embeddingIds);
    }
    _deleteOrDetachChunks(chunks, linkedSourceIds: linkedSourceIds);
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

    for (final chunk in chunks) {
      if (ChunkKind.fromWireName(chunk.chunkKind) == ChunkKind.flowchartChunk) {
        _removeFlowchart(
          chunk.publicId,
          preserveCanonicalEmbedding: linkedSourceIds.contains(chunk.publicId),
        );
      }
    }
  }

  Set<String> _linkedSourceIds(Set<String> sourceIds) {
    if (sourceIds.isEmpty) {
      return const {};
    }
    return {
      for (final link in _chunkNoteLinkBox.getAll())
        if (sourceIds.contains(link.chunkPublicId)) link.chunkPublicId,
    };
  }

  void _deleteOrDetachChunks(
    List<DocumentChunkEntity> chunks, {
    required Set<String> linkedSourceIds,
  }) {
    final removableIds = <int>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final chunk in chunks) {
      if (!linkedSourceIds.contains(chunk.publicId)) {
        removableIds.add(chunk.id);
        continue;
      }
      chunk.sourceType ??= ChunkSourceType.pdf.wireName;
      chunk.sourcePublicId ??= chunk.documentPublicId;
      chunk.documentPublicId = '';
      chunk.updatedAtMillis = now;
      _chunkBox.put(chunk);
    }
    if (removableIds.isNotEmpty) {
      _chunkBox.removeMany(removableIds);
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

  void _removeFlowchart(
    String flowchartPublicId, {
    bool preserveCanonicalEmbedding = false,
  }) {
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
    if (preserveCanonicalEmbedding) {
      for (final flowchart in flowcharts) {
        flowchart.documentPublicId = '';
        _flowchartBox.put(flowchart);
      }
      return;
    }
    final flowchartSourceIds = {
      ...nodes.map((node) => node.publicId),
      ...edges.map((edge) => edge.publicId),
      flowchartPublicId,
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
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) {
      return order;
    }
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

  String _sourceIdForItem(String documentPublicId, String itemId) {
    return itemId.startsWith('$documentPublicId:')
        ? itemId
        : '$documentPublicId:$itemId';
  }

  ExtractedKnowledgeItem _itemFromChunk(
    String documentPublicId,
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity? embedding,
  ) {
    final pipeline = LocalExtractionPipeline.fromWireName(chunk.pipeline);
    final canonicalKind = ChunkKind.fromWireName(chunk.chunkKind);
    final chunkKind = canonicalKind == ChunkKind.flowchartChunk
        ? LocalChunkKind.flowchart
        : LocalChunkKind.text;
    final embeddedSourceType = embedding == null
        ? null
        : evidenceSourceTypeFromWireName(embedding.sourceType);
    return ExtractedKnowledgeItem(
      id: _packageChunkId(documentPublicId, chunk.publicId),
      documentId: documentPublicId,
      sourceType: pipeline == LocalExtractionPipeline.ai
          ? embeddedSourceType ?? _sourceTypeForLocalKind(chunkKind)
          : _sourceTypeForLocalKind(chunkKind),
      text: chunk.text,
      pageNumber: chunk.pageNumber,
      sectionTitle: chunk.sectionTitle,
      embeddingModel: embedding?.model,
      sourceRectJson: chunk.sourceRectJson,
      pipeline: pipeline,
      chunkKind: chunkKind,
      auditState: LocalAuditState.fromWireName(chunk.auditState),
      endPageNumber: chunk.endPageNumber,
      confidence: chunk.confidence,
      sourcePageImagePath: chunk.sourcePageImagePath,
      tags: _tagsFromJson(chunk.tagsJson),
      sortOrder: chunk.sortOrder,
      structuredContentJson: chunk.structuredContentJson,
    );
  }

  EvidenceSourceType _sourceTypeForLocalKind(LocalChunkKind kind) {
    return switch (kind) {
      LocalChunkKind.table => EvidenceSourceType.tableChunk,
      LocalChunkKind.flowchart => EvidenceSourceType.flowchartNode,
      LocalChunkKind.text ||
      LocalChunkKind.list => EvidenceSourceType.textChunk,
    };
  }

  LocalChunkKind _localKindForSourceType(String sourceType) {
    if (sourceType == EvidenceSourceType.tableChunk.wireName) {
      return LocalChunkKind.table;
    }
    if (sourceType == EvidenceSourceType.scoreChunk.wireName) {
      return LocalChunkKind.table;
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
          ChunkComparisonRow(status: ChunkComparisonStatus.aiOnly, aiChunk: ai),
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
        .where(
          (entity) => switch (entity) {
            DocumentPageEntity item =>
              item.documentPublicId == documentPublicId,
            ExtractionAuditItemEntity item =>
              item.documentPublicId == documentPublicId,
            KnowledgeNodeEntity item =>
              item.documentPublicId == documentPublicId,
            KnowledgeEdgeEntity item =>
              item.documentPublicId == documentPublicId,
            KnowledgeEvidenceEntity item =>
              item.documentPublicId == documentPublicId,
            VisualObjectEntity item =>
              item.documentPublicId == documentPublicId,
            _ => false,
          },
        )
        .map(
          (entity) => switch (entity) {
            DocumentPageEntity item => item.id,
            ExtractionAuditItemEntity item => item.id,
            KnowledgeNodeEntity item => item.id,
            KnowledgeEdgeEntity item => item.id,
            KnowledgeEvidenceEntity item => item.id,
            VisualObjectEntity item => item.id,
            _ => 0,
          },
        )
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

  ExtractedKnowledgeItem _flowchartItem(
    String documentPublicId,
    FlowchartEntity flowchart,
    Map<String, ChunkEmbeddingEntity> embeddings,
  ) {
    final parent = _findChunk(flowchart.publicId);
    final decodedParent = parent == null ? null : _chunkCodec.decode(parent);
    final content = decodedParent?.kind == ChunkKind.flowchartChunk
        ? decodedParent!.content
        : _flowchartBlock(flowchart);
    final pipeline = LocalExtractionPipeline.fromWireName(parent?.pipeline);
    String? embeddingModel;
    for (final embedding in embeddings.values) {
      if (embedding.sourceId.startsWith('${flowchart.publicId}:')) {
        embeddingModel = embedding.model;
        break;
      }
    }
    return ExtractedKnowledgeItem(
      id: _packageChunkId(documentPublicId, flowchart.publicId),
      documentId: documentPublicId,
      sourceType: EvidenceSourceType.flowchartNode,
      text: content.plainText,
      pageNumber: flowchart.pageNumber,
      sectionTitle: content.title ?? 'Flowchart',
      embeddingModel: embeddingModel,
      flowchartId: flowchart.publicId,
      sourceRectJson: flowchart.sourceRectJson,
      pipeline: pipeline,
      chunkKind: LocalChunkKind.flowchart,
      auditState: parent == null
          ? _auditStateForValidationState(flowchart.validationState)
          : LocalAuditState.fromWireName(parent.auditState),
      confidence: flowchart.extractionConfidence,
      tags: parent == null ? const [] : _tagsFromJson(parent.tagsJson),
      sortOrder: parent?.sortOrder ?? 0,
      structuredContentJson: jsonEncode(content.toJson()),
    );
  }

  void _upsertFlowchartParentChunk(
    FlowchartEntity flowchart, {
    required DateTime now,
    required ChunkCreationMethod fallbackCreationMethod,
  }) {
    final existing = _findChunk(flowchart.publicId);
    final previous = existing == null ? null : _chunkCodec.decode(existing);
    final content = _flowchartBlock(flowchart, previous: previous?.content);
    final creationMethod = previous?.creationMethod ?? fallbackCreationMethod;
    final chunk = FlowchartChunk(
      id: flowchart.publicId,
      creationMethod: creationMethod,
      validationState: _auditStateForValidationState(flowchart.validationState),
      source: ChunkSource(
        sourceType: ChunkSourceType.pdf,
        sourceId: flowchart.documentPublicId,
        pageStart: flowchart.pageNumber,
        sourceRectJson: flowchart.sourceRectJson,
        originalText: previous?.source.originalText,
      ),
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
      content: content,
    );
    final entity =
        existing ??
        DocumentChunkEntity(
          publicId: flowchart.publicId,
          documentPublicId: flowchart.documentPublicId,
          text: chunk.plainText,
          pageNumber: flowchart.pageNumber,
          pipeline: fallbackCreationMethod == ChunkCreationMethod.aiGenerated
              ? LocalExtractionPipeline.ai.wireName
              : LocalExtractionPipeline.manual.wireName,
          chunkKind: ChunkKind.flowchartChunk.wireName,
          auditState: chunk.validationState.wireName,
        );
    synchronizeFlowchartParentDocumentRelation(
      parent: entity,
      flowchart: flowchart,
    );
    _chunkCodec.write(entity, chunk, now: now);
    _chunkBox.put(entity);
  }

  void _synchronizeFlowchartParent(String flowchartPublicId) {
    _flowchartProjection.synchronizeCanonicalValidation(flowchartPublicId);
  }

  NoteBlock _flowchartBlock(FlowchartEntity flowchart, {NoteBlock? previous}) {
    final nodes =
        _flowchartNodeBox
            .getAll()
            .where((node) => node.flowchartPublicId == flowchart.publicId)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final edges =
        _flowchartEdgeBox
            .getAll()
            .where((edge) => edge.flowchartPublicId == flowchart.publicId)
            .toList(growable: false)
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final previousContent = previous?.type == NoteBlockType.flowchart
        ? previous
        : null;
    final previousNodes = {
      for (final node in previousContent?.nodes ?? const <NoteFlowchartNode>[])
        node.id: node,
    };
    final previousEdges = {
      for (final edge in previousContent?.edges ?? const <NoteFlowchartEdge>[])
        edge.id: edge,
    };
    return NoteBlock(
      id: flowchart.publicId,
      type: NoteBlockType.flowchart,
      title: previousContent?.title ?? 'Flowchart',
      searchContext: previousContent?.searchContext,
      searchRole: previousContent?.searchRole ?? NoteSearchRoles.none,
      searchAliases: previousContent?.searchAliases ?? const [],
      tags: previousContent?.tags ?? const [],
      scopedTags: previousContent?.scopedTags ?? const [],
      nodes: [
        for (final node in nodes)
          (previousNodes[node.publicId] ??
                  NoteFlowchartNode(id: node.publicId, label: node.label))
              .copyWith(
                label: node.label,
                shape: AiFlowchartNodeShape.fromWireName(node.shape),
                order: node.sortOrder,
                x: node.positionX,
                y: node.positionY,
              ),
      ],
      edges: [
        for (final edge in edges)
          (previousEdges[edge.publicId] ??
                  NoteFlowchartEdge(
                    id: edge.publicId,
                    fromNodeId: edge.fromNodePublicId,
                    toNodeId: edge.toNodePublicId,
                    label: edge.label,
                  ))
              .copyWith(
                fromNodeId: edge.fromNodePublicId,
                toNodeId: edge.toNodePublicId,
                label: edge.label,
                order: edge.sortOrder,
              ),
      ],
    );
  }

  String? _sourceRectJson(Map<String, Object?>? sourceRect) {
    if (sourceRect == null) {
      return null;
    }
    return jsonEncode(sourceRect);
  }

  String? _tagsToJson(List<NoteKnowledgeTag> tags) {
    if (tags.isEmpty) {
      return null;
    }
    return jsonEncode([for (final tag in tags) tag.toJson()]);
  }

  List<NoteKnowledgeTag> _tagsFromJson(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .map(NoteKnowledgeTag.fromJson)
          .where((tag) => tag.label.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
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
      LocalAuditState.accepted ||
      LocalAuditState.edited => ValidationState.validated,
      LocalAuditState.rejected => ValidationState.rejected,
      LocalAuditState.unreviewed => ValidationState.unreviewed,
    };
  }

  LocalExtractionPipeline _pipelineForCreationMethod(
    ChunkCreationMethod method,
  ) {
    return switch (method) {
      ChunkCreationMethod.manualSelection => LocalExtractionPipeline.manual,
      ChunkCreationMethod.assistedSelection =>
        LocalExtractionPipeline.localPdfText,
      ChunkCreationMethod.aiGenerated ||
      ChunkCreationMethod.imported => LocalExtractionPipeline.ai,
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
    final dimensions = <int>{};
    for (final item in items) {
      if (item.embedding.isNotEmpty) {
        dimensions.add(item.embedding.length);
      }
      for (final embedding in item.embeddingRecords) {
        if (embedding.vector.isNotEmpty) {
          dimensions.add(embedding.vector.length);
        }
      }
    }
    return dimensions.length == 1 ? dimensions.single : 0;
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
