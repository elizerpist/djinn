import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_table_editor_screen.dart';

void main() {
  testWidgets('table editor edits cells and adds rows and columns', (tester) async {
    NoteBlock? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteBlock>(
                MaterialPageRoute(
                  builder: (_) => const NoteTableEditorScreen(
                    block: NoteBlock(
                      id: 'table-1',
                      type: NoteBlockType.table,
                      rows: [
                        ['Elem', 'Érték'],
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-0-1')), '88-92%');
    await tester.tap(find.byKey(const ValueKey('note-table-add-column')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-0-2')), 'Cél');
    await tester.tap(find.byKey(const ValueKey('note-table-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-1-0')), 'SpO2');
    await tester.tap(find.byKey(const ValueKey('note-table-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rows, hasLength(2));
    expect(result!.rows.first, ['Elem', '88-92%', 'Cél']);
    expect(result!.rows.last.first, 'SpO2');
  });
}
