import '../../local_store/entities.dart';

class FlowchartViewModel {
  const FlowchartViewModel({
    required this.id,
    required this.nodes,
    required this.edges,
  });

  final String id;
  final List<FlowchartNodeViewModel> nodes;
  final List<FlowchartEdgeViewModel> edges;
}

class FlowchartNodeViewModel {
  const FlowchartNodeViewModel({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.validationState,
    this.rejectionReason,
  });

  final String id;
  final String label;
  final double x;
  final double y;
  final ValidationState validationState;
  final String? rejectionReason;
}

class FlowchartEdgeViewModel {
  const FlowchartEdgeViewModel({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final ValidationState validationState;
  final String? rejectionReason;
}
