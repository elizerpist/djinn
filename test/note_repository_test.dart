import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';

void main() {

  test('creates and updates mixed document notes', () async {
    final repository = MemoryNoteRepository();
    final document = NoteDocument(blocks: [
      const NoteBlock(
        id: 'p1',
        type: NoteBlockType.paragraph,
        text: 'Szabad szöveg.',
      ),
      const NoteBlock(
        id: 'l1',
        type: NoteBlockType.listItem,
        text: 'Listaelem',
        level: 1,
      ),
      const NoteBlock(
        id: 't1',
        type: NoteBlockType.table,
        rows: [
          ['Elem', 'Érték'],
          ['SpO2', '88-92%'],
        ],
      ),
    ]);

    final note = await repository.createDocumentNote(
      title: 'Vegyes jegyzet',
      document: document,
    );

    expect(note.type, NoteItemType.document);
    expect(note.plainText, contains('Szabad szöveg.'));
    expect(note.plainText, contains('SpO2 | 88-92%'));

    final updated = await repository.updateNoteDocument(
      note.id,
      title: 'Frissített jegyzet',
      document: document.copyWith(blocks: [
        ...document.blocks,
        const NoteBlock(
          id: 'p2',
          type: NoteBlockType.paragraph,
          text: 'Új bekezdés.',
        ),
      ]),
      auditState: LocalAuditState.edited,
    );

    expect(updated.title, 'Frissített jegyzet');
    expect(updated.auditState, LocalAuditState.edited);
    expect(updated.document.blocks, hasLength(4));
    expect(updated.plainText, contains('Új bekezdés.'));
  });

  test('notes repository creates folders and filters note items by folder', () async {
    final repository = MemoryNoteRepository();
    final stroke = await repository.createFolder('Stroke');
    await repository.createNote(
      type: NoteItemType.text,
      title: 'RAVE score',
      plainText: 'RACE vagy RAVE elemek',
      payloadJson: '{"text":"RACE vagy RAVE elemek"}',
      folderId: stroke.id,
    );
    await repository.createNote(
      type: NoteItemType.table,
      title: 'Gyógyszerek',
      plainText: 'ASA 250 mg',
      payloadJson: '{"rows":[["ASA","250 mg"]]}',
    );

    expect(await repository.listNotes(folderId: stroke.id), hasLength(1));
    expect(await repository.listNotes(), hasLength(2));
  });

  test('note validation controls rag and citation eligibility', () async {
    final repository = MemoryNoteRepository();
    final note = await repository.createNote(
      type: NoteItemType.text,
      title: 'Oxigén cél',
      plainText: 'SpO2 cél 88-92%',
      payloadJson: '{"text":"SpO2 cél 88-92%"}',
    );

    expect(note.auditState, LocalAuditState.unreviewed);
    expect(note.ragEligible, isFalse);

    final accepted = await repository.updateNoteValidation(
      note.id,
      auditState: LocalAuditState.accepted,
      plainText: 'SpO2 cél 88-92%',
      reason: 'ellenőrizve',
    );
    expect(accepted.ragEligible, isTrue);
    expect(accepted.citationEligible, isTrue);

    final rejected = await repository.updateNoteValidation(
      note.id,
      auditState: LocalAuditState.rejected,
      reason: 'hibás forrás',
    );
    expect(rejected.ragEligible, isFalse);
    expect(rejected.reason, 'hibás forrás');
  });

  test('repository allows empty draft notes and marks note blocks indexed', () async {
    final repository = MemoryNoteRepository();
    final draft = await repository.createDocumentNote(
      title: 'Draft',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: ''),
      ]),
    );

    expect(draft.plainText, isEmpty);

    final updated = await repository.updateNoteDocument(
      draft.id,
      title: 'Draft renamed',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
      ]),
    );

    expect(updated.title, 'Draft renamed');
    expect(updated.document.blocks.single.isIndexFresh, isFalse);

    final indexed = await repository.markNoteBlocksIndexed(updated.id, ['block-1']);

    expect(indexed.document.blocks.single.isIndexFresh, isTrue);
    expect(indexed.document.blocks.single.needsReindex, isFalse);
  });

  test('repository moves notes between folders', () async {
    final repository = MemoryNoteRepository();
    final folder = await repository.createFolder('Eljárásrendek');
    final note = await repository.createDocumentNote(
      title: 'Mozgatás',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
      ]),
    );

    final moved = await repository.moveNoteToFolder(note.id, folder.id);
    expect(moved.folderId, folder.id);

    final cleared = await repository.moveNoteToFolder(note.id, null);
    expect(cleared.folderId, isNull);
  });

}
