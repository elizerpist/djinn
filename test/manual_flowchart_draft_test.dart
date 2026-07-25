import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/models/manual_flowchart_draft.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('manual flowchart draft becomes structured canonical content', () {
    final block = manualFlowchartBlockFromDraft(
      id: 'flow-1',
      title: 'Döntési folyamat',
      text: [
        '[flowchart]',
        'node start | start_end | Kezdés',
        'node decision | decision | Feltétel teljesül?',
        'node end | start_end | Vége',
        'edge Kezdés -> Feltétel teljesül?',
        'edge Feltétel teljesül? -> Vége [igen]',
      ].join('\n'),
    );

    expect(block.type, NoteBlockType.flowchart);
    expect(block.title, 'Döntési folyamat');
    expect(block.nodes, hasLength(3));
    expect(block.nodes[1].id, 'decision');
    expect(block.nodes[1].shape, AiFlowchartNodeShape.decision);
    expect(block.edges, hasLength(2));
    expect(block.edges[1].fromNodeId, 'decision');
    expect(block.edges[1].toNodeId, 'end');
    expect(block.edges[1].label, 'igen');
  });

  test('plain OCR lines become a sequential structured flowchart', () {
    final block = manualFlowchartBlockFromDraft(
      id: 'flow-2',
      text: 'Első lépés\nMásodik lépés\nHarmadik lépés',
    );

    expect(block.nodes.map((node) => node.label), [
      'Első lépés',
      'Második lépés',
      'Harmadik lépés',
    ]);
    expect(block.edges, hasLength(2));
    expect(block.edges.first.fromNodeId, block.nodes.first.id);
    expect(block.edges.first.toNodeId, block.nodes[1].id);
  });
}
