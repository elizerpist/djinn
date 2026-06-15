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

  testWidgets('editor FAB expands icon-only chunk actions', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: NoteDocument.empty(),
    );
    await tester.pumpWidget(
      MaterialApp(home: NoteEditorRoute(repository: repository, initialNote: note)),
    );

    await tester.tap(find.byKey(const ValueKey('note-editor-add-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-add-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-add-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-add-table')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-add-flowchart')), findsOneWidget);
    expect(find.text('Szöveg'), findsNothing);
  });

  testWidgets('delete chunk shows undo and restores original position', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Alpha'),
        NoteBlock(id: 'b', type: NoteBlockType.paragraph, text: 'Beta'),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(home: NoteEditorRoute(repository: repository, initialNote: note)),
    );

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-chunk-delete-a')));
    await tester.pump();

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsNothing);
    await tester.tap(find.text('Visszavonás'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsOneWidget);
    final saved = (await repository.listNotes()).single;
    expect(saved.document.blocks.map((block) => block.id), ['a', 'b']);
  });

  testWidgets('tapping a text chunk opens full-screen editor and autosaves edits', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Régi'),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(home: NoteEditorRoute(repository: repository, initialNote: note)),
    );

    await tester.tap(find.byKey(const ValueKey('note-chunk-card-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-text-chunk-editor')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('note-text-chunk-field')), 'Új szöveg');
    await tester.pump();

    final saved = (await repository.listNotes()).single;
    expect(saved.document.blocks.single.text, 'Új szöveg');
  });

}
