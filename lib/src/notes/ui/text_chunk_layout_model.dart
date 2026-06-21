import 'package:flutter/material.dart';

import '../models/note_document.dart';

const double textChunkIndentWidth = 24;

class TextChunkParagraph {
  const TextChunkParagraph({
    required this.index,
    required this.range,
    required this.indentLevel,
  });

  final int index;
  final TextRange range;
  final int indentLevel;
}

class TextChunkTagSegment {
  const TextChunkTagSegment({
    required this.rangeId,
    required this.start,
    required this.end,
    required this.tags,
  });

  final String rangeId;
  final int start;
  final int end;
  final List<NoteKnowledgeTag> tags;
}

class TextChunkUnderlineLane {
  const TextChunkUnderlineLane({
    required this.rangeId,
    required this.start,
    required this.end,
    required this.tagIndex,
    required this.tag,
  });

  final String rangeId;
  final int start;
  final int end;
  final int tagIndex;
  final NoteKnowledgeTag tag;
}

class TextChunkSelectionSegment {
  const TextChunkSelectionSegment({required this.start, required this.end});

  final int start;
  final int end;
}

class TextChunkVisualLine {
  const TextChunkVisualLine({
    required this.index,
    required this.paragraphIndex,
    required this.lineIndexInParagraph,
    required this.start,
    required this.end,
    required this.text,
    required this.indentLevel,
    required this.hardBreakAfter,
    required this.tagSegments,
    required this.underlineLanes,
    required this.selectionSegments,
  });

  final int index;
  final int paragraphIndex;
  final int lineIndexInParagraph;
  final int start;
  final int end;
  final String text;
  final int indentLevel;
  final bool hardBreakAfter;
  final List<TextChunkTagSegment> tagSegments;
  final List<TextChunkUnderlineLane> underlineLanes;
  final List<TextChunkSelectionSegment> selectionSegments;

  bool overlaps(TextRange range) {
    final startOffset = range.start < range.end ? range.start : range.end;
    final endOffset = range.start < range.end ? range.end : range.start;
    if (start == end) {
      return startOffset <= start && endOffset >= end;
    }
    return start < endOffset && end > startOffset;
  }
}

class TextChunkLayout {
  const TextChunkLayout({
    required this.text,
    required this.paragraphs,
    required this.lines,
    required this.selection,
    required this.railLineIndex,
  });

  final String text;
  final List<TextChunkParagraph> paragraphs;
  final List<TextChunkVisualLine> lines;
  final TextRange? selection;
  final int? railLineIndex;
}

TextChunkLayout buildTextChunkLayout({
  required String text,
  required double maxWidth,
  required TextStyle textStyle,
  required TextScaler textScaler,
  required List<NoteTextRangeTag> rangeTags,
  TextRange? selection,
  double railHeight = 0,
}) {
  final paragraphs = _paragraphsForText(text);
  final lines = <TextChunkVisualLine>[];
  for (
    var paragraphIndex = 0;
    paragraphIndex < paragraphs.length;
    paragraphIndex += 1
  ) {
    final paragraph = paragraphs[paragraphIndex];
    final paragraphLines = _visualLinesForParagraph(
      text: text,
      paragraph: paragraph,
      lineStartIndex: lines.length,
      maxWidth: maxWidth,
      textStyle: textStyle,
      textScaler: textScaler,
      rangeTags: rangeTags,
      selection: selection,
    );
    lines.addAll(paragraphLines);
    final nextParagraphStart = paragraphIndex + 1 < paragraphs.length
        ? paragraphs[paragraphIndex + 1].range.start
        : text.length;
    lines.addAll(
      _separatorLinesAfterParagraph(
        text: text,
        paragraph: paragraph,
        nextParagraphStart: nextParagraphStart,
        hasNextParagraph: paragraphIndex + 1 < paragraphs.length,
        lineStartIndex: lines.length,
        selection: selection,
      ),
    );
  }
  final layout = TextChunkLayout(
    text: text,
    paragraphs: paragraphs,
    lines: lines,
    selection: selection,
    railLineIndex: null,
  );
  return TextChunkLayout(
    text: text,
    paragraphs: paragraphs,
    lines: lines,
    selection: selection,
    railLineIndex: textChunkRailLineIndexForSelection(layout),
  );
}

TextRange? textChunkParagraphRangeForOffset(String text, int offset) {
  if (text.isEmpty) {
    return const TextRange(start: 0, end: 0);
  }
  final normalizedOffset = offset.clamp(0, text.length).toInt();
  for (final paragraph in _paragraphsForText(text)) {
    if (normalizedOffset >= paragraph.range.start &&
        normalizedOffset <= paragraph.range.end) {
      return paragraph.range;
    }
  }
  return _paragraphsForText(text).last.range;
}

