import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';
import '../models/source_evidence.dart';

abstract class LocalRetriever {
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
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
  }) async {
    return _items
        .where((item) => item.validationState != ValidationState.rejected)
        .where((item) => (item.score ?? 1) >= minimumSimilarity)
        .take(limit)
        .toList(growable: false);
  }
}

class ObjectBoxLocalRetriever implements LocalRetriever {
  ObjectBoxLocalRetriever({required Store store})
    : _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _flowchartBox = store.box<FlowchartEntity>(),
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>();

  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
  }) async {
    final query = _embeddingBox
        .query(
          ChunkEmbeddingEntity_.vector.nearestNeighborsF32(queryVector, limit),
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
        final mapped = _mapEmbedding(item.object, similarity);
        if (mapped != null) {
          evidence.add(mapped);
        }
      }
      return evidence.take(limit).toList(growable: false);
    } finally {
      query.close();
    }
  }

  SourceEvidence? _mapEmbedding(ChunkEmbeddingEntity embedding, double score) {
    switch (embedding.sourceType) {
      case 'text_chunk':
        return _mapChunk(embedding.sourceId, score);
      case 'flowchart_node':
        return _mapNode(embedding.sourceId, score);
      case 'flowchart_edge':
        return _mapEdge(embedding.sourceId, score);
    }
    return null;
  }

  SourceEvidence? _mapChunk(String publicId, double score) {
    final chunk = _findChunk(publicId);
    if (chunk == null) {
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
      score: score,
    );
  }

  SourceEvidence? _mapNode(String publicId, double score) {
    final node = _findNode(publicId);
    if (node == null) {
      return null;
    }
    final validationState = _validationStateFromWire(node.validationState);
    if (validationState == ValidationState.rejected ||
        _flowchartRejected(node.flowchartPublicId)) {
      return null;
    }
    return SourceEvidence(
      id: node.publicId,
      sourceType: EvidenceSourceType.flowchartNode,
      text: node.label,
      label: _flowchartLabel(validationState),
      validationState: validationState,
      score: score,
    );
  }

  SourceEvidence? _mapEdge(String publicId, double score) {
    final edge = _findEdge(publicId);
    if (edge == null) {
      return null;
    }
    final validationState = _validationStateFromWire(edge.validationState);
    if (validationState == ValidationState.rejected ||
        _flowchartRejected(edge.flowchartPublicId)) {
      return null;
    }
    return SourceEvidence(
      id: edge.publicId,
      sourceType: EvidenceSourceType.flowchartEdge,
      text: edge.label,
      label: _flowchartLabel(validationState),
      validationState: validationState,
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
    final query = _flowchartBox
        .query(FlowchartEntity_.publicId.equals(publicId))
        .build();
    try {
      final flowchart = query.findFirst();
      return flowchart?.validationState == ValidationState.rejected.wireName;
    } finally {
      query.close();
    }
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
