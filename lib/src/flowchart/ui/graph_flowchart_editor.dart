import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/flowchart_view_model.dart';

class GraphFlowchartEditor extends StatefulWidget {
  const GraphFlowchartEditor({super.key, required this.model, this.onSave});

  final FlowchartViewModel model;
  final Future<void> Function(FlowchartViewModel model)? onSave;

  @override
  State<GraphFlowchartEditor> createState() => _GraphFlowchartEditorState();
}

class _GraphFlowchartEditorState extends State<GraphFlowchartEditor> {
  late List<FlowchartNodeViewModel> _nodes = List.of(widget.model.nodes);

  FlowchartViewModel get _currentModel => FlowchartViewModel(
    id: widget.model.id,
    nodes: List.unmodifiable(_nodes),
    edges: widget.model.edges,
  );

  void _applyAutoLayout() {
    setState(() {
      _nodes = [
        for (var i = 0; i < _nodes.length; i += 1)
          FlowchartNodeViewModel(
            id: _nodes[i].id,
            label: _nodes[i].label,
            x: 24 + (i % 3) * 160,
            y: 24 + (i ~/ 3) * 96,
            validationState: _nodes[i].validationState,
            rejectionReason: _nodes[i].rejectionReason,
          ),
      ];
    });
  }

  Future<void> _save() async {
    await widget.onSave?.call(_currentModel);
  }

  Future<void> _editNode(FlowchartNodeViewModel node) async {
    final controller = TextEditingController(text: node.label);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Node szerkesztése'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Címke'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.trim().isEmpty) {
      return;
    }
    setState(() {
      _nodes = [
        for (final item in _nodes)
          item.id == node.id
              ? FlowchartNodeViewModel(
                  id: item.id,
                  label: updated.trim(),
                  x: item.x,
                  y: item.y,
                  validationState: item.validationState,
                  rejectionReason: item.rejectionReason,
                )
              : item,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _applyAutoLayout,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Auto layout'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Mentés'),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 3,
            boundaryMargin: const EdgeInsets.all(240),
            child: SizedBox(
              width: 720,
              height: 480,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _FlowchartEdgePainter(
                        nodes: _nodes,
                        edges: widget.model.edges,
                      ),
                    ),
                  ),
                  for (final edge in widget.model.edges)
                    _EdgeLabel(edge: edge, nodes: _nodes),
                  for (final node in _nodes)
                    Positioned(
                      left: node.x,
                      top: node.y,
                      child: _NodeCard(
                        node: node,
                        onTap: () => _editNode(node),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node, required this.onTap});

  final FlowchartNodeViewModel node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 112,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Center(
            child: Text(
              node.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgeLabel extends StatelessWidget {
  const _EdgeLabel({required this.edge, required this.nodes});

  final FlowchartEdgeViewModel edge;
  final List<FlowchartNodeViewModel> nodes;

  @override
  Widget build(BuildContext context) {
    final from = _findNode(edge.fromNodeId);
    final to = _findNode(edge.toNodeId);
    if (from == null || to == null) {
      return const SizedBox.shrink();
    }
    final x = (from.x + to.x) / 2 + 48;
    final y = (from.y + to.y) / 2 + 8;
    return Positioned(
      left: x,
      top: y,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(edge.label, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  FlowchartNodeViewModel? _findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }
}

class _FlowchartEdgePainter extends CustomPainter {
  const _FlowchartEdgePainter({required this.nodes, required this.edges});

  final List<FlowchartNodeViewModel> nodes;
  final List<FlowchartEdgeViewModel> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final from = _findNode(edge.fromNodeId);
      final to = _findNode(edge.toNodeId);
      if (from == null || to == null) {
        continue;
      }
      final start = Offset(from.x + 112, from.y + 28);
      final end = Offset(to.x, to.y + 28);
      canvas.drawLine(start, end, paint);
      _drawArrowHead(canvas, paint, start, end);
    }
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset start, Offset end) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    const length = 10.0;
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - length * math.cos(angle - math.pi / 6),
        end.dy - length * math.sin(angle - math.pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - length * math.cos(angle + math.pi / 6),
        end.dy - length * math.sin(angle + math.pi / 6),
      );
    canvas.drawPath(path, paint);
  }

  FlowchartNodeViewModel? _findNode(String id) {
    for (final node in nodes) {
      if (node.id == id) {
        return node;
      }
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant _FlowchartEdgePainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.edges != edges;
  }
}