int? textChunkRailLineIndexForSelection(TextChunkLayout layout) {
  final selection = layout.selection;
  if (selection == null || layout.lines.isEmpty) {
    return null;
  }
  final start = selection.start < selection.end
      ? selection.start
      : selection.end;
  final end = selection.start < selection.end ? selection.end : selection.start;
  if (start == end) {
    return _lineIndexForOffset(layout.lines, start);
  }
  var result = layout.lines.first.index;
  for (final line in layout.lines) {
    if (line.overlaps(TextRange(start: start, end: end))) {
      result = line.index;
    }
  }
  return result;
}

List<TextChunkParagraph> _paragraphsForText(String text) {
  if (text.isEmpty) {
    return const [
      TextChunkParagraph(
        index: 0,
        range: TextRange(start: 0, end: 0),
        indentLevel: 0,
      ),
    ];
  }
  final paragraphs = <TextChunkParagraph>[];
  var start = 0;
  var index = 0;
  while (start <= text.length) {
    final separator = text.indexOf('\n\n', start);
    final end = separator < 0 ? text.length : separator;
    if (end > start || paragraphs.isEmpty) {
      paragraphs.add(
        TextChunkParagraph(
          index: index,
          range: TextRange(start: start, end: end),
          indentLevel: _indentLevelAt(text, start, end),
        ),
      );
      index += 1;
    }
    if (separator < 0) {
      break;
    }
    start = separator + 2;
    while (start < text.length && text.codeUnitAt(start) == 10) {
      start += 1;
    }
  }
  return paragraphs;
}

int _indentLevelAt(String text, int start, int end) {
  var spaces = 0;
  var offset = start;
  while (offset < end && text.codeUnitAt(offset) == 32) {
    spaces += 1;
    offset += 1;
  }
  return spaces ~/ 2;
}

List<TextChunkVisualLine> _visualLinesForParagraph({
  required String text,
  required TextChunkParagraph paragraph,
  required int lineStartIndex,
  required double maxWidth,
  required TextStyle textStyle,
  required TextScaler textScaler,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange? selection,
}) {
  final lines = <TextChunkVisualLine>[];
  final range = paragraph.range;
  var manualStart = range.start;
  var lineIndexInParagraph = 0;
  while (manualStart <= range.end) {
    final newline = text.indexOf('\n', manualStart);
    final manualEnd = newline < 0 || newline > range.end ? range.end : newline;
    final hasHardBreak = newline >= 0 && newline < range.end;
    final visibleStart = _skipParagraphIndent(text, manualStart, manualEnd);
    final leadingIndentWidth = _textWidth(
      text: text.substring(manualStart, visibleStart),
      textStyle: textStyle,
      textScaler: textScaler,
    );
    final layoutMaxWidth = (maxWidth - leadingIndentWidth)
        .clamp(1, double.infinity)
        .toDouble();
    final visualSegments = _wrapSegment(
      text: text,
      start: visibleStart,
      end: manualEnd,
      maxWidth: layoutMaxWidth,
      textStyle: textStyle,
      textScaler: textScaler,
    );
    for (var i = 0; i < visualSegments.length; i += 1) {
      final segment = visualSegments[i];
      final tagSegments = _tagSegmentsForLine(
        rangeTags: rangeTags,
        textLength: text.length,
        lineStart: segment.start,
        lineEnd: segment.end,
      );
      lines.add(
        TextChunkVisualLine(
          index: lineStartIndex + lines.length,
          paragraphIndex: paragraph.index,
          lineIndexInParagraph: lineIndexInParagraph,
          start: segment.start,
          end: segment.end,
          text: segment.start >= segment.end
              ? ''
              : text.substring(segment.start, segment.end),
          indentLevel: paragraph.indentLevel,
          hardBreakAfter: hasHardBreak && i == visualSegments.length - 1,
          tagSegments: tagSegments,
          underlineLanes: _underlineLanesForSegments(tagSegments),
          selectionSegments: _selectionSegmentsForLine(
            selection: selection,
            lineStart: segment.start,
            lineEnd: segment.end,
          ),
        ),
      );
      lineIndexInParagraph += 1;
    }
    if (!hasHardBreak) {
      break;
    }
    manualStart = manualEnd + 1;
  }
  return lines;
}

List<TextChunkVisualLine> _separatorLinesAfterParagraph({
  required String text,
  required TextChunkParagraph paragraph,
  required int nextParagraphStart,
  required bool hasNextParagraph,
  required int lineStartIndex,
  required TextRange? selection,
}) {
  final gapLength = nextParagraphStart - paragraph.range.end;
  if (gapLength <= 0) {
    return const [];
  }
  final blankCount = hasNextParagraph ? gapLength - 1 : gapLength;
  if (blankCount <= 0) {
    return const [];
  }
  return [
    for (var index = 0; index < blankCount; index += 1)
      _blankLine(
        offset: (paragraph.range.end + 1 + index).clamp(0, text.length).toInt(),
        index: lineStartIndex + index,
        paragraph: paragraph,
        selection: selection,
      ),
  ];
}

