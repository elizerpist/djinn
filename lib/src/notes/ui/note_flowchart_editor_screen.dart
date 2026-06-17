import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ai/ai_client.dart';
import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteFlowchartEditorScreen extends StatefulWidget {
  const NoteFlowchartEditorScreen({
    super.key,
    required this.block,
    this.availableTags = const [],
    this.onChanged,
    this.onDelete,
  });

  final NoteBlock block;
  final List<NoteKnowledgeTag> availableTags;
  final ValueChanged<NoteBlock>? onChanged;
  final VoidCallback? onDelete;

  @override
  State<NoteFlowchartEditorScreen> createState() => _NoteFlowchartEditorScreenState();
}

class _NoteFlowchartEditorScreenState extends State<NoteFlowchartEditorScreen> {
  static const Size _minCanvasSize = Size(32000, 24000);
  static const double _canvasMargin = 8000;
  static const double _gridStep = 32;

  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _bodyStackKey = GlobalKey();
  final TransformationController _canvasController = TransformationController();
  late NoteBlock _block;
  _LinkEndpoint? _linkSource;
  NoteFlowchartNodeKind? _paletteDragKind;
  Offset? _paletteDragGlobalPosition;
  Stopwatch? _paletteDragWatch;
  int _paletteDragMoveCount = 0;
  final TextEditingController _inlineNodeController = TextEditingController();
  final TextEditingController _inlineEdgeController = TextEditingController();
  String? _editingNodeId;
  String? _editingEdgeId;
  String? _selectedNodeId;
  String? _selectedEdgeId;
  final Map<String, Stopwatch> _dragWatches = <String, Stopwatch>{};
  final Map<String, int> _dragMoveCounts = <String, int>{};
  Size _viewportSize = const Size(430, 720);
  int _viewportLogTick = 0;
  bool _initialCanvasCentered = false;

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
    _centerInitialCanvas();
    _canvasController.addListener(_onCanvasTransformChanged);
    _log('editor init nodes=${_block.nodes.length} edges=${_block.edges.length}');
  }

  @override
  void dispose() {
    _canvasController.removeListener(_onCanvasTransformChanged);
    _canvasController.dispose();
    _inlineNodeController.dispose();
    _inlineEdgeController.dispose();
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
    final updated = _block.copyWith(
      type: NoteBlockType.flowchart,
      nodes: _positionedNodes,
      clearIndex: clearIndex,
    );
    _block = updated;
    widget.onChanged?.call(updated);
    _log('commit reason=$reason nodes=${updated.nodes.length} edges=${updated.edges.length} clearIndex=$clearIndex');
  }

  void _save() {
    Navigator.of(context).pop(_block);
  }

  void _emitTitle(String value) {
    setState(() => _block = _block.copyWith(title: value.trim(), clearIndex: true));
    widget.onChanged?.call(_block);
  }

  Future<void> _tagChunk() async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: _block.tags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Chunk tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() => _block = _block.copyWith(tags: tags, clearIndex: true));
    widget.onChanged?.call(_block);
  }

  Future<void> _tagSelection() async {
    final target = _selectedTarget;
    if (target == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz ki egy flowchart elemet a tageléshez')),
      );
      return;
    }
    final tags = await showTagManagerSheet(
      context,
      initialTags: _tagsForTarget(target),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: target.kind == NoteTagTargetKind.flowchartEdge
          ? 'Flowchart kapcsolat tagjei'
          : 'Flowchart box tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!_sameTagTarget(assignment.target, target)) assignment,
          if (tags.isNotEmpty)
            NoteScopedTagAssignment(
              id: 'flow-tag-${DateTime.now().microsecondsSinceEpoch}',
              target: target,
              tags: tags,
            ),
        ],
        clearIndex: true,
      );
    });
    widget.onChanged?.call(_block);
  }

  void _deleteSelectedTag() {
    final target = _selectedTarget;
    if (target == null) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!_sameTagTarget(assignment.target, target)) assignment,
        ],
        clearIndex: true,
      );
    });
    widget.onChanged?.call(_block);
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  bool _sameTagTarget(NoteTagTarget left, NoteTagTarget right) {
    return left.kind == right.kind && left.elementId == right.elementId;
  }

  NoteTagTarget? get _selectedTarget {
    final selectedNodeId = _selectedNodeId;
    if (selectedNodeId != null) {
      return NoteTagTarget(
        kind: NoteTagTargetKind.flowchartNode,
        elementId: selectedNodeId,
      );
    }
    final selectedEdgeId = _selectedEdgeId;
    if (selectedEdgeId != null) {
      return NoteTagTarget(
        kind: NoteTagTargetKind.flowchartEdge,
        elementId: selectedEdgeId,
      );
    }
    return null;
  }

  List<NoteKnowledgeTag> _tagsForTarget(NoteTagTarget target) {
    for (final assignment in _block.scopedTags) {
      if (_sameTagTarget(assignment.target, target)) {
        return assignment.tags;
      }
    }
    return const [];
  }

  List<NoteKnowledgeTag> _tagsForNode(String nodeId) {
    return _tagsForTarget(
      NoteTagTarget(kind: NoteTagTargetKind.flowchartNode, elementId: nodeId),
    );
  }

  List<NoteKnowledgeTag> _tagsForEdge(String edgeId) {
    return _tagsForTarget(
      NoteTagTarget(kind: NoteTagTargetKind.flowchartEdge, elementId: edgeId),
    );
  }

  bool _nodeHasTags(String nodeId) => _tagsForNode(nodeId).isNotEmpty;

  bool _edgeHasTags(String edgeId) => _tagsForEdge(edgeId).isNotEmpty;

  Color _tagColorForTarget(NoteTagTarget target) {
    final tags = _tagsForTarget(target);
    if (tags.isEmpty) {
      return const Color(0xFF2563EB);
    }
    return Color(tags.first.resolvedColorValue);
  }

  bool get _selectedTargetHasTags {
    final target = _selectedTarget;
    return target != null && _tagsForTarget(target).isNotEmpty;
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

  void _centerInitialCanvas() {
    if (_initialCanvasCentered || !mounted || _positionedNodes.isEmpty) {
      return;
    }
    final geometry = _canvasGeometryFor(_positionedNodes);
    final nodes = _positionedNodes;
    final contentLeft = nodes.map((node) => node.x).reduce(math.min);
    final contentTop = nodes.map((node) => node.y).reduce(math.min);
    final local = Offset(contentLeft - geometry.bounds.left, contentTop - geometry.bounds.top);
    _canvasController.value = Matrix4.translationValues(120.0 - local.dx, 120.0 - local.dy, 0);
    _initialCanvasCentered = true;
    _log(
      'canvas initial center origin=${contentLeft.toStringAsFixed(1)},${contentTop.toStringAsFixed(1)} bounds=${geometry.bounds.left.toStringAsFixed(0)},${geometry.bounds.top.toStringAsFixed(0)},'
      '${geometry.bounds.width.toStringAsFixed(0)}x${geometry.bounds.height.toStringAsFixed(0)} '
      'translate=${(120.0 - local.dx).toStringAsFixed(1)},${(120.0 - local.dy).toStringAsFixed(1)}',
    );
  }

  void _onCanvasTransformChanged() {
    _viewportLogTick += 1;
    if (_viewportLogTick == 1 || _viewportLogTick % 24 == 0) {
      final visible = _visibleCanvasRect(_canvasGeometryFor(_positionedNodes).size);
      _log(
        'viewport transform tick=$_viewportLogTick scale=${_canvasController.value.getMaxScaleOnAxis().toStringAsFixed(2)} '
        'visible=${visible.left.toStringAsFixed(0)},${visible.top.toStringAsFixed(0)},${visible.width.toStringAsFixed(0)}x${visible.height.toStringAsFixed(0)}',
      );
    }
    if (mounted && (_viewportLogTick == 1 || _viewportLogTick % 12 == 0)) {
      setState(() {});
    }
  }

  void _zoomCanvas(double factor) {
    final current = _canvasController.value;
    final currentScale = current.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(0.22, 3.0).toDouble();
    if ((targetScale - currentScale).abs() < 0.01) {
      return;
    }
    final scale = targetScale / currentScale;
    final next = Matrix4.copy(current)..scaleByDouble(scale, scale, scale, 1.0);
    _canvasController.value = next;
  }

  _CanvasGeometry _canvasGeometryFor(List<NoteFlowchartNode> nodes) {
    if (nodes.isEmpty) {
      return const _CanvasGeometry(bounds: Rect.fromLTWH(-8000, -6000, 32000, 24000));
    }
    final sizes = _nodeSizesFor(nodes);
    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final node in nodes) {
      final size = sizes[node.id] ?? _nodeSizeFor(node);
      left = math.min(left, node.x);
      top = math.min(top, node.y);
      right = math.max(right, node.x + size.width);
      bottom = math.max(bottom, node.y + size.height);
    }
    final boundsLeft = math.min(left - _canvasMargin, -_canvasMargin);
    final boundsTop = math.min(top - _canvasMargin, -_canvasMargin);
    final boundsRight = math.max(right + _canvasMargin, boundsLeft + _minCanvasSize.width);
    final boundsBottom = math.max(bottom + _canvasMargin, boundsTop + _minCanvasSize.height);
    return _CanvasGeometry(bounds: Rect.fromLTRB(boundsLeft, boundsTop, boundsRight, boundsBottom));
  }

  NoteFlowchartNode _toCanvasNode(NoteFlowchartNode node, _CanvasGeometry geometry) {
    return node.copyWith(
      x: node.x - geometry.bounds.left,
      y: node.y - geometry.bounds.top,
    );
  }

  Offset _canvasLocalToData(Offset local) {
    final geometry = _canvasGeometryFor(_positionedNodes);
    return Offset(local.dx + geometry.bounds.left, local.dy + geometry.bounds.top);
  }

  Rect _visibleCanvasRect(Size canvasSize) {
    final viewport = Size(
      _viewportSize.width <= 0 ? 430 : _viewportSize.width,
      _viewportSize.height <= 0 ? 720 : _viewportSize.height,
    );
    final inverse = Matrix4.inverted(_canvasController.value);
    final a = MatrixUtils.transformPoint(inverse, Offset.zero);
    final b = MatrixUtils.transformPoint(inverse, Offset(viewport.width, viewport.height));
    return Rect.fromPoints(a, b).intersect(Offset.zero & canvasSize).inflate(520);
  }

  List<NoteFlowchartNode> _visibleNodes(
    List<NoteFlowchartNode> canvasNodes,
    Map<String, Size> nodeSizes,
    Rect visibleRect,
  ) {
    return [
      for (final node in canvasNodes)
        if (Rect.fromLTWH(
          node.x - _CanvasNodeCard.connectorPadding,
          node.y - _CanvasNodeCard.connectorPadding,
          (nodeSizes[node.id]?.width ?? _nodeSizeFor(node).width) + _CanvasNodeCard.connectorPadding * 2,
          (nodeSizes[node.id]?.height ?? _nodeSizeFor(node).height) + _CanvasNodeCard.connectorPadding * 2,
        ).overlaps(visibleRect))
          node,
    ];
  }

  List<NoteFlowchartEdge> _visibleEdges(
    List<NoteFlowchartEdge> edges,
    Map<String, NoteFlowchartNode> canvasNodesById,
    Map<String, Size> nodeSizes,
    Rect visibleRect,
  ) {
    return [
      for (final edge in edges)
        if (_edgeBounds(edge, canvasNodesById, nodeSizes)?.overlaps(visibleRect) == true)
          edge,
    ];
  }

  Rect? _edgeBounds(
    NoteFlowchartEdge edge,
    Map<String, NoteFlowchartNode> canvasNodesById,
    Map<String, Size> nodeSizes,
  ) {
    final from = canvasNodesById[edge.fromNodeId];
    final to = canvasNodesById[edge.toNodeId];
    if (from == null || to == null) {
      return null;
    }
    final route = _routeEdge(edge, from, to, nodeSizes);
    if (route.points.isEmpty) {
      return null;
    }
    var left = route.points.first.dx;
    var right = route.points.first.dx;
    var top = route.points.first.dy;
    var bottom = route.points.first.dy;
    for (final point in route.points.skip(1)) {
      left = math.min(left, point.dx);
      right = math.max(right, point.dx);
      top = math.min(top, point.dy);
      bottom = math.max(bottom, point.dy);
    }
    return Rect.fromLTRB(left, top, right, bottom).inflate(120);
  }

  void _addNode(NoteFlowchartNodeKind kind, Offset position) {
    final id = _nextNodeId();
    final draft = _nodeDraftForKind(id: id, kind: kind, order: _block.nodes.length + 1);
    final node = draft.copyWith(
      x: position.dx.toDouble(),
      y: position.dy.toDouble(),
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
    final centered = _canvasLocalToData(local - Offset(draftSize.width / 2, draftSize.height / 2));
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
    final size = _canvasGeometryFor(_positionedNodes).size;
    return localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= size.width &&
        localPosition.dy <= size.height;
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
    final moveCount = (_dragMoveCounts[node.id] ?? 0) + 1;
    _dragMoveCounts[node.id] = moveCount;
    if (moveCount % 16 == 0) {
      _log('drag update node=${node.id} moves=$moveCount dx=${delta.dx.toStringAsFixed(1)} dy=${delta.dy.toStringAsFixed(1)}');
    }
    setState(() {
      final positioned = _positionedNodes;
      if (!positioned.any((current) => current.id == node.id)) {
        _log('drag update ignored node=${node.id} reason=missing_current_node');
        return;
      }
      _block = _block.copyWith(
        type: NoteBlockType.flowchart,
        nodes: [
          for (final current in positioned)
            if (current.id == node.id)
              current.copyWith(
                x: (current.x + delta.dx).toDouble(),
                y: (current.y + delta.dy).toDouble(),
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
                          for (final port in _portsForNode(draft))
                            _PortEditorRow(
                              key: ValueKey('note-flowchart-node-popup-port-${port.id}'),
                              port: port,
                              locked: _isMandatoryPort(draft, port),
                              onLabelChanged: (label) => update(
                                _replacePortOnNode(draft, port.copyWith(label: label)),
                                'port_label_${port.id}',
                              ),
                              onSideChanged: (side) => update(
                                _replacePortOnNode(draft, port.copyWith(side: side)),
                                'port_side_${port.id}_${side.wireName}',
                              ),
                              onDelete: _isMandatoryPort(draft, port)
                                  ? null
                                  : () => update(_removePortFromNode(draft, port.id), 'port_delete_${port.id}'),
                            ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final side in NoteFlowchartPortSide.values)
                                IconButton.filledTonal(
                                  key: ValueKey('note-flowchart-node-popup-add-port-${side.wireName}'),
                                  tooltip: 'Port hozzáadása: ${_sideLabel(side)}',
                                  onPressed: () => update(_addPortToNode(draft, side), 'port_add_${side.wireName}'),
                                  icon: Icon(_sideIcon(side), size: 18),
                                ),
                            ],
                          ),
                        ],
                      ),
                      _NodeConfigSection(
                        title: 'Előnézet',
                        children: [
                          _NodePortPreview(
                            node: draft,
                            onPortSideChanged: (port, side) => update(
                              _replacePortOnNode(draft, port.copyWith(side: side)),
                              'port_preview_drag_${port.id}_${side.wireName}',
                            ),
                          ),
                        ],
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

  NoteFlowchartNode _replacePortOnNode(NoteFlowchartNode node, NoteFlowchartPort replacement) {
    final ports = [
      for (final port in _portsForNode(node))
        if (port.id == replacement.id) replacement else port,
    ];
    _log('port update node=${node.id} port=${replacement.id} label=${replacement.label} side=${replacement.side.wireName}');
    return node.copyWith(ports: ports);
  }

  NoteFlowchartNode _removePortFromNode(NoteFlowchartNode node, String portId) {
    _log('port delete node=${node.id} port=$portId');
    return node.copyWith(
      ports: _portsForNode(node).where((port) => port.id != portId).toList(growable: false),
    );
  }

  bool _isMandatoryPort(NoteFlowchartNode node, NoteFlowchartPort port) {
    if (node.kind == NoteFlowchartNodeKind.binaryDecision) {
      return port.semantic == NoteFlowchartPortSemantic.yes || port.semantic == NoteFlowchartPortSemantic.no;
    }
    return false;
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
    final semantic = node.kind == NoteFlowchartNodeKind.multiDecision ? NoteFlowchartPortSemantic.custom : NoteFlowchartPortSemantic.normal;
    final label = node.kind == NoteFlowchartNodeKind.multiDecision ? 'Ág ${ports.length + 1}' : _sideLabel(side);
    final port = NoteFlowchartPort(id: id, side: side, label: label, semantic: semantic);
    _log('port add node=${node.id} port=${port.id} side=${side.wireName}');
    return node.copyWith(ports: [...ports, port]);
  }

  void _deleteNode(NoteFlowchartNode node) {
    _log('node delete id=${node.id}');
    final removedEdgeIds = {
      for (final edge in _block.edges)
        if (edge.fromNodeId == node.id || edge.toNodeId == node.id) edge.id,
    };
    final removedNodeIds = {node.id};
    _emit(_block.copyWith(
      nodes: _positionedNodes.where((item) => item.id != node.id).toList(),
      edges: _block.edges
          .where((edge) => edge.fromNodeId != node.id && edge.toNodeId != node.id)
          .toList(),
      scopedTags: _withoutFlowchartScopedTargets(
        nodeIds: removedNodeIds,
        edgeIds: removedEdgeIds,
      ),
    ));
    if (_selectedNodeId == node.id || removedEdgeIds.contains(_selectedEdgeId)) {
      setState(() {
        if (_selectedNodeId == node.id) {
          _selectedNodeId = null;
        }
        if (removedEdgeIds.contains(_selectedEdgeId)) {
          _selectedEdgeId = null;
        }
      });
    }
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

  void _editEdgeLabel(NoteFlowchartEdge edge) {
    NoteFlowchartNode? from;
    for (final node in _positionedNodes) {
      if (node.id == edge.fromNodeId) {
        from = node;
        break;
      }
    }
    if (from == null) {
      return;
    }
    _inlineEdgeController.text = _edgeDisplayLabel(edge, from);
    _inlineEdgeController.selection = TextSelection.collapsed(offset: _inlineEdgeController.text.length);
    setState(() => _editingEdgeId = edge.id);
    _log('edge label edit open id=${edge.id} chars=${_inlineEdgeController.text.length}');
  }

  void _commitEdgeLabel(NoteFlowchartEdge edge) {
    final nextLabel = _inlineEdgeController.text.trim();
    final updatedNodes = [
      for (final node in _block.nodes)
        if (node.id == edge.fromNodeId && edge.fromPortId != null)
          node.copyWith(
            ports: [
              for (final port in _portsForNode(node))
                if (port.id == edge.fromPortId)
                  port.copyWith(label: nextLabel)
                else
                  port,
            ],
          )
        else
          node,
    ];
    final updatedEdges = [
      for (final item in _block.edges)
        if (item.id == edge.id)
          item.copyWith(label: nextLabel)
        else
          item,
    ];
    _log('edge label edit saved id=${edge.id} chars=${nextLabel.length}');
    setState(() => _editingEdgeId = null);
    _emit(_block.copyWith(nodes: updatedNodes, edges: updatedEdges));
  }

  void _cancelEdgeLabelEdit(NoteFlowchartEdge edge) {
    _log('edge label edit cancelled id=${edge.id}');
    setState(() => _editingEdgeId = null);
  }

  void _deleteEdge(NoteFlowchartEdge edge) {
    _log('edge delete id=${edge.id} from=${edge.fromNodeId} to=${edge.toNodeId}');
    _emit(_block.copyWith(
      edges: _block.edges.where((item) => item.id != edge.id).toList(),
      scopedTags: _withoutFlowchartScopedTargets(edgeIds: {edge.id}),
    ));
    if (_selectedEdgeId == edge.id) {
      setState(() => _selectedEdgeId = null);
    }
  }

  List<NoteScopedTagAssignment> _withoutFlowchartScopedTargets({
    Set<String> nodeIds = const {},
    Set<String> edgeIds = const {},
  }) {
    return [
      for (final assignment in _block.scopedTags)
        if (!_isRemovedFlowchartTarget(assignment.target, nodeIds, edgeIds))
          assignment,
    ];
  }

  bool _isRemovedFlowchartTarget(
    NoteTagTarget target,
    Set<String> nodeIds,
    Set<String> edgeIds,
  ) {
    return switch (target.kind) {
      NoteTagTargetKind.flowchartNode => nodeIds.contains(target.elementId),
      NoteTagTargetKind.flowchartEdge => edgeIds.contains(target.elementId),
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dataNodes = _positionedNodes;
    final geometry = _canvasGeometryFor(dataNodes);
    final canvasNodes = [for (final node in dataNodes) _toCanvasNode(node, geometry)];
    final dataNodesById = {for (final node in dataNodes) node.id: node};
    final canvasNodesById = {for (final node in canvasNodes) node.id: node};
    final nodeSizes = _nodeSizesFor(dataNodes);
    final visibleRect = _visibleCanvasRect(geometry.size);
    final visibleNodes = _visibleNodes(canvasNodes, nodeSizes, visibleRect);
    final visibleEdges = _visibleEdges(_block.edges, canvasNodesById, nodeSizes, visibleRect.inflate(240));
    final loopEdgeIds = {
      for (final edge in _block.edges)
        if (_isLoopClosingNoteEdge(_block.edges, edge)) edge.id,
    };
    if (_viewportLogTick == 0) {
      _log(
        'canvas build size=${geometry.size.width.toStringAsFixed(0)}x${geometry.size.height.toStringAsFixed(0)} '
        'nodes=${dataNodes.length} visibleNodes=${visibleNodes.length} edges=${_block.edges.length} visibleEdges=${visibleEdges.length}',
      );
    }
    return Scaffold(
      key: const ValueKey('note-flowchart-canvas-editor'),
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: 'Flowchart',
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selectedTargetHasTags,
        saveAction: widget.onChanged == null
            ? TextButton.icon(
                key: const ValueKey('note-flowchart-save'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Mentés'),
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final nextViewport = Size(constraints.maxWidth, constraints.maxHeight);
          if (_viewportSize != nextViewport) {
            _viewportSize = nextViewport;
          }
          return Stack(
            key: _bodyStackKey,
            children: [
              InteractiveViewer(
                transformationController: _canvasController,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(100000),
                minScale: 0.22,
                maxScale: 3.0,
                child: DragTarget<NoteFlowchartNodeKind>(
                  onAcceptWithDetails: (details) => _addDroppedNode(details.data, details.offset),
                  builder: (context, candidate, rejected) {
                    return SizedBox(
                      key: const ValueKey('note-flowchart-canvas-surface'),
                      width: geometry.size.width,
                      height: geometry.size.height,
                      child: RepaintBoundary(
                        key: _canvasKey,
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
                                    nodes: canvasNodes,
                                    edges: visibleEdges,
                                    loopEdgeIds: loopEdgeIds,
                                    nodeSizes: nodeSizes,
                                  ),
                                ),
                              ),
                              for (final edge in visibleEdges)
                                if (loopEdgeIds.contains(edge.id))
                                  _LoopEdgeAnchor(
                                    edge: edge,
                                    nodes: canvasNodes,
                                    nodeSizes: nodeSizes,
                                  ),
                              for (final canvasNode in visibleNodes)
                                if (dataNodesById[canvasNode.id] != null)
                                  Positioned(
                                    left: canvasNode.x - _CanvasNodeCard.connectorPadding,
                                    top: canvasNode.y - _CanvasNodeCard.connectorPadding,
                                    width: (nodeSizes[canvasNode.id]?.width ?? _nodeSizeFor(canvasNode).width) +
                                        _CanvasNodeCard.connectorPadding * 2,
                                    height: (nodeSizes[canvasNode.id]?.height ?? _nodeSizeFor(canvasNode).height) +
                                        _CanvasNodeCard.connectorPadding * 2,
                                    child: KeyedSubtree(
                                      key: ValueKey('note-flowchart-node-${canvasNode.id}'),
                                      child: _CanvasNodeCard(
                                        node: dataNodesById[canvasNode.id]!,
                                        size: nodeSizes[canvasNode.id] ?? _nodeSizeFor(canvasNode),
                                        connectors: _connectorsForNode(
                                          dataNodesById[canvasNode.id]!,
                                          edges: _block.edges,
                                        ),
                                        linkSource: _linkSource,
                                        onMoveStart: () => _beginMove(dataNodesById[canvasNode.id]!),
                                        onMove: (delta) => _moveNode(
                                          dataNodesById[canvasNode.id]!,
                                          delta / _canvasController.value.getMaxScaleOnAxis(),
                                        ),
                                        onMoveEnd: () => _endMove(dataNodesById[canvasNode.id]!),
                                        onEdit: () => _editNode(dataNodesById[canvasNode.id]!),
                                        onOpenConfig: () => _openNodeConfig(dataNodesById[canvasNode.id]!),
                                        onCommitEdit: () => _commitNodeEdit(dataNodesById[canvasNode.id]!),
                                        onCancelEdit: () => _cancelNodeEdit(dataNodesById[canvasNode.id]!),
                                        inlineController: _editingNodeId == canvasNode.id ? _inlineNodeController : null,
                                        editing: _editingNodeId == canvasNode.id,
                                        selected: _selectedNodeId == canvasNode.id,
                                        tagged: _nodeHasTags(canvasNode.id),
                                        connectModeActive: _linkSource != null,
                                        onSelect: () => setState(() {
                                          _selectedNodeId = canvasNode.id;
                                          _selectedEdgeId = null;
                                        }),
                                        onDelete: () => _deleteNode(dataNodesById[canvasNode.id]!),
                                        onConnectorTap: (connector) => _handleConnectorTap(dataNodesById[canvasNode.id]!, connector),
                                      ),
                                    ),
                                  ),
                              for (final edge in visibleEdges)
                                _EdgeLabel(
                                  edge: edge,
                                  nodes: canvasNodes,
                                  nodeSizes: nodeSizes,
                                  editing: _editingEdgeId == edge.id,
                                  selected: _selectedEdgeId == edge.id,
                                  tagged: _edgeHasTags(edge.id),
                                  tagColor: _tagColorForTarget(
                                    NoteTagTarget(
                                      kind: NoteTagTargetKind.flowchartEdge,
                                      elementId: edge.id,
                                    ),
                                  ),
                                  inlineController: _editingEdgeId == edge.id ? _inlineEdgeController : null,
                                  onSelect: () => setState(() {
                                    _selectedEdgeId = edge.id;
                                    _selectedNodeId = null;
                                  }),
                                  onEdit: () => _editEdgeLabel(edge),
                                  onCommitEdit: () => _commitEdgeLabel(edge),
                                  onCancelEdit: () => _cancelEdgeLabelEdit(edge),
                                  onDelete: () => _deleteEdge(edge),
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
                child: _FlowchartZoomControls(
                  onZoomIn: () => _zoomCanvas(1.18),
                  onZoomOut: () => _zoomCanvas(1 / 1.18),
                ),
              ),
              if (_selectedTarget != null && _tagsForTarget(_selectedTarget!).isNotEmpty)
                Positioned(
                  left: 12,
                  top: 68,
                  child: NoteSelectedTagTray(tags: _tagsForTarget(_selectedTarget!)),
                ),
              Positioned(
                right: 16,
                bottom: 24,
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
          );
        },
      ),
    );
  }
}

class _CanvasGeometry {
  const _CanvasGeometry({required this.bounds});

  final Rect bounds;

  Size get size => bounds.size;
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
    required this.selected,
    required this.tagged,
    required this.connectModeActive,
    required this.onSelect,
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
  final bool selected;
  final bool tagged;
  final bool connectModeActive;
  final VoidCallback onSelect;
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
                        color: selectedForLink || selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                        width: selectedForLink || selected ? 2 : 1,
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
                            key: ValueKey('note-flowchart-node-select-${node.id}'),
                            tooltip: 'Box kijelölése',
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                            onPressed: onSelect,
                            icon: Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 17,
                            ),
                          ),
                          if (tagged)
                            Padding(
                              key: ValueKey('note-flowchart-node-tag-marker-${node.id}'),
                              padding: const EdgeInsets.only(top: 9, right: 2),
                              child: const _FlowchartTagMarker(),
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

class _FlowchartTagMarker extends StatelessWidget {
  const _FlowchartTagMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x332563EB), blurRadius: 8),
        ],
      ),
      child: const SizedBox.square(dimension: 10),
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
        : switch (connector.usage) {
            _ConnectorUsageState.inputOnly => const Color(0xFF0F766E),
            _ConnectorUsageState.outputOnly => const Color(0xFF7C3AED),
            _ConnectorUsageState.inputAndOutput => const Color(0xFF0F766E),
            _ConnectorUsageState.unused => const Color(0xFF6B7280),
          };
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (connector.usage == _ConnectorUsageState.inputAndOutput)
                        DecoratedBox(
                          key: ValueKey('note-flowchart-connector-outer-${connector.nodeId}-${connector.id}'),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                          ),
                          child: const SizedBox.square(dimension: 34),
                        ),
                      AnimatedContainer(
                        key: ValueKey('note-flowchart-connector-state-${connector.nodeId}-${connector.id}-${connector.usage.name}'),
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
                    ],
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

class _FlowchartZoomControls extends StatelessWidget {
  const _FlowchartZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('note-flowchart-zoom-out'),
            tooltip: 'Kicsinyítés',
            onPressed: onZoomOut,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            key: const ValueKey('note-flowchart-zoom-in'),
            tooltip: 'Nagyítás',
            onPressed: onZoomIn,
            icon: const Icon(Icons.add),
          ),
        ],
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
    return Column(
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
          if (kind != kinds.last) const SizedBox(height: 12),
        ],
      ],
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
      child: Material(
        key: ValueKey('note-flowchart-fab-${_kindKey(kind)}'),
        elevation: 4,
        color: const Color(0xFF2563EB),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: SizedBox.square(
          dimension: 52,
          child: Icon(_kindIcon(kind), color: Colors.white),
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
    required this.editing,
    required this.selected,
    required this.tagged,
    required this.tagColor,
    required this.inlineController,
    required this.onSelect,
    required this.onEdit,
    required this.onCommitEdit,
    required this.onCancelEdit,
    required this.onDelete,
  });

  final NoteFlowchartEdge edge;
  final List<NoteFlowchartNode> nodes;
  final Map<String, Size> nodeSizes;
  final bool editing;
  final bool selected;
  final bool tagged;
  final Color tagColor;
  final TextEditingController? inlineController;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onCommitEdit;
  final VoidCallback onCancelEdit;
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
    final display = _edgeDisplayLabel(edge, from);
    return Positioned(
      left: middle.dx - 44,
      top: middle.dy - 18,
      child: DecoratedBox(
        key: ValueKey('note-flowchart-edge-${edge.id}'),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? const Color(0xFF2563EB)
                : tagged
                    ? tagColor
                    : const Color(0xFFE9D5FF),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [BoxShadow(color: Color(0x14111827), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              key: ValueKey('note-flowchart-edge-select-${edge.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onSelect,
              child: SizedBox.square(
                dimension: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      size: 16,
                      color: selected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                    ),
                    if (tagged)
                      Positioned(
                        key: ValueKey('note-flowchart-edge-tag-marker-${edge.id}'),
                        right: 4,
                        top: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const SizedBox.square(dimension: 7),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, right: 2),
              child: editing
                  ? SizedBox(
                      width: 92,
                      child: TextField(
                        key: ValueKey('note-flowchart-edge-inline-field-${edge.id}'),
                        controller: inlineController,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 1,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => onCommitEdit(),
                        onTapOutside: (_) => onCommitEdit(),
                      ),
                    )
                  : GestureDetector(
                      key: ValueKey('note-flowchart-edge-label-${edge.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onEdit,
                      child: Text(display, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
            ),
            if (editing)
              IconButton(
                key: ValueKey('note-flowchart-edge-commit-${edge.id}'),
                tooltip: 'Ágnév mentése',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                onPressed: onCommitEdit,
                icon: const Icon(Icons.check, size: 15),
              ),
            IconButton(
              key: ValueKey(editing ? 'note-flowchart-edge-cancel-${edge.id}' : 'note-flowchart-edge-delete-${edge.id}'),
              tooltip: editing ? 'Mégse' : 'Kapcsolat törlése',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 30, height: 30),
              onPressed: editing ? onCancelEdit : onDelete,
              icon: Icon(editing ? Icons.close : Icons.delete_outline, size: 15),
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

class _LoopEdgeAnchor extends StatelessWidget {
  const _LoopEdgeAnchor({
    required this.edge,
    required this.nodes,
    required this.nodeSizes,
  });

  final NoteFlowchartEdge edge;
  final List<NoteFlowchartNode> nodes;
  final Map<String, Size> nodeSizes;

  @override
  Widget build(BuildContext context) {
    final from = _nodeById(edge.fromNodeId);
    final to = _nodeById(edge.toNodeId);
    if (from == null || to == null) {
      return const SizedBox.shrink();
    }
    final route = _routeEdge(edge, from, to, nodeSizes);
    if (route.points.isEmpty) {
      return const SizedBox.shrink();
    }
    final middle = route.points[route.points.length ~/ 2];
    return Positioned(
      key: ValueKey('note-flowchart-loop-edge-${edge.id}'),
      left: middle.dx,
      top: middle.dy,
      width: 1,
      height: 1,
      child: const SizedBox.expand(),
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
    required this.loopEdgeIds,
    required this.nodeSizes,
  });

  final List<NoteFlowchartNode> nodes;
  final List<NoteFlowchartEdge> edges;
  final Set<String> loopEdgeIds;
  final Map<String, Size> nodeSizes;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in nodes) node.id: node};
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
      final loop = loopEdgeIds.contains(edge.id);
      final color = loop ? const Color(0xFFEA580C) : const Color(0xFF7C3AED);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final arrowPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      final path = Path()..moveTo(route.points.first.dx, route.points.first.dy);
      for (final point in route.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      if (loop) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
      _drawArrow(canvas, route.points[route.points.length - 2], route.points.last, arrowPaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 10, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 16;
      }
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
    return oldDelegate.nodes != nodes ||
        oldDelegate.edges != edges ||
        oldDelegate.loopEdgeIds != loopEdgeIds ||
        oldDelegate.nodeSizes != nodeSizes;
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

class _PortEditorRow extends StatefulWidget {
  const _PortEditorRow({
    super.key,
    required this.port,
    required this.locked,
    required this.onLabelChanged,
    required this.onSideChanged,
    required this.onDelete,
  });

  final NoteFlowchartPort port;
  final bool locked;
  final ValueChanged<String> onLabelChanged;
  final ValueChanged<NoteFlowchartPortSide> onSideChanged;
  final VoidCallback? onDelete;

  @override
  State<_PortEditorRow> createState() => _PortEditorRowState();
}

class _PortEditorRowState extends State<_PortEditorRow> {
  late final TextEditingController _labelController;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: _displayLabel(widget.port));
  }

  @override
  void didUpdateWidget(covariant _PortEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _displayLabel(widget.port);
    if (oldWidget.port.id != widget.port.id || oldWidget.port.label != widget.port.label) {
      if (_labelController.text != next) {
        _labelController.text = next;
        _labelController.selection = TextSelection.collapsed(offset: _labelController.text.length);
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String _displayLabel(NoteFlowchartPort port) => port.label.trim().isEmpty ? port.id : port.label.trim();

  @override
  Widget build(BuildContext context) {
    final port = widget.port;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_portSemanticIcon(port), size: 18, color: const Color(0xFF7C3AED)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: ValueKey('note-flowchart-node-popup-port-label-${port.id}'),
                      controller: _labelController,
                      enabled: !widget.locked,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: widget.locked ? 'Kötelező ág' : 'Ág neve',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: widget.onLabelChanged,
                      onSubmitted: widget.onLabelChanged,
                      onTapOutside: (_) => widget.onLabelChanged(_labelController.text),
                    ),
                  ),
                  if (widget.onDelete != null)
                    IconButton(
                      key: ValueKey('note-flowchart-node-popup-port-delete-${port.id}'),
                      tooltip: 'Port törlése',
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final side in NoteFlowchartPortSide.values)
                    ChoiceChip(
                      key: ValueKey('note-flowchart-node-popup-port-side-${port.id}-${side.wireName}'),
                      avatar: Icon(_sideIcon(side), size: 15),
                      selected: port.side == side,
                      label: Text(_sideLabel(side)),
                      onSelected: (_) => widget.onSideChanged(side),
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

class _NodePortPreview extends StatelessWidget {
  const _NodePortPreview({required this.node, required this.onPortSideChanged});

  final NoteFlowchartNode node;
  final void Function(NoteFlowchartPort port, NoteFlowchartPortSide side) onPortSideChanged;

  @override
  Widget build(BuildContext context) {
    final ports = _portsForNode(node);
    final grouped = <NoteFlowchartPortSide, List<NoteFlowchartPort>>{
      for (final side in NoteFlowchartPortSide.values) side: ports.where((port) => port.side == side).toList(growable: false),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: SizedBox(
        height: 124,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shapeWidth = math.min(170.0, math.max(130.0, constraints.maxWidth - 90));
            const shapeHeight = 58.0;
            final rect = Rect.fromLTWH(
              (constraints.maxWidth - shapeWidth) / 2,
              32,
              shapeWidth,
              shapeHeight,
            );
            return Stack(
              children: [
                for (final side in NoteFlowchartPortSide.values)
                  _PreviewSideDropZone(
                    rect: rect,
                    side: side,
                    onAccept: (port) => onPortSideChanged(port, side),
                  ),
                Positioned.fromRect(
                  rect: rect,
                  child: DecoratedBox(
                    key: const ValueKey('note-flowchart-preview-shape'),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(node.visualShape == NoteFlowchartVisualShape.oval ? 999 : 8),
                      border: Border.all(color: const Color(0xFF7C3AED)),
                    ),
                    child: Center(
                      child: Text(
                        _nodeTypeLabel(node),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                for (final side in NoteFlowchartPortSide.values)
                  for (var i = 0; i < grouped[side]!.length; i += 1)
                    _PreviewPortDot(
                      key: ValueKey('note-flowchart-preview-port-${grouped[side]![i].id}'),
                      port: grouped[side]![i],
                      rect: rect,
                      unitOffset: _portUnitOffset(side, i, grouped[side]!.length),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewSideDropZone extends StatelessWidget {
  const _PreviewSideDropZone({required this.rect, required this.side, required this.onAccept});

  final Rect rect;
  final NoteFlowchartPortSide side;
  final ValueChanged<NoteFlowchartPort> onAccept;

  @override
  Widget build(BuildContext context) {
    final zone = switch (side) {
      NoteFlowchartPortSide.top => Rect.fromLTWH(rect.left, rect.top - 22, rect.width, 44),
      NoteFlowchartPortSide.right => Rect.fromLTWH(rect.right - 22, rect.top, 44, rect.height),
      NoteFlowchartPortSide.bottom => Rect.fromLTWH(rect.left, rect.bottom - 22, rect.width, 44),
      NoteFlowchartPortSide.left => Rect.fromLTWH(rect.left - 22, rect.top, 44, rect.height),
    };
    return Positioned.fromRect(
      rect: zone,
      child: DragTarget<NoteFlowchartPort>(
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidate, rejected) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: candidate.isEmpty ? Colors.transparent : const Color(0x1A7C3AED),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _PreviewPortDot extends StatelessWidget {
  const _PreviewPortDot({super.key, required this.port, required this.rect, required this.unitOffset});

  final NoteFlowchartPort port;
  final Rect rect;
  final Offset unitOffset;

  @override
  Widget build(BuildContext context) {
    final color = port.semantic == NoteFlowchartPortSemantic.normal ? const Color(0xFF059669) : const Color(0xFF7C3AED);
    final dot = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: SizedBox.square(
        dimension: 14,
        child: Icon(_semanticMiniIcon(port.semantic), size: 9, color: color),
      ),
    );
    return Positioned(
      left: rect.left + rect.width * unitOffset.dx - 7,
      top: rect.top + rect.height * unitOffset.dy - 7,
      child: Draggable<NoteFlowchartPort>(
        data: port,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.45, child: dot),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: dot),
        child: dot,
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

enum _ConnectorUsageState { inputOnly, outputOnly, inputAndOutput, unused }

class _ConnectorSpec {
  const _ConnectorSpec({
    required this.id,
    required this.nodeId,
    required this.nodeSize,
    required this.unitOffset,
    required this.side,
    required this.semantic,
    required this.usage,
    required this.tooltip,
    this.edgeLabel = '',
  });

  final String id;
  final String nodeId;
  final Size nodeSize;
  final Offset unitOffset;
  final NoteFlowchartPortSide side;
  final NoteFlowchartPortSemantic semantic;
  final _ConnectorUsageState usage;
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

List<_ConnectorSpec> _connectorsForNode(
  NoteFlowchartNode node, {
  List<NoteFlowchartEdge> edges = const [],
}) {
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
          usage: _connectorUsageState(
            edges,
            node.id,
            grouped[side]![i].id,
          ),
          tooltip: grouped[side]![i].label.trim().isEmpty ? _sideLabel(side) : grouped[side]![i].label.trim(),
          edgeLabel: _edgeLabelForPort(grouped[side]![i]),
        ),
  ];
}

_ConnectorUsageState _connectorUsageState(
  List<NoteFlowchartEdge> edges,
  String nodeId,
  String connectorId,
) {
  final input = edges.any(
    (edge) => edge.toNodeId == nodeId && edge.toPortId == connectorId,
  );
  final output = edges.any(
    (edge) => edge.fromNodeId == nodeId && edge.fromPortId == connectorId,
  );
  if (input && output) {
    return _ConnectorUsageState.inputAndOutput;
  }
  if (input) {
    return _ConnectorUsageState.inputOnly;
  }
  if (output) {
    return _ConnectorUsageState.outputOnly;
  }
  return _ConnectorUsageState.unused;
}

bool _isLoopClosingNoteEdge(
  List<NoteFlowchartEdge> edges,
  NoteFlowchartEdge edge,
) {
  return _hasNotePathBetween(
    edges,
    startNodeId: edge.toNodeId,
    targetNodeId: edge.fromNodeId,
    ignoredEdgeId: edge.id,
  );
}

bool _hasNotePathBetween(
  List<NoteFlowchartEdge> edges, {
  required String startNodeId,
  required String targetNodeId,
  required String ignoredEdgeId,
}) {
  final visited = <String>{};
  bool visit(String nodeId) {
    if (nodeId == targetNodeId) {
      return true;
    }
    if (!visited.add(nodeId)) {
      return false;
    }
    final outgoing = edges.where(
      (edge) => edge.id != ignoredEdgeId && edge.fromNodeId == nodeId,
    );
    for (final edge in outgoing) {
      if (visit(edge.toNodeId)) {
        return true;
      }
    }
    return false;
  }

  return visit(startNodeId);
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
            usage: _ConnectorUsageState.unused,
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
            usage: _ConnectorUsageState.unused,
            tooltip: 'Kapcsolat',
          )
        : connectors.first,
  );
  final size = nodeSizes[to.id] ?? _nodeSizeFor(to);
  return Offset(to.x + size.width * connector.unitOffset.dx, to.y + size.height * connector.unitOffset.dy);
}


_ConnectorSpec _edgeStartConnector(
  NoteFlowchartEdge edge,
  NoteFlowchartNode from,
  Map<String, Size> nodeSizes,
) {
  final connectors = _connectorsForNode(from);
  return connectors.firstWhere(
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
            usage: _ConnectorUsageState.unused,
            tooltip: 'Kapcsolat',
          )
        : connectors.last,
  );
}

_ConnectorSpec _edgeEndConnector(
  NoteFlowchartEdge edge,
  NoteFlowchartNode to,
  Map<String, Size> nodeSizes,
) {
  final connectors = _connectorsForNode(to);
  return connectors.firstWhere(
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
            usage: _ConnectorUsageState.unused,
            tooltip: 'Kapcsolat',
          )
        : connectors.first,
  );
}

String _edgeDisplayLabel(NoteFlowchartEdge edge, NoteFlowchartNode from) {
  if (edge.fromPortId != null) {
    for (final port in _portsForNode(from)) {
      if (port.id == edge.fromPortId) {
        final label = _edgeLabelForPort(port).trim();
        if (label.isNotEmpty) {
          return label;
        }
      }
    }
  }
  final edgeLabel = edge.label.trim();
  return edgeLabel.isEmpty ? 'Kapcsolat' : edgeLabel;
}

Offset _sideExit(Offset point, NoteFlowchartPortSide side, double distance) {
  return switch (side) {
    NoteFlowchartPortSide.top => point.translate(0, -distance),
    NoteFlowchartPortSide.right => point.translate(distance, 0),
    NoteFlowchartPortSide.left => point.translate(-distance, 0),
    NoteFlowchartPortSide.bottom => point.translate(0, distance),
  };
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
  final startConnector = _edgeStartConnector(edge, from, nodeSizes);
  final endConnector = _edgeEndConnector(edge, to, nodeSizes);
  final start = _edgeStart(edge, from, nodeSizes);
  final end = _edgeEnd(edge, to, nodeSizes);
  final startExit = _sideExit(start, startConnector.side, 30);
  final endEntry = _sideExit(end, endConnector.side, 24);
  final fromSize = nodeSizes[from.id] ?? _nodeSizeFor(from);
  final toSize = nodeSizes[to.id] ?? _nodeSizeFor(to);
  final fromRect = Rect.fromLTWH(from.x, from.y, fromSize.width, fromSize.height).inflate(18);
  final toRect = Rect.fromLTWH(to.x, to.y, toSize.width, toSize.height).inflate(18);
  final isBackEdge = toRect.center.dy < fromRect.center.dy - 8;
  if (isBackEdge) {
    final leftLane = (math.min(fromRect.left, toRect.left) - 56).toDouble();
    final rightLane = (math.max(fromRect.right, toRect.right) + 56).toDouble();
    final useLeft = (startExit.dx - leftLane).abs() <= (rightLane - startExit.dx).abs();
    final laneX = useLeft ? leftLane : rightLane;
    return FlowchartRouteDebug(
      kind: 'backEdge',
      points: [
        start,
        startExit,
        Offset(laneX, startExit.dy),
        Offset(laneX, endEntry.dy),
        endEntry,
        end,
      ],
    );
  }
  final midY = (startExit.dy + endEntry.dy) / 2;
  return FlowchartRouteDebug(
    kind: 'orthogonal',
    points: [
      start,
      startExit,
      Offset(startExit.dx, midY),
      Offset(endEntry.dx, midY),
      endEntry,
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


IconData _sideIcon(NoteFlowchartPortSide side) {
  return switch (side) {
    NoteFlowchartPortSide.top => Icons.keyboard_arrow_up,
    NoteFlowchartPortSide.right => Icons.keyboard_arrow_right,
    NoteFlowchartPortSide.bottom => Icons.keyboard_arrow_down,
    NoteFlowchartPortSide.left => Icons.keyboard_arrow_left,
  };
}

IconData _portSemanticIcon(NoteFlowchartPort port) {
  return switch (port.semantic) {
    NoteFlowchartPortSemantic.yes => Icons.add_circle_outline,
    NoteFlowchartPortSemantic.no => Icons.remove_circle_outline,
    NoteFlowchartPortSemantic.custom => Icons.call_split,
    NoteFlowchartPortSemantic.normal => Icons.radio_button_checked,
  };
}

IconData _semanticMiniIcon(NoteFlowchartPortSemantic semantic) {
  return switch (semantic) {
    NoteFlowchartPortSemantic.yes => Icons.add,
    NoteFlowchartPortSemantic.no => Icons.remove,
    NoteFlowchartPortSemantic.custom => Icons.call_split,
    NoteFlowchartPortSemantic.normal => Icons.circle,
  };
}
