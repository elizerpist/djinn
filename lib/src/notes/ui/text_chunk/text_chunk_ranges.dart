import 'package:flutter/material.dart';

import '../../models/note_document.dart';

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

TextChunkEditResult applyTextChunkTextEdit({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required TextChunkTextEdit edit,
}) {
  final start = edit.offset.clamp(0, text.length).toInt();
  final end = (start + edit.deleteCount).clamp(start, text.length).toInt();
  return TextChunkEditResult(
    text: text.replaceRange(start, end, edit.insertText),
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
  final nextTextLength = oldTextLength + delta;
  final adjusted = <NoteTextRangeTag>[];
  for (final tag in rangeTags) {
    var start = tag.start;
    var end = tag.end;
    if (end <= editStart) {
      // Tag is before the edit.
    } else if (start >= editEnd) {
      start += delta;
      end += delta;
    } else {
      if (start >= editStart) {
        start = editStart + edit.insertText.length;
      }
      end = (end + delta).clamp(start, nextTextLength).toInt();
    }
    final next = NoteTextRangeTag(
      id: tag.id,
      start: start.clamp(0, nextTextLength).toInt(),
      end: end.clamp(0, nextTextLength).toInt(),
      tag: tag.tag,
      tags: tag.tags,
    );
    if (next.isValid) {
      adjusted.add(next);
    }
  }
  return adjusted;
}

List<TextRange> textChunkParagraphRanges(String text) {
  if (text.isEmpty) {
    return const [TextRange(start: 0, end: 0)];
  }
  final ranges = <TextRange>[];
  var start = 0;
  while (start <= text.length) {
    final separator = text.indexOf('\n\n', start);
    final end = separator < 0 ? text.length : separator;
    if (end > start || ranges.isEmpty) {
      ranges.add(TextRange(start: start, end: end));
    }
    if (separator < 0) {
      break;
    }
    start = separator + 2;
    while (start < text.length && text.codeUnitAt(start) == 10) {
      start += 1;
    }
  }
  return ranges;
}

TextRange textChunkParagraphRangeForOffset(String text, int offset) {
  final normalizedOffset = offset.clamp(0, text.length).toInt();
  final ranges = textChunkParagraphRanges(text);
  for (final range in ranges) {
    if (normalizedOffset >= range.start && normalizedOffset <= range.end) {
      return range;
    }
  }
  return ranges.last;
}

TextRange? textChunkTargetRangeForSelection({
  required TextSelection selection,
  required String text,
  required List<NoteTextRangeTag> rangeTags,
}) {
  if (!selection.isValid || text.isEmpty) {
    return null;
  }
  if (!selection.isCollapsed) {
    final start = selection.start < selection.end
        ? selection.start
        : selection.end;
    final end = selection.start < selection.end
        ? selection.end
        : selection.start;
    return TextRange(
      start: start.clamp(0, text.length).toInt(),
      end: end.clamp(0, text.length).toInt(),
    );
  }
  final offset = selection.extentOffset.clamp(0, text.length).toInt();
  for (final rawTag in rangeTags) {
    final tag = rawTag.clampToTextLength(text.length);
    if (tag.isValid && offset >= tag.start && offset < tag.end) {
      return TextRange(start: tag.start, end: tag.end);
    }
  }
  return null;
}

bool textChunkRangeHasTag({
  required TextRange range,
  required List<NoteTextRangeTag> rangeTags,
}) {
  return rangeTags.any((tag) => tag.start < range.end && tag.end > range.start);
}

List<NoteKnowledgeTag> textChunkTagsForRange({
  required TextRange? range,
  required List<NoteTextRangeTag> rangeTags,
}) {
  if (range == null) {
    return const [];
  }
  final tags = <NoteKnowledgeTag>[];
  for (final rangeTag in rangeTags) {
    if (rangeTag.start >= range.end || rangeTag.end <= range.start) {
      continue;
    }
    for (final tag in rangeTag.resolvedTags) {
      if (!tags.any((current) => current.metadataText == tag.metadataText)) {
        tags.add(tag);
      }
    }
  }
  return tags;
}

TextChunkEditResult applyTextChunkParagraphMarginStep({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required int offset,
  required int delta,
}) {
  if (text.isEmpty || delta == 0) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset.clamp(0, text.length).toInt(),
    );
  }
  final paragraph = textChunkParagraphRangeForOffset(text, offset);
  final edits = <TextChunkTextEdit>[];
  final indent = '  ';
  var lineStart = paragraph.start;
  while (lineStart <= paragraph.end) {
    final lineEnd = _lineEnd(text, lineStart, paragraph.end);
    if (delta > 0) {
      edits.add(
        TextChunkTextEdit(
          offset: lineStart,
          deleteCount: 0,
          insertText: indent,
        ),
      );
    } else if (lineStart + indent.length <= lineEnd &&
        text.startsWith(indent, lineStart)) {
      edits.add(
        TextChunkTextEdit(
          offset: lineStart,
          deleteCount: indent.length,
          insertText: '',
        ),
      );
    }
    if (lineEnd >= paragraph.end) {
      break;
    }
    lineStart = lineEnd + 1;
  }
  if (edits.isEmpty) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset.clamp(0, text.length).toInt(),
    );
  }
  edits.sort((a, b) => b.offset.compareTo(a.offset));
  var nextText = text;
  var nextRangeTags = rangeTags;
  var nextSelection = offset.clamp(0, text.length).toInt();
  for (final edit in edits) {
    if (edit.offset <= nextSelection) {
      nextSelection += edit.insertText.length - edit.deleteCount;
    }
    final result = applyTextChunkTextEdit(
      text: nextText,
      rangeTags: nextRangeTags,
      edit: edit,
    );
    nextText = result.text;
    nextRangeTags = result.rangeTags;
  }
  return TextChunkEditResult(
    text: nextText,
    rangeTags: nextRangeTags,
    selectionOffset: nextSelection.clamp(0, nextText.length).toInt(),
  );
}

int _lineEnd(String text, int start, int paragraphEnd) {
  final newline = text.indexOf('\n', start);
  if (newline < 0 || newline > paragraphEnd) {
    return paragraphEnd;
  }
  return newline;
}
