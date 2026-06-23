import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/pdf/note_flowchart_pdf_layout.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';

void main() {
  test('flowchart layout computes bounds and edge routes', () {
    const block = NoteBlock(
      id: 'flow',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(id: 'a', label: 'Start', x: 0, y: 0),
        NoteFlowchartNode(id: 'b', label: 'End', x: 260, y: 160),
      ],
      edges: [
        NoteFlowchartEdge(
          id: 'e1',
          fromNodeId: 'a',
          toNodeId: 'b',
          label: 'go',
        ),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 500,
      portraitHeight: 700,
      landscapeWidth: 760,
      landscapeHeight: 440,
    );

    expect(layout.nodeBoxes.map((box) => box.node.id), containsAll(['a', 'b']));
    expect(layout.edgeRoutes.single.edge.id, 'e1');
    expect(layout.edgeRoutes.single.labelAnchor.dx, greaterThan(0));
    expect(layout.edgeRoutes.single.labelAnchor.dy, greaterThan(0));
    expect(layout.bounds.width, greaterThan(260));
    expect(layout.pages.single.mode, NotePdfFlowchartPageMode.portraitSingle);
  });

  test('wide flowchart chooses landscape when portrait would be too small', () {
    final block = NoteBlock(
      id: 'wide',
      type: NoteBlockType.flowchart,
      nodes: [
        for (var i = 0; i < 4; i += 1)
          NoteFlowchartNode(id: 'n$i', label: 'Node $i', x: i * 220, y: 0),
      ],
      edges: [
        for (var i = 0; i < 3; i += 1)
          NoteFlowchartEdge(
            id: 'e$i',
            fromNodeId: 'n$i',
            toNodeId: 'n${i + 1}',
            label: '',
          ),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 260,
      portraitHeight: 700,
      landscapeWidth: 820,
      landscapeHeight: 420,
    );

    expect(layout.pages.single.mode, NotePdfFlowchartPageMode.landscapeSingle);
  });

  test('very large flowchart chooses overview plus tiled detail pages', () {
    final block = NoteBlock(
      id: 'huge',
      type: NoteBlockType.flowchart,
      nodes: [
        for (var row = 0; row < 3; row += 1)
          for (var col = 0; col < 6; col += 1)
            NoteFlowchartNode(
              id: 'n$row-$col',
              label: 'Node $row $col',
              x: col * 260,
              y: row * 180,
            ),
      ],
    );

    final layout = buildNotePdfFlowchartLayout(
      block,
      portraitWidth: 260,
      portraitHeight: 360,
      landscapeWidth: 420,
      landscapeHeight: 260,
    );

    expect(layout.pages.first.mode, NotePdfFlowchartPageMode.overviewAndTiles);
    expect(layout.pages.length, greaterThan(2));
    expect(layout.pages.where((page) => page.isOverview), hasLength(1));
  });
}
