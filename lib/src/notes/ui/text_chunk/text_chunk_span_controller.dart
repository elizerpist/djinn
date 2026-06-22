import 'package:flutter/material.dart';

import '../../models/note_document.dart';

const double textChunkUnderlineLaneHeight = 4;
const double textChunkUnderlineTopGap = 3;

class TextChunkSpanController extends TextEditingController {
  TextChunkSpanController({super.text});

  List<NoteTextRangeTag> _rangeTags = const [];

  void configureTextChunkSpans({required List<NoteTextRangeTag> rangeTags}) {
    _rangeTags = rangeTags;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_rangeTags.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }
    final breakpoints = <int>{0, text.length};
    for (final rawTag in _rangeTags) {
      final tag = rawTag.clampToTextLength(text.length);
      if (tag.isValid) {
        breakpoints
          ..add(tag.start)
          ..add(tag.end);
      }
    }
    final sortedBreakpoints = breakpoints.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index < sortedBreakpoints.length - 1; index += 1) {
      final start = sortedBreakpoints[index];
      final end = sortedBreakpoints[index + 1];
      if (start >= end) {
        continue;
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: _styleForRange(baseStyle, start, end),
        ),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  TextStyle _styleForRange(TextStyle baseStyle, int start, int end) {
    final tags = _tagsForRange(start, end);
    if (tags.isEmpty) {
      return baseStyle;
    }
    final secondaryLaneCount = tags.length - 1;
    final fontSize = baseStyle.fontSize;
    final lineHeight = fontSize == null || secondaryLaneCount <= 0
        ? baseStyle.height
        : (fontSize +
                  (secondaryLaneCount * textChunkUnderlineLaneHeight) +
                  textChunkUnderlineTopGap) /
              fontSize;
    return baseStyle.copyWith(
      backgroundColor: Color(
        tags.first.resolvedColorValue,
      ).withValues(alpha: 0.18),
      decoration: secondaryLaneCount > 0
          ? TextDecoration.underline
          : baseStyle.decoration,
      decorationColor: secondaryLaneCount > 0
          ? Color(tags[1].resolvedColorValue)
          : baseStyle.decorationColor,
      decorationThickness: secondaryLaneCount > 0
          ? 2
          : baseStyle.decorationThickness,
      height: lineHeight,
    );
  }

  List<NoteKnowledgeTag> _tagsForRange(int start, int end) {
    final tags = <NoteKnowledgeTag>[];
    for (final rawTag in _rangeTags) {
      final rangeTag = rawTag.clampToTextLength(text.length);
      if (!rangeTag.isValid || rangeTag.start >= end || rangeTag.end <= start) {
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
}
