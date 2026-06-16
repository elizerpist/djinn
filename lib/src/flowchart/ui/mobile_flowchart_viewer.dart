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
    this.kind = '',
    this.role = '',
    this.visualShape = '',
    this.ports = const [],
    this.order = 0,
    this.x,
    this.y,
  });

  final String id;
  final String label;
  final String shape;
  final String kind;
  final String role;
  final String visualShape;
  final List<MobileFlowchartPort> ports;
  final int order;
  final double? x;
  final double? y;
}

class MobileFlowchartPort {
  const MobileFlowchartPort({
    required this.id,
    required this.side,
    this.label = '',
    this.semantic = 'normal',
  });

  final String id;
  final String side;
  final String label;
  final String semantic;
}

class MobileFlowchartWaypoint {
  const MobileFlowchartWaypoint(this.x, this.y);

  final double x;
  final double y;

  Offset get offset => Offset(x, y);
}

class MobileFlowchartEdge {
  const MobileFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
    this.fromPortId,
    this.toPortId,
    this.routingMode = 'auto',
    this.manualWaypoints = const [],
    this.order = 0,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
  final String? fromPortId;
  final String? toPortId;
  final String routingMode;
  final List<MobileFlowchartWaypoint> manualWaypoints;
  final int order;
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
    _guideStep = _GuideStep.decision(_rootNode(widget.data)?.id ?? '');
  }

  @override
  void didUpdateWidget(covariant MobileFlowchartViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.id != widget.data.id) {
      _closedBranches.clear();
      _guideBackStack.clear();
      _guideStep = _GuideStep.decision(_rootNode(widget.data)?.id ?? '');
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
    final sourceSummary = widget.data.sourceSummary?.trim();
    final routeSummary = _routeSummary(widget.data);
    return DecoratedBox(
      key: ValueKey('mobile-flowchart-viewer-${widget.data.id}'),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = Column(
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (sourceSummary?.isNotEmpty == true)
                      Text(
                        sourceSummary!,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280)),
                      ),
                    _DepthPill(label: routeSummary),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ModeSelector(
              selected: _mode,
              onSelected: (mode) => setState(() => _mode = mode),
            ),
            const SizedBox(height: 8),
            if (_mode == MobileFlowchartViewMode.list) ...[
              _ListToolbar(
                onOpenAll: _openAllBranches,
                onCloseDeep: _closeDeepBranches,
              ),
              const SizedBox(height: 10),
            ] else
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
                  pathLabel: _guidePathLabel(),
                  onAnswer: _chooseGuideAnswer,
                  onNext: _advanceGuide,
                  onBack: _goGuideBack,
                ),
            },
          ],
            );
            if (!constraints.hasBoundedHeight) {
              return content;
            }
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: content,
            );
          },
        ),
      ),
    );
  }

  void _toggleBranch(String branchId) {
    setState(() {
      if (!_closedBranches.add(branchId)) {
        _closedBranches.remove(branchId);
      }
    });
  }

  void _openAllBranches() {
    setState(_closedBranches.clear);
  }

  void _closeDeepBranches() {
    setState(() {
      _closedBranches
        ..clear()
        ..addAll(_deepBranchIds(widget.data, minLevel: 3));
    });
  }

  void _zoomCanvas(double factor) {
    final current = _canvasController.value.clone();
    current.multiply(Matrix4.diagonal3Values(factor, factor, 1));
    setState(() => _canvasController.value = current);
  }

  String _guidePathLabel() {
    final labels = <String>[];
    for (final step in [..._guideBackStack, if (_guideStep != null) _guideStep!]) {
      final label = step.branch?.label.trim();
      if (label != null && label.isNotEmpty) {
        labels.add(label);
      }
    }
    return labels.isEmpty ? 'Kezdés' : labels.join(' -> ');
  }

  void _chooseGuideAnswer(_ResolvedBranch branch) {
    final current = _guideStep;
    if (current != null) {
      _guideBackStack.add(current);
    }
    setState(() => _guideStep = _GuideStep.answer(branch));
  }

  void _advanceGuide() {
    final step = _guideStep;
    final target = step?.branch?.target;
    if (target == null) {
      return;
    }
    _guideBackStack.add(step!);
    setState(() => _guideStep = _GuideStep.decision(target.id));
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
    return Row(
      children: [
        for (final item in MobileFlowchartViewMode.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: item == MobileFlowchartViewMode.values.last ? 0 : 6),
              child: _ModeButton(
                mode: item,
                selected: selected == item,
                onTap: () => onSelected(item),
              ),
            ),
          ),
      ],
    );
  }
}

class _DepthPill extends StatelessWidget {
  const _DepthPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFCAD4DD)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF617080))),
      ),
    );
  }
}

class _ListToolbar extends StatelessWidget {
  const _ListToolbar({required this.onOpenAll, required this.onCloseDeep});

