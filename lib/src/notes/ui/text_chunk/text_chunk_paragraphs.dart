import 'package:flutter/material.dart';

import '../../models/note_document.dart';

class TextChunkParagraphLevelResult {
  const TextChunkParagraphLevelResult({
    required this.text,
    required this.paragraphStyles,
    required this.selection,
  });

  final String text;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final TextSelection selection;
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
  return ranges.isEmpty ? const [TextRange(start: 0, end: 0)] : ranges;
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

TextChunkParagraphLevelResult applyTextChunkParagraphLevelStep({
  required String text,
  required List<NoteTextParagraphStyle> paragraphStyles,
  required TextSelection selection,
  required int delta,
}) {
  if (delta == 0 || text.isEmpty) {
    return TextChunkParagraphLevelResult(
      text: text,
      paragraphStyles: paragraphStyles,
      selection: selection,
    );
  }
  final touchedRanges = _touchedParagraphRanges(text, selection);
  if (touchedRanges.isEmpty) {
    return TextChunkParagraphLevelResult(
      text: text,
      paragraphStyles: paragraphStyles,
      selection: selection,
    );
  }
  final touchedKeys = {
    for (final range in touchedRanges) _paragraphKey(range.start, range.end),
  };
  final existingByKey = {
    for (final style in paragraphStyles)
      _paragraphKey(style.start, style.end): style,
  };
  final updatedByKey = <String, NoteTextParagraphStyle>{};
  for (final style in paragraphStyles) {
    final key = _paragraphKey(style.start, style.end);
    if (!touchedKeys.contains(key) && style.isValid) {
      updatedByKey[key] = style;
    }
  }
  for (final range in touchedRanges) {
    final key = _paragraphKey(range.start, range.end);
    final existing = existingByKey[key];
    final currentLevel = existing?.level ?? 0;
    final nextLevel = (currentLevel + delta).clamp(0, 8).toInt();
    if (nextLevel == 0) {
      updatedByKey.remove(key);
      continue;
    }
    updatedByKey[key] = NoteTextParagraphStyle(
      id: existing?.id ?? key,
      start: range.start,
      end: range.end,
      level: nextLevel,
    );
  }
  final updated = updatedByKey.values.toList(growable: false)
    ..sort((a, b) => a.start.compareTo(b.start));
  return TextChunkParagraphLevelResult(
    text: text,
    paragraphStyles: updated,
    selection: selection,
  );
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

List<TextRange> _touchedParagraphRanges(String text, TextSelection selection) {
  final ranges = textChunkParagraphRanges(text);
  if (!selection.isValid) {
    return [textChunkParagraphRangeForOffset(text, 0)];
  }
  if (selection.isCollapsed) {
    return [textChunkParagraphRangeForOffset(text, selection.extentOffset)];
  }
  final start = selection.start < selection.end
      ? selection.start
      : selection.end;
  final end = selection.start < selection.end ? selection.end : selection.start;
  return ranges
      .where((range) => range.start < end && range.end > start)
      .toList(growable: false);
}

String _paragraphKey(int start, int end) => 'paragraph-$start-$end';
