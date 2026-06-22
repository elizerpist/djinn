import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/tagged_text_visual.dart';

void main() {
  const tags = [
    NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.state,
      label: 'sulyos',
      colorValue: 0xFFDC2626,
    ),
    NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.topic,
      label: 'legzes',
      colorValue: 0xFF2563EB,
    ),
    NoteKnowledgeTag(
      type: NoteKnowledgeTagTypes.symbol,
      label: 'DO2',
      colorValue: 0xFF0D9488,
    ),
  ];

  test('computes primary background and one secondary color per extra tag', () {
    final style = noteTaggedTextVisualStyle(tags);

    expect(style.primaryBackground, const Color(0xFFDC2626));
    expect(style.secondaryUnderlineColors, [
      const Color(0xFF2563EB),
      const Color(0xFF0D9488),
    ]);
    expect(style.bottomPadding, 8);
  });

  test('builds editable range spans without changing plain text', () {
    const text = 'Alpha Beta Gamma';
    const rangeTags = [
      NoteTextRangeTag(
        id: 'range-1',
        start: 6,
        end: 10,
        tag: NoteKnowledgeTag(
          type: NoteKnowledgeTagTypes.state,
          label: 'sulyos',
          colorValue: 0xFFDC2626,
        ),
        tags: tags,
      ),
    ];

    final span = noteTaggedEditableTextSpan(
      text: text,
      rangeTags: rangeTags,
      baseStyle: const TextStyle(fontSize: 16),
    );

    expect(span.toPlainText(), text);
    expect(span.children, hasLength(3));
    final taggedSpan = span.children![1] as TextSpan;
    expect(taggedSpan.text, 'Beta');
    expect(
      taggedSpan.style?.backgroundColor,
      const Color(0xFFDC2626).withValues(alpha: 0.22),
    );
    expect(taggedSpan.style?.decoration, isNull);
    expect(taggedSpan.style?.height, greaterThan(1.2));

    final underlineRuns = noteTaggedTextUnderlineRuns(
      text: text,
      rangeTags: rangeTags,
    );
    expect(underlineRuns, hasLength(1));
    expect(underlineRuns.single.start, 6);
    expect(underlineRuns.single.end, 10);
    expect(underlineRuns.single.colors, [
      const Color(0xFF2563EB),
      const Color(0xFF0D9488),
    ]);
  });

  testWidgets('renders one underline widget for each secondary tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoteSecondaryTagUnderlines(
            tags: tags,
            prefix: 'sample',
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('sample-secondary-underline-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('sample-secondary-underline-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('sample-secondary-underline-3')), findsNothing);
  });
}