  final VoidCallback onOpenAll;
  final VoidCallback onCloseDeep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('mobile-flowchart-open-all'),
            onPressed: onOpenAll,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF263747),
              side: const BorderSide(color: Color(0xFFCAD4DD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Nyit mind', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            key: const ValueKey('mobile-flowchart-close-deep'),
            onPressed: onCloseDeep,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF263747),
              side: const BorderSide(color: Color(0xFFCAD4DD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Mély ágak zárása', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.mode, required this.selected, required this.onTap});

  final MobileFlowchartViewMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (mode) {
      MobileFlowchartViewMode.list => 'Lista',
      MobileFlowchartViewMode.canvas => 'Canvas',
      MobileFlowchartViewMode.guide => 'Guide',
    };
    final icon = switch (mode) {
      MobileFlowchartViewMode.list => Icons.format_list_bulleted,
      MobileFlowchartViewMode.canvas => Icons.open_with,
      MobileFlowchartViewMode.guide => Icons.assistant_direction_outlined,
    };
    return Material(
      color: selected ? const Color(0xFFE8F4F5) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('mobile-flowchart-selector-${mode.name}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF1B6B6F) : const Color(0xFFCAD4DD)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? const Color(0xFF134F52) : const Color(0xFF334454)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: selected ? const Color(0xFF134F52) : const Color(0xFF334454),
                    ),
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
    final branches = _branchesFor(data, root);
    if (branches.isEmpty) {
      return _ProcessCard(node: root, terminal: true);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _branchWidgets(root, path: const [], visited: const {}));
  }

  List<Widget> _branchWidgets(
    MobileFlowchartNode node, {
    required List<String> path,
    required Set<String> visited,
  }) {
    final branches = _branchesFor(data, node);
    final widgets = <Widget>[];
    for (var i = 0; i < branches.length; i += 1) {
      final branch = branches[i];
      if (i > 0) {
        widgets.add(_SiblingDivider(key: ValueKey('mobile-flowchart-sibling-divider-${node.id}'), label: '${node.label} · másik ág'));
      }
      final nextPath = [...path, branch.label];
      final branchId = _pathBranchId(nextPath);
      final closed = closedBranches.contains(branchId);
      widgets.add(
        _BranchCard(
          key: ValueKey('mobile-flowchart-branch-${node.id}-${branch.key}'),
          node: node,
          answer: branch.label,
          pathLabel: _pathLabel(nextPath),
          closed: closed,
          onTap: () => onToggleBranch(branchId),
        ),
      );
      if (closed) {
        continue;
      }
      widgets.add(const _Arrow());
      final target = branch.target;
      if (target == null) {
        widgets.add(_LeafCard(key: ValueKey('mobile-flowchart-leaf-${node.id}-${branch.key}'), label: branch.label));
        continue;
      }
      widgets.add(_ProcessCard(node: target, terminal: _branchesFor(data, target).isEmpty));
      if (visited.contains(target.id)) {
        widgets.add(const _LeafCard(label: 'Visszacsatolás'));
        continue;
      }
      final childBranches = _branchesFor(data, target);
      if (childBranches.isNotEmpty) {
        widgets.add(const _Arrow());
        widgets.addAll(_branchWidgets(target, path: nextPath, visited: {...visited, node.id}));
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
        ? const Color(0xFF16613B)
        : no
            ? const Color(0xFF8A3428)
            : const Color(0xFF374151);
    final bg = yes
        ? const Color(0xFFECF8F0)
        : no
            ? const Color(0xFFFFF1EF)
            : Colors.white;
    final border = yes
        ? const Color(0xFF238354)
        : no
            ? const Color(0xFFB25444)
            : const Color(0xFFD2DAE2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          node.label.trim().isEmpty ? 'Döntés' : node.label.trim(),
                          style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF21313F), height: 1.22),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _AnswerChip(label: answer, color: color),
                            if (pathLabel.isNotEmpty)
                              Text(pathLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF617080))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0x2E263747)),
                    ),
                    child: SizedBox.square(
                      dimension: 28,
                      child: Icon(closed ? Icons.chevron_right : Icons.expand_more, color: color, size: 19),
                    ),
                  ),
                ],
              ),
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
      decoration: BoxDecoration(color: color.withValues(alpha: 0.11), borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(label, style: TextStyle(fontSize: 12, height: 1, fontWeight: FontWeight.w900, color: color)),
      ),
    );
  }
}

class _ProcessCard extends StatelessWidget {
  const _ProcessCard({super.key, required this.node, required this.terminal});

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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD2DAE2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_shapeIcon(node), size: 19, color: const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nodeTypeText(node), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF617080))),
                    const SizedBox(height: 3),
                    SelectableText(
                      node.label.trim().isEmpty ? 'Névtelen lépés' : node.label.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700, height: 1.28, color: Color(0xFF263747)),
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

