import 'dart:math' as math;

import 'package:flutter/material.dart';

class MobileFlowchartData {
  const MobileFlowchartData({
    required this.id,
    required this.title,
    required this.nodes,
    required this.edges,
    this.sourceSummary,
  });

  final String id;
  final String title;
  final String? sourceSummary;
  final List<MobileFlowchartNode> nodes;
  final List<MobileFlowchartEdge> edges;
}

class MobileFlowchartNode {
  const MobileFlowchartNode({
    required this.id,
    required this.label,
    this.shape = 'process',
    this.x,
    this.y,
  });

  final String id;
  final String label;
  final String shape;
  final double? x;
  final double? y;
}

class MobileFlowchartEdge {
  const MobileFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
}

enum MobileFlowchartViewMode { list, canvas, guide }

class MobileFlowchartViewer extends StatefulWidget {
  const MobileFlowchartViewer({super.key, required this.data});

  final MobileFlowchartData data;

  @override
  State<MobileFlowchartViewer> createState() => _MobileFlowchartViewerState();
}

class _MobileFlowchartViewerState extends State<MobileFlowchartViewer> {
  MobileFlowchartViewMode _mode = MobileFlowchartViewMode.list;
  final Set<String> _closedBranches = <String>{};
  final TransformationController _canvasController = TransformationController();
  _GuideStep? _guideStep;
  final List<_GuideStep> _guideBackStack = <_GuideStep>[];

  @override
  void initState() {
    super.initState();
    _guideStep = _GuideStep.decision(_rootNode()?.id ?? '');
  }

  @override
  void didUpdateWidget(covariant MobileFlowchartViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _closedBranches.clear();
      _guideBackStack.clear();
      _guideStep = _GuideStep.decision(_rootNode()?.id ?? '');
      _canvasController.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _canvasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('mobile-flowchart-viewer-${widget.data.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, color: Color(0xFF7C3AED), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.data.title.trim().isEmpty ? 'Flowchart' : widget.data.title.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827)),
                  ),
                ),
                if (widget.data.sourceSummary?.trim().isNotEmpty == true)
                  Text(
                    widget.data.sourceSummary!.trim(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ModeSelector(
              selected: _mode,
              onSelected: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: 10),
            switch (_mode) {
              MobileFlowchartViewMode.list => _FlowchartListView(
                  key: ValueKey('mobile-flowchart-view-list-${widget.data.id}'),
                  data: widget.data,
                  closedBranches: _closedBranches,
                  onToggleBranch: _toggleBranch,
                ),
              MobileFlowchartViewMode.canvas => _FlowchartCanvasView(
                  key: ValueKey('mobile-flowchart-view-canvas-${widget.data.id}'),
                  data: widget.data,
                  controller: _canvasController,
                  onZoom: _zoomCanvas,
                ),
              MobileFlowchartViewMode.guide => _FlowchartGuideView(
                  key: ValueKey('mobile-flowchart-view-guide-${widget.data.id}'),
                  data: widget.data,
                  step: _guideStep,
                  canGoBack: _guideBackStack.isNotEmpty,
                  onAnswer: _chooseGuideAnswer,
                  onNext: _advanceGuide,
                  onBack: _goGuideBack,
                ),
            },
          ],
        ),
      ),
    );
  }

  MobileFlowchartNode? _rootNode() {
    if (widget.data.nodes.isEmpty) {
      return null;
    }
    final incoming = widget.data.edges.map((edge) => edge.toNodeId).toSet();
    return widget.data.nodes.firstWhere(
      (node) => !incoming.contains(node.id),
      orElse: () => widget.data.nodes.first,
    );
  }

  void _toggleBranch(String branchId) {
    setState(() {
      if (!_closedBranches.add(branchId)) {
        _closedBranches.remove(branchId);
      }
    });
  }

  void _zoomCanvas(double factor) {
    final current = _canvasController.value.clone();
    current.multiply(Matrix4.diagonal3Values(factor, factor, 1));
    setState(() => _canvasController.value = current);
  }

  void _chooseGuideAnswer(MobileFlowchartEdge edge) {
    final current = _guideStep;
    if (current != null) {
      _guideBackStack.add(current);
    }
    setState(() => _guideStep = _GuideStep.answer(edge));
  }

  void _advanceGuide() {
    final step = _guideStep;
    if (step == null || step.edge == null) {
      return;
    }
    _guideBackStack.add(step);
    setState(() => _guideStep = _GuideStep.decision(step.edge!.toNodeId));
  }

  void _goGuideBack() {
    if (_guideBackStack.isEmpty) {
      return;
    }
    setState(() => _guideStep = _guideBackStack.removeLast());
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onSelected});

  final MobileFlowchartViewMode selected;
  final ValueChanged<MobileFlowchartViewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MobileFlowchartViewMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: MobileFlowchartViewMode.list,
          label: Text('Lista', key: ValueKey('mobile-flowchart-selector-list')),
          icon: Icon(Icons.format_list_bulleted),
        ),
        ButtonSegment(
          value: MobileFlowchartViewMode.canvas,
          label: Text('Canvas', key: ValueKey('mobile-flowchart-selector-canvas')),
          icon: Icon(Icons.open_with),
        ),
        ButtonSegment(
          value: MobileFlowchartViewMode.guide,
          label: Text('Guide', key: ValueKey('mobile-flowchart-selector-guide')),
          icon: Icon(Icons.assistant_direction_outlined),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onSelected(value.single),
      multiSelectionEnabled: false,
      emptySelectionAllowed: false,
    );
  }
}

