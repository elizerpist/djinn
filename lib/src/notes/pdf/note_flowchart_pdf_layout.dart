import 'dart:math' as math;
import 'dart:ui';

import '../models/note_document.dart';
import 'note_pdf_export_models.dart';

const double _nodeWidth = 156;
const double _nodeMinHeight = 64;
const double _chartPadding = 24;
const double _minReadableScale = 0.72;
const double _tileOverlap = 56;

class NotePdfFlowchartLayout {
  const NotePdfFlowchartLayout({
    required this.bounds,
    required this.nodeBoxes,
    required this.edgeRoutes,
    required this.pages,
  });

  final Rect bounds;
  final List<NotePdfFlowchartNodeBox> nodeBoxes;
  final List<NotePdfFlowchartEdgeRoute> edgeRoutes;
  final List<NotePdfFlowchartPage> pages;
}

class NotePdfFlowchartNodeBox {
  const NotePdfFlowchartNodeBox({required this.node, required this.rect});

  final NoteFlowchartNode node;
  final Rect rect;
}

class NotePdfFlowchartEdgeRoute {
  const NotePdfFlowchartEdgeRoute({
    required this.edge,
    required this.points,
    required this.labelAnchor,
  });

  final NoteFlowchartEdge edge;
  final List<Offset> points;
  final Offset labelAnchor;
}

class NotePdfFlowchartPage {
  const NotePdfFlowchartPage({
    required this.mode,
    required this.sourceRect,
    required this.scale,
    this.isOverview = false,
    this.index = 1,
    this.total = 1,
  });

  final NotePdfFlowchartPageMode mode;
  final Rect sourceRect;
  final double scale;
  final bool isOverview;
  final int index;
  final int total;
}

NotePdfFlowchartLayout buildNotePdfFlowchartLayout(
  NoteBlock block, {
  required double portraitWidth,
  required double portraitHeight,
  required double landscapeWidth,
  required double landscapeHeight,
}) {
  final nodes = [...block.nodes]..sort((a, b) => a.order.compareTo(b.order));
  final nodeBoxes = [
    for (var i = 0; i < nodes.length; i += 1)
      NotePdfFlowchartNodeBox(
        node: nodes[i],
        rect: Rect.fromLTWH(
          nodes[i].x == 0 && nodes[i].y == 0 ? 80.0 : nodes[i].x,
          nodes[i].x == 0 && nodes[i].y == 0 ? 80.0 + i * 120.0 : nodes[i].y,
          _nodeWidth,
          _heightFor(nodes[i].label),
        ),
      ),
  ];
  final bounds = _boundsFor(nodeBoxes).inflate(_chartPadding);
  final boxesById = {for (final box in nodeBoxes) box.node.id: box};
  final edgeRoutes = [
    for (final edge in block.edges)
      if (boxesById[edge.fromNodeId] != null &&
          boxesById[edge.toNodeId] != null)
        _edgeRoute(
          edge,
          _route(
            edge,
            boxesById[edge.fromNodeId]!.rect,
            boxesById[edge.toNodeId]!.rect,
          ),
        ),
  ];
  final pages = _pagesFor(
    bounds,
    portraitWidth: portraitWidth,
    portraitHeight: portraitHeight,
    landscapeWidth: landscapeWidth,
    landscapeHeight: landscapeHeight,
  );
  return NotePdfFlowchartLayout(
    bounds: bounds,
    nodeBoxes: nodeBoxes,
    edgeRoutes: edgeRoutes,
    pages: pages,
  );
}

double _heightFor(String label) {
  final lines = (label.trim().length / 24).ceil().clamp(1, 4).toInt();
  return math.max(_nodeMinHeight, 46 + lines * 14);
}

Rect _boundsFor(List<NotePdfFlowchartNodeBox> boxes) {
  if (boxes.isEmpty) {
    return const Rect.fromLTWH(0, 0, _nodeWidth, _nodeMinHeight);
  }
  var rect = boxes.first.rect;
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.rect);
  }
  return rect;
}