class _LeafCard extends StatelessWidget {
  const _LeafCard({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD7DFE6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ág vége', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF617080))),
              const SizedBox(height: 3),
              SelectableText(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B7280), height: 1.26)),
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
          const Expanded(child: Divider(color: Color(0xFFD5DDE5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF617080))),
          ),
          const Expanded(child: Divider(color: Color(0xFFD5DDE5))),
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
    final layout = _canvasLayout(data);
    final bounds = _canvasBounds(data, layout).inflate(120);
    final size = Size(math.max(640, bounds.width), math.max(520, bounds.height));
    final nodes = {for (final node in data.nodes) node.id: node};
    return SizedBox(
      height: 360,
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
                  minScale: 0.35,
                  maxScale: 2.8,
                  boundaryMargin: const EdgeInsets.all(700),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: Stack(
                      children: [
                        Positioned.fill(child: CustomPaint(painter: const _GridPainter(step: 24))),
                        Positioned.fill(child: CustomPaint(painter: _CanvasEdgePainter(data: data, layout: layout, bounds: bounds))),
                        for (final edge in data.edges)
                          if (nodes[edge.fromNodeId] != null && nodes[edge.toNodeId] != null)
                            _CanvasEdgeAnchor(edge: edge, data: data, layout: layout, bounds: bounds),
                        for (final edge in data.edges)
                          if (nodes[edge.fromNodeId] != null && nodes[edge.toNodeId] != null)
                            _CanvasEdgeLabel(edge: edge, data: data, layout: layout, bounds: bounds),
                        for (final node in data.nodes)
                          _CanvasNodePreview(node: node, offset: layout[node.id]! - bounds.topLeft),
                      ],
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

class _CanvasNodePreview extends StatelessWidget {
  const _CanvasNodePreview({required this.node, required this.offset});

  final MobileFlowchartNode node;
  final Offset offset;

  @override
  Widget build(BuildContext context) {
    final size = _nodeSize(node);
    final ports = _effectivePorts(node);
    return Positioned(
      key: ValueKey('mobile-flowchart-canvas-node-${node.id}'),
      left: offset.dx,
      top: offset.dy,
      width: size.width,
      height: size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED), width: 1.4),
                boxShadow: const [BoxShadow(color: Color(0x12111827), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_shapeIcon(node), size: 18, color: const Color(0xFF7C3AED)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nodeTypeText(node), style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            node.label.trim().isEmpty ? 'Névtelen' : node.label.trim(),
                            overflow: TextOverflow.fade,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, height: 1.16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final port in ports)
            _CanvasPortDot(
              key: ValueKey('mobile-flowchart-canvas-port-${node.id}-${port.id}'),
              port: port,
              nodeSize: size,
              unitOffset: _portUnitOffset(port.side, ports.where((p) => p.side == port.side).toList().indexOf(port), ports.where((p) => p.side == port.side).length),
            ),
        ],
      ),
    );
  }
}

class _CanvasPortDot extends StatelessWidget {
  const _CanvasPortDot({super.key, required this.port, required this.nodeSize, required this.unitOffset});

  final MobileFlowchartPort port;
  final Size nodeSize;
  final Offset unitOffset;

  @override
  Widget build(BuildContext context) {
    final color = port.semantic == 'normal' ? const Color(0xFF059669) : const Color(0xFF7C3AED);
    final icon = switch (port.semantic) {
      'yes' => Icons.add,
      'no' => Icons.remove,
      'custom' => Icons.call_split,
      _ => Icons.radio_button_checked,
    };
    return Positioned(
      left: nodeSize.width * unitOffset.dx - 11,
      top: nodeSize.height * unitOffset.dy - 11,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: color, width: 1.5)),
        child: SizedBox.square(dimension: 22, child: Icon(icon, size: 12, color: color)),
      ),
    );
  }
}

class _CanvasEdgePainter extends CustomPainter {
  const _CanvasEdgePainter({required this.data, required this.layout, required this.bounds});

  final MobileFlowchartData data;
  final Map<String, Offset> layout;
  final Rect bounds;

  @override
  void paint(Canvas canvas, Size size) {
    final nodesById = {for (final node in data.nodes) node.id: node};
    final paint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.fill;
    for (final edge in data.edges) {
      final from = nodesById[edge.fromNodeId];
      final to = nodesById[edge.toNodeId];
      if (from == null || to == null) continue;
      final route = _routeEdge(edge, from, to, layout).map((point) => point - bounds.topLeft).toList(growable: false);
      if (route.length < 2) continue;
      final path = Path()..moveTo(route.first.dx, route.first.dy);
      for (final point in route.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      _drawArrow(canvas, route[route.length - 2], route.last, arrowPaint);
    }
  }

  void _drawArrow(Canvas canvas, Offset previous, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - previous.dy, end.dx - previous.dx);
    const size = 8.0;
    final p1 = end - Offset(math.cos(angle - math.pi / 7) * size, math.sin(angle - math.pi / 7) * size);
    final p2 = end - Offset(math.cos(angle + math.pi / 7) * size, math.sin(angle + math.pi / 7) * size);
    canvas.drawPath(Path()..moveTo(end.dx, end.dy)..lineTo(p1.dx, p1.dy)..lineTo(p2.dx, p2.dy)..close(), paint);
  }

