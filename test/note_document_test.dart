import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('serializes mixed note document and derives searchable text', () {
    final document = NoteDocument(blocks: [
      const NoteBlock(
        id: 'h1',
        type: NoteBlockType.heading,
        text: 'COPD kiváltó okok',
        level: 1,
      ),
      const NoteBlock(
        id: 'p1',
        type: NoteBlockType.paragraph,
        text: 'A kiváltó ok gyakran infekció.',
      ),
      const NoteBlock(
        id: 'l1',
        type: NoteBlockType.listItem,
        text: 'Virális fertőzés',
        level: 1,
      ),
      const NoteBlock(
        id: 't1',
        type: NoteBlockType.table,
        title: 'Célértékek',
        rows: [
          ['Elem', 'Érték'],
          ['SpO2', '88-92%'],
        ],
      ),
      const NoteBlock(
        id: 'f1',
        type: NoteBlockType.flowchart,
        title: 'Ellátási ág',
        nodes: [
          NoteFlowchartNode(
            id: 'n1',
            label: 'Légzési elégtelenség?',
            shape: AiFlowchartNodeShape.decision,
            order: 1,
          ),
          NoteFlowchartNode(id: 'n2', label: 'Oxigén', order: 2),
        ],
        edges: [
          NoteFlowchartEdge(
            id: 'e1',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            label: 'Igen',
            order: 1,
          ),
        ],
      ),
    ]);

    final reparsed = NoteDocument.fromPayload(document.toPayloadJson());

    expect(reparsed.blocks, hasLength(5));
    expect(reparsed.plainText, contains('COPD kiváltó okok'));
    expect(reparsed.plainText, contains('SpO2 | 88-92%'));
    expect(reparsed.plainText, contains('Légzési elégtelenség?'));
    expect(reparsed.plainText, contains('Igen'));
    expect(reparsed.preview, contains('COPD'));
  });

  test('migrates legacy table payload into a table block', () {
    final document = NoteDocument.fromPayload(
      '{"rows":[["Gyógyszer","Dózis"],["ASA","250 mg"]]}',
      legacyType: 'table',
      legacyText: 'ASA 250 mg',
      title: 'Gyógyszerek',
    );

    expect(document.blocks.single.type, NoteBlockType.table);
    expect(document.plainText, contains('ASA | 250 mg'));
  });

  test('migrates legacy text into one paragraph block', () {
    final document = NoteDocument.fromPayload(
      '{}',
      legacyType: 'text',
      legacyText: 'SpO2 cél 88-92%',
      title: 'Oxigén',
    );

    expect(document.blocks.single.type, NoteBlockType.paragraph);
    expect(document.plainText, 'SpO2 cél 88-92%');
  });
}
