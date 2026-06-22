import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_paragraphs.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_text_edits.dart';

void main() {
  const topicTag = NoteKnowledgeTag(
    type: NoteKnowledgeTagTypes.topic,
    label: 'Topic',
    colorValue: 0xFF2563EB,
  );

  test('single enter stays in paragraph and double enter starts a new one', () {
    expect(textChunkParagraphRanges('Alpha\nBeta\n\nGamma'), [
      const TextRange(start: 0, end: 10),
      const TextRange(start: 12, end: 17),
    ]);
  });

  test('paragraph level step changes metadata without changing text', () {
    const text = 'Alpha\nBeta\n\nGamma';
    final result = applyTextChunkParagraphLevelStep(
      text: text,
      paragraphStyles: const [],
      selection: const TextSelection(baseOffset: 1, extentOffset: 14),
      delta: 1,
    );

    expect(result.text, text);
    expect(
      result.selection,
      const TextSelection(baseOffset: 1, extentOffset: 14),
    );
    expect(result.paragraphStyles, hasLength(2));
    expect(result.paragraphStyles.map((style) => style.level), [1, 1]);
  });

  test('text edits remap paragraph styles and range tags', () {
    const text = 'Alpha\nBeta\n\nGamma';
    const style = NoteTextParagraphStyle(
      id: 'p-2',
      start: 12,
      end: 17,
      level: 2,
    );
    const rangeTag = NoteTextRangeTag(
      id: 'r-1',
      start: 12,
      end: 17,
      tag: topicTag,
    );

    final edit = textChunkEditFromTextChange(
      text,
      'Intro\nAlpha\nBeta\n\nGamma',
    );
    final styles = adjustTextChunkParagraphStylesForEdit(
      oldTextLength: text.length,
      paragraphStyles: const [style],
      edit: edit,
    );
    final tags = adjustTextChunkRangeTagsForEdit(
      oldTextLength: text.length,
      rangeTags: const [rangeTag],
      edit: edit,
    );

    expect(styles.single.start, 18);
    expect(styles.single.end, 23);
    expect(tags.single.start, 18);
    expect(tags.single.end, 23);
  });

  test('target range is explicit selection or tagged word under cursor', () {
    const text = 'Alpha Beta Gamma';
    const rangeTag = NoteTextRangeTag(
      id: 'range-beta',
      start: 6,
      end: 10,
      tag: topicTag,
    );

    expect(
      textChunkTargetRangeForSelection(
        selection: const TextSelection(baseOffset: 12, extentOffset: 2),
        text: text,
        rangeTags: const [rangeTag],
      ),
      const TextRange(start: 2, end: 12),
    );
    expect(
      textChunkTargetRangeForSelection(
        selection: const TextSelection.collapsed(offset: 8),
        text: text,
        rangeTags: const [rangeTag],
      ),
      const TextRange(start: 6, end: 10),
    );
    expect(
      textChunkTargetRangeForSelection(
        selection: const TextSelection.collapsed(offset: 1),
        text: text,
        rangeTags: const [rangeTag],
      ),
      isNull,
    );
  });
}
