import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../../debug/debug_console.dart';
import '../../knowledge/models/manual_flowchart_draft.dart';
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
    _log(
      'open document=${widget.documentId} page=${widget.pageNumber} '
      'initialChars=${widget.initialText.length} '
      'nodes=${_flowchart.nodes.length} edges=${_flowchart.edges.length}',
    );
  }

  void _log(String message) {
    DebugConsole.log('[ManualFlowchartDraft] $message');
  }

  EditableFlowchart _fromText(String text) {
    final block = manualFlowchartBlockFromDraft(
      id: 'manual-flowchart-draft',
      title: 'Kézi flowchart',
      text: text.trim().isEmpty ? 'Kezdés' : text,
    );
    return EditableFlowchart(
      id: block.id,
      documentId: widget.documentId,
      pageNumber: widget.pageNumber,
      title: block.title,
      nodes: [
        for (final node in block.nodes)
          EditableFlowchartNode(
            id: node.id,
            label: node.label,
            shape: node.shape,
            order: node.order,
          ),
      ],
      edges: [
        for (final edge in block.edges)
          EditableFlowchartEdge(
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
      _log('node add cancelled');
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(nodes: [..._flowchart.nodes, node]);
    });
    _log(
      'node add id=${node.id} labelChars=${node.label.length} '
      'shape=${node.shape.wireName} nodes=${_flowchart.nodes.length}',
    );
  }

  Future<void> _editNode(EditableFlowchartNode node) async {
    final edited = await _showNodeDialog(existing: node);
    if (edited == null) {
      _log('node edit cancelled id=${node.id}');
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
    _log(
      'node edit id=${edited.id} labelChars=${edited.label.length} '
      'shape=${edited.shape.wireName}',
    );
  }

  void _deleteNode(EditableFlowchartNode node) {
    setState(() {
      _flowchart = _flowchart.copyWith(
        nodes: _flowchart.nodes.where((item) => item.id != node.id).toList(),
        edges: _flowchart.edges
            .where(
              (edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id,
            )
            .toList(),
      );
    });
    _log(
      'node delete id=${node.id} nodes=${_flowchart.nodes.length} '
      'edges=${_flowchart.edges.length}',
    );
  }

  Future<EditableFlowchartNode?> _showNodeDialog({
    EditableFlowchartNode? existing,
  }) async {
    final order = existing?.order ?? _flowchart.nodes.length + 1;
    return showDialog<EditableFlowchartNode>(
      context: context,
      builder: (context) => _ManualFlowchartNodeDialog(
        existing: existing,
        nodeId: existing?.id ?? _nextNodeId(),
        order: order,
        labelFieldKey: 'manual-flowchart-node-label-field',
        shapeFieldKey: 'manual-flowchart-node-shape-field',
        shapeLabel: _shapeLabel,
      ),
    );
  }

  Future<void> _addEdge() async {
    if (_flowchart.nodes.length < 2) {
      _log(
        'edge add blocked reason=not_enough_nodes nodes=${_flowchart.nodes.length}',
      );
      return;
    }
    final edge = await showDialog<EditableFlowchartEdge>(
      context: context,
      builder: (context) => _ManualFlowchartEdgeDialog(
        nodes: _flowchart.nodes,
        initialFromNodeId: _flowchart.nodes.first.id,
        initialToNodeId: _flowchart.nodes.last.id,
        edgeId: _nextEdgeId(),
        order: _flowchart.edges.length + 1,
        fromFieldKey: 'manual-flowchart-edge-from-field',
        toFieldKey: 'manual-flowchart-edge-to-field',
        labelFieldKey: 'manual-flowchart-edge-label-field',
      ),
    );
    if (edge == null) {
      _log('edge add cancelled');
      return;
    }
    setState(() {
      _flowchart = _flowchart.copyWith(edges: [..._flowchart.edges, edge]);
    });
    _log(
      'edge add id=${edge.id} from=${edge.fromNodeId} to=${edge.toNodeId} '
      'labelChars=${edge.label.length} edges=${_flowchart.edges.length}',
    );
  }

  void _deleteEdge(EditableFlowchartEdge edge) {
    setState(() {
      _flowchart = _flowchart.copyWith(
        edges: _flowchart.edges.where((item) => item.id != edge.id).toList(),
      );
    });
    _log('edge delete id=${edge.id} edges=${_flowchart.edges.length}');
  }

  void _save() {
    _log(
      'save document=${widget.documentId} page=${widget.pageNumber} '
      'nodes=${_flowchart.nodes.length} edges=${_flowchart.edges.length}',
    );
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

class _ManualFlowchartNodeDialog extends StatefulWidget {
  const _ManualFlowchartNodeDialog({
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
  State<_ManualFlowchartNodeDialog> createState() =>
      _ManualFlowchartNodeDialogState();
}

class _ManualFlowchartNodeDialogState
    extends State<_ManualFlowchartNodeDialog> {
  late final TextEditingController _labelController;
  late AiFlowchartNodeShape _shape;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.existing?.label ?? '',
    );
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
      title: Text(
        widget.existing == null ? 'Új flowchart elem' : 'Elem szerkesztése',
      ),
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
                  DropdownMenuItem(
                    value: option,
                    child: Text(widget.shapeLabel(option)),
                  ),
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
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

class _ManualFlowchartEdgeDialog extends StatefulWidget {
  const _ManualFlowchartEdgeDialog({
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
  State<_ManualFlowchartEdgeDialog> createState() =>
      _ManualFlowchartEdgeDialogState();
}

class _ManualFlowchartEdgeDialogState
    extends State<_ManualFlowchartEdgeDialog> {
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
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