class _FlowchartListView extends StatelessWidget {
  const _FlowchartListView({
    super.key,
    required this.data,
    required this.closedBranches,
    required this.onToggleBranch,
  });

  final MobileFlowchartData data;
  final Set<String> closedBranches;
  final ValueChanged<String> onToggleBranch;

  @override
  Widget build(BuildContext context) {
    final root = _rootNode(data);
    if (root == null) {
      return const Text('Nincs flowchart tartalom', style: TextStyle(color: Color(0xFF6B7280)));
    }
    final children = _branchWidgets(root, path: const [], visited: const {});
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  List<Widget> _branchWidgets(
    MobileFlowchartNode node, {
    required List<String> path,
    required Set<String> visited,
  }) {
    final outgoing = _sortedOutgoing(data, node.id);
    if (outgoing.isEmpty) {
      return [_ProcessCard(node: node, terminal: true)];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < outgoing.length; i += 1) {
      final edge = outgoing[i];
      final normalized = _normalizedAnswer(edge.label, fallback: i + 1);
      final branchId = '${node.id}-${normalized.key}';
      if (i > 0) {
        widgets.add(_SiblingDivider(key: ValueKey('mobile-flowchart-sibling-divider-${node.id}'), label: '${node.label} · másik ág'));
      }
      final closed = closedBranches.contains(branchId);
      widgets.add(
        _BranchCard(
          key: ValueKey('mobile-flowchart-branch-${node.id}-${normalized.key}'),
          node: node,
          answer: normalized.label,
          pathLabel: _pathLabel([...path, normalized.label]),
          closed: closed,
          onTap: () => onToggleBranch(branchId),
        ),
      );
      if (closed) {
        continue;
      }
      final target = _nodeById(data, edge.toNodeId);
      if (target == null) {
        continue;
      }
      widgets.add(const _Arrow());
      widgets.add(_ProcessCard(node: target, terminal: _sortedOutgoing(data, target.id).isEmpty));
      if (visited.contains(target.id)) {
        continue;
      }
      final childOutgoing = _sortedOutgoing(data, target.id);
      if (childOutgoing.isNotEmpty) {
        widgets.add(const _Arrow());
        widgets.addAll(
          _branchWidgets(
            target,
            path: [...path, normalized.label],
            visited: {...visited, node.id},
          ),
        );
      }
    }
    return widgets;
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({super.key, required this.node, required this.answer, required this.pathLabel, required this.closed, required this.onTap});

  final MobileFlowchartNode node;
  final String answer;
  final String pathLabel;
  final bool closed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final yes = _isYes(answer);
    final no = _isNo(answer);
    final color = yes
        ? const Color(0xFF047857)
        : no
            ? const Color(0xFFB91C1C)
            : const Color(0xFF374151);
    final bg = yes
        ? const Color(0xFFECFDF5)
        : no
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF9FAFB);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(closed ? Icons.chevron_right : Icons.expand_more, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        node.label.trim().isEmpty ? 'Döntés' : node.label.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827), height: 1.22),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _AnswerChip(label: answer, color: color),
                          if (pathLabel.isNotEmpty)
                            Text(pathLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerChip extends StatelessWidget {
  const _AnswerChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({required this.node, required this.terminal});

  final MobileFlowchartNode node;
  final bool terminal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('mobile-flowchart-process-${node.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_shapeIcon(node.shape), size: 19, color: const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      node.label.trim().isEmpty ? 'Névtelen lépés' : node.label.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3, color: Color(0xFF111827)),
                    ),
                    if (terminal) ...[
                      const SizedBox(height: 6),
                      const Text('Ág vége', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: ValueKey('mobile-flowchart-arrow'),
      padding: EdgeInsets.only(bottom: 6),
      child: Center(child: Icon(Icons.arrow_downward, size: 16, color: Color(0xFF9CA3AF))),
    );
  }
}

class _SiblingDivider extends StatelessWidget {
  const _SiblingDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFD8B4FE))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D28D9))),
          ),
          const Expanded(child: Divider(color: Color(0xFFD8B4FE))),
        ],
      ),
    );
  }
}

