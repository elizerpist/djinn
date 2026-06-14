import '../../../objectbox.g.dart';
import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';
import '../../offline/offline_search_service.dart';
import '../models/source_evidence.dart';

abstract class LocalRetriever {
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
  });

  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
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
    String? query,
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

  @override
  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
  }) async {
    return _offlineSearchEvidence(
      query: query,
      limit: limit,
      evidence: _items
          .where((item) => item.validationState != ValidationState.rejected)
          .toList(growable: false),
    );
  }
}

class ObjectBoxLocalRetriever implements LocalRetriever {
  ObjectBoxLocalRetriever({required Store store})
    : _embeddingBox = store.box<ChunkEmbeddingEntity>(),
      _chunkBox = store.box<DocumentChunkEntity>(),
      _flowchartBox = store.box<FlowchartEntity>(),
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>(),
      _knowledgeEdgeBox = store.box<KnowledgeEdgeEntity>(),
      _knowledgeEvidenceBox = store.box<KnowledgeEvidenceEntity>();

  final Box<ChunkEmbeddingEntity> _embeddingBox;
  final Box<DocumentChunkEntity> _chunkBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;
  final Box<KnowledgeEdgeEntity> _knowledgeEdgeBox;
  final Box<KnowledgeEvidenceEntity> _knowledgeEvidenceBox;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
    String? query,
  }) async {
    DebugConsole.log(
      '[VectorGraph] objectbox retrieval start dim=${queryVector.length} '
      'limit=$limit min=$minimumSimilarity',
    );
    final embeddingQuery = _embeddingBox
        .query(
          ChunkEmbeddingEntity_.vector.nearestNeighborsF32(queryVector, limit),
        )
        .build();
    try {
      final scored = embeddingQuery.findWithScores();
      final evidence = <SourceEvidence>[];
      for (final item in scored) {
        final similarity = _similarityFromCosineDistance(item.score);
        if (similarity < minimumSimilarity) {
          continue;
        }
        final mapped = _mapEmbedding(item.object, similarity);
        if (mapped != null) {
          DebugConsole.log(
            '[VectorGraph] match source=${mapped.id} '
            'type=${mapped.sourceType.wireName} score=${similarity.toStringAsFixed(3)}',
          );
          evidence.add(mapped);
        }
      }
      final expanded = _expandWithLocalKeywordEvidence(
        query: query,
        existing: evidence,
        limit: limit,
      );
      final limited = expanded.take(limit).toList(growable: false);
      final vectorIds = evidence.map((item) => item.id).toSet();
      final expandedCount = limited
          .where((item) => !vectorIds.contains(item.id))
          .length;
      DebugConsole.log(
        '[VectorGraph] objectbox retrieval matches=${limited.length} '
        'vector=${evidence.length} expanded=$expandedCount',
      );
      return limited;
    } finally {
      embeddingQuery.close();
    }
  }

  @override
  Future<List<SourceEvidence>> retrieveOffline({
    required String query,
    required int limit,
  }) async {
    final evidence = <SourceEvidence>[];
    final embeddingsBySourceId = {
      for (final embedding in _embeddingBox.getAll())
        embedding.sourceId: embedding,
    };
    for (final chunk in _chunkBox.getAll()) {
      final sourceType = _sourceTypeFromWireName(
        embeddingsBySourceId[chunk.publicId]?.sourceType ??
            EvidenceSourceType.textChunk.wireName,
      );
      final validationState = _chunkValidationState(chunk);
      if (validationState == ValidationState.rejected) {
        continue;
      }
      evidence.add(
        SourceEvidence(
          id: chunk.publicId,
          sourceType: sourceType,
          text: chunk.text,
          label: _chunkLabel(sourceType),
          validationState: validationState,
          documentId: chunk.documentPublicId,
          pageNumber: chunk.pageNumber,
        ),
      );
    }
    for (final node in _nodeBox.getAll()) {
      final state = _validationStateFromWire(node.validationState);
      if (state == ValidationState.rejected ||
          _flowchartRejected(node.flowchartPublicId)) {
        continue;
      }
      final flowchart = _findFlowchart(node.flowchartPublicId);
      evidence.add(
        SourceEvidence(
          id: node.publicId,
          sourceType: EvidenceSourceType.flowchartNode,
          text: node.label,
          label: _flowchartLabel(state),
          validationState: state,
          documentId: flowchart?.documentPublicId,
          pageNumber: flowchart?.pageNumber,
        ),
      );
    }
    for (final edge in _edgeBox.getAll()) {
      final state = _validationStateFromWire(edge.validationState);
      if (state == ValidationState.rejected ||
          _flowchartRejected(edge.flowchartPublicId)) {
        continue;
      }
      final flowchart = _findFlowchart(edge.flowchartPublicId);
      evidence.add(
        SourceEvidence(
          id: edge.publicId,
          sourceType: EvidenceSourceType.flowchartEdge,
          text: _edgeRelation(edge),
          label: _flowchartLabel(state),
          validationState: state,
          documentId: flowchart?.documentPublicId,
          pageNumber: flowchart?.pageNumber,
        ),
      );
    }
    return _offlineSearchEvidence(
      query: query,
      limit: limit,
      evidence: evidence,
    );
  }


  List<SourceEvidence> _expandWithLocalKeywordEvidence({
    required String? query,
    required List<SourceEvidence> existing,
    required int limit,
  }) {
    final trimmed = query?.trim();
    if (trimmed == null || trimmed.isEmpty || existing.length >= limit) {
      return existing;
    }
    final existingIds = existing.map((item) => item.id).toSet();
    final localEvidence = <SourceEvidence>[];
    for (final chunk in _chunkBox.getAll()) {
      if (chunk.pipeline == 'ai' || existingIds.contains(chunk.publicId)) {
        continue;
      }
      final validationState = _chunkValidationState(chunk);
      if (validationState == ValidationState.rejected) {
        continue;
      }
      localEvidence.add(
        SourceEvidence(
          id: chunk.publicId,
          sourceType: _sourceTypeFromLocalChunkKind(chunk.chunkKind),
          text: chunk.text,
          label: 'Lokális OCR chunk',
          validationState: validationState,
          documentId: chunk.documentPublicId,
          pageNumber: chunk.pageNumber,
        ),
      );
    }
    final keywordMatches = _offlineSearchEvidence(
      query: trimmed,
      limit: limit - existing.length,
      evidence: localEvidence,
    );
    final graphMatches = _expandWithGraphEvidence(
      seeds: keywordMatches,
      existing: [...existing, ...keywordMatches],
      limit: limit,
    );
    DebugConsole.log(
      '[VectorGraph] keyword expansion candidates=${localEvidence.length} '
      'matches=${keywordMatches.length}',
    );
    return [...existing, ...keywordMatches, ...graphMatches];
  }

  List<SourceEvidence> _expandWithGraphEvidence({
    required List<SourceEvidence> seeds,
    required List<SourceEvidence> existing,
    required int limit,
  }) {
    if (seeds.isEmpty || existing.length >= limit) {
      DebugConsole.log('[VectorGraph] graph expansion seeds=${seeds.length} edges=0 matches=0');
      return const [];
    }
    final existingIds = existing.map((item) => item.id).toSet();
    final seedSourceIds = seeds.map((item) => item.id).toSet();
    final seedNodeIds = _knowledgeEvidenceBox
        .getAll()
        .where((evidence) => seedSourceIds.contains(evidence.sourceId))
        .map((evidence) => evidence.nodePublicId)
        .toSet();
    if (seedNodeIds.isEmpty) {
      DebugConsole.log('[VectorGraph] graph expansion seeds=${seeds.length} edges=0 matches=0');
      return const [];
    }
    final edges = _knowledgeEdgeBox
        .getAll()
        .where(
          (edge) =>
              seedNodeIds.contains(edge.fromNodePublicId) ||
              seedNodeIds.contains(edge.toNodePublicId),
        )
        .toList(growable: false);
    final neighborNodeIds = <String>{};
    for (final edge in edges) {
      if (!seedNodeIds.contains(edge.fromNodePublicId)) {
        neighborNodeIds.add(edge.fromNodePublicId);
      }
      if (!seedNodeIds.contains(edge.toNodePublicId)) {
        neighborNodeIds.add(edge.toNodePublicId);
      }
    }
    final results = <SourceEvidence>[];
    for (final evidence in _knowledgeEvidenceBox.getAll()) {
      if (results.length + existing.length >= limit) {
        break;
      }
      if (!neighborNodeIds.contains(evidence.nodePublicId) ||
          existingIds.contains(evidence.sourceId)) {
        continue;
      }
      final chunk = _findChunk(evidence.sourceId);
      if (chunk == null || chunk.pipeline == 'ai') {
        continue;
      }
      final validationState = _chunkValidationState(chunk);
      if (validationState == ValidationState.rejected) {
        continue;
      }
      results.add(
        SourceEvidence(
          id: chunk.publicId,
          sourceType: _sourceTypeFromLocalChunkKind(chunk.chunkKind),
          text: chunk.text,
          label: 'Lokális graph kapcsolat',
          validationState: validationState,
          documentId: chunk.documentPublicId,
          pageNumber: chunk.pageNumber,
        ),
      );
    }
    DebugConsole.log(
      '[VectorGraph] graph expansion seeds=${seeds.length} '
      'edges=${edges.length} matches=${results.length}',
    );
    return results;
  }

  ValidationState _chunkValidationState(DocumentChunkEntity chunk) {
    return switch (chunk.auditState) {
      'accepted' || 'edited' => ValidationState.validated,
      'rejected' => ValidationState.rejected,
      _ => ValidationState.unreviewed,
    };
  }

  EvidenceSourceType _sourceTypeFromLocalChunkKind(String value) {
    return switch (value) {
      'table' => EvidenceSourceType.tableChunk,
      'score' => EvidenceSourceType.scoreChunk,
      'flowchart' => EvidenceSourceType.flowchartNode,
      _ => EvidenceSourceType.textChunk,
    };
  }

  SourceEvidence? _mapEmbedding(ChunkEmbeddingEntity embedding, double score) {
    switch (embedding.sourceType) {
      case 'text_chunk':
        return _mapChunk(
          embedding.sourceId,
          score,
          EvidenceSourceType.textChunk,
        );
      case 'table_chunk':
        return _mapChunk(
          embedding.sourceId,
          score,
          EvidenceSourceType.tableChunk,
        );
      case 'score_chunk':
        return _mapChunk(
          embedding.sourceId,
          score,
          EvidenceSourceType.scoreChunk,
        );
      case 'flowchart_node':
        return _mapNode(embedding.sourceId, score);
      case 'flowchart_edge':
        return _mapEdge(embedding.sourceId, score);
    }
    return null;
  }

  SourceEvidence? _mapChunk(
    String publicId,
    double score,
    EvidenceSourceType sourceType,
  ) {
    final chunk = _findChunk(publicId);
    if (chunk == null) {
      return null;
    }
    final validationState = _chunkValidationState(chunk);
    if (validationState == ValidationState.rejected) {
      DebugConsole.log('[VectorGraph] skipped rejected chunk=${chunk.publicId}');
      return null;
    }
    return SourceEvidence(
      id: chunk.publicId,
      sourceType: sourceType,
      text: chunk.text,
      label: _chunkLabel(sourceType),
      validationState: validationState,
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
      DebugConsole.log('[VectorGraph] skipped rejected node=${node.publicId}');
      return null;
    }
    final flowchart = _findFlowchart(node.flowchartPublicId);
    return SourceEvidence(
      id: node.publicId,
      sourceType: EvidenceSourceType.flowchartNode,
      text: node.label,
      label: _flowchartLabel(validationState),
      validationState: validationState,
      documentId: flowchart?.documentPublicId,
      pageNumber: flowchart?.pageNumber,
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
      DebugConsole.log('[VectorGraph] skipped rejected edge=${edge.publicId}');
      return null;
    }
    final flowchart = _findFlowchart(edge.flowchartPublicId);
    return SourceEvidence(
      id: edge.publicId,
      sourceType: EvidenceSourceType.flowchartEdge,
      text: _edgeRelation(edge),
      label: _flowchartLabel(validationState),
      validationState: validationState,
      documentId: flowchart?.documentPublicId,
      pageNumber: flowchart?.pageNumber,
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

  String _edgeRelation(FlowchartEdgeEntity edge) {
    final from =
        _findNode(edge.fromNodePublicId)?.label ?? edge.fromNodePublicId;
    final to = _findNode(edge.toNodePublicId)?.label ?? edge.toNodePublicId;
    final label = edge.label.trim();
    return label.isEmpty ? '$from -> $to' : '$from -> $to [$label]';
  }

  bool _flowchartRejected(String publicId) {
    final flowchart = _findFlowchart(publicId);
    return flowchart?.validationState == ValidationState.rejected.wireName;
  }

  EvidenceSourceType _sourceTypeFromWireName(String value) {
    return EvidenceSourceType.values.firstWhere(
      (item) => item.wireName == value,
      orElse: () => EvidenceSourceType.textChunk,
    );
  }

  String _chunkLabel(EvidenceSourceType sourceType) {
    return switch (sourceType) {
      EvidenceSourceType.textChunk => 'Szöveges PDF-részlet',
      EvidenceSourceType.tableChunk => 'Táblázatból kinyert részlet',
      EvidenceSourceType.scoreChunk => 'Score elem',
      EvidenceSourceType.flowchartNode ||
      EvidenceSourceType.flowchartEdge => 'Flowchart elem',
    };
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

List<SourceEvidence> _offlineSearchEvidence({
  required String query,
  required int limit,
  required List<SourceEvidence> evidence,
}) {
  DebugConsole.log('[Offline] search start chars=${query.length} limit=$limit');
  final byId = {for (final item in evidence) item.id: item};
  final results = const OfflineSearchService().search(
    query: query,
    limit: limit,
    chunks: evidence
        .map(
          (item) =>
              OfflineChunk(id: item.id, label: item.label, text: item.text),
        )
        .toList(growable: false),
  );
  final matched = results
      .map((result) => byId[result.id])
      .whereType<SourceEvidence>()
      .toList(growable: false);
  DebugConsole.log('[Offline] search matches=${matched.length}');
  return matched;
}
