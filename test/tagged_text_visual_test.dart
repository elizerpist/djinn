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

  test('knowledge tags never compute a content background', () {
    final style = noteTaggedTextVisualStyle(tags);

    expect(style.primaryBackground, isNull);
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
    expect(span.children, isNull);
    expect(span.style?.backgroundColor, isNull);
  });

  test('count marker label keeps fixed mode full and clamps adaptive mode', () {
    expect(
      noteTaggedTextCountMarkerLabel(
        mode: NoteTaggedTextCountMarkerMode.fixedCorner,
        tagCount: 4,
        rangeWidth: 8,
      ),
      '4+',
    );
    expect(
      noteTaggedTextCountMarkerLabel(
        mode: NoteTaggedTextCountMarkerMode.adaptiveClamp,
        tagCount: 4,
        rangeWidth: 52,
      ),
      '4+',
    );
    expect(
      noteTaggedTextCountMarkerLabel(
        mode: NoteTaggedTextCountMarkerMode.adaptiveClamp,
        tagCount: 4,
        rangeWidth: 18,
      ),
      '+',
    );
    expect(
      noteTaggedTextCountMarkerLabel(
        mode: NoteTaggedTextCountMarkerMode.adaptiveClamp,
        tagCount: 4,
        rangeWidth: 8,
      ),
      '•',
    );
    expect(
      noteTaggedTextCountMarkerLabel(
        mode: NoteTaggedTextCountMarkerMode.countOnly,
        tagCount: 4,
        rangeWidth: 8,
      ),
      '4',
    );
  });

  test('range tags do not create inline count or color markers', () {
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

    final runs = noteTaggedTextCountMarkerRuns(
      text: text,
      rangeTags: rangeTags,
    );

    expect(runs, isEmpty);
  });
}
