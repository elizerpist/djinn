import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/flowchart/ui/mobile_flowchart_viewer.dart';
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

  testWidgets('expanded flowchart preview normalizes legacy node shapes to rounded boxes', (tester) async {
    const block = NoteBlock(
      id: 'flow-1',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(
          id: 'decision',
          label: 'Súlyos?',
          shape: AiFlowchartNodeShape.decision,
          visualShape: NoteFlowchartVisualShape.diamond,
        ),
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

    final viewer = tester.widget<MobileFlowchartViewer>(
      find.byType(MobileFlowchartViewer),
    );
    expect(viewer.data.nodes.single.visualShape, 'rectangle');
  });

  testWidgets('chunk card exposes direct inherited tags and edit action', (tester) async {
    var edited = false;
    const block = NoteBlock(
      id: 'block-1',
      type: NoteBlockType.paragraph,
      text: 'High flow oxygen.',
      tags: [
        NoteKnowledgeTag(
          type: NoteKnowledgeTagTypes.state,
          label: 'súlyos',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteChunkCard(
            block: block,
            expanded: false,
            inheritedTags: const [
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.topic,
                label: 'légzési elégtelenség',
              ),
            ],
            dragHandle: const Icon(Icons.drag_indicator),
            onToggleExpanded: () {},
            onOpenEditor: () {},
            onEditTags: () => edited = true,
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Tag: state súlyos'), findsOneWidget);
    expect(find.text('Örökölt tag: topic légzési elégtelenség'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-chunk-tags-block-1')));
    expect(edited, isTrue);
  });

  testWidgets('paragraph body highlights text range tags read only', (tester) async {
    const block = NoteBlock(
      id: 'block-1',
      type: NoteBlockType.paragraph,
      text: 'Súlyos esetben high flow oxygen.',
      rangeTags: [
        NoteTextRangeTag(
          id: 'range-1',
          start: 0,
          end: 6,
          tag: NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.state,
            label: 'súlyos',
            colorValue: 0xFFDC2626,
          ),
        ),
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

    expect(find.text('Részlet tag: state súlyos'), findsOneWidget);
    final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
    final span = selectable.textSpan;
    expect(span, isNotNull);
    expect(span!.toPlainText(), 'Súlyos esetben high flow oxygen.');
    expect(
      span.children!.where((child) => child.style?.backgroundColor != null),
      isNotEmpty,
    );
  });

}
