import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
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
  final currentIndent = _indentLevelAt(text, paragraph.start, paragraph.end);
  final nextIndent = (currentIndent + delta).clamp(0, 12).toInt();
  if (nextIndent == currentIndent) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: offset,
    );
  }
  final normalized = _removeParagraphSoftWraps(
    text: text,
    rangeTags: rangeTags,
    paragraph: paragraph,
    indentLevel: currentIndent,
    selectionOffset: offset,
  );
  final normalizedParagraph = textChunkParagraphRangeForOffset(
    normalized.text,
    normalized.selectionOffset,
  );
  if (normalizedParagraph == null) {
    return normalized;
  }
  final indentWidth = _indentTextWidth(
    indentLevel: nextIndent,
    textStyle: textStyle,
    textScaler: textScaler,
  );
  final layoutMaxWidth = (maxWidth - indentWidth)
      .clamp(1, double.infinity)
      .toDouble();
  final layout = buildTextChunkLayout(
    text: normalized.text,
    rangeTags: normalized.rangeTags,
    maxWidth: layoutMaxWidth,
    textStyle: textStyle,
    textScaler: textScaler,
  );
  final edits = _paragraphIndentEdits(
    text: normalized.text,
    paragraph: normalizedParagraph,
    layout: layout,
    indentLevel: nextIndent,
  );
  DebugConsole.log(
    '[TextChunkStepReflow] delta=$delta currentIndent=$currentIndent '
    'nextIndent=$nextIndent paragraph=${paragraph.start}-${paragraph.end} '
    'normalizedParagraph=${normalizedParagraph.start}-${normalizedParagraph.end} '
    'maxWidth=${maxWidth.toStringAsFixed(1)} '
    'indentGlyphWidth=${indentWidth.toStringAsFixed(1)} '
    'layoutMaxWidth=${layoutMaxWidth.toStringAsFixed(1)} '
    'rightEdgePolicy=fullWidthMinusIndentGlyphs '
    'layoutLines=${layout.lines.length} indentEdits=${edits.length} '
    'oldLen=${text.length} normalizedLen=${normalized.text.length}',
  );
  if (edits.isEmpty) {
    return TextChunkEditResult(
      text: normalized.text,
      rangeTags: normalized.rangeTags,
      selectionOffset: normalized.selectionOffset,
    );
  }
  return _applyTextChunkTextEdits(
    text: normalized.text,
    rangeTags: normalized.rangeTags,
    edits: edits,
    selectionOffset: normalized.selectionOffset,
  );
}

TextChunkEditResult _removeParagraphSoftWraps({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange paragraph,
  required int indentLevel,
  required int selectionOffset,
}) {
  if (indentLevel <= 0 || paragraph.start >= paragraph.end) {
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: selectionOffset,
    );
  }
  final indent = '  ' * indentLevel;
  final edits = <TextChunkTextEdit>[];
  var offset = paragraph.start;
  while (offset < paragraph.end) {
    final newline = text.indexOf('\n', offset);
    if (newline < 0 || newline >= paragraph.end) {
      break;
    }
    final nextStart = newline + 1;
    if (nextStart + indent.length <= paragraph.end &&
        text.startsWith(indent, nextStart)) {
      final afterOffset = nextStart + indent.length;
      edits.add(
        TextChunkTextEdit(
          offset: newline,
          deleteCount: 1 + indent.length,
          insertText: '',
        ),
      );
      offset = afterOffset;
      continue;
    }
    offset = nextStart;
  }
  if (edits.isEmpty) {
    DebugConsole.log(
      '[TextChunkStepNormalize] paragraph=${paragraph.start}-${paragraph.end} '
      'indent=$indentLevel softWrapEdits=0 oldLen=${text.length} '
      'newLen=${text.length} selection=$selectionOffset->$selectionOffset',
    );
    return TextChunkEditResult(
      text: text,
      rangeTags: rangeTags,
      selectionOffset: selectionOffset,
    );
  }
  edits.sort((a, b) => b.offset.compareTo(a.offset));
  final result = _applyTextChunkTextEdits(
    text: text,
    rangeTags: rangeTags,
    edits: edits,
    selectionOffset: selectionOffset,
  );
  DebugConsole.log(
    '[TextChunkStepNormalize] paragraph=${paragraph.start}-${paragraph.end} '
    'indent=$indentLevel softWrapEdits=${edits.length} '
    'oldLen=${text.length} newLen=${result.text.length} '
    'selection=$selectionOffset->${result.selectionOffset}',
  );
  return result;
}

