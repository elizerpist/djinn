import '../../../objectbox.g.dart';
import '../../chunks/data/chunk_entity_codec.dart';
import '../../chunks/models/chunk.dart';
import '../../knowledge/models/local_extraction.dart';
import '../../local_store/entities.dart';

enum CanonicalFlowchartProjectionAction { project, remove }

CanonicalFlowchartProjectionAction canonicalFlowchartProjectionAction({
  required String documentPublicId,
  required bool isNoteLinked,
}) {
  return documentPublicId.trim().isNotEmpty || isNoteLinked
      ? CanonicalFlowchartProjectionAction.project
      : CanonicalFlowchartProjectionAction.remove;
}

/// Compatibility projection between the canonical FlowchartChunk row and the
/// legacy flowchart tables still used by the validation UI.
///
/// Chunk content is authoritative. Legacy node/edge rows are a derived view;
/// only their per-element validation fields are preserved across projection.
class ObjectBoxFlowchartProjection {
  ObjectBoxFlowchartProjection({
    required Store store,
    ChunkEntityCodec codec = const ChunkEntityCodec(),
  }) : _chunkBox = store.box<DocumentChunkEntity>(),
       _flowchartBox = store.box<FlowchartEntity>(),
       _nodeBox = store.box<FlowchartNodeEntity>(),
       _edgeBox = store.box<FlowchartEdgeEntity>(),
       _linkBox = store.box<ChunkNoteLinkEntity>(),
       _codec = codec;

  final Box<DocumentChunkEntity> _chunkBox;
  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;
  final Box<ChunkNoteLinkEntity> _linkBox;
  final ChunkEntityCodec _codec;

  void projectCanonicalChunk(DocumentChunkEntity entity) {
    final chunk = _codec.decode(entity);
    if (chunk.kind != ChunkKind.flowchartChunk) {
      removeProjection(entity.publicId);
      return;
    }
    final isNoteLinked = _linkBox.getAll().any(
      (link) => link.chunkPublicId == entity.publicId,
    );
    if (canonicalFlowchartProjectionAction(
          documentPublicId: entity.documentPublicId,
          isNoteLinked: isNoteLinked,
        ) ==
        CanonicalFlowchartProjectionAction.remove) {
      removeProjection(entity.publicId);
      return;
    }
    final flowchartId = entity.publicId;
    final existingFlowchart = _findFlowchart(flowchartId);
    final validation = _validationForAudit(chunk.validationState).wireName;
    _flowchartBox.put(
      FlowchartEntity(
        id: existingFlowchart?.id ?? 0,
        publicId: flowchartId,
        documentPublicId: entity.documentPublicId,
        pageNumber: chunk.source.pageStart ?? entity.pageNumber,
        validationState: validation,
        sourceRectJson:
            chunk.source.sourceRectJson ?? existingFlowchart?.sourceRectJson,
        extractionConfidence:
            entity.confidence ?? existingFlowchart?.extractionConfidence,
      ),
    );

    final existingNodes = {
      for (final node in _nodes(flowchartId)) node.publicId: node,
    };
    final retainedNodeIds = <String>{};
    final projectedNodeIdByCanonicalId = <String, String>{};
    for (var index = 0; index < chunk.content.nodes.length; index += 1) {
      final node = chunk.content.nodes[index];
      final nodeId = _projectedElementId(
        flowchartId,
        node.id,
        fallback: 'node-${index + 1}',
      );
      projectedNodeIdByCanonicalId[node.id] = nodeId;
      retainedNodeIds.add(nodeId);
      final existing = existingNodes[nodeId];
      _nodeBox.put(
        FlowchartNodeEntity(
          id: existing?.id ?? 0,
          publicId: nodeId,
          flowchartPublicId: flowchartId,
          label: node.label,
          validationState: existing?.validationState ?? validation,
          rejectionReason: existing?.rejectionReason,
          positionX: node.x,
          positionY: node.y,
          shape: node.shape.wireName,
          sortOrder: node.order == 0 ? index : node.order,
          sourceRectJson: existing?.sourceRectJson,
          colorSlot: existing?.colorSlot,
        ),
      );
    }
    final staleNodeRowIds = existingNodes.values
        .where((node) => !retainedNodeIds.contains(node.publicId))
        .map((node) => node.id)
        .toList(growable: false);

    final existingEdges = {
      for (final edge in _edges(flowchartId)) edge.publicId: edge,
    };
    final retainedEdgeIds = <String>{};
    for (var index = 0; index < chunk.content.edges.length; index += 1) {
      final edge = chunk.content.edges[index];
      final edgeId = _projectedElementId(
        flowchartId,
        edge.id,
        fallback: 'edge-${index + 1}',
      );
      final fromNodeId =
          projectedNodeIdByCanonicalId[edge.fromNodeId] ??
          _projectedElementId(
            flowchartId,
            edge.fromNodeId,
            fallback: 'missing-from-${index + 1}',
          );
      final toNodeId =
          projectedNodeIdByCanonicalId[edge.toNodeId] ??
          _projectedElementId(
            flowchartId,
            edge.toNodeId,
            fallback: 'missing-to-${index + 1}',
          );
      retainedEdgeIds.add(edgeId);
      final existing = existingEdges[edgeId];
      _edgeBox.put(
        FlowchartEdgeEntity(
          id: existing?.id ?? 0,
          publicId: edgeId,
          flowchartPublicId: flowchartId,
          fromNodePublicId: fromNodeId,
          toNodePublicId: toNodeId,
          label: edge.label,
          validationState: existing?.validationState ?? validation,
          rejectionReason: existing?.rejectionReason,
          sortOrder: edge.order == 0 ? index : edge.order,
          sourceRectJson: existing?.sourceRectJson,
        ),
      );
    }
    final staleEdgeRowIds = existingEdges.values
        .where((edge) => !retainedEdgeIds.contains(edge.publicId))
        .map((edge) => edge.id)
        .toList(growable: false);
    if (staleEdgeRowIds.isNotEmpty) {
      _edgeBox.removeMany(staleEdgeRowIds);
    }
    if (staleNodeRowIds.isNotEmpty) {
      _nodeBox.removeMany(staleNodeRowIds);
    }
  }

