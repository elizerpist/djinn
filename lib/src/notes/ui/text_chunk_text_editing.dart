import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

class TextChunkTextEdit {
  const TextChunkTextEdit({
    required this.offset,
    required this.deleteCount,
    required this.insertText,
  });

  final int offset;
  final int deleteCount;
  final String insertText;
}

class TextChunkEditResult {
  const TextChunkEditResult({
    required this.text,
    required this.rangeTags,
    required this.selectionOffset,
  });

  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final int selectionOffset;
}

typedef ParagraphStepResult = TextChunkEditResult;

TextChunkEditResult applyTextChunkTextEdit({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required TextChunkTextEdit edit,
}) {
  final start = edit.offset.clamp(0, text.length).toInt();
  final end = (start + edit.deleteCount).clamp(start, text.length).toInt();
  final nextText = text.replaceRange(start, end, edit.insertText);
  return TextChunkEditResult(
    text: nextText,
    rangeTags: adjustTextChunkRangeTagsForEdit(
      oldTextLength: text.length,
      rangeTags: rangeTags,
      edit: edit,
    ),
    selectionOffset: start + edit.insertText.length,
  );
}

List<NoteTextRangeTag> adjustTextChunkRangeTagsForEdit({
  required int oldTextLength,
  required List<NoteTextRangeTag> rangeTags,
  required TextChunkTextEdit edit,
}) {
  final editStart = edit.offset.clamp(0, oldTextLength).toInt();
  final editEnd = (editStart + edit.deleteCount)
      .clamp(editStart, oldTextLength)
      .toInt();
  final delta = edit.insertText.length - (editEnd - editStart);
  final adjusted = <NoteTextRangeTag>[];
  for (final tag in rangeTags) {
    var start = tag.start;
    var end = tag.end;
    if (end <= editStart) {
      // Before edit.
    } else if (start >= editEnd) {
      start += delta;
      end += delta;
    } else {
      if (start >= editStart) {
        start = editStart + edit.insertText.length;
      }
      end = (end + delta).clamp(start, oldTextLength + delta).toInt();
    }
    final next = NoteTextRangeTag(
      id: tag.id,
      start: start < 0 ? 0 : start,
      end: end < 0 ? 0 : end,
      tag: tag.tag,
      tags: tag.tags,
    );
    if (next.isValid) {
      adjusted.add(next);
    }
  }
  return adjusted;
}

ParagraphStepResult applyTextChunkParagraphStep({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required int offset,
  required int delta,
  required double maxWidth,
  required TextStyle textStyle,
  required TextScaler textScaler,
}) {
  if (text.isEmpty || delta == 0) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset,
    );
  }
  final paragraph = textChunkParagraphRangeForOffset(text, offset);
  if (paragraph == null) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset,
    );
  }
  if (delta > 0) {
    return applyTextChunkTextEdit(
      text: text,
      rangeTags: rangeTags,
      edit: TextChunkTextEdit(
        offset: paragraph.start,
        deleteCount: 0,
        insertText: '  ',
      ),
    );
  }
  final removable = _removableIndent(text, paragraph.start, paragraph.end);
  if (removable == 0) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset,
    );
  }
  return applyTextChunkTextEdit(
    text: text,
    rangeTags: rangeTags,
    edit: TextChunkTextEdit(
      offset: paragraph.start,
      deleteCount: removable,
      insertText: '',
    ),
  );
}

int _removableIndent(String text, int start, int end) {
  var count = 0;
  while (count < 2 &&
      start + count < end &&
      text.codeUnitAt(start + count) == 32) {
    count += 1;
  }
  return count;
}
