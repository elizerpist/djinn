import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/text_chunk/text_chunk_ranges.dart';

void main() {
  const topicTag = NoteKnowledgeTag(
    type: NoteKnowledgeTagTypes.topic,
    label: 'Alpha',
    colorValue: 0xFF2563EB,
  );

  test('single enter stays in paragraph and double enter starts a new one', () {
    const text = 'Alpha\nBeta\n\nGamma';

    expect(textChunkParagraphRanges(text), [
      const TextRange(start: 0, end: 10),
      const TextRange(start: 12, end: 17),
    ]);
    expect(
      textChunkParagraphRangeForOffset(text, 8),
      const TextRange(start: 0, end: 10),
    );
    expect(
      textChunkParagraphRangeForOffset(text, 14),
      const TextRange(start: 12, end: 17),
    );
  });

  test('range tags move across plain text edits without layout helpers', () {
    const range = NoteTextRangeTag(
      id: 'range-alpha',
      start: 6,
      end: 10,
      tag: topicTag,
    );

    final inserted = adjustTextChunkRangeTagsForEdit(
      oldTextLength: 16,
      rangeTags: const [range],
      edit: const TextChunkTextEdit(
        offset: 0,
        deleteCount: 0,
        insertText: 'Intro ',
      ),
    );
    expect(inserted.single.start, 12);
    expect(inserted.single.end, 16);

    final deleted = adjustTextChunkRangeTagsForEdit(
      oldTextLength: 22,
      rangeTags: inserted,
      edit: const TextChunkTextEdit(offset: 0, deleteCount: 6, insertText: ''),
    );
    expect(deleted.single.start, 6);
    expect(deleted.single.end, 10);
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