  @override
  bool shouldRepaint(covariant _CanvasEdgePainter oldDelegate) => oldDelegate.data != data || oldDelegate.layout != layout || oldDelegate.bounds != bounds;
}

class _CanvasEdgeAnchor extends StatelessWidget {
  const _CanvasEdgeAnchor({required this.edge, required this.data, required this.layout, required this.bounds});

  final MobileFlowchartEdge edge;
  final MobileFlowchartData data;
  final Map<String, Offset> layout;
  final Rect bounds;

  @override
  Widget build(BuildContext context) {
    final nodes = {for (final node in data.nodes) node.id: node};
    final from = nodes[edge.fromNodeId];
    final to = nodes[edge.toNodeId];
    if (from == null || to == null) return const SizedBox.shrink();
    final route = _routeEdge(edge, from, to, layout).map((point) => point - bounds.topLeft).toList(growable: false);
    if (route.isEmpty) return const SizedBox.shrink();
    final middle = route[route.length ~/ 2];
    return Positioned(
      key: ValueKey('mobile-flowchart-canvas-edge-${edge.id}'),
      left: middle.dx,
      top: middle.dy,
      width: 1,
      height: 1,
      child: const SizedBox.expand(),
    );
  }
}

class _CanvasEdgeLabel extends StatelessWidget {
  const _CanvasEdgeLabel({required this.edge, required this.data, required this.layout, required this.bounds});

  final MobileFlowchartEdge edge;
  final MobileFlowchartData data;
  final Map<String, Offset> layout;
  final Rect bounds;

  @override
  Widget build(BuildContext context) {
    final nodes = {for (final node in data.nodes) node.id: node};
    final from = nodes[edge.fromNodeId];
    final to = nodes[edge.toNodeId];
    if (from == null || to == null) return const SizedBox.shrink();
    final route = _routeEdge(edge, from, to, layout).map((point) => point - bounds.topLeft).toList(growable: false);
    if (route.isEmpty) return const SizedBox.shrink();
    final middle = route[route.length ~/ 2];
    final label = _edgeDisplayLabel(data, edge, fallback: 1);
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Positioned(
      key: ValueKey('mobile-flowchart-canvas-label-${edge.id}'),
      left: middle.dx - 36,
      top: middle.dy - 16,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE9D5FF)),
          boxShadow: const [BoxShadow(color: Color(0x14111827), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF374151))),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.step});

  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = const Color(0xFFEDE9FE)..strokeWidth = 0.7;
    final strong = Paint()..color = const Color(0xFFD8B4FE)..strokeWidth = 1.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ((x / step).round() % 4 == 0) ? strong : light);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ((y / step).round() % 4 == 0) ? strong : light);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.step != step;
}

class _FlowchartGuideView extends StatelessWidget {
  const _FlowchartGuideView({
    super.key,
    required this.data,
    required this.step,
    required this.canGoBack,
    required this.pathLabel,
    required this.onAnswer,
    required this.onNext,
    required this.onBack,
  });

  final MobileFlowchartData data;
  final _GuideStep? step;
  final bool canGoBack;
  final String pathLabel;
  final ValueChanged<_ResolvedBranch> onAnswer;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final current = step;
    if (current == null) {
      return const Text('Nincs flowchart tartalom');
    }
    final branch = current.branch;
    final node = _nodeById(data, current.nodeId);
    if (branch == null) {
      final outgoing = node == null ? <_ResolvedBranch>[] : _branchesFor(data, node);
      return _GuidePanel(
        children: [
          if (canGoBack) _GuideBackButton(onBack: onBack),
          _GuideCard(
            kicker: pathLabel,
            child: SelectableText(
              node?.label.trim().isNotEmpty == true ? node!.label.trim() : 'Döntés',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.25),
            ),
          ),
          if (outgoing.isEmpty)
            const _GuideDisabledChoice(label: 'Ág vége')
          else
            for (final item in outgoing)
              if (item.target == null)
                _GuideDisabledChoice(key: ValueKey('mobile-flowchart-guide-disabled-${item.key}'), label: item.label)
              else
                _GuideChoice(key: ValueKey('mobile-flowchart-guide-answer-${item.key}'), branch: item, onTap: () => onAnswer(item)),
        ],
      );
    }
    final target = branch.target;
    return _GuidePanel(
      children: [
        if (canGoBack) _GuideBackButton(onBack: onBack),
        _GuideCard(
          kicker: pathLabel,
          child: SelectableText(
            target?.label.trim().isNotEmpty == true ? target!.label.trim() : 'Ág vége',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.3),
          ),
        ),
        if (target != null && _branchesFor(data, target).isNotEmpty)
          FilledButton.icon(
            key: const ValueKey('mobile-flowchart-guide-next'),
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Tovább a következő döntéshez', overflow: TextOverflow.ellipsis),
          )
        else
          const _GuideDisabledChoice(label: 'Ág vége'),
      ],
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final child in children) Padding(padding: const EdgeInsets.only(bottom: 8), child: child)]);
  }
}

