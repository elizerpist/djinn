import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/pdf_shared_chunk_adapter.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_shared_chunk_adapter.dart';
import 'package:djinn/src/shared/chunks/shared_chunk.dart';

void main() {
  test('note blocks adapt to shared chunk kinds', () {
    const textBlock = NoteBlock(
      id: 'text-1',
      type: NoteBlockType.paragraph,
      text: 'Legzesi elegtelenseg',
    );
    const tableBlock = NoteBlock(
      id: 'table-1',
      type: NoteBlockType.table,
      rows: [
        ['Allapot', 'Terapia'],
        ['Sulyos', 'O2'],
      ],
    );

    final text = sharedChunkFromNoteBlock(
      noteId: 'note-1',
      noteTitle: 'Legzes',
      block: textBlock,
    );
    final table = sharedChunkFromNoteBlock(
      noteId: 'note-1',
      noteTitle: 'Legzes',
      block: tableBlock,
    );

    expect(text.origin, SharedChunkOrigin.note);
    expect(text.kind, SharedChunkKind.text);
    expect(text.title, 'Szöveg chunk');
    expect(text.preview, contains('Legzesi'));
    expect(table.kind, SharedChunkKind.table);
    expect(table.preview, contains('Sulyos'));
  });

  test('pdf extracted items adapt to shared mode and source metadata', () {
    const item = ExtractedKnowledgeItem(
      id: 'manual-1',
      documentId: 'doc-1',
      sourceType: EvidenceSourceType.tableChunk,
      text: '| A | B |',
      pageNumber: 3,
      pipeline: LocalExtractionPipeline.manual,
      chunkKind: LocalChunkKind.table,
      auditState: LocalAuditState.edited,
      sourceRectJson:
          '{"page":3,"viewport_rect":{"left":10,"top":20,"right":110,"bottom":80}}',
    );

    final shared = sharedChunkFromExtractedItem(
      item,
      filename: 'protocol.pdf',
      isImage: false,
    );

    expect(shared.origin, SharedChunkOrigin.pdf);
    expect(shared.mode, SharedChunkMode.manual);
    expect(shared.kind, SharedChunkKind.table);
    expect(shared.pageLabel, 'Táblázat - 3. oldal');
    expect(shared.hasSourceRect, isTrue);
  });

  test('legacy pdf chunk kinds map into the four shared kinds', () {
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.text),
      SharedChunkKind.text,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.list),
      SharedChunkKind.list,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.table),
      SharedChunkKind.table,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.flowchart),
      SharedChunkKind.flowchart,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.score),
      SharedChunkKind.table,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.imageRegion),
      SharedChunkKind.text,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.visualFact),
      SharedChunkKind.text,
    );
    expect(
      sharedKindFromLocalChunkKind(LocalChunkKind.unknown),
      SharedChunkKind.text,
    );
  });
}
