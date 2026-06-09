import '../../../objectbox.g.dart';
import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../models/source_evidence.dart';

abstract class LocalRetriever {
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? collectionName,
  });
}

class MemoryLocalRetriever implements LocalRetriever {
  MemoryLocalRetriever(this._items);

  final List<SourceEvidence> _items;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? collectionName,
  }) async {
    DebugConsole.log(
      '[VectorGraph] memory retrieval start dim=${queryVector.length} '
      'limit=$limit min=$minimumSimilarity',
    );
    final evidence = <SourceEvidence>[];
    for (final item in _items) {
      if (item.validationState == ValidationState.rejected) {
        DebugConsole.log(
          '[VectorGraph] memory skipped rejected source=${item.id}',
        );
        continue;
      }
      if (!item.ragEnabled) {
        DebugConsole.log(
          '[VectorGraph] memory skipped disabled source=${item.id}',
        );
        continue;
      }
      if (collectionName != null &&
          collectionName.isNotEmpty &&
          item.collectionName != collectionName) {
        continue;
      }
      if ((item.score ?? 1) < minimumSimilarity) {
        continue;
      }
      evidence.add(item);
      if (evidence.length >= limit) {
        break;
      }
    }
    DebugConsole.log(
      '[VectorGraph] memory retrieval matches=${evidence.length}',
    );
    return evidence;
  }
}