List<Offset> _route(NoteFlowchartEdge edge, Rect from, Rect to) {
  if (edge.routingMode == NoteFlowchartRoutingMode.manual &&
      edge.manualWaypoints.isNotEmpty) {
    return [
      from.center,
      ...edge.manualWaypoints.map((point) => Offset(point.x, point.y)),
      to.center,
    ];
  }
  final start = Offset(from.right, from.center.dy);
  final end = Offset(to.left, to.center.dy);
  final midX = (start.dx + end.dx) / 2;
  return [start, Offset(midX, start.dy), Offset(midX, end.dy), end];
}

NotePdfFlowchartEdgeRoute _edgeRoute(
  NoteFlowchartEdge edge,
  List<Offset> points,
) {
  return NotePdfFlowchartEdgeRoute(
    edge: edge,
    points: points,
    labelAnchor: _labelAnchor(points),
  );
}

Offset _labelAnchor(List<Offset> points) {
  if (points.isEmpty) {
    return Offset.zero;
  }
  if (points.length == 1) {
    return points.single;
  }
  final segments = <({Offset from, Offset to, double length})>[];
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i += 1) {
    final from = points[i];
    final to = points[i + 1];
    final length = (to - from).distance;
    segments.add((from: from, to: to, length: length));
    total += length;
  }
  var remaining = total / 2;
  for (final segment in segments) {
    if (remaining <= segment.length || segment == segments.last) {
      final t = segment.length == 0 ? 0.0 : remaining / segment.length;
      return Offset(
        segment.from.dx + (segment.to.dx - segment.from.dx) * t,
        segment.from.dy + (segment.to.dy - segment.from.dy) * t,
      );
    }
    remaining -= segment.length;
  }
  return points[points.length ~/ 2];
}

List<NotePdfFlowchartPage> _pagesFor(
  Rect bounds, {
  required double portraitWidth,
  required double portraitHeight,
  required double landscapeWidth,
  required double landscapeHeight,
}) {
  final portraitScale = math.min(
    portraitWidth / bounds.width,
    portraitHeight / bounds.height,
  );
  if (portraitScale >= _minReadableScale) {
    return [
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.portraitSingle,
        sourceRect: bounds,
        scale: portraitScale.clamp(0.1, 1.0).toDouble(),
      ),
    ];
  }
  final landscapeScale = math.min(
    landscapeWidth / bounds.width,
    landscapeHeight / bounds.height,
  );
  if (landscapeScale >= _minReadableScale) {
    return [
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.landscapeSingle,
        sourceRect: bounds,
        scale: landscapeScale.clamp(0.1, 1.0).toDouble(),
      ),
    ];
  }
  final detailWidth = landscapeWidth / _minReadableScale;
  final detailHeight = landscapeHeight / _minReadableScale;
  final tiles = <Rect>[];
  var y = bounds.top;
  while (y < bounds.bottom) {
    var x = bounds.left;
    while (x < bounds.right) {
      tiles.add(
        Rect.fromLTWH(
          x,
          y,
          detailWidth,
          detailHeight,
        ).inflate(_tileOverlap).intersect(bounds),
      );
      x += detailWidth - _tileOverlap;
    }
    y += detailHeight - _tileOverlap;
  }
  final total = tiles.length + 1;
  return [
    NotePdfFlowchartPage(
      mode: NotePdfFlowchartPageMode.overviewAndTiles,
      sourceRect: bounds,
      scale: math.min(
        landscapeWidth / bounds.width,
        landscapeHeight / bounds.height,
      ),
      isOverview: true,
      index: 1,
      total: total,
    ),
    for (var i = 0; i < tiles.length; i += 1)
      NotePdfFlowchartPage(
        mode: NotePdfFlowchartPageMode.overviewAndTiles,
        sourceRect: tiles[i],
        scale: _minReadableScale,
        index: i + 2,
        total: total,
      ),
  ];
}
