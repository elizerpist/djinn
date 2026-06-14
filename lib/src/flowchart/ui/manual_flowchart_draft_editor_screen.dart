import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../models/editable_flowchart.dart';
import 'flowchart_editor_canvas.dart';

class ManualFlowchartDraftEditorScreen extends StatefulWidget {
  const ManualFlowchartDraftEditorScreen({
    super.key,
    required this.initialText,
    required this.documentId,
    required this.pageNumber,
  });

  final String initialText;
  final String documentId;
  final int pageNumber;

  @override
  State<ManualFlowchartDraftEditorScreen> createState() =>
      _ManualFlowchartDraftEditorScreenState();
}

class _ManualFlowchartDraftEditorScreenState
    extends State<ManualFlowchartDraftEditorScreen> {
  late EditableFlowchart _flowchart;

  @override
  void initState() {
    super.initState();
    _flowchart = _fromText(widget.initialText);
  }

  EditableFlowchart _fromText(String text) {
    final labels = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final nodeLabels = labels.isEmpty ? ['Kezdés'] : labels;
    final nodes = [
      for (var i = 0; i < nodeLabels.length; i += 1)
        EditableFlowchartNode(
          id: 'draft-node-${i + 1}',
          label: nodeLabels[i],
          shape: i == 0
              ? AiFlowchartNodeShape.startEnd
              : AiFlowchartNodeShape.process,
          order: i + 1,
        ),
    ];
    final edges = [
      for (var i = 0; i < nodes.length - 1; i += 1)
        EditableFlowchartEdge(
          id: 'draft-edge-${i + 1}',
          fromNodeId: nodes[i].id,
          toNodeId: nodes[i + 1].id,
          label: '',
          order: i + 1,
        ),
    ];
    return EditableFlowchart(
      id: 'manual-flowchart-draft',
      documentId: widget.documentId,
      pageNumber: widget.pageNumber,
      title: 'Kézi flowchart',
      nodes: nodes,
      edges: edges,
    );
  }

  String _nextNodeId() {
    var index = _flowchart.nodes.length + 1;
    while (_flowchart.nodes.any((node) => node.id == 'draft-node-$index')) {
      index += 1;
    }
    return 'draft-node-$index';
  }

  String _nextEdgeId() {
    var index = _flowchart.edges.length + 1;
    while (_flowchart.edges.any((edge) => edge.id == 'draft-edge-$index')) {
      index += 1;
    }
    return 'draft-edge-$index';
  }

  Future<void> _addNode() async {
    final node = await _showNodeDialog();
    if (node == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(nodes: [..._flowchart.nodes, node]);
    });
  }

  Future<void> _editNode(EditableFlowchartNode node) async {
    final edited = await _showNodeDialog(existing: node);
    if (edited == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(
        nodes: [
          for (final current in _flowchart.nodes)
            if (current.id == node.id) edited else current,
        ],
      );
    });
  }

  void _deleteNode(EditableFlowchartNode node) {
    setState(() {
      _flowchart = _flowchart.copyWith(
        nodes: _flowchart.nodes.where((item) => item.id != node.id).toList(),
        edges: _flowchart.edges
            .where((edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id)
            .toList(),
      );
    });
  }

  Future<EditableFlowchartNode?> _showNodeDialog({
    EditableFlowchartNode? existing,
  }) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    var shape = existing?.shape ?? AiFlowchartNodeShape.process;
    final order = existing?.order ?? _flowchart.nodes.length + 1;
    final result = await showDialog<EditableFlowchartNode>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Új flowchart elem' : 'Elem szerkesztése'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('manual-flowchart-node-label-field'),
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Felirat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiFlowchartNodeShape>(
                key: const ValueKey('manual-flowchart-node-shape-field'),
                initialValue: shape,
                decoration: const InputDecoration(
                  labelText: 'Típus',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final option in AiFlowchartNodeShape.values)
                    if (option != AiFlowchartNodeShape.unknown)
                      DropdownMenuItem(value: option, child: Text(_shapeLabel(option))),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => shape = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: () {
                final label = labelController.text.trim();
                if (label.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(
                  EditableFlowchartNode(
                    id: existing?.id ?? _nextNodeId(),
                    label: label,
                    shape: shape,
                    order: order,
                  ),
                );
              },
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    return result;
  }

  Future<void> _addEdge() async {
    if (_flowchart.nodes.length < 2) {
      return;
    }
    var from = _flowchart.nodes.first.id;
    var to = _flowchart.nodes.last.id;
    final labelController = TextEditingController();
    final edge = await showDialog<EditableFlowchartEdge>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Új kapcsolat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NodeDropdown(
                keyValue: 'manual-flowchart-edge-from-field',
                label: 'Innen',
                value: from,
                nodes: _flowchart.nodes,
                onChanged: (value) => setDialogState(() => from = value),
              ),
              const SizedBox(height: 12),
              _NodeDropdown(
                keyValue: 'manual-flowchart-edge-to-field',
                label: 'Ide',
                value: to,
                nodes: _flowchart.nodes,
                onChanged: (value) => setDialogState(() => to = value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('manual-flowchart-edge-label-field'),
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Ág felirata',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Mégse'),
            ),
            FilledButton(
              onPressed: from == to
                  ? null
                  : () => Navigator.of(context).pop(
                        EditableFlowchartEdge(
                          id: _nextEdgeId(),
                          fromNodeId: from,
                          toNodeId: to,
                          label: labelController.text.trim(),
                          order: _flowchart.edges.length + 1,
                        ),
                      ),
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
    if (edge == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(edges: [..._flowchart.edges, edge]);
    });
  }

  void _deleteEdge(EditableFlowchartEdge edge) {
    setState(() {
      _flowchart = _flowchart.copyWith(
        edges: _flowchart.edges.where((item) => item.id != edge.id).toList(),
      );
    });
  }

  void _save() {
    Navigator.of(context).pop(_serialize());
  }

  String _serialize() {
    final nodesById = {for (final node in _flowchart.nodes) node.id: node};
    final lines = <String>['[flowchart]'];
    final nodes = [..._flowchart.nodes]
      ..sort((a, b) => a.order.compareTo(b.order));
    final edges = [..._flowchart.edges]
      ..sort((a, b) => a.order.compareTo(b.order));
    for (final node in nodes) {
      lines.add('node ${node.id} | ${node.shape.wireName} | ${node.label}');
    }
    for (final edge in edges) {
      final from = nodesById[edge.fromNodeId]?.label ?? edge.fromNodeId;
      final to = nodesById[edge.toNodeId]?.label ?? edge.toNodeId;
      final label = edge.label.trim();
      lines.add(
        label.isEmpty ? 'edge $from -> $to' : 'edge $from -> $to [$label]',
      );
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kézi flowchart szerkesztő'),
        actions: [
          TextButton.icon(
            key: const ValueKey('manual-flowchart-save'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Mentés'),
          ),
        ],
      ),
      body: FlowchartEditorCanvas(
        flowchart: _flowchart,
        onEditNode: _editNode,
        onDeleteNode: _deleteNode,
        onDeleteEdge: _deleteEdge,
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            key: const ValueKey('manual-flowchart-add-edge'),
            heroTag: 'manual-add-edge',
            onPressed: _addEdge,
            child: const Icon(Icons.add_link),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            key: const ValueKey('manual-flowchart-add-node'),
            heroTag: 'manual-add-node',
            onPressed: _addNode,
            icon: const Icon(Icons.add),
            label: const Text('Elem'),
          ),
        ],
      ),
    );
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
}

class _NodeDropdown extends StatelessWidget {
  const _NodeDropdown({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.nodes,
    required this.onChanged,
  });

  final String keyValue;
  final String label;
  final String value;
  final List<EditableFlowchartNode> nodes;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(keyValue),
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final node in nodes)
          DropdownMenuItem(value: node.id, child: Text(node.label)),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}