class ObjectBoxLocalRetriever implements LocalRetriever {
  ObjectBoxLocalRetriever({required Store store})
    : _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _documentBox = store.box<KnowledgeDocumentEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _flowchartBox = store.box<FlowchartEntity>(),
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>();

  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? collectionName,
  }) async {
    DebugConsole.log(
      '[VectorGraph] objectbox retrieval start dim=${queryVector.length} '
      'limit=$limit min=$minimumSimilarity',
    );
    final searchLimit = limit < 10 ? 50 : limit * 5;
    final query = _embeddingBox
        .query(
          ChunkEmbeddingEntity_.vector.nearestNeighborsF32(
            queryVector,
            searchLimit,
          ),
        )
        .build();
    try {
      final scored = query.findWithScores();
      final evidence = <SourceEvidence>[];
      for (final item in scored) {
        final similarity = _similarityFromCosineDistance(item.score);
        if (similarity < minimumSimilarity) {
          continue;
        }
        final mapped = _mapEmbedding(item.object, similarity, collectionName);
        if (mapped != null) {
          DebugConsole.log(
            '[VectorGraph] match source=${mapped.id} '
            'type=${mapped.sourceType.wireName} score=${similarity.toStringAsFixed(3)}',
          );
          evidence.add(mapped);
        }
      }
      final limited = evidence.take(limit).toList(growable: false);
      DebugConsole.log(
        '[VectorGraph] objectbox retrieval matches=${limited.length}',
      );
      return limited;
    } finally {
      query.close();
    }
  }

  SourceEvidence? _mapEmbedding(
    ChunkEmbeddingEntity embedding,
    double score,
    String? collectionName,
  ) {
    switch (embedding.sourceType) {
      case 'text_chunk':
        return _mapChunk(embedding.sourceId, score, collectionName);
      case 'flowchart_node':
        return _mapNode(embedding.sourceId, score, collectionName);
      case 'flowchart_edge':
        return _mapEdge(embedding.sourceId, score, collectionName);
    }
    return null;
  }

  SourceEvidence? _mapChunk(
    String publicId,
    double score,
    String? collectionName,
  ) {
    final chunk = _findChunk(publicId);
    if (chunk == null) {
      return null;
    }
    final document = _findDocument(chunk.documentPublicId);
    if (!_documentAllowed(document, collectionName)) {
      return null;
    }
    return SourceEvidence(
      id: chunk.publicId,
      sourceType: EvidenceSourceType.textChunk,
      text: chunk.text,
      label: 'Szöveges PDF-részlet',
      validationState: ValidationState.validated,
      documentId: chunk.documentPublicId,
      pageNumber: chunk.pageNumber,
      ragEnabled: document?.ragEnabled ?? true,
      collectionName: document?.collectionName ?? 'Alap',
      score: score,
    );
  }

  SourceEvidence? _mapNode(
    String publicId,
    double score,
    String? collectionName,
  ) {
    final node = _findNode(publicId);
    if (node == null) {
      return null;
    }
    final validationState = _validationStateFromWire(node.validationState);
    if (validationState == ValidationState.rejected ||
        _flowchartRejected(node.flowchartPublicId)) {
      DebugConsole.log('[VectorGraph] skipped rejected node=${node.publicId}');
      return null;
    }
    final flowchart = _findFlowchart(node.flowchartPublicId);
    final document = flowchart == null
        ? null
        : _findDocument(flowchart.documentPublicId);
    if (!_documentAllowed(document, collectionName)) {
      return null;
    }
    return SourceEvidence(
      id: node.publicId,
      sourceType: EvidenceSourceType.flowchartNode,
      text: node.label,
      label: _flowchartLabel(validationState),
      validationState: validationState,
      documentId: document?.publicId,
      pageNumber: flowchart?.pageNumber,
      ragEnabled: document?.ragEnabled ?? true,
      collectionName: document?.collectionName ?? 'Alap',
      score: score,
    );
  }

  SourceEvidence? _mapEdge(
    String publicId,
    double score,
    String? collectionName,
  ) {
    final edge = _findEdge(publicId);
    if (edge == null) {
      return null;
    }
    final validationState = _validationStateFromWire(edge.validationState);
    if (validationState == ValidationState.rejected ||
        _flowchartRejected(edge.flowchartPublicId)) {
      DebugConsole.log('[VectorGraph] skipped rejected edge=${edge.publicId}');
      return null;
    }
    final flowchart = _findFlowchart(edge.flowchartPublicId);
    final document = flowchart == null
        ? null
        : _findDocument(flowchart.documentPublicId);
    if (!_documentAllowed(document, collectionName)) {
      return null;
    }
    return SourceEvidence(
      id: edge.publicId,
      sourceType: EvidenceSourceType.flowchartEdge,
      text: edge.label,
      label: _flowchartLabel(validationState),
      validationState: validationState,
      documentId: document?.publicId,
      pageNumber: flowchart?.pageNumber,
      ragEnabled: document?.ragEnabled ?? true,
      collectionName: document?.collectionName ?? 'Alap',
      score: score,
    );
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
    final query = _nodeBox
        .query(FlowchartNodeEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  FlowchartEdgeEntity? _findEdge(String publicId) {
    final query = _edgeBox
        .query(FlowchartEdgeEntity_.publicId.equals(publicId))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  bool _flowchartRejected(String publicId) {
    final flowchart = _findFlowchart(publicId);
    return flowchart?.validationState == ValidationState.rejected.wireName;
  }

  bool _documentAllowed(
    KnowledgeDocumentEntity? document,
    String? collectionName,
  ) {
    if (document == null) {
      return true;
    }
    if (!document.ragEnabled) {
      DebugConsole.log(
        '[VectorGraph] skipped disabled document=${document.publicId}',
      );
      return false;
    }
    if (collectionName != null &&
        collectionName.isNotEmpty &&
        document.collectionName != collectionName) {
      return false;
    }
    return true;
  }

  double _similarityFromCosineDistance(double distance) {
    final bounded = distance.clamp(0.0, 2.0).toDouble();
    return 1 - (bounded / 2);
  }

  ValidationState _validationStateFromWire(String value) {
    return ValidationState.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => ValidationState.unreviewed,
    );
  }

  String _flowchartLabel(ValidationState state) {
    return switch (state) {
      ValidationState.validated => 'Validált flowchart',
      ValidationState.partiallyValidated => 'Részben validált flowchart',
      ValidationState.unreviewed ||
      ValidationState.rejected => 'Nem validált flowchart',
    };
  }
}
