import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_editor_route.dart';

void main() {
  testWidgets('note editor autosaves title edits immediately', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Régi cím',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(home: NoteEditorRoute(repository: repository, initialNote: note)),
    );

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('note-editor-title-field')), 'Új cím');
    await tester.pump();

    final saved = (await repository.listNotes()).single;
    expect(saved.title, 'Új cím');
  });
}
