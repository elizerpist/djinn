import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/ai_client.dart';
import '../../debug/debug_console.dart';
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
  static const double _gridStep = 32;

  final GlobalKey _canvasKey = GlobalKey();
  late NoteBlock _block;
  _LinkEndpoint? _linkSource;
  final TextEditingController _inlineNodeController = TextEditingController();
  String? _editingNodeId;
  final Map<String, Stopwatch> _dragWatches = <String, Stopwatch>{};
  final Map<String, int> _dragMoveCounts = <String, int>{};

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
    _log('editor init nodes=${_block.nodes.length} edges=${_block.edges.length}');
  }

  @override
  void dispose() {
    _inlineNodeController.dispose();
    super.dispose();
  }

  void _log(String message) {
    DebugConsole.log('[Notes/Flowchart] $message');
  }

  void _emit(NoteBlock next, {bool clearIndex = true}) {
    final updated = next.copyWith(type: NoteBlockType.flowchart, clearIndex: clearIndex);
    setState(() => _block = updated);
    widget.onChanged?.call(updated);
  }

  void _commitCurrent({required String reason, bool clearIndex = false}) {
    final updated = _block.copyWith(type: NoteBlockType.flowchart, clearIndex: clearIndex);
    _block = updated;
    widget.onChanged?.call(updated);
    _log('commit reason=$reason nodes=${updated.nodes.length} edges=${updated.edges.length} clearIndex=$clearIndex');
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

  Map<String, Size> _nodeSizesFor(List<NoteFlowchartNode> nodes) {
    return {for (final node in nodes) node.id: _nodeSizeFor(node)};
  }

  void _addNode(AiFlowchartNodeShape shape, Offset position) {
    final id = _nextNodeId();
    final label = _defaultLabel(shape);
    final draft = NoteFlowchartNode(
      id: id,
      label: label,
      shape: shape,
      order: _block.nodes.length + 1,
    );
    final nodeSize = _nodeSizeFor(draft);
    final node = draft.copyWith(
      x: position.dx.clamp(24, _canvasSize.width - nodeSize.width - 24).toDouble(),
      y: position.dy.clamp(24, _canvasSize.height - nodeSize.height - 24).toDouble(),
    );
    _log('node add id=$id shape=${shape.wireName} x=${node.x.toStringAsFixed(1)} y=${node.y.toStringAsFixed(1)}');
    _emit(_block.copyWith(nodes: [..._positionedNodes, node]));
  }

  void _addDroppedNode(AiFlowchartNodeShape shape, Offset globalOffset) {
    final context = _canvasKey.currentContext;
    if (context == null) {
      _log('drop fallback shape=${shape.wireName} reason=no_canvas_context');
      _addNode(shape, const Offset(120, 120));
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(globalOffset) ?? const Offset(120, 120);
    final draftSize = _nodeSizeFor(NoteFlowchartNode(id: 'draft', label: _defaultLabel(shape), shape: shape));
    final centered = local - Offset(draftSize.width / 2, draftSize.height / 2);
    _log(
      'drop shape=${shape.wireName} global=${globalOffset.dx.toStringAsFixed(1)},${globalOffset.dy.toStringAsFixed(1)} '
      'local=${local.dx.toStringAsFixed(1)},${local.dy.toStringAsFixed(1)}',
    );
    _addNode(shape, centered);
  }

  void _beginMove(NoteFlowchartNode node) {
    _dragWatches[node.id] = Stopwatch()..start();
    _dragMoveCounts[node.id] = 0;
    _log('drag start node=${node.id} x=${node.x.toStringAsFixed(1)} y=${node.y.toStringAsFixed(1)}');
  }

  void _moveNode(NoteFlowchartNode node, Offset delta) {
    final positioned = _positionedNodes;
    final sizes = _nodeSizesFor(positioned);
    final size = sizes[node.id] ?? _nodeSizeFor(node);
    final moveCount = (_dragMoveCounts[node.id] ?? 0) + 1;
    _dragMoveCounts[node.id] = moveCount;
    if (moveCount % 16 == 0) {
      _log('drag update node=${node.id} moves=$moveCount dx=${delta.dx.toStringAsFixed(1)} dy=${delta.dy.toStringAsFixed(1)}');
    }
    setState(() {
      _block = _block.copyWith(
        type: NoteBlockType.flowchart,
        nodes: [
          for (final current in positioned)
            if (current.id == node.id)
              current.copyWith(
                x: (current.x + delta.dx).clamp(0, _canvasSize.width - size.width).toDouble(),
                y: (current.y + delta.dy).clamp(0, _canvasSize.height - size.height).toDouble(),
              )
            else
              current,
        ],
      );
    });
  }

  void _endMove(NoteFlowchartNode node) {
    final watch = _dragWatches.remove(node.id);
    final moves = _dragMoveCounts.remove(node.id) ?? 0;
    watch?.stop();
    final current = _positionedNodes.firstWhere(
      (candidate) => candidate.id == node.id,
      orElse: () => node,
    );
    _log(
      'drag end node=${node.id} moves=$moves elapsedMs=${watch?.elapsedMilliseconds ?? 0} '
      'x=${current.x.toStringAsFixed(1)} y=${current.y.toStringAsFixed(1)}',
    );
    if (moves == 0) {
      _log('drag end ignored node=${node.id} reason=no_movement');
      return;
    }
    _commitCurrent(reason: 'drag_end', clearIndex: false);
  }

  void _deleteNode(NoteFlowchartNode node) {
    _log('node delete id=${node.id}');
    _emit(_block.copyWith(
      nodes: _positionedNodes.where((item) => item.id != node.id).toList(),
      edges: _block.edges
          .where((edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id)
          .toList(),
    ));
  }

  void _editNode(NoteFlowchartNode node) {
    _log('node inline edit start id=${node.id} chars=${node.label.length}');
    setState(() {
      _editingNodeId = node.id;
      _inlineNodeController.text = node.label;
      _inlineNodeController.selection = TextSelection.collapsed(offset: _inlineNodeController.text.length);
    });
  }

  void _commitNodeEdit(NoteFlowchartNode node) {
    if (_editingNodeId != node.id) {
      return;
    }
    final label = _inlineNodeController.text.trim();
    setState(() => _editingNodeId = null);
    if (label.isEmpty || label == node.label) {
      _log('node inline edit closed id=${node.id} changed=false chars=${node.label.length}');
      return;
    }
    final positioned = _positionedNodes;
    final edited = node.copyWith(label: label);
    _log('node inline edit saved id=${node.id} chars=${label.length} shape=${edited.shape.wireName}');
    _emit(_block.copyWith(
      nodes: [
        for (final current in positioned)
          if (current.id == node.id) edited else current,
      ],
    ));
  }

  void _cancelNodeEdit(NoteFlowchartNode node) {
    if (_editingNodeId != node.id) {
      return;
    }
    _log('node inline edit cancelled id=${node.id}');
    setState(() => _editingNodeId = null);
  }

  void _handleConnectorTap(NoteFlowchartNode node, _ConnectorSpec connector) {
    final source = _linkSource;
    if (source == null) {
      if (connector.type == _ConnectorType.input) {
        _log('connector ignored node=${node.id} connector=${connector.id} reason=input_without_source');
        return;
      }
      setState(() => _linkSource = _LinkEndpoint(
            nodeId: node.id,
            connectorId: connector.id,
            edgeLabel: connector.edgeLabel,
          ));
      _log('connector source selected node=${node.id} connector=${connector.id} label=${connector.edgeLabel}');
      return;
    }
    if (source.nodeId == node.id && source.connectorId == connector.id) {
      setState(() => _linkSource = null);
      _log('connector source cleared node=${node.id} connector=${connector.id}');
      return;
    }
    if (connector.type == _ConnectorType.output) {
      setState(() => _linkSource = _LinkEndpoint(
            nodeId: node.id,
            connectorId: connector.id,
            edgeLabel: connector.edgeLabel,
          ));
      _log('connector source switched node=${node.id} connector=${connector.id} label=${connector.edgeLabel}');
      return;
    }
    if (source.nodeId == node.id) {
      setState(() => _linkSource = null);
      _log('connector cancelled same_node node=${node.id}');
      return;
    }
    final edge = NoteFlowchartEdge(
      id: _nextEdgeId(),
      fromNodeId: source.nodeId,
      toNodeId: node.id,
      label: source.edgeLabel,
      order: _block.edges.length + 1,
    );
    _log(
      'edge add id=${edge.id} from=${edge.fromNodeId}.${source.connectorId} '
      'to=${edge.toNodeId}.${connector.id} label=${edge.label}',
    );
    _emit(_block.copyWith(edges: [..._block.edges, edge]));
    setState(() => _linkSource = null);
  }

  void _deleteEdge(NoteFlowchartEdge edge) {
    _log('edge delete id=${edge.id} from=${edge.fromNodeId} to=${edge.toNodeId}');
    _emit(_block.copyWith(edges: _block.edges.where((item) => item.id != edge.id).toList()));
  }

  @override
  Widget build(BuildContext context) {
    final nodes = _positionedNodes;
    final nodeSizes = _nodeSizesFor(nodes);
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
                  child: RepaintBoundary(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            key: const ValueKey('note-flowchart-grid'),
                            painter: const _FlowchartGridPainter(step: _gridStep),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _FlowchartEdgePainter(
                              nodes: nodes,
                              edges: _block.edges,
                              nodeSizes: nodeSizes,
                            ),
                          ),
                        ),
                        for (final edge in _block.edges)
                          _EdgeLabel(
                            edge: edge,
                            nodes: nodes,
                            nodeSizes: nodeSizes,
                            onDelete: () => _deleteEdge(edge),
                          ),
                        for (final node in nodes)
                          Positioned(
                            left: node.x,
                            top: node.y,
                            width: nodeSizes[node.id]?.width ?? _nodeSizeFor(node).width,
                            height: nodeSizes[node.id]?.height ?? _nodeSizeFor(node).height,
                            child: _CanvasNodeCard(
                              node: node,
                              size: nodeSizes[node.id] ?? _nodeSizeFor(node),
                              connectors: _connectorsForNode(node),
                              linkSource: _linkSource,
                              onMoveStart: () => _beginMove(node),
                              onMove: (delta) => _moveNode(node, delta),
                              onMoveEnd: () => _endMove(node),
                              onEdit: () => _editNode(node),
                              onCommitEdit: () => _commitNodeEdit(node),
                              onCancelEdit: () => _cancelNodeEdit(node),
                              inlineController: _editingNodeId == node.id ? _inlineNodeController : null,
                              editing: _editingNodeId == node.id,
                              connectModeActive: _linkSource != null,
                              onDelete: () => _deleteNode(node),
                              onConnectorTap: (connector) => _handleConnectorTap(node, connector),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _FlowchartPalette(
              onDragLog: _log,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasNodeCard extends StatelessWidget {
  const _CanvasNodeCard({
    required this.node,
    required this.size,
    required this.connectors,
    required this.linkSource,
    required this.onMoveStart,
    required this.onMove,
    required this.onMoveEnd,
    required this.onEdit,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.inlineController,
    required this.editing,
    required this.connectModeActive,
    required this.onDelete,
    required this.onConnectorTap,
  });

  final NoteFlowchartNode node;
  final Size size;
  final List<_ConnectorSpec> connectors;
  final _LinkEndpoint? linkSource;
  final VoidCallback onMoveStart;
  final ValueChanged<Offset> onMove;
  final VoidCallback onMoveEnd;
  final VoidCallback onEdit;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
  final TextEditingController? inlineController;
  final bool editing;
  final bool connectModeActive;
  final VoidCallback onDelete;
  final ValueChanged<_ConnectorSpec> onConnectorTap;

  @override
  Widget build(BuildContext context) {
    final selectedForLink = linkSource?.nodeId == node.id;
    return AnimatedScale(
      key: ValueKey('note-flowchart-source-scale-${node.id}'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      scale: selectedForLink ? 1.06 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => onMoveStart(),
        onPanUpdate: (details) => onMove(details.delta),
        onPanEnd: (_) => onMoveEnd(),
        onPanCancel: onMoveEnd,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  key: ValueKey('note-flowchart-card-opacity-${node.id}'),
                  duration: const Duration(milliseconds: 120),
                  opacity: connectModeActive ? 0.42 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selectedForLink ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                        width: selectedForLink ? 2 : 1,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x1A111827), blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(_shapeIcon(node.shape), color: const Color(0xFF7C3AED)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _shapeLabel(node.shape),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: editing
                                        ? TextField(
                                            key: ValueKey('note-flowchart-node-inline-field-${node.id}'),
                                            controller: inlineController,
                                            autofocus: true,
                                            minLines: 1,
                                            maxLines: 4,
                                            textInputAction: TextInputAction.done,
                                            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.18),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                              border: InputBorder.none,
                                            ),
                                            onSubmitted: (_) => onCommitEdit(),
                                            onTapOutside: (_) => onCommitEdit(),
                                          )
                                        : GestureDetector(
                                            key: ValueKey('note-flowchart-node-label-${node.id}'),
                                            behavior: HitTestBehavior.opaque,
                                            onTap: onEdit,
                                            onLongPress: onEdit,
                                            child: Text(
                                              node.label,
                                              overflow: TextOverflow.fade,
                                              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.18),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Törlés',
                            visualDensity: VisualDensity.compact,
                            onPressed: onDelete,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (editing)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: IconButton(
                    tooltip: 'Szerkesztés bezárása',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancelEdit,
                    icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                  ),
                ),
              for (final connector in connectors)
                _ConnectorButton(
                  connector: connector,
                  selected: linkSource?.nodeId == node.id && linkSource?.connectorId == connector.id,
                  onPressed: () => onConnectorTap(connector),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectorButton extends StatelessWidget {
  const _ConnectorButton({
    required this.connector,
    required this.selected,
    required this.onPressed,
  });

  final _ConnectorSpec connector;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? const Color(0xFF2563EB)
        : connector.type == _ConnectorType.output
            ? const Color(0xFF7C3AED)
            : const Color(0xFF059669);
    final icon = switch (connector.id) {
      'yes' => Icons.add,
      'no' => Icons.remove,
      _ => connector.type == _ConnectorType.output ? Icons.arrow_outward : Icons.radio_button_checked,
    };
    return Positioned(
      left: connector.unitOffset.dx * connector.nodeSize.width - 22,
      top: connector.unitOffset.dy * connector.nodeSize.height - 22,
      child: Tooltip(
        message: connector.tooltip,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('note-flowchart-connector-${connector.nodeId}-${connector.id}'),
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.28 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: selected ? 30 : 24,
                    height: selected ? 30 : 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: selected ? 2.4 : 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: selected ? 0.34 : 0.18),
                          blurRadius: selected ? 12 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: connector.id == 'yes' || connector.id == 'no' ? 15 : 12, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowchartPalette extends StatelessWidget {
  const _FlowchartPalette({required this.onDragLog});

  final ValueChanged<String> onDragLog;

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
                dragAnchorStrategy: pointerDragAnchorStrategy,
                maxSimultaneousDrags: 1,
                feedbackOffset: const Offset(28, 28),
                onDragStarted: () {
                  HapticFeedback.selectionClick();
                  onDragLog('palette drag start shape=${shape.wireName}');
                },
                onDragUpdate: (details) {
                  if (details.globalPosition.dx.round() % 64 == 0) {
                    onDragLog(
                      'palette drag update shape=${shape.wireName} '
                      'global=${details.globalPosition.dx.toStringAsFixed(1)},${details.globalPosition.dy.toStringAsFixed(1)}',
                    );
                  }
                },
                onDragEnd: (details) => onDragLog(
                  'palette drag end shape=${shape.wireName} accepted=${details.wasAccepted} '
                  'offset=${details.offset.dx.toStringAsFixed(1)},${details.offset.dy.toStringAsFixed(1)}',
                ),
                feedback: Material(
                  color: Colors.transparent,
                  child: _PaletteGhost(shape: shape),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.35,
                  child: _PaletteButton(shape: shape),
                ),
                child: _PaletteButton(shape: shape),
              ),
              if (shape != shapes.last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.shape});

  final AiFlowchartNodeShape shape;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _shapeLabel(shape),
      child: DecoratedBox(
        key: ValueKey('note-flowchart-palette-${shape.wireName}'),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(_shapeIcon(shape), color: const Color(0xFF374151)),
        ),
      ),
    );
  }
}

class _PaletteGhost extends StatelessWidget {
  const _PaletteGhost({required this.shape});

  final AiFlowchartNodeShape shape;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: SizedBox.square(
        dimension: 56,
        child: Icon(_shapeIcon(shape), color: Colors.white),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({
    required this.edge,
    required this.nodes,
    required this.nodeSizes,
    required this.onDelete,
  });

  final NoteFlowchartEdge edge;
  final List<NoteFlowchartNode> nodes;
  final Map<String, Size> nodeSizes;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final from = _nodeById(edge.fromNodeId);
    final to = _nodeById(edge.toNodeId);
    if (from == null || to == null || edge.label.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final start = _edgeStart(edge, from, nodeSizes);
    final end = _edgeEnd(to, nodeSizes);
    final left = (start.dx + end.dx) / 2 - 30;
    final top = (start.dy + end.dy) / 2 - 16;
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

class _FlowchartGridPainter extends CustomPainter {
  const _FlowchartGridPainter({required this.step});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final lightPaint = Paint()
      ..color = const Color(0xFFEDE9FE)
      ..strokeWidth = 0.7;
    final strongPaint = Paint()
      ..color = const Color(0xFFD8B4FE)
      ..strokeWidth = 1.0;
    for (var x = 0.0; x <= size.width; x += step) {
      final paint = ((x / step).round() % 4 == 0) ? strongPaint : lightPaint;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      final paint = ((y / step).round() % 4 == 0) ? strongPaint : lightPaint;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowchartGridPainter oldDelegate) => oldDelegate.step != step;
}

class _FlowchartEdgePainter extends CustomPainter {
  const _FlowchartEdgePainter({
    required this.nodes,
    required this.edges,
    required this.nodeSizes,
  });

  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;
  final Map<String, Size> nodeSizes;

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
      final start = _edgeStart(edge, from, nodeSizes);
      final end = _edgeEnd(to, nodeSizes);
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
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges || oldDelegate.nodeSizes != nodeSizes;
  }
}

class _LinkEndpoint {
  const _LinkEndpoint({
    required this.nodeId,
    required this.connectorId,
    required this.edgeLabel,
  });

  final String nodeId;
  final String connectorId;
  final String edgeLabel;
}

enum _ConnectorType { input, output }

class _ConnectorSpec {
  const _ConnectorSpec({
    required this.id,
    required this.nodeId,
    required this.nodeSize,
    required this.unitOffset,
    required this.type,
    required this.tooltip,
    this.edgeLabel = '',
  });

  final String id;
  final String nodeId;
  final Size nodeSize;
  final Offset unitOffset;
  final _ConnectorType type;
  final String tooltip;
  final String edgeLabel;
}

List<_ConnectorSpec> _connectorsForNode(NoteFlowchartNode node) {
  final size = _nodeSizeFor(node);
  _ConnectorSpec spec({
    required String id,
    required Offset offset,
    required _ConnectorType type,
    required String tooltip,
    String edgeLabel = '',
  }) {
    return _ConnectorSpec(
      id: id,
      nodeId: node.id,
      nodeSize: size,
      unitOffset: offset,
      type: type,
      tooltip: tooltip,
      edgeLabel: edgeLabel,
    );
  }

  if (node.shape == AiFlowchartNodeShape.decision) {
    return [
      spec(id: 'in', offset: const Offset(0.5, 0), type: _ConnectorType.input, tooltip: 'Bemenet'),
      spec(id: 'yes', offset: const Offset(0.28, 1), type: _ConnectorType.output, tooltip: 'Igen ág', edgeLabel: 'Igen'),
      spec(id: 'no', offset: const Offset(0.72, 1), type: _ConnectorType.output, tooltip: 'Nem ág', edgeLabel: 'Nem'),
    ];
  }
  if (node.shape == AiFlowchartNodeShape.startEnd) {
    final label = node.label.trim().toLowerCase();
    final isEnd = label.contains('vég') || label == 'end';
    if (isEnd && !label.contains('kezd')) {
      return [
        spec(id: 'in', offset: const Offset(0.5, 0), type: _ConnectorType.input, tooltip: 'Bemenet'),
      ];
    }
    return [
      spec(id: 'out', offset: const Offset(0.5, 1), type: _ConnectorType.output, tooltip: 'Kimenet'),
    ];
  }
  if (node.shape == AiFlowchartNodeShape.connector) {
    return [
      spec(id: 'in', offset: const Offset(0.5, 0), type: _ConnectorType.input, tooltip: 'Bemenet'),
      spec(id: 'out', offset: const Offset(0.5, 1), type: _ConnectorType.output, tooltip: 'Kimenet'),
    ];
  }
  return [
    spec(id: 'in', offset: const Offset(0.5, 0), type: _ConnectorType.input, tooltip: 'Bemenet'),
    spec(id: 'out', offset: const Offset(0.5, 1), type: _ConnectorType.output, tooltip: 'Kimenet'),
  ];
}

Size _nodeSizeFor(NoteFlowchartNode node) {
  final text = node.label.trim().isEmpty ? _defaultLabel(node.shape) : node.label.trim();
  final explicitLines = text.split('\n');
  final longestLine = explicitLines.fold<int>(0, (max, line) => math.max(max, line.length));
  final width = (188 + longestLine * 3.8).clamp(210.0, 370.0).toDouble();
  var estimatedLines = 0;
  final charsPerLine = math.max(16, ((width - 76) / 7.2).floor());
  for (final line in explicitLines) {
    estimatedLines += math.max(1, (line.length / charsPerLine).ceil());
  }
  final minHeight = node.shape == AiFlowchartNodeShape.decision ? 96.0 : 78.0;
  final height = (48 + estimatedLines * 20.0).clamp(minHeight, 240.0).toDouble();
  return Size(width, height);
}

Offset _edgeStart(NoteFlowchartEdge edge, NoteFlowchartNode from, Map<String, Size> nodeSizes) {
  final connectors = _connectorsForNode(from);
  final normalized = edge.label.trim().toLowerCase();
  final connector = connectors.firstWhere(
    (candidate) {
      if (candidate.type != _ConnectorType.output) {
        return false;
      }
      if (from.shape == AiFlowchartNodeShape.decision) {
        if (normalized == 'igen') {
          return candidate.id == 'yes';
        }
        if (normalized == 'nem') {
          return candidate.id == 'no';
        }
      }
      return candidate.id == 'out' || candidate.type == _ConnectorType.output;
    },
    orElse: () => connectors.last,
  );
  final size = nodeSizes[from.id] ?? _nodeSizeFor(from);
  return Offset(from.x + size.width * connector.unitOffset.dx, from.y + size.height * connector.unitOffset.dy);
}

Offset _edgeEnd(NoteFlowchartNode to, Map<String, Size> nodeSizes) {
  final connectors = _connectorsForNode(to);
  final connector = connectors.firstWhere(
    (candidate) => candidate.type == _ConnectorType.input,
    orElse: () => connectors.first,
  );
  final size = nodeSizes[to.id] ?? _nodeSizeFor(to);
  return Offset(to.x + size.width * connector.unitOffset.dx, to.y + size.height * connector.unitOffset.dy);
}

String _defaultLabel(AiFlowchartNodeShape shape) {
  return switch (shape) {
    AiFlowchartNodeShape.startEnd => 'Kezdés / Vége',
    AiFlowchartNodeShape.decision => 'Döntés?',
    AiFlowchartNodeShape.inputOutput => 'Bemenet / kimenet',
    AiFlowchartNodeShape.subprocess => 'Alfolyamat',
    AiFlowchartNodeShape.dataStore => 'Adattárolás',
    AiFlowchartNodeShape.connector => 'Kapcsoló',
    AiFlowchartNodeShape.process || AiFlowchartNodeShape.unknown => 'Folyamatlépés',
  };
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
