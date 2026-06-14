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
    final labelController = TextEditingController(text: existing?.label ?? '');
    var shape = existing?.shape ?? AiFlowchartNodeShape.process;
    final nextOrder = (_flowchart?.nodes.length ?? 0) + 1;
    final result = await showDialog<EditableFlowchartNode>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Új flowchart elem' : 'Elem szerkesztése'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('flowchart-editor-node-label-field'),
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Felirat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiFlowchartNodeShape>(
                key: const ValueKey('flowchart-editor-node-shape-field'),
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
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
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
                    order: existing?.order ?? nextOrder,
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
    final flowchart = _flowchart;
    if (flowchart == null || flowchart.nodes.length < 2) {
      return;
    }
    var from = flowchart.nodes.first.id;
    var to = flowchart.nodes.last.id;
    final labelController = TextEditingController();
    final edge = await showDialog<EditableFlowchartEdge>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Új kapcsolat'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const ValueKey('flowchart-editor-edge-from-field'),
                initialValue: from,
                decoration: const InputDecoration(labelText: 'Innen', border: OutlineInputBorder()),
                items: [
                  for (final node in flowchart.nodes)
                    DropdownMenuItem(value: node.id, child: Text(node.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => from = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('flowchart-editor-edge-to-field'),
                initialValue: to,
                decoration: const InputDecoration(labelText: 'Ide', border: OutlineInputBorder()),
                items: [
                  for (final node in flowchart.nodes)
                    DropdownMenuItem(value: node.id, child: Text(node.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => to = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('flowchart-editor-edge-label-field'),
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Ág felirata', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
            FilledButton(
              onPressed: from == to
                  ? null
                  : () => Navigator.of(context).pop(
                        EditableFlowchartEdge(
                          id: _nextEdgeId(),
                          fromNodeId: from,
                          toNodeId: to,
                          label: labelController.text.trim(),
                          order: flowchart.edges.length + 1,
                        ),
                      ),
              child: const Text('Mentés'),
            ),
          ],
        ),
      ),
    );
    labelController.dispose();
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
