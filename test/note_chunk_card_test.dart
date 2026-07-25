import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/flowchart/ui/mobile_flowchart_viewer.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_chunk_card.dart';

void main() {
  testWidgets(
    'expanded chunk card renders list content and status chips read only',
    (tester) async {
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
    },
  );

  testWidgets('expanded flowchart body uses symmetric horizontal padding', (
    tester,
  ) async {
    const block = NoteBlock(
      id: 'flow-1',
      type: NoteBlockType.flowchart,
      nodes: [NoteFlowchartNode(id: 'start', label: 'Kezdés')],
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

    final padding = tester.widget<Padding>(
      find.byKey(const ValueKey('note-chunk-expanded-body-flowchart')),
    );
    expect(padding.padding, const EdgeInsets.fromLTRB(8, 10, 8, 2));
  });

  testWidgets(
    'expanded flowchart preview normalizes legacy node shapes to rounded boxes',
    (tester) async {
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
    },
  );

  testWidgets('expanded flowchart preview renders persisted label fills', (
    tester,
  ) async {
    const block = NoteBlock(
      id: 'flow-filled',
      type: NoteBlockType.flowchart,
      nodes: [
        NoteFlowchartNode(
          id: 'decision',
          label: 'Súlyos állapot?',
          labelFills: [
            NoteTextFill(
              id: 'node-fill',
              start: 0,
              end: 6,
              colorValue: 0xFFFFE082,
              targetKey: 'flowchart-node:decision',
            ),
          ],
        ),
        NoteFlowchartNode(id: 'next', label: 'Teendő'),
      ],
      edges: [
        NoteFlowchartEdge(
          id: 'edge-1',
          fromNodeId: 'decision',
          toNodeId: 'next',
          label: 'Igen',
          labelFills: [
            NoteTextFill(
              id: 'edge-fill',
              start: 0,
              end: 4,
              colorValue: 0xFFC8E6C9,
              targetKey: 'flowchart-edge:edge-1',
            ),
          ],
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
    expect(viewer.data.nodes.first.labelFills.single.colorValue, 0xFFFFE082);
    expect(viewer.data.edges.single.labelFills.single.colorValue, 0xFFC8E6C9);
    final label = tester.widget<SelectableText>(
      find.byKey(const ValueKey('mobile-flowchart-node-label-decision')),
    );
    expect(
      _containsFilledText(
        label.textSpan!,
        text: 'Súlyos',
        color: const Color(0xFFFFE082),
      ),
      isTrue,
    );
    final edgeLabel = tester.widget<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-flowchart-edge-label-edge-1')),
        matching: find.byType(RichText),
      ),
    );
    expect(
      _containsFilledText(
        edgeLabel.text,
        text: 'Igen',
        color: const Color(0xFFC8E6C9),
      ),
      isTrue,
    );
  });

  testWidgets('chunk card shows one unique tag-count badge and edit action', (
    tester,
  ) async {
    var edited = false;
    const block = NoteBlock(
      id: 'block-1',
      type: NoteBlockType.paragraph,
      text: 'High flow oxygen.',
      tags: [
        NoteKnowledgeTag(type: NoteKnowledgeTagTypes.state, label: 'súlyos'),
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

    expect(
      find.byKey(const ValueKey('note-chunk-card-tag-count-block-1')),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('Tag:'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note-chunk-tags-block-1')));
    expect(edited, isTrue);
  });

  testWidgets('range tags count in badge but never highlight card content', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('note-chunk-card-tag-count-block-1')),
      findsOneWidget,
    );
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    expect(selectable.data, 'Súlyos esetben high flow oxygen.');
    expect(selectable.textSpan, isNull);
  });

  testWidgets(
    'canonical mixed NoteChunk renders paragraph list table and fills',
    (tester) async {
      const block = NoteBlock(
        id: 'mixed-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'paragraph-1',
            type: NoteMixedSectionType.paragraph,
            text: 'Kiemelt bekezdés',
            textFills: [
              NoteTextFill(
                id: 'fill-1',
                start: 0,
                end: 7,
                colorValue: 0xFFFFE082,
                targetKey: 'paragraph',
              ),
            ],
          ),
          NoteMixedSection(
            id: 'list-1',
            type: NoteMixedSectionType.list,
            listItems: [NoteListItem(id: 'item-1', text: 'Listaelem')],
          ),
          NoteMixedSection(
            id: 'table-1',
            type: NoteMixedSectionType.table,
            rows: [
              ['Kulcs', 'Érték'],
              ['A', 'B'],
            ],
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

      expect(
        find.byKey(const ValueKey('unified-mixed-paragraph-paragraph-1')),
        findsOneWidget,
      );
      expect(find.text('Listaelem'), findsOneWidget);
      expect(find.text('Kulcs'), findsOneWidget);
      expect(find.text('Érték'), findsOneWidget);
      final paragraph = tester.widget<SelectableText>(
        find.byKey(const ValueKey('unified-mixed-paragraph-paragraph-1')),
      );
      final spans = paragraph.textSpan!.children!.whereType<TextSpan>();
      expect(
        spans.any(
          (span) =>
              span.text == 'Kiemelt' &&
              span.style?.backgroundColor == const Color(0xFFFFE082),
        ),
        isTrue,
      );
    },
  );
}

bool _containsFilledText(
  InlineSpan span, {
  required String text,
  required Color color,
}) {
  if (span is! TextSpan) {
    return false;
  }
  if (span.text == text && span.style?.backgroundColor == color) {
    return true;
  }
  return span.children?.any(
        (child) => _containsFilledText(child, text: text, color: color),
      ) ??
      false;
}
