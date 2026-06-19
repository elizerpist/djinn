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
