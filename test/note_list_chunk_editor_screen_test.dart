import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_list_chunk_editor_screen.dart';

void main() {
  testWidgets('list editor autosaves item edits and new rows', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [NoteListItem(id: 'item-1', text: 'Régi')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('note-list-item-item-1')), 'Első pont');
    await tester.pump();
    expect(latest!.listItems.first.text, 'Első pont');

    await tester.tap(find.byKey(const ValueKey('note-list-header-add-item')));
    await tester.pumpAndSettle();
    expect(latest!.listItems, hasLength(2));
    expect(find.byKey(const ValueKey('note-list-add-item')), findsNothing);
  });

  testWidgets('list editor autosaves editable list title', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            title: 'Régi lista',
            listItems: [NoteListItem(id: 'item-1', text: 'Első')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('note-list-title-field')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('note-chunk-title-field')), 'Felszerelés lista');
    await tester.pump();

    expect(latest, isNotNull);
    expect(latest!.title, 'Felszerelés lista');
    expect(latest!.plainText, startsWith('Felszerelés lista'));
  });

  testWidgets('list editor tags the selected item through the shared menu', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [NoteListItem(id: 'item-1', text: 'High flow oxygen')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-list-item-select-item-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-menu-tag-selection')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag-manager-name')), 'súlyos');
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag-manager-name')), 'légzési elégtelenség');
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(
      latest!.listItems.first.tags.map((tag) => tag.label),
      ['súlyos', 'légzési elégtelenség'],
    );
    expect(find.byKey(const ValueKey('note-list-item-tag-pill-item-1-súlyos')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-list-item-tags-item-1')), findsNothing);
  });
}
