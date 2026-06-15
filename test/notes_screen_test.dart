import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/ui/notes_screen.dart';

void main() {
  testWidgets('notes screen shows PDF-like folder subheader by default', (tester) async {
    final repository = MemoryNoteRepository();
    await repository.createFolder('Stroke');
    await repository.createDocumentNote(
      title: 'Stroke note',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Stroke tartalom'),
      ]),
    );
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Jegyzetek'), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-folder-bar')), findsOneWidget);
    expect(find.text('Összes'), findsOneWidget);
    expect(find.text('Stroke'), findsOneWidget);
  });

  testWidgets('notes folder bar omits all pill when library has no notes', (tester) async {
    final repository = MemoryNoteRepository();
    await repository.createFolder('Üres mappa');
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes-folder-bar')), findsOneWidget);
    expect(find.text('Összes'), findsNothing);
    expect(find.text('Üres mappa'), findsOneWidget);
  });

  testWidgets('notes FAB opens full-screen note editor route', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(find.byKey(const ValueKey('notes-create-fab')));
    expect(fab.isExtended, isFalse);

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-create-preview-box')), findsNothing);
    expect((await repository.listNotes()).single.type, NoteItemType.document);
  });

  testWidgets('tapping a note opens full-screen note editor route', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Oxigén cél',
      document: const NoteDocument(blocks: [
        NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'SpO2 cél 88-92%'),
      ]),
    );
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('note-box-${note.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-title-field')), findsOneWidget);
  });

  testWidgets('long pressing a note enters note selection mode with note actions', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'COPD kiváltó okok',
      document: const NoteDocument(blocks: [
        NoteBlock(
          id: 'p1',
          type: NoteBlockType.paragraph,
          text: 'Fertőzés és környezeti irritánsok.',
        ),
      ]),
    );
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(ValueKey('note-box-${note.id}')));
    await tester.pumpAndSettle();

    expect(find.text('1 kijelölve'), findsOneWidget);
    expect(find.byKey(ValueKey('note-checkbox-${note.id}')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-share-selected')), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-delete-selected')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('notes-selection-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Szerkesztés'), findsOneWidget);
    expect(find.text('Chunkok megtekintése'), findsOneWidget);
    expect(find.text('Kinyert tartalom audit'), findsOneWidget);
    expect(find.text('Másolat'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kijelölés megszüntetése'));
    await tester.pumpAndSettle();
    expect(find.text('Jegyzetek'), findsOneWidget);
  });

}
