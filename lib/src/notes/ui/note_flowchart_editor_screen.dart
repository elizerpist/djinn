import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../../flowchart/models/editable_flowchart.dart';
import '../../flowchart/ui/flowchart_editor_canvas.dart';
import '../models/note_document.dart';

class NoteFlowchartEditorScreen extends StatefulWidget {
  const NoteFlowchartEditorScreen({super.key, required this.block});

  final NoteBlock block;

  @override
  State<NoteFlowchartEditorScreen> createState() => _NoteFlowchartEditorScreenState();
}

class _NoteFlowchartEditorScreenState extends State<NoteFlowchartEditorScreen> {
  late EditableFlowchart _flowchart;

  @override
  void initState() {
    super.initState();
    _flowchart = _editableFromBlock(widget.block);
  }

  EditableFlowchart _editableFromBlock(NoteBlock block) {
    final nodes = block.nodes.isEmpty
        ? const [
            EditableFlowchartNode(
              id: 'node-1',
              label: 'Kezdés',
              shape: AiFlowchartNodeShape.startEnd,
              order: 1,
            ),
          ]
        : [
            for (final node in block.nodes)
              EditableFlowchartNode(
                id: node.id,
                label: node.label,
                shape: node.shape,
                order: node.order,
              ),
          ];
    final edges = [
      for (final edge in block.edges)
        EditableFlowchartEdge(
          id: edge.id,
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          label: edge.label,
          order: edge.order,
        ),
    ];
    return EditableFlowchart(
      id: block.id,
      documentId: 'note',
      pageNumber: 0,
      title: block.title,
      nodes: nodes,
      edges: edges,
    );
  }

  NoteBlock _blockFromEditable() {
    return widget.block.copyWith(
      type: NoteBlockType.flowchart,
      nodes: [
        for (final node in _flowchart.nodes)
          NoteFlowchartNode(
            id: node.id,
            label: node.label,
            shape: node.shape,
            order: node.order,
          ),
      ],
      edges: [
        for (final edge in _flowchart.edges)
          NoteFlowchartEdge(
            id: edge.id,
            fromNodeId: edge.fromNodeId,
            toNodeId: edge.toNodeId,
            label: edge.label,
            order: edge.order,
          ),
      ],
    );
  }

  String _nextNodeId() {
    var index = _flowchart.nodes.length + 1;
    while (_flowchart.nodes.any((node) => node.id == 'node-$index')) {
      index += 1;
    }
    return 'node-$index';
  }

  String _nextEdgeId() {
    var index = _flowchart.edges.length + 1;
    while (_flowchart.edges.any((edge) => edge.id == 'edge-$index')) {
      index += 1;
    }
    return 'edge-$index';
  }

  Future<void> _addNode() async {
    final node = await _showNodeDialog();
    if (node == null || !mounted) {
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(nodes: [..._flowchart.nodes, node]);
    });
  }

  Future<void> _editNode(EditableFlowchartNode node) async {
    final edited = await _showNodeDialog(existing: node);
    if (edited == null || !mounted) {
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
                key: const ValueKey('note-flowchart-node-label-field'),
                controller: labelController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Felirat',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AiFlowchartNodeShape>(
                key: const ValueKey('note-flowchart-node-shape-field'),
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
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
                keyValue: 'note-flowchart-edge-from-field',
                label: 'Innen',
                value: from,
                nodes: _flowchart.nodes,
                onChanged: (value) => setDialogState(() => from = value),
              ),
              const SizedBox(height: 12),
              _NodeDropdown(
                keyValue: 'note-flowchart-edge-to-field',
                label: 'Ide',
                value: to,
                nodes: _flowchart.nodes,
                onChanged: (value) => setDialogState(() => to = value),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('note-flowchart-edge-label-field'),
                controller: labelController,
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
    await Future<void>.delayed(const Duration(milliseconds: 250));
    labelController.dispose();
    if (edge == null || !mounted) {
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
    Navigator.of(context).pop(_blockFromEditable());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flowchart szerkesztő'),
        actions: [
          TextButton.icon(
            key: const ValueKey('note-flowchart-save'),
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
            key: const ValueKey('note-flowchart-add-edge'),
            heroTag: 'note-flowchart-add-edge',
            onPressed: _addEdge,
            child: const Icon(Icons.add_link),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            key: const ValueKey('note-flowchart-add-node'),
            heroTag: 'note-flowchart-add-node',
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