  void removeProjection(String flowchartPublicId) {
    final edgeIds = _edges(
      flowchartPublicId,
    ).map((edge) => edge.id).toList(growable: false);
    final nodeIds = _nodes(
      flowchartPublicId,
    ).map((node) => node.id).toList(growable: false);
    final flowchartIds = _flowchartBox
        .getAll()
        .where((flowchart) => flowchart.publicId == flowchartPublicId)
        .map((flowchart) => flowchart.id)
        .toList(growable: false);
    if (edgeIds.isNotEmpty) {
      _edgeBox.removeMany(edgeIds);
    }
    if (nodeIds.isNotEmpty) {
      _nodeBox.removeMany(nodeIds);
    }
    if (flowchartIds.isNotEmpty) {
      _flowchartBox.removeMany(flowchartIds);
    }
  }

  void synchronizeCanonicalValidation(String flowchartPublicId) {
    final flowchart = _findFlowchart(flowchartPublicId);
    if (flowchart == null) {
      return;
    }
    final states = <String>[
      for (final node in _nodes(flowchartPublicId)) node.validationState,
      for (final edge in _edges(flowchartPublicId)) edge.validationState,
    ];
    final aggregate = _aggregateValidation(states);
    flowchart.validationState = aggregate.wireName;
    _flowchartBox.put(flowchart);

    final entity = _findChunk(flowchartPublicId);
    if (entity == null) {
      return;
    }
    final decoded = _codec.decode(entity);
    if (decoded.kind != ChunkKind.flowchartChunk) {
      return;
    }
    final now = DateTime.now();
    final updated = FlowchartChunk(
      id: decoded.id,
      creationMethod: decoded.creationMethod,
      validationState: _auditForValidation(aggregate),
      source: decoded.source,
      createdAt: decoded.createdAt,
      updatedAt: now,
      content: decoded.content,
    );
    _codec.write(entity, updated, now: now);
    _chunkBox.put(entity);
  }

  ValidationState _aggregateValidation(List<String> states) {
    if (states.isEmpty) {
      return ValidationState.unreviewed;
    }
    if (states.every((state) => state == ValidationState.validated.wireName)) {
      return ValidationState.validated;
    }
    if (states.every((state) => state == ValidationState.rejected.wireName)) {
      return ValidationState.rejected;
    }
    if (states.any(
      (state) =>
          state == ValidationState.validated.wireName ||
          state == ValidationState.rejected.wireName,
    )) {
      return ValidationState.partiallyValidated;
    }
    return ValidationState.unreviewed;
  }

  ValidationState _validationForAudit(LocalAuditState state) {
    return switch (state) {
      LocalAuditState.accepted ||
      LocalAuditState.edited => ValidationState.validated,
      LocalAuditState.rejected => ValidationState.rejected,
      LocalAuditState.unreviewed => ValidationState.unreviewed,
    };
  }

  LocalAuditState _auditForValidation(ValidationState state) {
    return switch (state) {
      ValidationState.validated ||
      ValidationState.partiallyValidated => LocalAuditState.accepted,
      ValidationState.rejected => LocalAuditState.rejected,
      ValidationState.unreviewed => LocalAuditState.unreviewed,
    };
  }

  String _projectedElementId(
    String flowchartId,
    String requested, {
    required String fallback,
  }) {
    final trimmed = requested.trim();
    final localId = trimmed.isEmpty ? fallback : trimmed;
    return localId.startsWith('$flowchartId:')
        ? localId
        : '$flowchartId:$localId';
  }

  FlowchartEntity? _findFlowchart(String publicId) {
    return _flowchartBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  DocumentChunkEntity? _findChunk(String publicId) {
    return _chunkBox
        .getAll()
        .where((entity) => entity.publicId == publicId)
        .firstOrNull;
  }

  List<FlowchartNodeEntity> _nodes(String flowchartId) {
    return _nodeBox
        .getAll()
        .where((node) => node.flowchartPublicId == flowchartId)
        .toList(growable: false);
  }

  List<FlowchartEdgeEntity> _edges(String flowchartId) {
    return _edgeBox
        .getAll()
        .where((edge) => edge.flowchartPublicId == flowchartId)
        .toList(growable: false);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
