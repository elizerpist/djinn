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

    await tester.tap(find.byKey(const ValueKey('note-list-add-item')));
    await tester.pumpAndSettle();
    expect(latest!.listItems, hasLength(2));
  });
}