class _GuideBackButton extends StatelessWidget {
  const _GuideBackButton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(key: const ValueKey('mobile-flowchart-guide-back'), onPressed: onBack, icon: const Icon(Icons.arrow_back), label: const Text('Vissza')),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.kicker, required this.child});

  final String kicker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD2DAE2)), boxShadow: const [BoxShadow(color: Color(0x111F2D3A), blurRadius: 12, offset: Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kicker, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF617080))),
          const SizedBox(height: 6),
          child,
        ]),
      ),
    );
  }
}

class _GuideChoice extends StatelessWidget {
  const _GuideChoice({super.key, required this.branch, required this.onTap});

  final _ResolvedBranch branch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _isYes(branch.label) ? const Color(0xFF16613B) : _isNo(branch.label) ? const Color(0xFF8A3428) : const Color(0xFF374151);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCAD4DD))),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              _AnswerChip(label: branch.label, color: color),
              const SizedBox(width: 8),
              Expanded(child: Text(branch.target?.label.trim().isNotEmpty == true ? branch.target!.label.trim() : 'Tovább', style: const TextStyle(fontWeight: FontWeight.w800))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GuideDisabledChoice extends StatelessWidget {
  const _GuideDisabledChoice({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD1D5DB))),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep._({required this.nodeId, this.branch});

  factory _GuideStep.decision(String nodeId) => _GuideStep._(nodeId: nodeId);
  factory _GuideStep.answer(_ResolvedBranch branch) => _GuideStep._(nodeId: branch.source.id, branch: branch);

  final String nodeId;
  final _ResolvedBranch? branch;
}

class _ResolvedBranch {
  const _ResolvedBranch({required this.source, required this.port, required this.edge, required this.target, required this.label, required this.key, required this.order});

  final MobileFlowchartNode source;
  final MobileFlowchartPort? port;
  final MobileFlowchartEdge? edge;
  final MobileFlowchartNode? target;
  final String label;
  final String key;
  final int order;
}

String _routeSummary(MobileFlowchartData data) {
  final root = _rootNode(data);
  if (root == null) return '1 -> 0';
  final count = _terminalPathCount(data, root, const <String>{});
  return '1 -> $count';
}

int _terminalPathCount(MobileFlowchartData data, MobileFlowchartNode node, Set<String> visited) {
  final branches = _branchesFor(data, node);
  if (branches.isEmpty) return 1;
  var count = 0;
  for (final branch in branches) {
    final target = branch.target;
    if (target == null || visited.contains(target.id)) {
      count += 1;
    } else {
      count += _terminalPathCount(data, target, {...visited, node.id});
    }
  }
  return math.max(1, count);
}

MobileFlowchartNode? _rootNode(MobileFlowchartData data) {
  if (data.nodes.isEmpty) return null;
  final sorted = [...data.nodes]..sort((a, b) => a.order.compareTo(b.order));
  final explicitStart = _firstWhereOrNull(
    sorted,
    (node) => node.role.trim().toLowerCase() == 'start' || node.shape.trim().toLowerCase() == 'start_end',
  );
  if (explicitStart != null) return explicitStart;
  final incoming = data.edges.map((edge) => edge.toNodeId).where((id) => id.trim().isNotEmpty).toSet();
  return sorted.firstWhere((node) => !incoming.contains(node.id), orElse: () => sorted.first);
}

MobileFlowchartNode? _nodeById(MobileFlowchartData data, String id) {
  for (final node in data.nodes) {
    if (node.id == id) return node;
  }
  return null;
}