List<TextChunkTextEdit> _paragraphIndentEdits({
  required String text,
  required TextRange paragraph,
  required TextChunkLayout layout,
  required int indentLevel,
}) {
  final indent = '  ' * indentLevel;
  final edits = <TextChunkTextEdit>[];

  void replaceHardLineIndent(int lineStart) {
    final deleteCount = _leadingSpacesAt(text, lineStart, paragraph.end);
    final currentIndent = text.substring(lineStart, lineStart + deleteCount);
    if (currentIndent == indent) {
      return;
    }
    edits.add(
      TextChunkTextEdit(
        offset: lineStart,
        deleteCount: deleteCount,
        insertText: indent,
      ),
    );
  }

  replaceHardLineIndent(paragraph.start);
  final visualLineStarts = <int>{
    for (final line in layout.lines)
      if (line.paragraphIndex == _paragraphIndexForRange(layout, paragraph) &&
          line.lineIndexInParagraph > 0)
        line.start,
  }.toList()..sort();

  for (final lineStart in visualLineStarts) {
    if (lineStart <= paragraph.start || lineStart > paragraph.end) {
      continue;
    }
    final startsAfterHardBreak =
        lineStart > 0 && text.codeUnitAt(lineStart - 1) == 10;
    if (startsAfterHardBreak) {
      replaceHardLineIndent(lineStart);
      continue;
    }
    if (indent.isEmpty) {
      continue;
    }
    edits.add(
      TextChunkTextEdit(
        offset: lineStart,
        deleteCount: 0,
        insertText: '\n$indent',
      ),
    );
  }

  edits.sort((a, b) => b.offset.compareTo(a.offset));
  return edits;
}

int _paragraphIndexForRange(TextChunkLayout layout, TextRange range) {
  for (final paragraph in layout.paragraphs) {
    if (paragraph.range.start == range.start &&
        paragraph.range.end == range.end) {
      return paragraph.index;
    }
  }
  return layout.paragraphs.isEmpty ? 0 : layout.paragraphs.first.index;
}

TextChunkEditResult _applyTextChunkTextEdits({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required List<TextChunkTextEdit> edits,
  required int selectionOffset,
}) {
  var nextText = text;
  var nextRangeTags = rangeTags;
  var nextSelectionOffset = selectionOffset.clamp(0, text.length).toInt();
  for (final edit in edits) {
    if (edit.offset <= nextSelectionOffset) {
      nextSelectionOffset += edit.insertText.length - edit.deleteCount;
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
    selectionOffset: nextSelectionOffset.clamp(0, nextText.length).toInt(),
  );
}

int _indentLevelAt(String text, int start, int end) {
  return _leadingSpacesAt(text, start, end) ~/ 2;
}

double _indentTextWidth({
  required int indentLevel,
  required TextStyle textStyle,
  required TextScaler textScaler,
}) {
  if (indentLevel <= 0) {
    return 0;
  }
  final painter = TextPainter(
    text: TextSpan(text: '  ' * indentLevel, style: textStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
  return painter.width;
}

int _leadingSpacesAt(String text, int start, int end) {
  var count = 0;
  while (start + count < end && text.codeUnitAt(start + count) == 32) {
    count += 1;
  }
  return count;
}
