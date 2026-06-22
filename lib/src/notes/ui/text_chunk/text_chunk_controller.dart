import 'package:flutter/material.dart';

import '../../models/note_document.dart';
import 'text_chunk_underlines.dart';

class TextChunkEditingController extends TextEditingController {
  TextChunkEditingController({super.text});

  List<NoteTextRangeTag> _rangeTags = const [];

  void configureTextChunkPresentation({
    required List<NoteTextRangeTag> rangeTags,
  }) {
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
    final tag = _tagForRange(start, end);
    if (tag == null || tag.resolvedTags.isEmpty) {
      return baseStyle;
    }
    final secondaryLaneCount = tag.resolvedTags.length - 1;
    final fontSize = baseStyle.fontSize;
    final lineHeight = fontSize == null || secondaryLaneCount <= 0
        ? baseStyle.height
        : (fontSize +
                  (secondaryLaneCount * textChunkUnderlineLaneHeight) +
                  textChunkUnderlineTopGap) /
              fontSize;
    return baseStyle.copyWith(
      backgroundColor: Color(
        tag.resolvedTags.first.resolvedColorValue,
      ).withValues(alpha: 0.18),
      height: lineHeight,
    );
  }

  NoteTextRangeTag? _tagForRange(int start, int end) {
    for (final rawTag in _rangeTags) {
      final tag = rawTag.clampToTextLength(text.length);
      if (tag.isValid && tag.start <= start && tag.end >= end) {
        return tag;
      }
    }
    return null;
  }
}
