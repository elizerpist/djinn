import '../../../objectbox.g.dart';
import '../../debug/debug_console.dart';
import '../../local_store/entities.dart';

enum FlowchartZeroReason {
  noProcessedDocuments('no_processed_documents'),
  noDetectedFlowcharts('no_detected_flowcharts'),
  alreadyValidated('already_validated'),
  extractionFailed('extraction_failed');

  const FlowchartZeroReason(this.wireName);

  final String wireName;
}

class FlowchartReviewList {
  const FlowchartReviewList({required this.items, this.zeroReason});

  final List<FlowchartEntity> items;
  final FlowchartZeroReason? zeroReason;
}

abstract class FlowchartValidationRepository {
  Future<FlowchartReviewList> listFlowchartReviewState();

  Future<List<FlowchartEntity>> listFlowchartsNeedingReview();
  Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId);
  Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId);

  Future<void> updateNodeValidation({
    required String nodePublicId,
    required ValidationState state,
    String? rejectionReason,
  });

  Future<void> updateEdgeValidation({
    required String edgePublicId,
    required ValidationState state,
    String? rejectionReason,
  });

  Future<bool> isNodeAnswerable(String nodePublicId);
}

class ObjectBoxFlowchartValidationRepository
    implements FlowchartValidationRepository {
  ObjectBoxFlowchartValidationRepository({required Store store})
    : _flowchartBox = store.box<FlowchartEntity>(),
      _documentBox = store.box<KnowledgeDocumentEntity>(),
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>();

  final Box<FlowchartEntity> _flowchartBox;
  final Box<KnowledgeDocumentEntity> _documentBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;

  @override
  Future<FlowchartReviewList> listFlowchartReviewState() async {
    final allFlowcharts = _flowchartBox.getAll();
    final flowcharts = allFlowcharts
        .where((item) => _needsReview(item.validationState))
        .toList(growable: false);
    final zeroReason = flowcharts.isEmpty ? _zeroReason(allFlowcharts) : null;
    DebugConsole.log(
      '[Flowchart] review list count=${flowcharts.length} '
      'reason=${zeroReason?.wireName ?? 'has_candidates'}',
    );
    return FlowchartReviewList(items: flowcharts, zeroReason: zeroReason);
  }

  @override
  Future<List<FlowchartEntity>> listFlowchartsNeedingReview() async {
    return (await listFlowchartReviewState()).items;
  }

  @override
  Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId) async {
    final nodes = _nodeBox
        .getAll()
        .where((item) => item.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
    DebugConsole.log(
      '[Flowchart] nodes flowchart=$flowchartPublicId count=${nodes.length}',
    );
    return nodes;
  }

  @override
  Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId) async {
    final edges = _edgeBox
        .getAll()
        .where((item) => item.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
    DebugConsole.log(
      '[Flowchart] edges flowchart=$flowchartPublicId count=${edges.length}',
    );
    return edges;
  }

  @override
  Future<void> updateNodeValidation({
    required String nodePublicId,
    required ValidationState state,
    String? rejectionReason,
  }) async {
    final node = _findNode(nodePublicId);
    if (node == null) {
      throw StateError('flowchart node not found: $nodePublicId');
    }
    node.validationState = state.wireName;
    node.rejectionReason = rejectionReason;
    _nodeBox.put(node);
    DebugConsole.log(
      '[Flowchart] node validation node=$nodePublicId state=${state.wireName}',
    );
  }

  @override
  Future<void> updateEdgeValidation({
    required String edgePublicId,
    required ValidationState state,
    String? rejectionReason,
  }) async {
    final edge = _findEdge(edgePublicId);
    if (edge == null) {
      throw StateError('flowchart edge not found: $edgePublicId');
    }
    edge.validationState = state.wireName;
    edge.rejectionReason = rejectionReason;
    _edgeBox.put(edge);
    DebugConsole.log(
      '[Flowchart] edge validation edge=$edgePublicId state=${state.wireName}',
    );
  }

  @override
  Future<bool> isNodeAnswerable(String nodePublicId) async {
    final node = _findNode(nodePublicId);
    return node != null &&
        node.validationState != ValidationState.rejected.wireName;
  }

  FlowchartNodeEntity? _findNode(String nodePublicId) {
    for (final node in _nodeBox.getAll()) {
      if (node.publicId == nodePublicId) {
        return node;
      }
    }
    return null;
  }

  FlowchartEdgeEntity? _findEdge(String edgePublicId) {
    for (final edge in _edgeBox.getAll()) {
      if (edge.publicId == edgePublicId) {
        return edge;
      }
    }
    return null;
  }

  bool _needsReview(String validationState) {
    return validationState == ValidationState.unreviewed.wireName ||
        validationState == ValidationState.partiallyValidated.wireName;
  }

  FlowchartZeroReason _zeroReason(List<FlowchartEntity> allFlowcharts) {
    if (allFlowcharts.isNotEmpty) {
      return FlowchartZeroReason.alreadyValidated;
    }
    final documents = _documentBox.getAll();
    if (documents.any(
      (document) => document.processingState == ProcessingState.failed.wireName,
    )) {
      return FlowchartZeroReason.extractionFailed;
    }
    if (documents.any(_isProcessedDocument)) {
      return FlowchartZeroReason.noDetectedFlowcharts;
    }
    return FlowchartZeroReason.noProcessedDocuments;
  }

  bool _isProcessedDocument(KnowledgeDocumentEntity document) {
    return document.processingState == ProcessingState.ready.wireName ||
        document.processingState == ProcessingState.embedded.wireName ||
        document.processingState == ProcessingState.needsReview.wireName;
  }
}
