import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
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

  testWidgets('notes FAB opens document slide-up with preview and full editor action', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(find.byKey(const ValueKey('notes-create-fab')));
    expect(fab.isExtended, isFalse);

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-create-preview-box')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-create-open-editor')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-create-type-dropdown')), findsNothing);
  });

  testWidgets('notes creation sheet saves a mixed document note', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-create-title-field')), 'Oxigén cél');
    await tester.tap(find.byKey(const ValueKey('note-create-open-editor')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-document-block-block-1')), 'SpO2 cél 88-92%');
    await tester.tap(find.byKey(const ValueKey('note-document-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-create-save')));
    await tester.pumpAndSettle();

    expect(find.text('Oxigén cél'), findsOneWidget);
    expect((await repository.listNotes()).single.type, NoteItemType.document);
    expect((await repository.listNotes()).single.plainText, 'SpO2 cél 88-92%');
  });

  testWidgets('long pressing a note opens shared validation editor', (tester) async {
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
    expect(find.byKey(const ValueKey('chunk-validation-card')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chunk-validation-text-field')),
      'Fertőzés, levegőszennyezés és terápiahűség romlása.',
    );
    await tester.tap(find.text('Elfogad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chunk-validation-save')));
    await tester.pumpAndSettle();

    final saved = (await repository.listNotes()).single;
    expect(saved.plainText, 'Fertőzés, levegőszennyezés és terápiahűség romlása.');
    expect(saved.auditState, LocalAuditState.accepted);
  });
}