List<_ResolvedBranch> _branchesFor(MobileFlowchartData data, MobileFlowchartNode node) {
  final ports = _effectivePorts(node);
  final usedPortIds = <String>{};
  final result = <_ResolvedBranch>[];
  final edges = data.edges.where((edge) => edge.fromNodeId == node.id).toList()
    ..sort((a, b) => a.order == b.order ? a.id.compareTo(b.id) : a.order.compareTo(b.order));
  var fallback = 1;
  for (final edge in edges) {
    final port = _portForEdge(node, edge, ports);
    if (port != null) usedPortIds.add(port.id);
    final label = _branchLabel(port, edge, fallback: fallback);
    result.add(_ResolvedBranch(
      source: node,
      port: port,
      edge: edge,
      target: _nodeById(data, edge.toNodeId),
      label: label,
      key: _labelKey(label, fallback: fallback),
      order: _portOrder(ports, port, edge.order),
    ));
    fallback += 1;
  }
  for (final port in ports) {
    if (usedPortIds.contains(port.id) || !_isBranchPort(port)) continue;
    final label = _branchLabel(port, null, fallback: fallback);
    result.add(_ResolvedBranch(
      source: node,
      port: port,
      edge: null,
      target: null,
      label: label,
      key: _labelKey(label, fallback: fallback),
      order: _portOrder(ports, port, 1000 + fallback),
    ));
    fallback += 1;
  }
  result.sort((a, b) {
    final ak = _normalizedOrderKey(a.label);
    final bk = _normalizedOrderKey(b.label);
    if (ak != bk) return ak.compareTo(bk);
    return a.order.compareTo(b.order);
  });
  return result;
}

int _normalizedOrderKey(String label) {
  if (_isYes(label)) return 0;
  if (_isNo(label)) return 90;
  return 10;
}

int _portOrder(List<MobileFlowchartPort> ports, MobileFlowchartPort? port, int fallback) {
  if (port == null) return fallback;
  final index = ports.indexWhere((item) => item.id == port.id);
  return index < 0 ? fallback : index;
}

MobileFlowchartPort? _portForEdge(MobileFlowchartNode node, MobileFlowchartEdge edge, List<MobileFlowchartPort> ports) {
  if (edge.fromPortId != null) {
    for (final port in ports) {
      if (port.id == edge.fromPortId) return port;
    }
  }
  final lower = edge.label.trim().toLowerCase();
  if (lower == 'igen' || lower == 'yes') {
    return _firstWhereOrNull(ports, (port) => port.semantic == 'yes');
  }
  if (lower == 'nem' || lower == 'no') {
    return _firstWhereOrNull(ports, (port) => port.semantic == 'no');
  }
  final outputs = ports.where((port) => _isOutputLike(port)).toList();
  if (outputs.length == 1) return outputs.single;
  return null;
}

String _branchLabel(MobileFlowchartPort? port, MobileFlowchartEdge? edge, {required int fallback}) {
  if (port != null) {
    final semantic = port.semantic.trim().toLowerCase();
    if (semantic == 'yes') return 'Igen';
    if (semantic == 'no') return 'Nem';
    final label = port.label.trim();
    if (label.isNotEmpty) return label;
  }
  final edgeLabel = edge?.label.trim();
  if (edgeLabel != null && edgeLabel.isNotEmpty) return edgeLabel;
  return 'Ág $fallback';
}

bool _isBranchPort(MobileFlowchartPort port) => port.semantic == 'yes' || port.semantic == 'no' || port.semantic == 'custom';
bool _isOutputLike(MobileFlowchartPort port) => _isBranchPort(port) || port.id == 'out' || port.side == 'right' || port.side == 'bottom';

String _edgeDisplayLabel(MobileFlowchartData data, MobileFlowchartEdge edge, {required int fallback}) {
  final source = _nodeById(data, edge.fromNodeId);
  final port = source == null ? null : _portForEdge(source, edge, _effectivePorts(source));
  return _branchLabel(port, edge, fallback: fallback);
}

List<MobileFlowchartPort> _effectivePorts(MobileFlowchartNode node) {
  if (node.ports.isNotEmpty) return node.ports;
  final kind = node.kind.trim().toLowerCase();
  final role = node.role.trim().toLowerCase();
  final shape = node.shape.trim().toLowerCase();
  if (kind == 'binary_decision' || shape == 'decision') {
    return const [
      MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet'),
      MobileFlowchartPort(id: 'yes', side: 'bottom', label: 'Igen', semantic: 'yes'),
      MobileFlowchartPort(id: 'no', side: 'bottom', label: 'Nem', semantic: 'no'),
    ];
  }
  if (kind == 'multi_decision') {
    return const [
      MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet'),
      MobileFlowchartPort(id: 'branch-1', side: 'right', label: 'Ág 1', semantic: 'custom'),
      MobileFlowchartPort(id: 'branch-2', side: 'bottom', label: 'Ág 2', semantic: 'custom'),
    ];
  }
  if (role == 'start' || shape == 'start_end') {
    return const [MobileFlowchartPort(id: 'out', side: 'bottom', label: 'Kimenet')];
  }
  if (role == 'end') {
    return const [MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet')];
  }
  return const [
    MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet'),
    MobileFlowchartPort(id: 'out', side: 'bottom', label: 'Kimenet'),
  ];
}

String _labelKey(String value, {required int fallback}) {
  final key = value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóöőúüű]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return key.isEmpty ? 'ag-$fallback' : key;
}

