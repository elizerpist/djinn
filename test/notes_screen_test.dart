import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/ui/notes_screen.dart';

void main() {
  testWidgets('notes screen shows folder subheader from header menu', (tester) async {
    final repository = MemoryNoteRepository();
    await repository.createFolder('Stroke');
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Jegyzetek'), findsOneWidget);
    expect(find.text('Stroke'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('notes-header-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mappasáv mutatása'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes-folder-bar')), findsOneWidget);
    expect(find.text('Összes'), findsOneWidget);
    expect(find.text('Stroke'), findsOneWidget);
  });

  testWidgets('notes FAB opens one creation sheet with type dropdown', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-create-type-dropdown')), findsOneWidget);
    expect(find.text('Szöveges chunk'), findsOneWidget);
    expect(find.text('PDF-hez csatolás'), findsNothing);
  });

  testWidgets('notes creation sheet saves a text note', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-create-title-field')), 'Oxigén cél');
    await tester.enterText(find.byKey(const ValueKey('note-create-content-field')), 'SpO2 cél 88-92%');
    await tester.tap(find.byKey(const ValueKey('note-create-save')));
    await tester.pumpAndSettle();

    expect(find.text('Oxigén cél'), findsOneWidget);
    expect((await repository.listNotes()).single.type, NoteItemType.text);
  });

  testWidgets('long pressing a note opens shared validation editor', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createNote(
      type: NoteItemType.text,
      title: 'COPD kiváltó okok',
      plainText: 'Fertőzés és környezeti irritánsok.',
      payloadJson: '{}',
    );
    await tester.pumpWidget(MaterialApp(home: NotesScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(ValueKey('chunk-card-note-${note.id}')));
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
