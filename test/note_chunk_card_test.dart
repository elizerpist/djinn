import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_chunk_card.dart';

void main() {
  testWidgets('expanded chunk card renders list content and status chips read only', (tester) async {
    const block = NoteBlock(
      id: 'list-1',
      type: NoteBlockType.listItem,
      listItems: [
        NoteListItem(id: 'i1', text: 'Első pont'),
        NoteListItem(id: 'i2', text: 'Alpont', level: 1),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteChunkCard(
            block: block,
            expanded: true,
            dragHandle: const Icon(Icons.drag_indicator),
            onToggleExpanded: () {},
            onOpenEditor: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Kinyerve'), findsOneWidget);
    expect(find.text('Első pont'), findsOneWidget);
    expect(find.text('Alpont'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('expanded flowchart body uses symmetric horizontal padding', (tester) async {
    const block = NoteBlock(
      id: 'flow-1',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(id: 'start', label: 'Kezdés'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteChunkCard(
            block: block,
            expanded: true,
            dragHandle: const Icon(Icons.drag_indicator),
            onToggleExpanded: () {},
            onOpenEditor: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    final padding = tester.widget<Padding>(find.byKey(const ValueKey('note-chunk-expanded-body-flowchart')));
    expect(padding.padding, const EdgeInsets.fromLTRB(8, 10, 8, 2));
  });

}
