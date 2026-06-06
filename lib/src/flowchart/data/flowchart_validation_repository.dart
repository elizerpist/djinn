import '../../../objectbox.g.dart';
import '../../local_store/entities.dart';

abstract class FlowchartValidationRepository {
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
      _nodeBox = store.box<FlowchartNodeEntity>(),
      _edgeBox = store.box<FlowchartEdgeEntity>();

  final Box<FlowchartEntity> _flowchartBox;
  final Box<FlowchartNodeEntity> _nodeBox;
  final Box<FlowchartEdgeEntity> _edgeBox;

  @override
  Future<List<FlowchartEntity>> listFlowchartsNeedingReview() async {
    return _flowchartBox
        .getAll()
        .where((item) => _needsReview(item.validationState))
        .toList(growable: false);
  }

  @override
  Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId) async {
    return _nodeBox
        .getAll()
        .where((item) => item.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
  }

  @override
  Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId) async {
    return _edgeBox
        .getAll()
        .where((item) => item.flowchartPublicId == flowchartPublicId)
        .toList(growable: false);
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
}
