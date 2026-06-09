import 'package:uuid/uuid.dart';

import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../../openai/openai_client.dart';
import 'document_processing_service.dart';
import 'training_pack_service.dart';

abstract class KnowledgeRepository {
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    String? contentHash,
    String ocrStatus = 'unknown',
    String collectionName = 'Alap',
    bool ragEnabled = true,
  });

  Future<List<KnowledgeDocumentEntity>> listDocuments();

  Future<KnowledgeDocumentEntity?> findDocumentByPublicId(String publicId);

  Future<KnowledgeDocumentEntity?> findDocumentByContentHash(
    String contentHash,
  );

  Future<void> updateProcessingState(
    String documentPublicId,
    ProcessingState state, {
    String? errorMessage,
  });

  Future<void> updateRagEnabled(String documentPublicId, bool enabled);

  Future<void> updateCollection(String documentPublicId, String collectionName);

  Future<void> saveChunk(
    DocumentChunkEntity chunk,
    ChunkEmbeddingEntity embedding,
  );

  Future<bool> hasReadyDocuments();
}

class ObjectBoxKnowledgeRepository
    implements
        KnowledgeRepository,
        ProcessingRepository,
        TrainingPackRepository {
  ObjectBoxKnowledgeRepository({required Store store, Uuid? uuid})
    : _documentBox = store.box<KnowledgeDocumentEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _flowchartBox = store.box<FlowchartEntity>(),
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>(),
      _uuid = uuid ?? const Uuid();

  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;
  final Uuid _uuid;

  @override
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    String? contentHash,
    String ocrStatus = 'unknown',
    String collectionName = 'Alap',
    bool ragEnabled = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final document = KnowledgeDocumentEntity(
      publicId: _uuid.v4(),
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAtMillis: now,
      processingState: ProcessingState.imported.wireName,
      contentHash: contentHash,
      ragEnabled: ragEnabled,
      collectionName: _normalizeCollection(collectionName),
      ocrStatus: ocrStatus,
    );
    _documentBox.put(document);
    return document;
  }

  @override
  Future<List<KnowledgeDocumentEntity>> listDocuments() async {
    return _documentBox.getAll();
  }

  @override
  Future<KnowledgeDocumentEntity?> findDocumentByPublicId(
    String publicId,
  ) async {
    return _findDocument(publicId);
  }

  @override
  Future<KnowledgeDocumentEntity?> findDocumentByContentHash(
    String contentHash,
  ) async {
    final query = _documentBox
        .query(KnowledgeDocumentEntity_.contentHash.equals(contentHash))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
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
    if (state == ProcessingState.ready ||
        state == ProcessingState.needsReview) {
      document.trainedAtMillis = DateTime.now().millisecondsSinceEpoch;
    }
    _documentBox.put(document);
  }

  @override
  Future<void> updateRagEnabled(String documentPublicId, bool enabled) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    document.ragEnabled = enabled;
    _documentBox.put(document);
  }

  @override
  Future<void> updateCollection(
    String documentPublicId,
    String collectionName,
  ) async {
    final document = _findDocument(documentPublicId);
    if (document == null) {
      throw StateError('knowledge document not found: $documentPublicId');
    }
    document.collectionName = _normalizeCollection(collectionName);
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
  }) {
    return updateProcessingState(
      documentPublicId,
      state,
      errorMessage: errorMessage,
    );
  }

  @override
  Future<void> clearEvidence(String documentPublicId) async {
    _deleteEvidenceForDocument(documentPublicId);
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
  Future<void> saveExtractedFlowchart({
    required String documentPublicId,
    required OpenAiExtractedFlowchart flowchart,
    required Map<String, List<double>> embeddingsBySourceId,
    required String embeddingModel,
  }) async {
    final flowchartId = '$documentPublicId:${flowchart.id}';
    _flowchartBox.put(
      FlowchartEntity(
        publicId: flowchartId,
        documentPublicId: documentPublicId,
        pageNumber: flowchart.pageNumber,
        validationState: ValidationState.unreviewed.wireName,
        extractionConfidence: flowchart.confidence,
      ),
    );
    for (final node in flowchart.nodes) {
      final nodeId = _nodeSourceId(flowchartId, node.id);
      _nodeBox.put(
        FlowchartNodeEntity(
          publicId: nodeId,
          flowchartPublicId: flowchartId,
          label: node.label,
          validationState: ValidationState.unreviewed.wireName,
          positionX: node.positionX,
          positionY: node.positionY,
        ),
      );
      _putFlowchartEmbedding(
        sourceId: nodeId,
        sourceType: EvidenceSourceType.flowchartNode,
        embedding: embeddingsBySourceId[nodeId],
        model: embeddingModel,
      );
    }
    for (final edge in flowchart.edges) {
      final edgeId = _edgeSourceId(flowchartId, edge.id);
      _edgeBox.put(
        FlowchartEdgeEntity(
          publicId: edgeId,
          flowchartPublicId: flowchartId,
          fromNodePublicId: _nodeSourceId(flowchartId, edge.fromNodeId),
          toNodePublicId: _nodeSourceId(flowchartId, edge.toNodeId),
          label: edge.label,
          validationState: ValidationState.unreviewed.wireName,
        ),
      );
      _putFlowchartEmbedding(
        sourceId: edgeId,
        sourceType: EvidenceSourceType.flowchartEdge,
        embedding: embeddingsBySourceId[edgeId],
        model: embeddingModel,
      );
    }
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
    return _documentBox.getAll().any(
      (document) =>
          document.ragEnabled &&
          (document.processingState == ProcessingState.ready.wireName ||
              document.processingState == ProcessingState.needsReview.wireName),
    );
  }

  @override
  Future<List<TrainingPackDocument>> listDocumentPacks() async {
    return _documentBox.getAll().map(_toPackDocument).toList(growable: false);
  }

  @override
  Future<void> upsertDocumentPack(TrainingPackDocument document) async {
    final existing = document.contentHash.isEmpty
        ? null
        : await findDocumentByContentHash(document.contentHash);
    final entity =
        existing ??
        KnowledgeDocumentEntity(
          publicId: document.id.isEmpty ? _uuid.v4() : document.id,
          filename: document.filename,
          localPath: document.localPath,
          sizeBytes: document.sizeBytes,
          importedAtMillis: document.importedAtMillis,
          processingState: document.processingState,
        );
    entity.filename = document.filename;
    entity.localPath = document.localPath;
    entity.sizeBytes = document.sizeBytes;
    entity.importedAtMillis = document.importedAtMillis;
    entity.processingState = document.processingState;
    entity.contentHash = document.contentHash;
    entity.ragEnabled = document.ragEnabled;
    entity.collectionName = _normalizeCollection(document.collectionName);
    entity.ocrStatus = document.ocrStatus;
    entity.trainedAtMillis = document.trainedAtMillis;
    entity.packVersion = document.packVersion ?? 1;
    if (existing != null) {
      _deleteEvidenceForDocument(entity.publicId);
    }
    _documentBox.put(entity);

    for (final chunk in document.chunks) {
      _chunkBox.put(
        DocumentChunkEntity(
          publicId: chunk.id,
          documentPublicId: entity.publicId,
          text: chunk.text,
          pageNumber: chunk.pageNumber,
          sectionTitle: chunk.sectionTitle,
        ),
      );
    }
    for (final embedding in document.embeddings) {
      if (embedding.vector.length != 3072) {
        continue;
      }
      _embeddingBox.put(
        ChunkEmbeddingEntity(
          sourceId: embedding.sourceId,
          sourceType: embedding.sourceType,
          vector: embedding.vector,
          model: embedding.model,
          createdAtMillis: embedding.createdAtMillis,
        ),
      );
    }
    for (final flowchart in document.flowcharts) {
      _flowchartBox.put(
        FlowchartEntity(
          publicId: flowchart.id,
          documentPublicId: entity.publicId,
          pageNumber: flowchart.pageNumber,
          validationState: flowchart.validationState,
          extractionConfidence: flowchart.extractionConfidence,
        ),
      );
      for (final node in flowchart.nodes) {
        _nodeBox.put(
          FlowchartNodeEntity(
            publicId: node.id,
            flowchartPublicId: flowchart.id,
            label: node.label,
            validationState: node.validationState,
            rejectionReason: node.rejectionReason,
            positionX: node.positionX,
            positionY: node.positionY,
          ),
        );
      }
      for (final edge in flowchart.edges) {
        _edgeBox.put(
          FlowchartEdgeEntity(
            publicId: edge.id,
            flowchartPublicId: flowchart.id,
            fromNodePublicId: edge.fromNodeId,
            toNodePublicId: edge.toNodeId,
            label: edge.label,
            validationState: edge.validationState,
            rejectionReason: edge.rejectionReason,
          ),
        );
      }
    }
  }

  void _deleteEvidenceForDocument(String documentPublicId) {
    final chunks = _chunkBox
        .getAll()
        .where((chunk) => chunk.documentPublicId == documentPublicId)
        .toList(growable: false);
    final flowcharts = _flowchartBox
        .getAll()
        .where((flowchart) => flowchart.documentPublicId == documentPublicId)
        .toList(growable: false);
    final flowchartIds = flowcharts
        .map((flowchart) => flowchart.publicId)
        .toSet();
    final nodes = _nodeBox
        .getAll()
        .where((node) => flowchartIds.contains(node.flowchartPublicId))
        .toList(growable: false);
    final edges = _edgeBox
        .getAll()
        .where((edge) => flowchartIds.contains(edge.flowchartPublicId))
        .toList(growable: false);
    final sourceIds = {
      for (final chunk in chunks) chunk.publicId,
      for (final node in nodes) node.publicId,
      for (final edge in edges) edge.publicId,
    };
    final embeddings = _embeddingBox
        .getAll()
        .where((embedding) => sourceIds.contains(embedding.sourceId))
        .toList(growable: false);
    _embeddingBox.removeMany(embeddings.map((item) => item.id).toList());
    _edgeBox.removeMany(edges.map((item) => item.id).toList());
    _nodeBox.removeMany(nodes.map((item) => item.id).toList());
    _flowchartBox.removeMany(flowcharts.map((item) => item.id).toList());
    _chunkBox.removeMany(chunks.map((item) => item.id).toList());
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

  void _putFlowchartEmbedding({
    required String sourceId,
    required EvidenceSourceType sourceType,
    required List<double>? embedding,
    required String model,
  }) {
    if (embedding == null) {
      return;
    }
    _embeddingBox.put(
      ChunkEmbeddingEntity(
        sourceId: sourceId,
        sourceType: sourceType.wireName,
        vector: embedding,
        model: model,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String _nodeSourceId(String flowchartId, String nodeId) {
    return '$flowchartId:node:$nodeId';
  }

  String _edgeSourceId(String flowchartId, String edgeId) {
    return '$flowchartId:edge:$edgeId';
  }

  String _normalizeCollection(String value) {
    return value.trim().isEmpty ? 'Alap' : value.trim();
  }

  TrainingPackDocument _toPackDocument(KnowledgeDocumentEntity document) {
    final chunks = _chunkBox
        .getAll()
        .where((chunk) => chunk.documentPublicId == document.publicId)
        .map(
          (chunk) => TrainingPackChunk(
            id: chunk.publicId,
            text: chunk.text,
            pageNumber: chunk.pageNumber,
            sectionTitle: chunk.sectionTitle,
          ),
        )
        .toList(growable: false);
    final flowcharts = _flowchartBox
        .getAll()
        .where((flowchart) => flowchart.documentPublicId == document.publicId)
        .map(_toPackFlowchart)
        .toList(growable: false);
    final sourceIds = {
      for (final chunk in chunks) chunk.id,
      for (final flowchart in flowcharts) ...[
        for (final node in flowchart.nodes) node.id,
        for (final edge in flowchart.edges) edge.id,
      ],
    };
    final embeddings = _embeddingBox
        .getAll()
        .where((embedding) => sourceIds.contains(embedding.sourceId))
        .map(
          (embedding) => TrainingPackEmbedding(
            sourceId: embedding.sourceId,
            sourceType: embedding.sourceType,
            vector: embedding.vector ?? const [],
            model: embedding.model,
            createdAtMillis: embedding.createdAtMillis,
          ),
        )
        .toList(growable: false);
    return TrainingPackDocument(
      id: document.publicId,
      filename: document.filename,
      localPath: document.localPath,
      sizeBytes: document.sizeBytes,
      importedAtMillis: document.importedAtMillis,
      processingState: document.processingState,
      contentHash: document.contentHash ?? '',
      ragEnabled: document.ragEnabled,
      collectionName: document.collectionName,
      ocrStatus: document.ocrStatus,
      trainedAtMillis: document.trainedAtMillis,
      packVersion: document.packVersion,
      chunks: chunks,
      embeddings: embeddings,
      flowcharts: flowcharts,
    );
  }

  TrainingPackFlowchart _toPackFlowchart(FlowchartEntity flowchart) {
    final nodes = _nodeBox
        .getAll()
        .where((node) => node.flowchartPublicId == flowchart.publicId)
        .map(
          (node) => TrainingPackFlowchartNode(
            id: node.publicId,
            label: node.label,
            validationState: node.validationState,
            rejectionReason: node.rejectionReason,
            positionX: node.positionX,
            positionY: node.positionY,
          ),
        )
        .toList(growable: false);
    final edges = _edgeBox
        .getAll()
        .where((edge) => edge.flowchartPublicId == flowchart.publicId)
        .map(
          (edge) => TrainingPackFlowchartEdge(
            id: edge.publicId,
            fromNodeId: edge.fromNodePublicId,
            toNodeId: edge.toNodePublicId,
            label: edge.label,
            validationState: edge.validationState,
            rejectionReason: edge.rejectionReason,
          ),
        )
        .toList(growable: false);
    return TrainingPackFlowchart(
      id: flowchart.publicId,
      pageNumber: flowchart.pageNumber,
      validationState: flowchart.validationState,
      extractionConfidence: flowchart.extractionConfidence,
      nodes: nodes,
      edges: edges,
    );
  }
}
