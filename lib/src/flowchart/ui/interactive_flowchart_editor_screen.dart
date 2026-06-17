import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../models/editable_flowchart.dart';
import 'flowchart_editor_canvas.dart';

class InteractiveFlowchartEditorScreen extends StatefulWidget {
  const InteractiveFlowchartEditorScreen({
    super.key,
    required this.repository,
    required this.documentId,
    required this.flowchartId,
  });

  final KnowledgeDocumentRepository repository;
  final String documentId;
  final String flowchartId;

  @override
  State<InteractiveFlowchartEditorScreen> createState() =>
      _InteractiveFlowchartEditorScreenState();
}

class _InteractiveFlowchartEditorScreenState
    extends State<InteractiveFlowchartEditorScreen> {
  late Future<EditableFlowchart?> _future;
  EditableFlowchart? _flowchart;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<EditableFlowchart?> _load() async {
    final flowchart = await widget.repository.loadEditableFlowchart(
      documentId: widget.documentId,
      flowchartId: widget.flowchartId,
    );
    _flowchart = flowchart;
    return flowchart;
  }

  Future<void> _save() async {
    final flowchart = _flowchart;
    if (flowchart == null) {
      return;
    }
    setState(() => _saving = true);
    await widget.repository.saveEditableFlowchart(flowchart);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  String _nextNodeId() {
    final flowchart = _flowchart!;
    var index = flowchart.nodes.length + 1;
    while (flowchart.nodes.any((node) => node.id.endsWith('node-$index') || node.id == 'node-$index')) {
      index += 1;
    }
    return flowchart.id.contains(':') ? '${flowchart.id}:node-$index' : 'node-$index';
  }

  String _nextEdgeId() {
    final flowchart = _flowchart!;
    var index = flowchart.edges.length + 1;
    while (flowchart.edges.any((edge) => edge.id.endsWith('edge-$index') || edge.id == 'edge-$index')) {
      index += 1;
    }
    return flowchart.id.contains(':') ? '${flowchart.id}:edge-$index' : 'edge-$index';
  }

  Future<void> _addNode() async {
    final node = await _showNodeDialog();
    if (node == null || _flowchart == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart!.copyWith(nodes: [..._flowchart!.nodes, node]);
    });
  }

  Future<void> _editNode(EditableFlowchartNode node) async {
    final edited = await _showNodeDialog(existing: node);
    if (edited == null || _flowchart == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart!.copyWith(
        nodes: [
          for (final current in _flowchart!.nodes)
            if (current.id == node.id) edited else current,
        ],
      );
    });
  }

  void _deleteNode(EditableFlowchartNode node) {
    final flowchart = _flowchart;
    if (flowchart == null) {
      return;
    }
    setState(() {
      _flowchart = flowchart.copyWith(
        nodes: flowchart.nodes.where((item) => item.id != node.id).toList(),
        edges: flowchart.edges
            .where((edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id)
            .toList(),
      );
    });
  }

  Future<EditableFlowchartNode?> _showNodeDialog({
    EditableFlowchartNode? existing,
  }) async {
    final nextOrder = (_flowchart?.nodes.length ?? 0) + 1;
    return showDialog<EditableFlowchartNode>(
      context: context,
      builder: (context) => _FlowchartNodeDialog(
        existing: existing,
        nodeId: existing?.id ?? _nextNodeId(),
        order: existing?.order ?? nextOrder,
        labelFieldKey: 'flowchart-editor-node-label-field',
        shapeFieldKey: 'flowchart-editor-node-shape-field',
        shapeLabel: _shapeLabel,
      ),
    );
  }

  Future<void> _addEdge() async {
    final flowchart = _flowchart;
    if (flowchart == null || flowchart.nodes.length < 2) {
      return;
    }
    final edge = await showDialog<EditableFlowchartEdge>(
      context: context,
      builder: (context) => _FlowchartEdgeDialog(
        nodes: flowchart.nodes,
        initialFromNodeId: flowchart.nodes.first.id,
        initialToNodeId: flowchart.nodes.last.id,
        edgeId: _nextEdgeId(),
        order: flowchart.edges.length + 1,
        fromFieldKey: 'flowchart-editor-edge-from-field',
        toFieldKey: 'flowchart-editor-edge-to-field',
        labelFieldKey: 'flowchart-editor-edge-label-field',
      ),
    );
    if (edge == null || _flowchart == null) {
      return;
    }
    setState(() {
      _flowchart = _flowchart!.copyWith(edges: [..._flowchart!.edges, edge]);
    });
  }

  void _deleteEdge(EditableFlowchartEdge edge) {
    final flowchart = _flowchart;
    if (flowchart == null) {
      return;
    }
    setState(() {
      _flowchart = flowchart.copyWith(
        edges: flowchart.edges.where((item) => item.id != edge.id).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flowchart szerkesztő'),
        actions: [
          TextButton.icon(
            key: const ValueKey('flowchart-editor-save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: const Text('Mentés'),
          ),
        ],
      ),
      body: FutureBuilder<EditableFlowchart?>(
        future: _future,
        builder: (context, snapshot) {
          final flowchart = _flowchart ?? snapshot.data;
          if (snapshot.connectionState != ConnectionState.done && flowchart == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (flowchart == null) {
            return const Center(child: Text('A flowchart nem található.'));
          }
          return FlowchartEditorCanvas(
            flowchart: flowchart,
            onEditNode: _editNode,
            onDeleteNode: _deleteNode,
            onDeleteEdge: _deleteEdge,
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            key: const ValueKey('flowchart-editor-add-edge'),
            heroTag: 'add-edge',
            onPressed: _addEdge,
            child: const Icon(Icons.add_link),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            key: const ValueKey('flowchart-editor-add-node'),
            heroTag: 'add-node',
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

class _FlowchartNodeDialog extends StatefulWidget {
  const _FlowchartNodeDialog({
    required this.existing,
    required this.nodeId,
    required this.order,
    required this.labelFieldKey,
    required this.shapeFieldKey,
    required this.shapeLabel,
  });

  final EditableFlowchartNode? existing;
  final String nodeId;
  final int order;
  final String labelFieldKey;
  final String shapeFieldKey;
  final String Function(AiFlowchartNodeShape) shapeLabel;

  @override
  State<_FlowchartNodeDialog> createState() => _FlowchartNodeDialogState();
}

class _FlowchartNodeDialogState extends State<_FlowchartNodeDialog> {
  late final TextEditingController _labelController;
  late AiFlowchartNodeShape _shape;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.existing?.label ?? '');
    _shape = widget.existing?.shape ?? AiFlowchartNodeShape.process;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Új flowchart elem' : 'Elem szerkesztése'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: ValueKey(widget.labelFieldKey),
            controller: _labelController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Felirat',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AiFlowchartNodeShape>(
            key: ValueKey(widget.shapeFieldKey),
            initialValue: _shape,
            decoration: const InputDecoration(
              labelText: 'Típus',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final option in AiFlowchartNodeShape.values)
                if (option != AiFlowchartNodeShape.unknown)
                  DropdownMenuItem(value: option, child: Text(widget.shapeLabel(option))),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _shape = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
        FilledButton(
          onPressed: () {
            final label = _labelController.text.trim();
            if (label.isEmpty) {
              return;
            }
            Navigator.of(context).pop(
              EditableFlowchartNode(
                id: widget.nodeId,
                label: label,
                shape: _shape,
                order: widget.order,
              ),
            );
          },
          child: const Text('Mentés'),
        ),
      ],
    );
  }
}

class _FlowchartEdgeDialog extends StatefulWidget {
  const _FlowchartEdgeDialog({
    required this.nodes,
    required this.initialFromNodeId,
    required this.initialToNodeId,
    required this.edgeId,
    required this.order,
    required this.fromFieldKey,
    required this.toFieldKey,
    required this.labelFieldKey,
  });

  final List<EditableFlowchartNode> nodes;
  final String initialFromNodeId;
  final String initialToNodeId;
  final String edgeId;
  final int order;
  final String fromFieldKey;
  final String toFieldKey;
  final String labelFieldKey;

  @override
  State<_FlowchartEdgeDialog> createState() => _FlowchartEdgeDialogState();
}

class _FlowchartEdgeDialogState extends State<_FlowchartEdgeDialog> {
  late final TextEditingController _labelController;
  late String _fromNodeId;
  late String _toNodeId;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _fromNodeId = widget.initialFromNodeId;
    _toNodeId = widget.initialToNodeId;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Új kapcsolat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NodeDropdown(
            keyValue: widget.fromFieldKey,
            label: 'Innen',
            value: _fromNodeId,
            nodes: widget.nodes,
            onChanged: (value) => setState(() => _fromNodeId = value),
          ),
          const SizedBox(height: 12),
          _NodeDropdown(
            keyValue: widget.toFieldKey,
            label: 'Ide',
            value: _toNodeId,
            nodes: widget.nodes,
            onChanged: (value) => setState(() => _toNodeId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            key: ValueKey(widget.labelFieldKey),
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Ág felirata',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
        FilledButton(
          onPressed: _fromNodeId == _toNodeId
              ? null
              : () => Navigator.of(context).pop(
                    EditableFlowchartEdge(
                      id: widget.edgeId,
                      fromNodeId: _fromNodeId,
                      toNodeId: _toNodeId,
                      label: _labelController.text.trim(),
                      order: widget.order,
                    ),
                  ),
          child: const Text('Mentés'),
        ),
      ],
    );
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
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
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