class _FlowchartCanvasView extends StatelessWidget {
  const _FlowchartCanvasView({super.key, required this.data, required this.controller, required this.onZoom});

  final MobileFlowchartData data;
  final TransformationController controller;
  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    final layout = _autoLayout(data);
    final size = _canvasSizeFor(layout);
    return SizedBox(
      height: 280,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5E7EB))),
                child: InteractiveViewer(
                  transformationController: controller,
                  constrained: false,
                  minScale: 0.45,
                  maxScale: 2.8,
                  boundaryMargin: const EdgeInsets.all(500),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: CustomPaint(
                      painter: _MobileCanvasPainter(data: data, layout: layout),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                IconButton.filledTonal(
                  key: const ValueKey('mobile-flowchart-canvas-zoom-in'),
                  tooltip: 'Nagyítás',
                  onPressed: () => onZoom(1.18),
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(height: 6),
                IconButton.filledTonal(
                  key: const ValueKey('mobile-flowchart-canvas-zoom-out'),
                  tooltip: 'Kicsinyítés',
                  onPressed: () => onZoom(0.84),
                  icon: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowchartGuideView extends StatelessWidget {
  const _FlowchartGuideView({super.key, required this.data, required this.step, required this.canGoBack, required this.onAnswer, required this.onNext, required this.onBack});

  final MobileFlowchartData data;
  final _GuideStep? step;
  final bool canGoBack;
  final ValueChanged<MobileFlowchartEdge> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final current = step;
    if (current == null) {
      return const Text('Nincs flowchart tartalom');
    }
    final node = _nodeById(data, current.nodeId);
    final edge = current.edge;
    final showingAnswer = edge != null;
    final target = edge == null ? null : _nodeById(data, edge.toNodeId);
    final outgoing = node == null ? <MobileFlowchartEdge>[] : _sortedOutgoing(data, node.id);
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canGoBack)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('mobile-flowchart-guide-back'),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Vissza'),
                ),
              ),
            if (!showingAnswer) ...[
              SelectableText(
                node?.label.trim().isNotEmpty == true ? node!.label.trim() : 'Döntés',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.25),
              ),
              const SizedBox(height: 12),
              if (outgoing.isEmpty)
                const Text('Ág vége', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280)))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < outgoing.length; i += 1)
                      FilledButton.tonal(
                        key: ValueKey('mobile-flowchart-guide-answer-${_normalizedAnswer(outgoing[i].label, fallback: i + 1).key}'),
                        onPressed: () => onAnswer(outgoing[i]),
                        child: Text(_normalizedAnswer(outgoing[i].label, fallback: i + 1).label),
                      ),
                  ],
                ),
            ] else ...[
              _AnswerChip(label: _normalizedAnswer(edge.label, fallback: 1).label, color: const Color(0xFF7C3AED)),
              const SizedBox(height: 10),
              SelectableText(
                target?.label.trim().isNotEmpty == true ? target!.label.trim() : 'Ág vége',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
              ),
              const SizedBox(height: 12),
              if (target != null && _sortedOutgoing(data, target.id).isNotEmpty)
                FilledButton.icon(
                  key: const ValueKey('mobile-flowchart-guide-next'),
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Tovább a következő döntéshez'),
                )
              else
                const Text('Ág vége', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep._({required this.nodeId, this.edge});

  factory _GuideStep.decision(String nodeId) => _GuideStep._(nodeId: nodeId);
  factory _GuideStep.answer(MobileFlowchartEdge edge) => _GuideStep._(nodeId: edge.fromNodeId, edge: edge);

  final String nodeId;
  final MobileFlowchartEdge? edge;
}

class _AnswerLabel {
  const _AnswerLabel({required this.key, required this.label});

  final String key;
  final String label;
}

_AnswerLabel _normalizedAnswer(String value, {required int fallback}) {
  final trimmed = value.trim();
  final lower = trimmed.toLowerCase();
  if (lower == 'igen' || lower == 'yes' || lower == 'i') {
    return const _AnswerLabel(key: 'igen', label: 'Igen');
  }
  if (lower == 'nem' || lower == 'no' || lower == 'n') {
    return const _AnswerLabel(key: 'nem', label: 'Nem');
  }
  if (trimmed.isEmpty) {
    return _AnswerLabel(key: 'ag-$fallback', label: 'Ág $fallback');
  }
  final key = trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return _AnswerLabel(key: key.isEmpty ? 'ag-$fallback' : key, label: trimmed);
}

bool _isYes(String value) => value.trim().toLowerCase() == 'igen' || value.trim().toLowerCase() == 'yes';
bool _isNo(String value) => value.trim().toLowerCase() == 'nem' || value.trim().toLowerCase() == 'no';

String _pathLabel(List<String> parts) {
  if (parts.isEmpty) {
    return '';
  }
  return 'L${parts.length} · ${parts.map((part) => _isYes(part) ? 'I' : _isNo(part) ? 'N' : 'A').join()}';
}

MobileFlowchartNode? _rootNode(MobileFlowchartData data) {
  if (data.nodes.isEmpty) {
    return null;
  }
  final incoming = data.edges.map((edge) => edge.toNodeId).toSet();
  return data.nodes.firstWhere((node) => !incoming.contains(node.id), orElse: () => data.nodes.first);
}

MobileFlowchartNode? _nodeById(MobileFlowchartData data, String id) {
  for (final node in data.nodes) {
    if (node.id == id) {
      return node;
    }
  }
  return null;
}

List<MobileFlowchartEdge> _sortedOutgoing(MobileFlowchartData data, String nodeId) {
  final edges = data.edges.where((edge) => edge.fromNodeId == nodeId).toList(growable: false);
  return edges..sort((a, b) {
    final aa = _normalizedAnswer(a.label, fallback: 1).key;
    final bb = _normalizedAnswer(b.label, fallback: 2).key;
    if (aa == 'igen' && bb != 'igen') return -1;
    if (bb == 'igen' && aa != 'igen') return 1;
    if (aa == 'nem' && bb != 'nem') return 1;
    if (bb == 'nem' && aa != 'nem') return -1;
    return a.id.compareTo(b.id);
  });
}

Map<String, Offset> _autoLayout(MobileFlowchartData data) {
  final result = <String, Offset>{};
  final root = _rootNode(data);
  if (root == null) {
    return result;
  }
  var row = 0;
  void visit(MobileFlowchartNode node, int depth, Set<String> path) {
    if (result.containsKey(node.id)) {
      return;
    }
    result[node.id] = Offset(80 + depth * 240, 70 + row * 112);
    row += 1;
    if (path.contains(node.id)) {
      return;
    }
    for (final edge in _sortedOutgoing(data, node.id)) {
      final target = _nodeById(data, edge.toNodeId);
      if (target != null) {
        visit(target, depth + 1, {...path, node.id});
      }
    }
  }
  visit(root, 0, const {});
  for (final node in data.nodes) {
    result.putIfAbsent(node.id, () => Offset(80, 70 + row++ * 112));
  }
  return result;
}

Size _canvasSizeFor(Map<String, Offset> layout) {
  var maxX = 420.0;
  var maxY = 280.0;
  for (final offset in layout.values) {
    maxX = math.max(maxX, offset.dx + 220);
    maxY = math.max(maxY, offset.dy + 100);
  }
  return Size(maxX + 80, maxY + 80);
}

IconData _shapeIcon(String shape) {
  return switch (shape) {
    'start_end' => Icons.trip_origin,
    'decision' => Icons.change_history,
    'input_output' => Icons.input,
    'subprocess' => Icons.integration_instructions_outlined,
    'data_store' => Icons.storage,
    'connector' => Icons.radio_button_unchecked,
    _ => Icons.crop_square,
  };
}

class _MobileCanvasPainter extends CustomPainter {
  const _MobileCanvasPainter({required this.data, required this.layout});

  final MobileFlowchartData data;
  final Map<String, Offset> layout;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final nodePaint = Paint()..color = const Color(0xFFFFFFFF);
    final borderPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr, maxLines: 3, ellipsis: '...');
    for (final edge in data.edges) {
      final from = layout[edge.fromNodeId];
      final to = layout[edge.toNodeId];
      if (from == null || to == null) continue;
      final start = from + const Offset(180, 34);
      final end = to + const Offset(0, 34);
      final midX = (start.dx + end.dx) / 2;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(midX, start.dy)
        ..lineTo(midX, end.dy)
        ..lineTo(end.dx, end.dy);
      canvas.drawPath(path, linePaint);
    }
    for (final node in data.nodes) {
      final offset = layout[node.id];
      if (offset == null) continue;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(offset.dx, offset.dy, 180, 68), const Radius.circular(8));
      canvas.drawRRect(rect, nodePaint);
      canvas.drawRRect(rect, borderPaint);
      textPainter.text = TextSpan(
        text: node.label.trim().isEmpty ? 'Névtelen' : node.label.trim(),
        style: const TextStyle(color: Color(0xFF111827), fontSize: 12, fontWeight: FontWeight.w700),
      );
      textPainter.layout(maxWidth: 148);
      textPainter.paint(canvas, offset + const Offset(16, 14));
    }
  }

  @override
  bool shouldRepaint(covariant _MobileCanvasPainter oldDelegate) => oldDelegate.data != data || oldDelegate.layout != layout;
}
