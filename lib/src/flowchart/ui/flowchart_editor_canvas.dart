import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../models/editable_flowchart.dart';

class FlowchartEditorCanvas extends StatelessWidget {
  const FlowchartEditorCanvas({
    super.key,
    required this.flowchart,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onDeleteEdge,
  });

  final EditableFlowchart flowchart;
  final ValueChanged<EditableFlowchartNode> onEditNode;
  final ValueChanged<EditableFlowchartNode> onDeleteNode;
  final ValueChanged<EditableFlowchartEdge> onDeleteEdge;

  @override
  Widget build(BuildContext context) {
    final nodesById = {for (final node in flowchart.nodes) node.id: node};
    final edgesByFrom = <String, List<EditableFlowchartEdge>>{};
    for (final edge in flowchart.edges) {
      edgesByFrom.putIfAbsent(edge.fromNodeId, () => []).add(edge);
    }
    final incoming = {for (final node in flowchart.nodes) node.id: 0};
    for (final edge in flowchart.edges) {
      incoming[edge.toNodeId] = (incoming[edge.toNodeId] ?? 0) + 1;
    }
    final roots = flowchart.nodes
        .where((node) => (incoming[node.id] ?? 0) == 0)
        .toList(growable: false);
    final visibleRoots = roots.isEmpty ? flowchart.nodes : roots;
    return SingleChildScrollView(
      key: const ValueKey('flowchart-editor-canvas'),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final root in visibleRoots)
            _NodeTree(
              node: root,
              nodesById: nodesById,
              edgesByFrom: edgesByFrom,
              depth: 0,
              visited: const {},
              onEditNode: onEditNode,
              onDeleteNode: onDeleteNode,
              onDeleteEdge: onDeleteEdge,
            ),
        ],
      ),
    );
  }
}

class _NodeTree extends StatelessWidget {
  const _NodeTree({
    required this.node,
    required this.nodesById,
    required this.edgesByFrom,
    required this.depth,
    required this.visited,
    required this.onEditNode,
    required this.onDeleteNode,
    required this.onDeleteEdge,
  });

  final EditableFlowchartNode node;
  final Map<String, EditableFlowchartNode> nodesById;
  final Map<String, List<EditableFlowchartEdge>> edgesByFrom;
  final int depth;
  final Set<String> visited;
  final ValueChanged<EditableFlowchartNode> onEditNode;
  final ValueChanged<EditableFlowchartNode> onDeleteNode;
  final ValueChanged<EditableFlowchartEdge> onDeleteEdge;

  @override
  Widget build(BuildContext context) {
    final nextVisited = {...visited, node.id};
    final edges = edgesByFrom[node.id] ?? const <EditableFlowchartEdge>[];
    return Padding(
      padding: EdgeInsets.only(left: depth * 18.0, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EditableNodeCard(
            node: node,
            onEdit: () => onEditNode(node),
            onDelete: () => onDeleteNode(node),
          ),
          for (final edge in edges) ...[
            _EditableEdgePill(edge: edge, onDelete: () => onDeleteEdge(edge)),
            if (!nextVisited.contains(edge.toNodeId) && nodesById[edge.toNodeId] != null)
              _NodeTree(
                node: nodesById[edge.toNodeId]!,
                nodesById: nodesById,
                edgesByFrom: edgesByFrom,
                depth: depth + 1,
                visited: nextVisited,
                onEditNode: onEditNode,
                onDeleteNode: onDeleteNode,
                onDeleteEdge: onDeleteEdge,
              ),
          ],
        ],
      ),
    );
  }
}

class _EditableNodeCard extends StatelessWidget {
  const _EditableNodeCard({
    required this.node,
    required this.onEdit,
    required this.onDelete,
  });

  final EditableFlowchartNode node;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('flowchart-editor-node-${node.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(_shapeIcon(node.shape), color: const Color(0xFF7C3AED)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_shapeLabel(node.shape), style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(node.label, style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Elem szerkesztése',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Elem törlése',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableEdgePill extends StatelessWidget {
  const _EditableEdgePill({required this.edge, required this.onDelete});

  final EditableFlowchartEdge edge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InputChip(
          key: ValueKey('flowchart-editor-edge-${edge.id}'),
          avatar: const Icon(Icons.arrow_downward, size: 16),
          label: Text(edge.label.trim().isEmpty ? 'nyíl' : edge.label),
          onDeleted: onDelete,
        ),
      ),
    );
  }
}

IconData _shapeIcon(AiFlowchartNodeShape shape) {
  return switch (shape) {
    AiFlowchartNodeShape.startEnd => Icons.play_circle_outline,
    AiFlowchartNodeShape.decision => Icons.change_history,
    AiFlowchartNodeShape.inputOutput => Icons.input,
    AiFlowchartNodeShape.subprocess => Icons.view_agenda_outlined,
    AiFlowchartNodeShape.dataStore => Icons.storage,
    AiFlowchartNodeShape.connector => Icons.radio_button_unchecked,
    AiFlowchartNodeShape.process => Icons.crop_square,
    AiFlowchartNodeShape.unknown => Icons.help_outline,
  };
}

String _shapeLabel(AiFlowchartNodeShape shape) {
  return switch (shape) {
    AiFlowchartNodeShape.startEnd => 'Kezdés/Vége',
    AiFlowchartNodeShape.decision => 'Döntés',
    AiFlowchartNodeShape.inputOutput => 'Bemenet/Kimenet',
    AiFlowchartNodeShape.subprocess => 'Alfolyamat',
    AiFlowchartNodeShape.dataStore => 'Adattárolás',
    AiFlowchartNodeShape.connector => 'Kapcsoló',
    AiFlowchartNodeShape.process => 'Folyamatlépés',
    AiFlowchartNodeShape.unknown => 'Ismeretlen',
  };
}
