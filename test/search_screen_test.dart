import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/search/ui/search_screen.dart';

void main() {
  testWidgets('search only returns accepted or edited note knowledge', (
    tester,
  ) async {
    final notes = MemoryNoteRepository();
    final accepted = await notes.createNote(
      type: NoteItemType.text,
      title: 'Oxigén cél',
      plainText: 'SpO2 cél 88-92%',
      payloadJson: '{}',
    );
    await notes.updateNoteValidation(
      accepted.id,
      auditState: LocalAuditState.accepted,
    );
    await notes.createNote(
      type: NoteItemType.text,
      title: 'Nem auditált oxigén',
      plainText: 'Ezt még nem szabad RAG-ben használni.',
      payloadJson: '{}',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SearchScreen(
          knowledgeRepository: KnowledgeDocumentRepository(),
          noteRepository: notes,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'oxigén',
    );
    await tester.pumpAndSettle();

    expect(find.text('Oxigén cél'), findsOneWidget);
    expect(find.text('Nem auditált oxigén'), findsNothing);
  });
}
