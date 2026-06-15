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
  final GlobalKey _bodyStackKey = GlobalKey();
  late NoteBlock _block;
  _LinkEndpoint? _linkSource;
  NoteFlowchartNodeKind? _paletteDragKind;
  Offset? _paletteDragGlobalPosition;
  Stopwatch? _paletteDragWatch;
  int _paletteDragMoveCount = 0;
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

  void _addNode(NoteFlowchartNodeKind kind, Offset position) {
    final id = _nextNodeId();
    final draft = _nodeDraftForKind(id: id, kind: kind, order: _block.nodes.length + 1);
    final nodeSize = _nodeSizeFor(draft);
    final node = draft.copyWith(
      x: position.dx.clamp(24, _canvasSize.width - nodeSize.width - 24).toDouble(),
      y: position.dy.clamp(24, _canvasSize.height - nodeSize.height - 24).toDouble(),
    );
    _log('node add id=$id kind=${kind.wireName} shape=${node.shape.wireName} x=${node.x.toStringAsFixed(1)} y=${node.y.toStringAsFixed(1)}');
    _emit(_block.copyWith(nodes: [..._positionedNodes, node]));
  }

  NoteFlowchartNode _nodeDraftForKind({
    required String id,
    required NoteFlowchartNodeKind kind,
    required int order,
  }) {
    return switch (kind) {
      NoteFlowchartNodeKind.binaryDecision => NoteFlowchartNode(
          id: id,
          label: 'Döntés?',
          shape: AiFlowchartNodeShape.decision,
          kind: NoteFlowchartNodeKind.binaryDecision,
          visualShape: NoteFlowchartVisualShape.diamond,
          ports: const [
            NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
            NoteFlowchartPort(id: 'yes', side: NoteFlowchartPortSide.bottom, label: 'Igen', semantic: NoteFlowchartPortSemantic.yes),
            NoteFlowchartPort(id: 'no', side: NoteFlowchartPortSide.bottom, label: 'Nem', semantic: NoteFlowchartPortSemantic.no),
          ],
          order: order,
        ),
      NoteFlowchartNodeKind.multiDecision => NoteFlowchartNode(
          id: id,
          label: 'Többágú döntés',
          shape: AiFlowchartNodeShape.decision,
          kind: NoteFlowchartNodeKind.multiDecision,
          visualShape: NoteFlowchartVisualShape.diamond,
          ports: const [
            NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
            NoteFlowchartPort(id: 'branch-1', side: NoteFlowchartPortSide.right, label: 'Ág 1', semantic: NoteFlowchartPortSemantic.custom),
            NoteFlowchartPort(id: 'branch-2', side: NoteFlowchartPortSide.bottom, label: 'Ág 2', semantic: NoteFlowchartPortSemantic.custom),
          ],
          order: order,
        ),
      NoteFlowchartNodeKind.universal => NoteFlowchartNode(
          id: id,
          label: 'Folyamatlépés',
          shape: AiFlowchartNodeShape.process,
          kind: NoteFlowchartNodeKind.universal,
          visualShape: NoteFlowchartVisualShape.rectangle,
          ports: const [
            NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
            NoteFlowchartPort(id: 'out', side: NoteFlowchartPortSide.bottom, label: 'Kimenet'),
          ],
          order: order,
        ),
    };
  }

  void _addDroppedNode(NoteFlowchartNodeKind kind, Offset globalOffset) {
    final context = _canvasKey.currentContext;
    if (context == null) {
      _log('drop fallback kind=${kind.wireName} reason=no_canvas_context');
      _addNode(kind, const Offset(120, 120));
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(globalOffset) ?? const Offset(120, 120);
    final draftSize = _nodeSizeFor(_nodeDraftForKind(id: 'draft', kind: kind, order: 0));
    final centered = local - Offset(draftSize.width / 2, draftSize.height / 2);
    _log(
      'drop kind=${kind.wireName} global=${globalOffset.dx.toStringAsFixed(1)},${globalOffset.dy.toStringAsFixed(1)} '
      'local=${local.dx.toStringAsFixed(1)},${local.dy.toStringAsFixed(1)}',
    );
    _addNode(kind, centered);
  }

  String _formatOffset(Offset offset) {
    return '${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)}';
  }

  RenderBox? _canvasBox() {
    final context = _canvasKey.currentContext;
    if (context == null) {
      return null;
    }
    return context.findRenderObject() as RenderBox?;
  }

  Offset? _canvasLocalFromGlobal(Offset globalPosition) {
    final box = _canvasBox();
    return box?.globalToLocal(globalPosition);
  }

  bool _isInCanvas(Offset localPosition) {
    return localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= _canvasSize.width &&
        localPosition.dy <= _canvasSize.height;
  }

  Offset? _paletteGhostBodyPosition() {
    final globalPosition = _paletteDragGlobalPosition;
    if (globalPosition == null) {
      return null;
    }
    final context = _bodyStackKey.currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    final local = box?.globalToLocal(globalPosition) ?? globalPosition;
    return local - const Offset(28, 28);
  }

  void _startPaletteDrag(NoteFlowchartNodeKind kind, Offset globalPosition) {
    HapticFeedback.selectionClick();
    final canvasLocal = _canvasLocalFromGlobal(globalPosition);
    _paletteDragWatch = Stopwatch()..start();
    _paletteDragMoveCount = 0;
    setState(() {
      _paletteDragKind = kind;
      _paletteDragGlobalPosition = globalPosition;
    });
    _log(
      'palette long_press_start kind=${kind.wireName} '
      'global=${_formatOffset(globalPosition)} canvasReady=${_canvasKey.currentContext != null} '
      'canvasLocal=${canvasLocal == null ? 'null' : _formatOffset(canvasLocal)}',
    );
  }

  void _updatePaletteDrag(NoteFlowchartNodeKind kind, Offset globalPosition) {
    if (_paletteDragKind != kind) {
      _log(
        'palette drag update ignored kind=${kind.wireName} '
        'active=${_paletteDragKind?.wireName ?? 'none'} reason=stale_kind',
      );
      return;
    }
    _paletteDragMoveCount += 1;
    final canvasLocal = _canvasLocalFromGlobal(globalPosition);
    final overCanvas = canvasLocal != null && _isInCanvas(canvasLocal);
    setState(() => _paletteDragGlobalPosition = globalPosition);
    if (_paletteDragMoveCount == 1 || _paletteDragMoveCount % 8 == 0) {
      _log(
        'palette drag_move kind=${kind.wireName} moves=$_paletteDragMoveCount '
        'global=${_formatOffset(globalPosition)} overCanvas=$overCanvas '
        'canvasLocal=${canvasLocal == null ? 'null' : _formatOffset(canvasLocal)}',
      );
    }
  }

  void _endPaletteDrag(NoteFlowchartNodeKind kind, Offset globalPosition) {
    final watch = _paletteDragWatch;
    watch?.stop();
    final activeKind = _paletteDragKind;
    final canvasLocal = _canvasLocalFromGlobal(globalPosition);
    final accepted = activeKind == kind && canvasLocal != null && _isInCanvas(canvasLocal);
    _log(
      'palette drag_end kind=${kind.wireName} active=${activeKind?.wireName ?? 'none'} '
      'moves=$_paletteDragMoveCount elapsedMs=${watch?.elapsedMilliseconds ?? 0} '
      'global=${_formatOffset(globalPosition)} accepted=$accepted '
      'canvasLocal=${canvasLocal == null ? 'null' : _formatOffset(canvasLocal)}',
    );
    setState(() {
      _paletteDragKind = null;
      _paletteDragGlobalPosition = null;
      _paletteDragWatch = null;
      _paletteDragMoveCount = 0;
    });
    if (accepted) {
      _addDroppedNode(kind, globalPosition);
    } else {
      final reason = activeKind != kind
          ? 'stale_kind'
          : canvasLocal == null
              ? 'no_canvas_context'
              : 'outside_canvas';
      _log('palette drop rejected kind=${kind.wireName} reason=$reason');
    }
  }

  void _cancelPaletteDrag(NoteFlowchartNodeKind kind) {
    final watch = _paletteDragWatch;
    watch?.stop();
    _log(
      'palette drag_cancel kind=${kind.wireName} active=${_paletteDragKind?.wireName ?? 'none'} '
      'moves=$_paletteDragMoveCount elapsedMs=${watch?.elapsedMilliseconds ?? 0}',
    );
    setState(() {
      _paletteDragKind = null;
      _paletteDragGlobalPosition = null;
      _paletteDragWatch = null;
      _paletteDragMoveCount = 0;
    });
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

  void _replaceNode(NoteFlowchartNode edited, {String reason = 'node_update'}) {
    _log('node update id=${edited.id} reason=$reason kind=${edited.kind.wireName} ports=${edited.ports.length}');
    _emit(_block.copyWith(
      nodes: [
        for (final current in _positionedNodes)
          if (current.id == edited.id) edited else current,
      ],
    ));
  }

  void _openNodeConfig(NoteFlowchartNode node) {
    _log('popup open node=${node.id} kind=${node.kind.wireName} ports=${_portsForNode(node).length}');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        var draft = _positionedNodes.firstWhere(
          (candidate) => candidate.id == node.id,
          orElse: () => node,
        );
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void update(NoteFlowchartNode next, String reason) {
              setSheetState(() => draft = next);
              _replaceNode(next, reason: reason);
            }

            return SafeArea(
              child: Padding(
                key: const ValueKey('note-flowchart-node-popup'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Elem beállításai',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Bezárás',
                            onPressed: () {
                              _log('popup close node=${draft.id} reason=close_button');
                              Navigator.of(sheetContext).pop();
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _NodeConfigSection(
                        title: 'Típus',
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final kind in NoteFlowchartNodeKind.values)
                                ChoiceChip(
                                  key: ValueKey('note-flowchart-node-popup-type-${_kindKey(kind)}'),
                                  selected: draft.kind == kind,
                                  label: Text(_kindLabel(kind)),
                                  onSelected: (_) => update(_nodeWithKind(draft, kind), 'kind'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      _NodeConfigSection(
                        title: 'Szerep',
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final role in NoteFlowchartNodeRole.values)
                                ChoiceChip(
                                  selected: draft.role == role,
                                  label: Text(_roleLabel(role)),
                                  onSelected: (_) => update(draft.copyWith(role: role), 'role'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      _NodeConfigSection(
                        title: 'Forma',
                        children: [
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final shape in NoteFlowchartVisualShape.values)
                                ChoiceChip(
                                  selected: draft.visualShape == shape,
                                  label: Text(_visualShapeLabel(shape)),
                                  onSelected: (_) => update(draft.copyWith(visualShape: shape), 'visual_shape'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      _NodeConfigSection(
                        title: 'Portok',
                        children: [
                          for (final side in NoteFlowchartPortSide.values)
                            _PortSideRow(
                              side: side,
                              ports: _portsForNode(draft).where((port) => port.side == side).toList(growable: false),
                              onAdd: () => update(_addPortToNode(draft, side), 'port_add_${side.wireName}'),
                              onDelete: (port) => update(
                                draft.copyWith(ports: _portsForNode(draft).where((item) => item.id != port.id).toList(growable: false)),
                                'port_delete_${port.id}',
                              ),
                            ),
                        ],
                      ),
                      _NodeConfigSection(
                        title: 'Előnézet',
                        children: [_NodePortPreview(node: draft)],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => _log('popup close node=${node.id} reason=sheet_closed'));
  }

  NoteFlowchartNode _nodeWithKind(NoteFlowchartNode node, NoteFlowchartNodeKind kind) {
    final draft = _nodeDraftForKind(id: node.id, kind: kind, order: node.order);
    return node.copyWith(
      kind: kind,
      shape: draft.shape,
      visualShape: draft.visualShape,
      ports: draft.ports,
      label: node.label.trim().isEmpty ? draft.label : node.label,
    );
  }

  NoteFlowchartNode _addPortToNode(NoteFlowchartNode node, NoteFlowchartPortSide side) {
    final ports = _portsForNode(node);
    final countOnSide = ports.where((port) => port.side == side).length + 1;
    final idBase = '${side.wireName}-$countOnSide';
    var id = idBase;
    var suffix = 2;
    while (ports.any((port) => port.id == id)) {
      id = '$idBase-$suffix';
      suffix += 1;
    }
    final port = NoteFlowchartPort(id: id, side: side, label: _sideLabel(side));
    _log('port add node=${node.id} port=${port.id} side=${side.wireName}');
    return node.copyWith(ports: [...ports, port]);
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
    if (source.nodeId == node.id) {
      setState(() => _linkSource = null);
      _log('connector cancelled same_node node=${node.id}');
      return;
    }
    final edge = NoteFlowchartEdge(
      id: _nextEdgeId(),
      fromNodeId: source.nodeId,
      fromPortId: source.connectorId,
      toNodeId: node.id,
      toPortId: connector.id,
      label: source.edgeLabel,
      order: _block.edges.length + 1,
    );
    _log(
      'edge add id=${edge.id} from=${edge.fromNodeId}.${source.connectorId} '
      'to=${edge.toNodeId}.${connector.id} label=${edge.label}',
    );
    _logEdgeRouteFromCallback(_log, edge, _positionedNodes, _nodeSizesFor(_positionedNodes));
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
        key: _bodyStackKey,
        children: [
          InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(800),
            minScale: 0.35,
            maxScale: 2.5,
            child: DragTarget<NoteFlowchartNodeKind>(
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
                            left: node.x - _CanvasNodeCard.connectorPadding,
                            top: node.y - _CanvasNodeCard.connectorPadding,
                            width: (nodeSizes[node.id]?.width ?? _nodeSizeFor(node).width) + _CanvasNodeCard.connectorPadding * 2,
                            height: (nodeSizes[node.id]?.height ?? _nodeSizeFor(node).height) + _CanvasNodeCard.connectorPadding * 2,
                            child: _CanvasNodeCard(
                              node: node,
                              size: nodeSizes[node.id] ?? _nodeSizeFor(node),
                              connectors: _connectorsForNode(node),
                              linkSource: _linkSource,
                              onMoveStart: () => _beginMove(node),
                              onMove: (delta) => _moveNode(node, delta),
                              onMoveEnd: () => _endMove(node),
                              onEdit: () => _editNode(node),
                              onOpenConfig: () => _openNodeConfig(node),
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
              activeKind: _paletteDragKind,
              onTapIgnored: (kind) => _log('palette tap ignored kind=${kind.wireName} reason=drag_only'),
              onDragStart: _startPaletteDrag,
              onDragUpdate: _updatePaletteDrag,
              onDragEnd: _endPaletteDrag,
              onDragCancel: _cancelPaletteDrag,
            ),
          ),
          if (_paletteDragKind != null && _paletteGhostBodyPosition() != null)
            Positioned(
              left: _paletteGhostBodyPosition()!.dx,
              top: _paletteGhostBodyPosition()!.dy,
              child: IgnorePointer(
                child: _PaletteGhost(kind: _paletteDragKind!),
              ),
            ),
        ],
      ),
    );
  }
}

class _CanvasNodeCard extends StatelessWidget {
  static const double connectorPadding = 22;

  const _CanvasNodeCard({
    required this.node,
    required this.size,
    required this.connectors,
    required this.linkSource,
    required this.onMoveStart,
    required this.onMove,
    required this.onMoveEnd,
    required this.onEdit,
    required this.onOpenConfig,
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
  final VoidCallback onOpenConfig;
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
          width: size.width + connectorPadding * 2,
          height: size.height + connectorPadding * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: connectorPadding,
                top: connectorPadding,
                width: size.width,
                height: size.height,
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
                          GestureDetector(
                            key: ValueKey('note-flowchart-node-body-${node.id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onOpenConfig,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(_nodeIcon(node), color: const Color(0xFF7C3AED)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onOpenConfig,
                                  child: Text(
                                    _nodeTypeLabel(node),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w800,
                                    ),
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
                  right: connectorPadding + 2,
                  bottom: connectorPadding + 2,
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
        : connector.semantic == NoteFlowchartPortSemantic.normal
            ? const Color(0xFF059669)
            : const Color(0xFF7C3AED);
    final icon = switch (connector.semantic) {
      NoteFlowchartPortSemantic.yes => Icons.add,
      NoteFlowchartPortSemantic.no => Icons.remove,
      NoteFlowchartPortSemantic.custom => Icons.call_split,
      NoteFlowchartPortSemantic.normal => Icons.radio_button_checked,
    };
    return Positioned(
      left: connector.unitOffset.dx * connector.nodeSize.width,
      top: connector.unitOffset.dy * connector.nodeSize.height,
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
                    child: Icon(icon, size: connector.semantic == NoteFlowchartPortSemantic.normal ? 12 : 15, color: color),
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
  const _FlowchartPalette({
    required this.activeKind,
    required this.onTapIgnored,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
  });

  final NoteFlowchartNodeKind? activeKind;
  final ValueChanged<NoteFlowchartNodeKind> onTapIgnored;
  final void Function(NoteFlowchartNodeKind kind, Offset globalPosition) onDragStart;
  final void Function(NoteFlowchartNodeKind kind, Offset globalPosition) onDragUpdate;
  final void Function(NoteFlowchartNodeKind kind, Offset globalPosition) onDragEnd;
  final ValueChanged<NoteFlowchartNodeKind> onDragCancel;

  @override
  Widget build(BuildContext context) {
    const kinds = [
      NoteFlowchartNodeKind.universal,
      NoteFlowchartNodeKind.binaryDecision,
      NoteFlowchartNodeKind.multiDecision,
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
            for (final kind in kinds) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTapIgnored(kind),
                onLongPressStart: (details) => onDragStart(kind, details.globalPosition),
                onLongPressMoveUpdate: (details) => onDragUpdate(kind, details.globalPosition),
                onLongPressEnd: (details) => onDragEnd(kind, details.globalPosition),
                onLongPressCancel: () => onDragCancel(kind),
                child: Opacity(
                  opacity: activeKind == kind ? 0.35 : 1,
                  child: _PaletteButton(kind: kind),
                ),
              ),
              if (kind != kinds.last) const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _PaletteButton extends StatelessWidget {
  const _PaletteButton({required this.kind});

  final NoteFlowchartNodeKind kind;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _kindLabel(kind),
      button: true,
      child: DecoratedBox(
        key: ValueKey('note-flowchart-palette-${_kindKey(kind)}'),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: SizedBox.square(
          dimension: 48,
          child: Icon(_kindIcon(kind), color: const Color(0xFF374151)),
        ),
      ),
    );
  }
}

class _PaletteGhost extends StatelessWidget {
  const _PaletteGhost({required this.kind});

  final NoteFlowchartNodeKind kind;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('note-flowchart-palette-ghost-${_kindKey(kind)}'),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: SizedBox.square(
        dimension: 56,
        child: Icon(_kindIcon(kind), color: Colors.white),
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
    if (from == null || to == null) {
      return const SizedBox.shrink();
    }
    final route = _routeEdge(edge, from, to, nodeSizes);
    final points = route.points;
    final middle = points[points.length ~/ 2];
    final display = edge.label.trim().isEmpty ? 'Kapcsolat' : edge.label.trim();
    return Positioned(
      left: middle.dx - 44,
      top: middle.dy - 18,
      child: DecoratedBox(
        key: ValueKey('note-flowchart-edge-${edge.id}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE9D5FF)),
          boxShadow: const [BoxShadow(color: Color(0x14111827), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, right: 2),
              child: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              key: ValueKey('note-flowchart-edge-delete-${edge.id}'),
              tooltip: 'Kapcsolat törlése',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 15),
            ),
          ],
        ),
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
      final route = _routeEdge(edge, from, to, nodeSizes);
      if (route.points.length < 2) {
        continue;
      }
      final path = Path()..moveTo(route.points.first.dx, route.points.first.dy);
      for (final point in route.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      _drawArrow(canvas, route.points[route.points.length - 2], route.points.last, arrowPaint);
    }
  }

  void _drawArrow(Canvas canvas, Offset previous, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
    const size = 9.0;
    final p1 = end - Offset(math.cos(angle - math.pi / 7) * size, math.sin(angle - math.pi / 7) * size);
    final p2 = end - Offset(math.cos(angle + math.pi / 7) * size, math.sin(angle + math.pi / 7) * size);
    final arrow = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(arrow, paint);
  }

  @override
  bool shouldRepaint(covariant _FlowchartEdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges || oldDelegate.nodeSizes != nodeSizes;
  }
}

class _NodeConfigSection extends StatelessWidget {
  const _NodeConfigSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _PortSideRow extends StatelessWidget {
  const _PortSideRow({
    required this.side,
    required this.ports,
    required this.onAdd,
    required this.onDelete,
  });

  final NoteFlowchartPortSide side;
  final List<NoteFlowchartPort> ports;
  final VoidCallback onAdd;
  final ValueChanged<NoteFlowchartPort> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_sideLabel(side), style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final port in ports)
                  InputChip(
                    label: Text(port.label.trim().isEmpty ? port.id : port.label.trim()),
                    onDeleted: () => onDelete(port),
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton.filledTonal(
                  key: ValueKey('note-flowchart-node-popup-add-port-${side.wireName}'),
                  tooltip: 'Port hozzáadása: ${_sideLabel(side)}',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodePortPreview extends StatelessWidget {
  const _NodePortPreview({required this.node});

  final NoteFlowchartNode node;

  @override
  Widget build(BuildContext context) {
    final ports = _portsForNode(node);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SizedBox(
        height: 116,
        child: Stack(
          children: [
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(node.visualShape == NoteFlowchartVisualShape.oval ? 999 : 8),
                  border: Border.all(color: const Color(0xFF7C3AED)),
                ),
                child: SizedBox(
                  width: 150,
                  height: 58,
                  child: Center(
                    child: Text(
                      _nodeTypeLabel(node),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
            for (final side in NoteFlowchartPortSide.values)
              for (var i = 0; i < ports.where((port) => port.side == side).length; i += 1)
                _PreviewPortDot(side: side, index: i, count: ports.where((port) => port.side == side).length),
          ],
        ),
      ),
    );
  }
}

class _PreviewPortDot extends StatelessWidget {
  const _PreviewPortDot({required this.side, required this.index, required this.count});

  final NoteFlowchartPortSide side;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final fraction = (index + 1) / (count + 1);
    final left = switch (side) {
      NoteFlowchartPortSide.left => 54.0,
      NoteFlowchartPortSide.right => 222.0,
      NoteFlowchartPortSide.top => 74 + 132 * fraction,
      NoteFlowchartPortSide.bottom => 74 + 132 * fraction,
    };
    final top = switch (side) {
      NoteFlowchartPortSide.top => 26.0,
      NoteFlowchartPortSide.bottom => 86.0,
      NoteFlowchartPortSide.left => 34 + 44 * fraction,
      NoteFlowchartPortSide.right => 34 + 44 * fraction,
    };
    return Positioned(
      left: left,
      top: top,
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
        child: SizedBox.square(dimension: 10),
      ),
    );
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

class _ConnectorSpec {
  const _ConnectorSpec({
    required this.id,
    required this.nodeId,
    required this.nodeSize,
    required this.unitOffset,
    required this.side,
    required this.semantic,
    required this.tooltip,
    this.edgeLabel = '',
  });

  final String id;
  final String nodeId;
  final Size nodeSize;
  final Offset unitOffset;
  final NoteFlowchartPortSide side;
  final NoteFlowchartPortSemantic semantic;
  final String tooltip;
  final String edgeLabel;
}

List<NoteFlowchartPort> _portsForNode(NoteFlowchartNode node) {
  if (node.ports.isNotEmpty) {
    return node.ports;
  }
  if (node.kind == NoteFlowchartNodeKind.binaryDecision || node.shape == AiFlowchartNodeShape.decision) {
    return const [
      NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
      NoteFlowchartPort(id: 'yes', side: NoteFlowchartPortSide.bottom, label: 'Igen', semantic: NoteFlowchartPortSemantic.yes),
      NoteFlowchartPort(id: 'no', side: NoteFlowchartPortSide.bottom, label: 'Nem', semantic: NoteFlowchartPortSemantic.no),
    ];
  }
  if (node.kind == NoteFlowchartNodeKind.multiDecision) {
    return const [
      NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
      NoteFlowchartPort(id: 'branch-1', side: NoteFlowchartPortSide.right, label: 'Ág 1', semantic: NoteFlowchartPortSemantic.custom),
      NoteFlowchartPort(id: 'branch-2', side: NoteFlowchartPortSide.bottom, label: 'Ág 2', semantic: NoteFlowchartPortSemantic.custom),
    ];
  }
  if (node.role == NoteFlowchartNodeRole.start) {
    return const [NoteFlowchartPort(id: 'out', side: NoteFlowchartPortSide.bottom, label: 'Kimenet')];
  }
  if (node.role == NoteFlowchartNodeRole.end) {
    return const [NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet')];
  }
  return const [
    NoteFlowchartPort(id: 'in', side: NoteFlowchartPortSide.top, label: 'Bemenet'),
    NoteFlowchartPort(id: 'out', side: NoteFlowchartPortSide.bottom, label: 'Kimenet'),
  ];
}

List<_ConnectorSpec> _connectorsForNode(NoteFlowchartNode node) {
  final size = _nodeSizeFor(node);
  final ports = _portsForNode(node);
  final grouped = <NoteFlowchartPortSide, List<NoteFlowchartPort>>{
    for (final side in NoteFlowchartPortSide.values) side: ports.where((port) => port.side == side).toList(growable: false),
  };
  return [
    for (final side in NoteFlowchartPortSide.values)
      for (var i = 0; i < grouped[side]!.length; i += 1)
        _ConnectorSpec(
          id: grouped[side]![i].id,
          nodeId: node.id,
          nodeSize: size,
          unitOffset: _portUnitOffset(side, i, grouped[side]!.length),
          side: side,
          semantic: grouped[side]![i].semantic,
          tooltip: grouped[side]![i].label.trim().isEmpty ? _sideLabel(side) : grouped[side]![i].label.trim(),
          edgeLabel: _edgeLabelForPort(grouped[side]![i]),
        ),
  ];
}

Offset _portUnitOffset(NoteFlowchartPortSide side, int index, int count) {
  final fraction = (index + 1) / (count + 1);
  return switch (side) {
    NoteFlowchartPortSide.top => Offset(fraction, 0),
    NoteFlowchartPortSide.bottom => Offset(fraction, 1),
    NoteFlowchartPortSide.left => Offset(0, fraction),
    NoteFlowchartPortSide.right => Offset(1, fraction),
  };
}

String _edgeLabelForPort(NoteFlowchartPort port) {
  if (port.semantic == NoteFlowchartPortSemantic.yes) {
    return 'Igen';
  }
  if (port.semantic == NoteFlowchartPortSemantic.no) {
    return 'Nem';
  }
  if (port.semantic == NoteFlowchartPortSemantic.custom) {
    return port.label.trim();
  }
  return '';
}

Size _nodeSizeFor(NoteFlowchartNode node) {
  final text = node.label.trim().isEmpty ? _defaultLabelForNode(node) : node.label.trim();
  final explicitLines = text.split('\n');
  final longestLine = explicitLines.fold<int>(0, (max, line) => math.max(max, line.length));
  final width = (188 + longestLine * 3.8).clamp(210.0, 370.0).toDouble();
  var estimatedLines = 0;
  final charsPerLine = math.max(16, ((width - 76) / 7.2).floor());
  for (final line in explicitLines) {
    estimatedLines += math.max(1, (line.length / charsPerLine).ceil());
  }
  final minHeight = node.kind == NoteFlowchartNodeKind.binaryDecision || node.kind == NoteFlowchartNodeKind.multiDecision || node.shape == AiFlowchartNodeShape.decision ? 96.0 : 78.0;
  final height = (48 + estimatedLines * 20.0).clamp(minHeight, 240.0).toDouble();
  return Size(width, height);
}

Offset _edgeStart(NoteFlowchartEdge edge, NoteFlowchartNode from, Map<String, Size> nodeSizes) {
  final connectors = _connectorsForNode(from);
  final connector = connectors.firstWhere(
    (candidate) {
      if (edge.fromPortId != null) {
        return candidate.id == edge.fromPortId;
      }
      final normalized = edge.label.trim().toLowerCase();
      if (normalized == 'igen') {
        return candidate.semantic == NoteFlowchartPortSemantic.yes;
      }
      if (normalized == 'nem') {
        return candidate.semantic == NoteFlowchartPortSemantic.no;
      }
      return candidate.id == 'out' || candidate.side == NoteFlowchartPortSide.bottom || candidate.side == NoteFlowchartPortSide.right;
    },
    orElse: () => connectors.isEmpty
        ? _ConnectorSpec(
            id: 'center',
            nodeId: from.id,
            nodeSize: nodeSizes[from.id] ?? _nodeSizeFor(from),
            unitOffset: const Offset(0.5, 0.5),
            side: NoteFlowchartPortSide.bottom,
            semantic: NoteFlowchartPortSemantic.normal,
            tooltip: 'Kapcsolat',
          )
        : connectors.last,
  );
  final size = nodeSizes[from.id] ?? _nodeSizeFor(from);
  return Offset(from.x + size.width * connector.unitOffset.dx, from.y + size.height * connector.unitOffset.dy);
}

Offset _edgeEnd(NoteFlowchartEdge edge, NoteFlowchartNode to, Map<String, Size> nodeSizes) {
  final connectors = _connectorsForNode(to);
  final connector = connectors.firstWhere(
    (candidate) {
      if (edge.toPortId != null) {
        return candidate.id == edge.toPortId;
      }
      return candidate.id == 'in' || candidate.side == NoteFlowchartPortSide.top || candidate.side == NoteFlowchartPortSide.left;
    },
    orElse: () => connectors.isEmpty
        ? _ConnectorSpec(
            id: 'center',
            nodeId: to.id,
            nodeSize: nodeSizes[to.id] ?? _nodeSizeFor(to),
            unitOffset: const Offset(0.5, 0.5),
            side: NoteFlowchartPortSide.top,
            semantic: NoteFlowchartPortSemantic.normal,
            tooltip: 'Kapcsolat',
          )
        : connectors.first,
  );
  final size = nodeSizes[to.id] ?? _nodeSizeFor(to);
  return Offset(to.x + size.width * connector.unitOffset.dx, to.y + size.height * connector.unitOffset.dy);
}

FlowchartRouteDebug debugFlowchartRouteForTest(
  NoteFlowchartEdge edge,
  NoteFlowchartNode from,
  NoteFlowchartNode to,
  Map<String, Size> nodeSizes,
) {
  return _routeEdge(edge, from, to, nodeSizes);
}

class FlowchartRouteDebug {
  const FlowchartRouteDebug({required this.kind, required this.points});

  final String kind;
  final List<Offset> points;
}

FlowchartRouteDebug _routeEdge(
  NoteFlowchartEdge edge,
  NoteFlowchartNode from,
  NoteFlowchartNode to,
  Map<String, Size> nodeSizes,
) {
  final start = _edgeStart(edge, from, nodeSizes);
  final end = _edgeEnd(edge, to, nodeSizes);
  final fromSize = nodeSizes[from.id] ?? _nodeSizeFor(from);
  final toSize = nodeSizes[to.id] ?? _nodeSizeFor(to);
  final fromRect = Rect.fromLTWH(from.x, from.y, fromSize.width, fromSize.height).inflate(18);
  final toRect = Rect.fromLTWH(to.x, to.y, toSize.width, toSize.height).inflate(18);
  final isBackEdge = toRect.center.dy < fromRect.center.dy - 8;
  if (isBackEdge) {
    final leftLane = (math.min(fromRect.left, toRect.left) - 42).toDouble();
    final rightLane = (math.max(fromRect.right, toRect.right) + 42).toDouble();
    final useLeft = (start.dx - leftLane).abs() <= (rightLane - start.dx).abs();
    final laneX = useLeft ? leftLane : rightLane;
    final entryX = end.dx + (useLeft ? -24 : 24);
    return FlowchartRouteDebug(
      kind: 'backEdge',
      points: [
        start,
        Offset(laneX, start.dy),
        Offset(laneX, end.dy),
        Offset(entryX, end.dy),
        end,
      ],
    );
  }
  final midY = (start.dy + end.dy) / 2;
  return FlowchartRouteDebug(
    kind: 'orthogonal',
    points: [
      start,
      Offset(start.dx, midY),
      Offset(end.dx, midY),
      end,
    ],
  );
}

void _logEdgeRouteFromCallback(
  void Function(String message) log,
  NoteFlowchartEdge edge,
  List<NoteFlowchartNode> nodes,
  Map<String, Size> nodeSizes,
) {
  NoteFlowchartNode? from;
  NoteFlowchartNode? to;
  for (final node in nodes) {
    if (node.id == edge.fromNodeId) {
      from = node;
    }
    if (node.id == edge.toNodeId) {
      to = node;
    }
  }
  if (from == null || to == null) {
    return;
  }
  final route = _routeEdge(edge, from, to, nodeSizes);
  log('edge route id=${edge.id} kind=${route.kind} points=${route.points.length}');
}

String _defaultLabelForNode(NoteFlowchartNode node) {
  return switch (node.kind) {
    NoteFlowchartNodeKind.binaryDecision => 'Döntés?',
    NoteFlowchartNodeKind.multiDecision => 'Többágú döntés',
    NoteFlowchartNodeKind.universal => switch (node.role) {
        NoteFlowchartNodeRole.start => 'Kezdés',
        NoteFlowchartNodeRole.end => 'Vége',
        NoteFlowchartNodeRole.normal => 'Folyamatlépés',
      },
  };
}

String _kindKey(NoteFlowchartNodeKind kind) {
  return switch (kind) {
    NoteFlowchartNodeKind.universal => 'universal',
    NoteFlowchartNodeKind.binaryDecision => 'binary-decision',
    NoteFlowchartNodeKind.multiDecision => 'multi-decision',
  };
}

String _kindLabel(NoteFlowchartNodeKind kind) {
  return switch (kind) {
    NoteFlowchartNodeKind.universal => 'Univerzális',
    NoteFlowchartNodeKind.binaryDecision => 'Igen/Nem döntés',
    NoteFlowchartNodeKind.multiDecision => 'Többágú döntés',
  };
}

IconData _kindIcon(NoteFlowchartNodeKind kind) {
  return switch (kind) {
    NoteFlowchartNodeKind.universal => Icons.crop_square,
    NoteFlowchartNodeKind.binaryDecision => Icons.change_history,
    NoteFlowchartNodeKind.multiDecision => Icons.account_tree_outlined,
  };
}

NoteFlowchartNodeKind _effectiveKind(NoteFlowchartNode node) {
  if (node.kind == NoteFlowchartNodeKind.universal && node.shape == AiFlowchartNodeShape.decision) {
    return NoteFlowchartNodeKind.binaryDecision;
  }
  return node.kind;
}

IconData _nodeIcon(NoteFlowchartNode node) {
  if (node.role == NoteFlowchartNodeRole.start || node.role == NoteFlowchartNodeRole.end || node.visualShape == NoteFlowchartVisualShape.oval) {
    return Icons.trip_origin;
  }
  return _kindIcon(_effectiveKind(node));
}

String _nodeTypeLabel(NoteFlowchartNode node) {
  if (node.role == NoteFlowchartNodeRole.start) {
    return 'Kezdés';
  }
  if (node.role == NoteFlowchartNodeRole.end) {
    return 'Vége';
  }
  return _kindLabel(_effectiveKind(node));
}

String _roleLabel(NoteFlowchartNodeRole role) {
  return switch (role) {
    NoteFlowchartNodeRole.normal => 'Normál',
    NoteFlowchartNodeRole.start => 'Kezdés',
    NoteFlowchartNodeRole.end => 'Vége',
  };
}

String _visualShapeLabel(NoteFlowchartVisualShape shape) {
  return switch (shape) {
    NoteFlowchartVisualShape.rectangle => 'Téglalap',
    NoteFlowchartVisualShape.oval => 'Ovális',
    NoteFlowchartVisualShape.diamond => 'Rombusz',
  };
}

String _sideLabel(NoteFlowchartPortSide side) {
  return switch (side) {
    NoteFlowchartPortSide.top => 'Fent',
    NoteFlowchartPortSide.right => 'Jobb',
    NoteFlowchartPortSide.bottom => 'Lent',
    NoteFlowchartPortSide.left => 'Bal',
  };
}
