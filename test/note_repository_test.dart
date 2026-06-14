import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_item.dart';

void main() {
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
}