bool _isYes(String value) => value.trim().toLowerCase() == 'igen' || value.trim().toLowerCase() == 'yes';
bool _isNo(String value) => value.trim().toLowerCase() == 'nem' || value.trim().toLowerCase() == 'no';

Set<String> _deepBranchIds(MobileFlowchartData data, {required int minLevel}) {
  final root = _rootNode(data);
  if (root == null) return const <String>{};
  final result = <String>{};
  void visit(MobileFlowchartNode node, List<String> path, Set<String> visited) {
    for (final branch in _branchesFor(data, node)) {
      final nextPath = [...path, branch.label];
      if (nextPath.length >= minLevel) {
        result.add(_pathBranchId(nextPath));
      }
      final target = branch.target;
      if (target != null && !visited.contains(target.id)) {
        visit(target, nextPath, {...visited, node.id});
      }
    }
  }

  visit(root, const [], const {});
  return result;
}

String _pathBranchId(List<String> parts) => parts.asMap().entries.map((entry) => '${entry.key + 1}-${_labelKey(entry.value, fallback: entry.key + 1)}').join('--');

String _pathLabel(List<String> parts) {
  if (parts.isEmpty) return '';
  return 'L${parts.length} · ${parts.map((part) => _isYes(part) ? 'I' : _isNo(part) ? 'N' : 'A').join()}';
}

IconData _shapeIcon(MobileFlowchartNode node) {
  final kind = node.kind.trim().toLowerCase();
  final role = node.role.trim().toLowerCase();
  final shape = node.shape.trim().toLowerCase();
  if (role == 'start' || role == 'end' || shape == 'start_end') return Icons.trip_origin;
  if (kind == 'multi_decision') return Icons.account_tree_outlined;
  if (kind == 'binary_decision' || shape == 'decision') return Icons.change_history;
  if (shape == 'input_output') return Icons.input;
  if (shape == 'subprocess') return Icons.integration_instructions_outlined;
  if (shape == 'data_store') return Icons.storage;
  if (shape == 'connector') return Icons.radio_button_unchecked;
  return Icons.crop_square;
}

String _nodeTypeText(MobileFlowchartNode node) {
  final kind = node.kind.trim().toLowerCase();
  final role = node.role.trim().toLowerCase();
  if (role == 'start') return 'Kezdés';
  if (role == 'end') return 'Vége';
  if (kind == 'multi_decision') return 'Többágú döntés';
  if (kind == 'binary_decision' || node.shape == 'decision') return 'Döntés';
  return 'Folyamat';
}

Map<String, Offset> _canvasLayout(MobileFlowchartData data) {
  final result = <String, Offset>{};
  final auto = _autoLayout(data);
  for (final node in data.nodes) {
    final x = node.x;
    final y = node.y;
    if (x != null || y != null) {
      result[node.id] = Offset(x ?? auto[node.id]?.dx ?? 80, y ?? auto[node.id]?.dy ?? 80);
    } else {
      result[node.id] = auto[node.id] ?? const Offset(80, 80);
    }
  }
  return result;
}

Map<String, Offset> _autoLayout(MobileFlowchartData data) {
  final result = <String, Offset>{};
  final root = _rootNode(data);
  if (root == null) return result;
  var row = 0;
  void visit(MobileFlowchartNode node, int depth, Set<String> path) {
    if (result.containsKey(node.id)) return;
    result[node.id] = Offset(80 + depth * 240, 70 + row * 112);
    row += 1;
    if (path.contains(node.id)) return;
    for (final branch in _branchesFor(data, node)) {
      final target = branch.target;
      if (target != null) visit(target, depth + 1, {...path, node.id});
    }
  }
  visit(root, 0, const {});
  for (final node in data.nodes) {
    result.putIfAbsent(node.id, () => Offset(80, 70 + row++ * 112));
  }
  return result;
}

