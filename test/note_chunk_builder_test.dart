import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/notes/data/note_chunk_builder.dart';
import 'package:djinn/src/notes/models/note_document.dart';

void main() {
  test('builds inspectable chunks from mixed note blocks', () {
    final chunks = const NoteChunkBuilder().build(
      noteId: 'note-1',
      noteTitle: 'Vegyes jegyzet',
      document: NoteDocument(blocks: [
        NoteBlock(
          id: 'p1',
          type: NoteBlockType.paragraph,
          text: 'Első bekezdés.',
        ),
        NoteBlock(
          id: 'p2',
          type: NoteBlockType.paragraph,
          text: 'Második bekezdés.',
        ),
        NoteBlock(
          id: 'l1',
          type: NoteBlockType.listItem,
          listItems: [
            NoteListItem(id: 'i1', text: 'Listaelem', level: 1),
          ],
        ),
        NoteBlock(
          id: 't1',
          type: NoteBlockType.table,
          rows: [
            ['Elem', 'Érték'],
            ['SpO2', '88-92%'],
          ],
        ),
        NoteBlock(
          id: 'f1',
          type: NoteBlockType.flowchart,
          nodes: [
            NoteFlowchartNode(
              id: 'n1',
              label: 'Döntés?',
              shape: AiFlowchartNodeShape.decision,
            ),
            NoteFlowchartNode(id: 'n2', label: 'Oxigén'),
          ],
          edges: [
            NoteFlowchartEdge(
              id: 'e1',
              fromNodeId: 'n1',
              toNodeId: 'n2',
              label: 'Igen',
            ),
          ],
        ),
      ]),
    );

    expect(chunks.map((chunk) => chunk.blockId), ['p1', 'p2', 'l1', 't1', 'f1']);
    expect(chunks.map((chunk) => chunk.kind), [
      NoteChunkKind.text,
      NoteChunkKind.text,
      NoteChunkKind.list,
      NoteChunkKind.table,
      NoteChunkKind.flowchart,
    ]);
    expect(chunks[0].text, contains('Első bekezdés'));
    expect(chunks[1].text, contains('Második bekezdés'));
    expect(chunks[2].text, contains('  Listaelem'));
    expect(chunks[3].text, contains('SpO2 | 88-92%'));
    expect(chunks[4].text, contains('Döntés? -> Oxigén [Igen]'));
    expect(chunks.every((chunk) => chunk.isIndexFresh), isFalse);
    expect(chunks.every((chunk) => chunk.needsReindex), isFalse);
    expect(chunks.every((chunk) => chunk.groupId == 'note-1'), isTrue);
  });
}