TextChunkVisualLine _blankLine({
  required int offset,
  required int index,
  required TextChunkParagraph paragraph,
  required TextRange? selection,
}) {
  return TextChunkVisualLine(
    index: index,
    paragraphIndex: paragraph.index,
    lineIndexInParagraph: 0,
    start: offset,
    end: offset,
    text: '',
    indentLevel: paragraph.indentLevel,
    hardBreakAfter: false,
    tagSegments: const [],
    underlineLanes: const [],
    selectionSegments: _selectionSegmentsForLine(
      selection: selection,
      lineStart: offset,
      lineEnd: offset,
    ),
  );
}

int _skipParagraphIndent(String text, int start, int end) {
  var offset = start;
  while (offset < end && text.codeUnitAt(offset) == 32) {
    offset += 1;
  }
  return offset;
}

double _textWidth({
  required String text,
  required TextStyle textStyle,
  required TextScaler textScaler,
}) {
  if (text.isEmpty) {
    return 0;
  }
  const sentinel = '|';
  final painter = TextPainter(
    text: TextSpan(text: '$text$sentinel', style: textStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout();
  final boxes = painter.getBoxesForSelection(
    TextSelection(baseOffset: text.length, extentOffset: text.length + 1),
  );
  if (boxes.isEmpty) {
    return 0;
  }
  return boxes.first.left;
}

List<({int start, int end})> _wrapSegment({
  required String text,
  required int start,
  required int end,
  required double maxWidth,
  required TextStyle textStyle,
  required TextScaler textScaler,
}) {
  if (start >= end) {
    return [(start: start, end: end)];
  }
  final value = text.substring(start, end);
  final painter = TextPainter(
    text: TextSpan(text: value, style: textStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth <= 0 ? 1 : maxWidth);
  final metrics = painter.computeLineMetrics();
  if (metrics.isEmpty) {
    return [(start: start, end: end)];
  }
  final lines = <({int start, int end})>[];
  for (final metric in metrics) {
    final top = metric.baseline - metric.ascent;
    final bottom = metric.baseline + metric.descent;
    final position = painter.getPositionForOffset(
      Offset(0, (top + bottom) / 2),
    );
    final boundary = painter.getLineBoundary(position);
    final lineStart = start + boundary.start.clamp(0, value.length).toInt();
    final lineEnd = start + boundary.end.clamp(0, value.length).toInt();
    if (lines.isNotEmpty &&
        lines.last.start == lineStart &&
        lines.last.end == lineEnd) {
      continue;
    }
    lines.add((start: lineStart, end: lineEnd));
  }
  return lines.isEmpty ? [(start: start, end: end)] : lines;
}

List<TextChunkTagSegment> _tagSegmentsForLine({
  required List<NoteTextRangeTag> rangeTags,
  required int textLength,
  required int lineStart,
  required int lineEnd,
}) {
  final segments = <TextChunkTagSegment>[];
  for (final rawTag in rangeTags) {
    final tag = rawTag.clampToTextLength(textLength);
    if (!tag.isValid || tag.end <= lineStart || tag.start >= lineEnd) {
      continue;
    }
    segments.add(
      TextChunkTagSegment(
        rangeId: tag.id,
        start: tag.start < lineStart ? lineStart : tag.start,
        end: tag.end > lineEnd ? lineEnd : tag.end,
        tags: tag.resolvedTags,
      ),
    );
  }
  return segments;
}

List<TextChunkUnderlineLane> _underlineLanesForSegments(
  List<TextChunkTagSegment> segments,
) {
  final lanes = <TextChunkUnderlineLane>[];
  for (final segment in segments) {
    for (var index = 1; index < segment.tags.length; index += 1) {
      lanes.add(
        TextChunkUnderlineLane(
          rangeId: segment.rangeId,
          start: segment.start,
          end: segment.end,
          tagIndex: index,
          tag: segment.tags[index],
        ),
      );
    }
  }
  return lanes;
}

List<TextChunkSelectionSegment> _selectionSegmentsForLine({
  required TextRange? selection,
  required int lineStart,
  required int lineEnd,
}) {
  if (selection == null || selection.isCollapsed) {
    return const [];
  }
  final start = selection.start < selection.end
      ? selection.start
      : selection.end;
  final end = selection.start < selection.end ? selection.end : selection.start;
  if (end <= lineStart || start >= lineEnd) {
    return const [];
  }
  return [
    TextChunkSelectionSegment(
      start: start < lineStart ? lineStart : start,
      end: end > lineEnd ? lineEnd : end,
    ),
  ];
}

int _lineIndexForOffset(List<TextChunkVisualLine> lines, int offset) {
  for (final line in lines) {
    if (offset >= line.start && offset <= line.end) {
      return line.index;
    }
  }
  return lines.last.index;
}
