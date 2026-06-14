import '../../ai/ai_client.dart';

class EditableFlowchart {
  const EditableFlowchart({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.nodes,
    required this.edges,
    this.title,
  });

  final String id;
  final String documentId;
  final int pageNumber;
  final String? title;
  final List<EditableFlowchartNode> nodes;
  final List<EditableFlowchartEdge> edges;

  EditableFlowchart copyWith({
    String? title,
    List<EditableFlowchartNode>? nodes,
    List<EditableFlowchartEdge>? edges,
  }) {
    return EditableFlowchart(
      id: id,
      documentId: documentId,
      pageNumber: pageNumber,
      title: title ?? this.title,
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
    );
  }
}

class EditableFlowchartNode {
  const EditableFlowchartNode({
    required this.id,
    required this.label,
    this.shape = AiFlowchartNodeShape.process,
    this.order = 0,
  });

  final String id;
  final String label;
  final AiFlowchartNodeShape shape;
  final int order;

  EditableFlowchartNode copyWith({
    String? label,
    AiFlowchartNodeShape? shape,
    int? order,
  }) {
    return EditableFlowchartNode(
      id: id,
      label: label ?? this.label,
      shape: shape ?? this.shape,
      order: order ?? this.order,
    );
  }
}

class EditableFlowchartEdge {
  const EditableFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    this.order = 0,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final int order;

  EditableFlowchartEdge copyWith({
    String? fromNodeId,
    String? toNodeId,
    String? label,
    int? order,
  }) {
    return EditableFlowchartEdge(
      id: id,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      toNodeId: toNodeId ?? this.toNodeId,
      label: label ?? this.label,
      order: order ?? this.order,
    );
  }
}
