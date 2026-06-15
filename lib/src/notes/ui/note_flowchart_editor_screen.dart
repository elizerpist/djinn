import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../models/note_document.dart';

class NoteFlowchartEditorScreen extends StatefulWidget {
  const NoteFlowchartEditorScreen({
    super.key,
    required this.block,
    this.onChanged,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock>? onChanged;

  @override
  State<NoteFlowchartEditorScreen> createState() => _NoteFlowchartEditorScreenState();
}

class _NoteFlowchartEditorScreenState extends State<NoteFlowchartEditorScreen> {
  static const Size _canvasSize = Size(1800, 1300);
  static const Size _nodeSize = Size(230, 78);

  final GlobalKey _canvasKey = GlobalKey();
  late NoteBlock _block;
  String? _linkSourceNodeId;

  @override
  void initState() {
    super.initState();
    _block = widget.block.nodes.isEmpty
        ? widget.block.copyWith(
            type: NoteBlockType.flowchart,
            nodes: const [
              NoteFlowchartNode(
                id: 'node-1',
                label: 'Kezdés',
                shape: AiFlowchartNodeShape.startEnd,
                order: 1,
                x: 120,
                y: 120,
              ),
            ],
          )
        : widget.block.copyWith(type: NoteBlockType.flowchart);
  }

  void _emit(NoteBlock next) {
    setState(() => _block = next.copyWith(type: NoteBlockType.flowchart, clearIndex: true));
    widget.onChanged?.call(_block);
  }

  void _save() {
    Navigator.of(context).pop(_block);
  }

  String _nextNodeId() {
    var index = _block.nodes.length + 1;
    while (_block.nodes.any((node) => node.id == 'node-$index')) {
      index += 1;
    }
    return 'node-$index';
  }

  String _nextEdgeId() {
    var index = _block.edges.length + 1;
    while (_block.edges.any((edge) => edge.id == 'edge-$index')) {
      index += 1;
    }
    return 'edge-$index';
  }

  List<NoteFlowchartNode> get _positionedNodes {
    return [
      for (var i = 0; i < _block.nodes.length; i += 1)
        if (_block.nodes[i].x == 0 && _block.nodes[i].y == 0)
          _block.nodes[i].copyWith(x: 120, y: 120 + i * 120)
        else
          _block.nodes[i],
    ];
  }

  void _addNode(AiFlowchartNodeShape shape, Offset position) {
    final id = _nextNodeId();
    final label = switch (shape) {
      AiFlowchartNodeShape.startEnd => 'Kezdés / Vége',
      AiFlowchartNodeShape.decision => 'Döntés?',
      AiFlowchartNodeShape.inputOutput => 'Bemenet / kimenet',
      AiFlowchartNodeShape.subprocess => 'Alfolyamat',
      AiFlowchartNodeShape.dataStore => 'Adattárolás',
      AiFlowchartNodeShape.connector => 'Kapcsoló',
      AiFlowchartNodeShape.process || AiFlowchartNodeShape.unknown => 'Folyamatlépés',
    };
    _emit(_block.copyWith(
      nodes: [
        ..._positionedNodes,
        NoteFlowchartNode(
          id: id,
          label: label,
          shape: shape,
          order: _block.nodes.length + 1,
          x: position.dx.clamp(24, _canvasSize.width - _nodeSize.width).toDouble(),
          y: position.dy.clamp(24, _canvasSize.height - _nodeSize.height).toDouble(),
        ),
      ],
    ));
  }

  void _addPaletteNode(AiFlowchartNodeShape shape) {
    final offset = Offset(140 + (_block.nodes.length % 3) * 270, 120 + _block.nodes.length * 38);
    _addNode(shape, offset);
  }

  void _addDroppedNode(AiFlowchartNodeShape shape, Offset globalOffset) {
    final context = _canvasKey.currentContext;
    if (context == null) {
      _addPaletteNode(shape);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(globalOffset) ?? const Offset(120, 120);
    _addNode(shape, local);
  }

  void _moveNode(NoteFlowchartNode node, Offset delta) {
    final positioned = _positionedNodes;
    _emit(_block.copyWith(
      nodes: [
        for (final current in positioned)
          if (current.id == node.id)
            current.copyWith(
              x: (current.x + delta.dx).clamp(0, _canvasSize.width - _nodeSize.width).toDouble(),
              y: (current.y + delta.dy).clamp(0, _canvasSize.height - _nodeSize.height).toDouble(),
            )
          else
            current,
      ],
    ));
  }

  void _deleteNode(NoteFlowchartNode node) {
    _emit(_block.copyWith(
      nodes: _positionedNodes.where((item) => item.id != node.id).toList(),
      edges: _block.edges
          .where((edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id)
          .toList(),
    ));
  }

  Future<void> _editNode(NoteFlowchartNode node) async {
    final edited = await _showNodeDialog(existing: node);
    if (edited == null || !mounted) {
      return;
    }
    _emit(_block.copyWith(
      nodes: [
        for (final current in _positionedNodes)
          if (current.id == node.id) edited else current,
      ],
    ));
  }

  Future<NoteFlowchartNode?> _showNodeDialog({NoteFlowchartNode? existing}) async {
    final labelController = TextEditingController(text: existing?.label ?? '');
    var shape = existing?.shape ?? AiFlowchartNodeShape.process;
    final result = await showDialog<NoteFlowchartNode>(
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
                  NoteFlowchartNode(
                    id: existing?.id ?? _nextNodeId(),
                    label: label,
                    shape: shape,
                    order: existing?.order ?? _block.nodes.length + 1,
                    x: existing?.x ?? 120,
                    y: existing?.y ?? 120,
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

  void _startOrFinishLink(NoteFlowchartNode node) {
    final source = _linkSourceNodeId;
    if (source == null) {
      setState(() => _linkSourceNodeId = node.id);
      return;
    }
    if (source == node.id) {
      setState(() => _linkSourceNodeId = null);
      return;
    }
    final sourceNode = _block.nodes.firstWhere(
      (candidate) => candidate.id == source,
      orElse: () => node,
    );
    final label = sourceNode.shape == AiFlowchartNodeShape.decision
        ? (_block.edges.where((edge) => edge.fromNodeId == source).isEmpty ? 'Igen' : 'Nem')
        : '';
    _emit(_block.copyWith(
      edges: [
        ..._block.edges,
        NoteFlowchartEdge(
          id: _nextEdgeId(),
          fromNodeId: source,
          toNodeId: node.id,
          label: label,
          order: _block.edges.length + 1,
        ),
      ],
    ));
    setState(() => _linkSourceNodeId = null);
  }

  Future<void> _addEdge() async {
    if (_block.nodes.length < 2) {
      return;
    }
    var from = _block.nodes.first.id;
    var to = _block.nodes.last.id;
    final labelController = TextEditingController();
    final edge = await showDialog<NoteFlowchartEdge>(
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
                nodes: _block.nodes,
                onChanged: (value) => setDialogState(() => from = value),
              ),
              const SizedBox(height: 12),
              _NodeDropdown(
                keyValue: 'note-flowchart-edge-to-field',
                label: 'Ide',
                value: to,
                nodes: _block.nodes,
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
                        NoteFlowchartEdge(
                          id: _nextEdgeId(),
                          fromNodeId: from,
                          toNodeId: to,
                          label: labelController.text.trim(),
                          order: _block.edges.length + 1,
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
    _emit(_block.copyWith(edges: [..._block.edges, edge]));
  }

  void _deleteEdge(NoteFlowchartEdge edge) {
    _emit(_block.copyWith(edges: _block.edges.where((item) => item.id != edge.id).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _positionedNodes;
    return Scaffold(
      key: const ValueKey('note-flowchart-canvas-editor'),
      appBar: AppBar(
        title: const Text('Flowchart szerkesztő'),
        actions: [
          if (widget.onChanged == null)
            TextButton.icon(
              key: const ValueKey('note-flowchart-save'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Mentés'),
            ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(800),
            minScale: 0.35,
            maxScale: 2.5,
            child: DragTarget<AiFlowchartNodeShape>(
              onAcceptWithDetails: (details) => _addDroppedNode(details.data, details.offset),
              builder: (context, candidate, rejected) {
                return SizedBox(
                  key: _canvasKey,
                  width: _canvasSize.width,
                  height: _canvasSize.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FlowchartEdgePainter(
                            nodes: nodes,
                            edges: _block.edges,
                            nodeSize: _nodeSize,
                          ),
                        ),
                      ),
                      for (final edge in _block.edges)
                        _EdgeLabel(
                          edge: edge,
                          nodes: nodes,
                          nodeSize: _nodeSize,
                          onDelete: () => _deleteEdge(edge),
                        ),
                      for (final node in nodes)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          width: _nodeSize.width,
                          child: _CanvasNodeCard(
                            node: node,
                            selectedForLink: _linkSourceNodeId == node.id,
                            onMove: (delta) => _moveNode(node, delta),
                            onEdit: () => _editNode(node),
                            onDelete: () => _deleteNode(node),
                            onLinkTap: () => _startOrFinishLink(node),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _FlowchartPalette(onAdd: _addPaletteNode),
          ),
        ],
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
          FloatingActionButton.small(
            key: const ValueKey('note-flowchart-add-node'),
            heroTag: 'note-flowchart-add-node',
            onPressed: () => _addPaletteNode(AiFlowchartNodeShape.process),
            child: const Icon(Icons.add),
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

class _CanvasNodeCard extends StatelessWidget {
  const _CanvasNodeCard({
    required this.node,
    required this.selectedForLink,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
    required this.onLinkTap,
  });

  final NoteFlowchartNode node;
  final bool selectedForLink;
  final ValueChanged<Offset> onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => onMove(details.delta),
      onDoubleTap: onEdit,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectedForLink ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: selectedForLink ? 2 : 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x1A111827), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
          child: Row(
            children: [
              Icon(_shapeIcon(node.shape), color: const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_shapeLabel(node.shape), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(node.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, height: 1.15)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Kapcsolat',
                    visualDensity: VisualDensity.compact,
                    onPressed: onLinkTap,
                    icon: const Icon(Icons.link, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Törlés',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowchartPalette extends StatelessWidget {
  const _FlowchartPalette({required this.onAdd});

  final ValueChanged<AiFlowchartNodeShape> onAdd;

  @override
  Widget build(BuildContext context) {
    const shapes = [
      AiFlowchartNodeShape.startEnd,
      AiFlowchartNodeShape.process,
      AiFlowchartNodeShape.decision,
      AiFlowchartNodeShape.inputOutput,
      AiFlowchartNodeShape.subprocess,
      AiFlowchartNodeShape.dataStore,
      AiFlowchartNodeShape.connector,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [BoxShadow(color: Color(0x1A111827), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final shape in shapes) ...[
              LongPressDraggable<AiFlowchartNodeShape>(
                data: shape,
                feedback: Material(
                  color: Colors.transparent,
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Icon(_shapeIcon(shape), color: Colors.white),
                  ),
                ),
                child: IconButton(
                  tooltip: _shapeLabel(shape),
                  onPressed: () => onAdd(shape),
                  icon: Icon(_shapeIcon(shape)),
                ),
              ),
              if (shape != shapes.last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({
    required this.edge,
    required this.nodes,
    required this.nodeSize,
    required this.onDelete,
  });

  final NoteFlowchartEdge edge;
  final List<NoteFlowchartNode> nodes;
  final Size nodeSize;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final from = _nodeById(edge.fromNodeId);
    final to = _nodeById(edge.toNodeId);
    if (from == null || to == null || edge.label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final left = (from.x + to.x + nodeSize.width) / 2 - 30;
    final top = (from.y + to.y + nodeSize.height) / 2 - 16;
    return Positioned(
      left: left,
      top: top,
      child: InputChip(
        key: ValueKey('note-flowchart-edge-${edge.id}'),
        label: Text(edge.label.trim()),
        onDeleted: onDelete,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  NoteFlowchartNode? _nodeById(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }
}

class _FlowchartEdgePainter extends CustomPainter {
  const _FlowchartEdgePainter({
    required this.nodes,
    required this.edges,
    required this.nodeSize,
  });

  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;
  final Size nodeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in nodes) node.id: node};
    final paint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;
    for (final edge in edges) {
      final from = nodesById[edge.fromNodeId];
      final to = nodesById[edge.toNodeId];
      if (from == null || to == null) {
        continue;
      }
      final start = Offset(from.x + nodeSize.width / 2, from.y + nodeSize.height);
      final end = Offset(to.x + nodeSize.width / 2, to.y);
      final midY = (start.dy + end.dy) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
      canvas.drawPath(path, paint);
      final arrow = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 6, end.dy - 9)
        ..lineTo(end.dx + 6, end.dy - 9)
        ..close();
      canvas.drawPath(arrow, arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowchartEdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
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
  final List<NoteFlowchartNode> nodes;
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

IconData _shapeIcon(AiFlowchartNodeShape shape) {
  return switch (shape) {
    AiFlowchartNodeShape.startEnd => Icons.trip_origin,
    AiFlowchartNodeShape.decision => Icons.change_history,
    AiFlowchartNodeShape.inputOutput => Icons.input,
    AiFlowchartNodeShape.subprocess => Icons.integration_instructions_outlined,
    AiFlowchartNodeShape.dataStore => Icons.storage,
    AiFlowchartNodeShape.connector => Icons.radio_button_unchecked,
    AiFlowchartNodeShape.process || AiFlowchartNodeShape.unknown => Icons.crop_square,
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
