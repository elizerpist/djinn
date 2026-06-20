import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk_layout_model.dart';
import 'package:djinn/src/notes/ui/text_chunk_text_editing.dart';

void main() {
  const textStyle = TextStyle(fontSize: 16);

  TextChunkLayout layoutFor(
    String text, {
    double maxWidth = 420,
    List<NoteTextRangeTag> rangeTags = const [],
    TextRange? selection,
  }) {
    return buildTextChunkLayout(
      text: text,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textScaler: TextScaler.noScaling,
      rangeTags: rangeTags,
      selection: selection,
      railHeight: 96,
    );
  }

  test(
    'single enter stays inside one paragraph and double enter splits paragraphs',
    () {
      const text = 'Alpha\nBeta\n\nGamma';
      final layout = layoutFor(text);

      expect(layout.paragraphs, hasLength(2));
      expect(layout.paragraphs[0].range, const TextRange(start: 0, end: 10));
      expect(layout.paragraphs[1].range, const TextRange(start: 12, end: 17));
      expect(layout.lines.map((line) => line.paragraphIndex), [0, 0, 1]);
      expect(
        textChunkParagraphRangeForOffset(text, 8),
        const TextRange(start: 0, end: 10),
      );
      expect(
        textChunkParagraphRangeForOffset(text, 14),
        const TextRange(start: 12, end: 17),
      );
    },
  );

  test(
    'paragraph step changes one paragraph indent and leaves next paragraph unchanged',
    () {
      const text = 'Alpha\nBeta continues inside the same paragraph\n\nGamma';

      final result = applyTextChunkParagraphStep(
        text: text,
        rangeTags: const [],
        offset: 8,
        delta: 1,
        maxWidth: 160,
        textStyle: textStyle,
        textScaler: TextScaler.noScaling,
      );

      expect(
        result.text,
        '  Alpha\nBeta continues inside the same paragraph\n\nGamma',
      );
      final layout = layoutFor(result.text, maxWidth: 160);
      final firstParagraphLines = layout.lines.where(
        (line) => line.paragraphIndex == 0,
      );
      expect(firstParagraphLines.length, greaterThan(2));
      expect(
        firstParagraphLines.every((line) => line.indentLevel == 1),
        isTrue,
      );
      expect(
        layout.lines
            .where((line) => line.paragraphIndex == 1)
            .single
            .indentLevel,
        0,
      );
    },
  );

  test('paragraph outdent removes only the paragraph leading indent', () {
    const text = '  Alpha\nBeta\n\n  Gamma';

    final result = applyTextChunkParagraphStep(
      text: text,
      rangeTags: const [],
      offset: 4,
      delta: -1,
      maxWidth: 300,
      textStyle: textStyle,
      textScaler: TextScaler.noScaling,
    );

    expect(result.text, 'Alpha\nBeta\n\n  Gamma');
  });

  test(
    'multi-line selection anchors the rail below the lowest selected line',
    () {
      const text = 'Alpha\nBeta\nGamma';
      final layout = layoutFor(
        text,
        selection: const TextRange(start: 1, end: 8),
      );

      expect(textChunkRailLineIndexForSelection(layout), 1);
    },
  );

  test('secondary tag lanes belong to the tagged range line only', () {
    const text = 'Alpha\nBeta\nGamma';
    final betaStart = text.indexOf('Beta');
    final layout = layoutFor(
      text,
      rangeTags: [
        NoteTextRangeTag(
          id: 'range-beta',
          start: betaStart,
          end: betaStart + 4,
          tag: const NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.state,
            label: 'primary',
            colorValue: 0xFFDC2626,
          ),
          tags: const [
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'primary',
              colorValue: 0xFFDC2626,
            ),
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'secondary-a',
              colorValue: 0xFF2563EB,
            ),
            NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.custom,
              label: 'secondary-b',
              colorValue: 0xFF059669,
            ),
          ],
        ),
      ],
    );

    final betaLine = layout.lines.singleWhere((line) => line.text == 'Beta');
    expect(betaLine.tagSegments.single.rangeId, 'range-beta');
    expect(betaLine.underlineLanes.map((lane) => lane.tag.label), [
      'secondary-a',
      'secondary-b',
    ]);
    expect(
      layout.lines
          .where((line) => line.text != 'Beta')
          .every((line) => line.underlineLanes.isEmpty),
      isTrue,
    );
  });
}