Rect _canvasBounds(MobileFlowchartData data, Map<String, Offset> layout) {
  if (data.nodes.isEmpty) return const Rect.fromLTWH(0, 0, 640, 520);
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  void includePoint(Offset point, [double margin = 40]) {
    left = math.min(left, point.dx - margin);
    top = math.min(top, point.dy - margin);
    right = math.max(right, point.dx + margin);
    bottom = math.max(bottom, point.dy + margin);
  }

  for (final node in data.nodes) {
    final offset = layout[node.id] ?? Offset.zero;
    final size = _nodeSize(node);
    includePoint(offset);
    includePoint(offset + Offset(size.width, size.height));
  }
  final nodes = {for (final node in data.nodes) node.id: node};
  for (final edge in data.edges) {
    final from = nodes[edge.fromNodeId];
    final to = nodes[edge.toNodeId];
    if (from == null || to == null) continue;
    for (final point in _routeEdge(edge, from, to, layout)) {
      includePoint(point, 56);
    }
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

Size _nodeSize(MobileFlowchartNode node) {
  final text = node.label.trim().isEmpty ? _nodeTypeText(node) : node.label.trim();
  final longest = text.split('\n').fold<int>(0, (value, line) => math.max(value, line.length));
  final width = (188 + longest * 3.8).clamp(210.0, 370.0).toDouble();
  final lines = math.max(1, (text.length / math.max(16, ((width - 76) / 7.2).floor())).ceil());
  final minHeight = node.kind == 'binary_decision' || node.kind == 'multi_decision' || node.shape == 'decision' ? 96.0 : 78.0;
  final height = (48 + lines * 20.0).clamp(minHeight, 240.0).toDouble();
  return Size(width, height);
}

Offset _portUnitOffset(String side, int index, int count) {
  final fraction = (index + 1) / (count + 1);
  return switch (side) {
    'top' => Offset(fraction, 0),
    'right' => Offset(1, fraction),
    'left' => Offset(0, fraction),
    _ => Offset(fraction, 1),
  };
}

Offset _portOffset(MobileFlowchartNode node, MobileFlowchartPort? port, Map<String, Offset> layout) {
  final nodeOffset = layout[node.id] ?? Offset.zero;
  final size = _nodeSize(node);
  final ports = _effectivePorts(node);
  final actual = port ?? (ports.isEmpty ? null : ports.last);
  if (actual == null) return nodeOffset + Offset(size.width / 2, size.height / 2);
  final sameSide = ports.where((item) => item.side == actual.side).toList(growable: false);
  final unit = _portUnitOffset(actual.side, sameSide.indexWhere((item) => item.id == actual.id), sameSide.length);
  return nodeOffset + Offset(size.width * unit.dx, size.height * unit.dy);
}

List<Offset> _routeEdge(MobileFlowchartEdge edge, MobileFlowchartNode from, MobileFlowchartNode to, Map<String, Offset> layout) {
  final fromPort = _portForEdge(from, edge, _effectivePorts(from));
  final toPorts = _effectivePorts(to);
  final toPort = edge.toPortId == null ? (toPorts.isEmpty ? null : toPorts.first) : _firstWhereOrNull(toPorts, (port) => port.id == edge.toPortId);
  final start = _portOffset(from, fromPort, layout);
  final end = _portOffset(to, toPort, layout);
  final fromSize = _nodeSize(from);
  final toSize = _nodeSize(to);
  final fromRect = Rect.fromLTWH((layout[from.id] ?? Offset.zero).dx, (layout[from.id] ?? Offset.zero).dy, fromSize.width, fromSize.height).inflate(18);
  final toRect = Rect.fromLTWH((layout[to.id] ?? Offset.zero).dx, (layout[to.id] ?? Offset.zero).dy, toSize.width, toSize.height).inflate(18);
  final isBackEdge = toRect.center.dy < fromRect.center.dy - 8;
  final startExit = _exitPoint(start, fromPort?.side ?? 'bottom', 30);
  final endEntry = _entryPoint(end, toPort?.side ?? 'top', 24);
  if (edge.routingMode == 'manual' && edge.manualWaypoints.isNotEmpty) {
    return [start, ...edge.manualWaypoints.map((point) => point.offset), end];
  }
  if (isBackEdge) {
    final leftLane = math.min(fromRect.left, toRect.left) - 56;
    final rightLane = math.max(fromRect.right, toRect.right) + 56;
    final useLeft = (startExit.dx - leftLane).abs() <= (rightLane - startExit.dx).abs();
    final laneX = useLeft ? leftLane : rightLane;
    return [start, startExit, Offset(laneX, startExit.dy), Offset(laneX, endEntry.dy), endEntry, end];
  }
  final midY = (startExit.dy + endEntry.dy) / 2;
  return [start, startExit, Offset(startExit.dx, midY), Offset(endEntry.dx, midY), endEntry, end];
}

Offset _exitPoint(Offset point, String side, double distance) {
  return switch (side) {
    'top' => point.translate(0, -distance),
    'right' => point.translate(distance, 0),
    'left' => point.translate(-distance, 0),
    _ => point.translate(0, distance),
  };
}

Offset _entryPoint(Offset point, String side, double distance) {
  return switch (side) {
    'top' => point.translate(0, -distance),
    'right' => point.translate(distance, 0),
    'left' => point.translate(-distance, 0),
    _ => point.translate(0, distance),
  };
}


T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T value) test) {
  for (final value in values) {
    if (test(value)) return value;
  }
  return null;
}
