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
    required this.paragraphStyles,
    required this.selectionOffset,
  });

  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final int selectionOffset;
}

TextChunkTextEdit textChunkEditFromTextChange(String oldText, String newText) {
  var prefix = 0;
  while (prefix < oldText.length &&
      prefix < newText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix += 1;
  }
  var oldSuffix = oldText.length;
  var newSuffix = newText.length;
  while (oldSuffix > prefix &&
      newSuffix > prefix &&
      oldText.codeUnitAt(oldSuffix - 1) == newText.codeUnitAt(newSuffix - 1)) {
    oldSuffix -= 1;
    newSuffix -= 1;
  }
  return TextChunkTextEdit(
    offset: prefix,
    deleteCount: oldSuffix - prefix,
    insertText: newText.substring(prefix, newSuffix),
  );
}

TextChunkEditResult applyTextChunkTextEdit({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required List<NoteTextParagraphStyle> paragraphStyles,
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
    paragraphStyles: adjustTextChunkParagraphStylesForEdit(
      oldTextLength: text.length,
      paragraphStyles: paragraphStyles,
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
  final adjustedTags = <NoteTextRangeTag>[];
  for (final tag in rangeTags) {
    final adjusted = _adjustRangeForEdit(
      oldTextLength: oldTextLength,
      start: tag.start,
      end: tag.end,
      edit: edit,
    );
    if (adjusted == null) {
      continue;
    }
    final next = NoteTextRangeTag(
      id: tag.id,
      start: adjusted.start,
      end: adjusted.end,
      tag: tag.tag,
      tags: tag.tags,
    );
    if (next.isValid) {
      adjustedTags.add(next);
    }
  }
  return adjustedTags;
}

List<NoteTextParagraphStyle> adjustTextChunkParagraphStylesForEdit({
  required int oldTextLength,
  required List<NoteTextParagraphStyle> paragraphStyles,
  required TextChunkTextEdit edit,
}) {
  final adjustedStyles = <NoteTextParagraphStyle>[];
  for (final style in paragraphStyles) {
    final adjusted = _adjustRangeForEdit(
      oldTextLength: oldTextLength,
      start: style.start,
      end: style.end,
      edit: edit,
    );
    if (adjusted == null) {
      continue;
    }
    final next = style.copyWith(start: adjusted.start, end: adjusted.end);
    if (next.isValid) {
      adjustedStyles.add(next);
    }
  }
  return adjustedStyles;
}

({int start, int end})? _adjustRangeForEdit({
  required int oldTextLength,
  required int start,
  required int end,
  required TextChunkTextEdit edit,
}) {
  final editStart = edit.offset.clamp(0, oldTextLength).toInt();
  final editEnd = (editStart + edit.deleteCount)
      .clamp(editStart, oldTextLength)
      .toInt();
  final delta = edit.insertText.length - (editEnd - editStart);
  final nextTextLength = oldTextLength + delta;
  var nextStart = start;
  var nextEnd = end;
  if (nextEnd <= editStart) {
    // Range is before the edit.
  } else if (nextStart >= editEnd) {
    nextStart += delta;
    nextEnd += delta;
  } else {
    if (nextStart >= editStart) {
      nextStart = editStart + edit.insertText.length;
    }
    nextEnd = (nextEnd + delta).clamp(nextStart, nextTextLength).toInt();
  }
  nextStart = nextStart.clamp(0, nextTextLength).toInt();
  nextEnd = nextEnd.clamp(nextStart, nextTextLength).toInt();
  return nextEnd > nextStart ? (start: nextStart, end: nextEnd) : null;
}
