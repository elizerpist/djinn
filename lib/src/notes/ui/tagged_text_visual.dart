import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/note_document.dart';

class NoteTaggedTextVisualStyle {
  const NoteTaggedTextVisualStyle({
    required this.primaryBackground,
    required this.secondaryUnderlineColors,
  });

  final Color? primaryBackground;
  final List<Color> secondaryUnderlineColors;

  double get bottomPadding => secondaryUnderlineColors.length * 4.0;
}

class NoteTaggedTextUnderlineRun {
  const NoteTaggedTextUnderlineRun({
    required this.start,
    required this.end,
    required this.colors,
  });

  final int start;
  final int end;
  final List<Color> colors;
}

NoteTaggedTextVisualStyle noteTaggedTextVisualStyle(
  List<NoteKnowledgeTag> tags,
) {
  if (tags.isEmpty) {
    return const NoteTaggedTextVisualStyle(
      primaryBackground: null,
      secondaryUnderlineColors: [],
    );
  }
  return NoteTaggedTextVisualStyle(
    primaryBackground: Color(tags.first.resolvedColorValue),
    secondaryUnderlineColors: [
      for (final tag in tags.skip(1)) Color(tag.resolvedColorValue),
    ],
  );
}

TextStyle noteTaggedEditableTextStyle(
  List<NoteKnowledgeTag> tags, {
  double alpha = 0.22,
}) {
  final visualStyle = noteTaggedTextVisualStyle(tags);
  final primary = visualStyle.primaryBackground;
  if (primary == null) {
    return const TextStyle();
  }
  return TextStyle(
    backgroundColor: primary.withValues(alpha: alpha),
    fontWeight: FontWeight.w600,
  );
}

TextSpan noteTaggedEditableTextSpan({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  TextStyle? baseStyle,
  double alpha = 0.22,
}) {
  final validTags = _validRangeTags(text, rangeTags);
  if (validTags.isEmpty) {
    return TextSpan(style: baseStyle, text: text);
  }

  final children = <InlineSpan>[];
  var cursor = 0;
  for (final rangeTag in validTags) {
    if (rangeTag.start < cursor) {
      continue;
    }
    if (rangeTag.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, rangeTag.start)));
    }
    final tags = rangeTag.resolvedTags;
    final visualStyle = noteTaggedTextVisualStyle(tags);
    final primary = visualStyle.primaryBackground;
    children.add(
      TextSpan(
        text: text.substring(rangeTag.start, rangeTag.end),
        style: TextStyle(
          backgroundColor: primary?.withValues(alpha: alpha),
          height: _taggedRangeHeight(visualStyle.secondaryUnderlineColors),
        ),
      ),
    );
    cursor = rangeTag.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: children);
}

List<NoteTaggedTextUnderlineRun> noteTaggedTextUnderlineRuns({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
}) {
  final runs = <NoteTaggedTextUnderlineRun>[];
  for (final rangeTag in _validRangeTags(text, rangeTags)) {
    final colors = noteTaggedTextVisualStyle(
      rangeTag.resolvedTags,
    ).secondaryUnderlineColors;
    if (colors.isEmpty) {
      continue;
    }
    runs.add(
      NoteTaggedTextUnderlineRun(
        start: rangeTag.start,
        end: rangeTag.end,
        colors: colors,
      ),
    );
  }
  return runs;
}

class NoteTaggedTextEditingController extends TextEditingController {
  NoteTaggedTextEditingController({
    super.text,
    List<NoteTextRangeTag> rangeTags = const [],
  }) : _rangeTags = rangeTags;

  List<NoteTextRangeTag> _rangeTags;

  List<NoteTextRangeTag> get rangeTags => _rangeTags;

  void setRangeTags(List<NoteTextRangeTag> rangeTags) {
    _rangeTags = rangeTags;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_rangeTags.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    return noteTaggedEditableTextSpan(
      text: text,
      rangeTags: _rangeTags,
      baseStyle: style,
    );
  }
}

class NoteTaggedTextUnderlinePainter extends CustomPainter {
  const NoteTaggedTextUnderlinePainter({
    required this.text,
    required this.runs,
    required this.textStyle,
    required this.textDirection,
    this.scrollOffset = 0,
    this.renderEditable,
    this.editableOffset = Offset.zero,
  });

  final String text;
  final List<NoteTaggedTextUnderlineRun> runs;
  final TextStyle textStyle;
  final TextDirection textDirection;
  final double scrollOffset;
  final RenderEditable? renderEditable;
  final Offset editableOffset;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || runs.isEmpty || size.width <= 0) {
      return;
    }
    final editable = renderEditable;
    if (editable != null && editable.attached) {
      canvas.save();
      canvas.translate(editableOffset.dx, editableOffset.dy);
      for (final run in runs) {
        _paintUnderlineBoxes(
          canvas: canvas,
          boxes: editable.getBoxesForSelection(
            TextSelection(baseOffset: run.start, extentOffset: run.end),
          ),
          colors: run.colors,
          visibleTop: -editableOffset.dy - 8,
          visibleBottom: -editableOffset.dy + size.height + 8,
        );
      }
      canvas.restore();
      return;
    }

    final painter = TextPainter(
      text: _underlineLayoutTextSpan(
        text: text,
        runs: runs,
        baseStyle: textStyle,
      ),
      textDirection: textDirection,
    )..layout(maxWidth: size.width);

    canvas.save();
    canvas.translate(0, -scrollOffset);
    for (final run in runs) {
      _paintUnderlineBoxes(
        canvas: canvas,
        boxes: painter.getBoxesForSelection(
          TextSelection(baseOffset: run.start, extentOffset: run.end),
        ),
        colors: run.colors,
        visibleTop: scrollOffset - 8,
        visibleBottom: scrollOffset + size.height + 8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NoteTaggedTextUnderlinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.runs != runs ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.renderEditable != renderEditable ||
        oldDelegate.editableOffset != editableOffset;
  }
}

void _paintUnderlineBoxes({
  required Canvas canvas,
  required List<TextBox> boxes,
  required List<Color> colors,
  required double visibleTop,
  required double visibleBottom,
}) {
  for (final box in boxes) {
    final left = box.left;
    final width = box.right - box.left;
    if (width <= 0) {
      continue;
    }
    for (var index = 0; index < colors.length; index += 1) {
      final top = box.bottom + 2 + index * 4;
      if (top < visibleTop || top > visibleBottom) {
        continue;
      }
      final rect = Rect.fromLTWH(left, top, width, 2);
      final rrect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(999),
      );
      canvas.drawRRect(rrect, Paint()..color = colors[index]);
    }
  }
}

List<NoteTextRangeTag> _validRangeTags(
  String text,
  List<NoteTextRangeTag> rangeTags,
) {
  return rangeTags
      .map((tag) => tag.clampToTextLength(text.length))
      .where((tag) => tag.isValid)
      .toList()
    ..sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      return startCompare == 0 ? a.end.compareTo(b.end) : startCompare;
    });
}

TextSpan _underlineLayoutTextSpan({
  required String text,
  required List<NoteTaggedTextUnderlineRun> runs,
  TextStyle? baseStyle,
}) {
  if (runs.isEmpty) {
    return TextSpan(style: baseStyle, text: text);
  }
  final sortedRuns = [...runs]
    ..sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      return startCompare == 0 ? a.end.compareTo(b.end) : startCompare;
    });
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final run in sortedRuns) {
    if (run.start < cursor) {
      continue;
    }
    if (run.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, run.start)));
    }
    children.add(
      TextSpan(
        text: text.substring(run.start, run.end),
        style: TextStyle(height: _taggedRangeHeight(run.colors)),
      ),
    );
    cursor = run.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: children);
}

double? _taggedRangeHeight(List<Color> secondaryUnderlineColors) {
  if (secondaryUnderlineColors.isEmpty) {
    return null;
  }
  return 1.34 + secondaryUnderlineColors.length * 0.42;
}

class NoteSecondaryTagUnderlines extends StatelessWidget {
  const NoteSecondaryTagUnderlines({
    super.key,
    required this.tags,
    required this.prefix,
  });

  final List<NoteKnowledgeTag> tags;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final secondaryColors = noteTaggedTextVisualStyle(
      tags,
    ).secondaryUnderlineColors;
    if (secondaryColors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < secondaryColors.length; index += 1)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 1 : 2),
              child: DecoratedBox(
                key: ValueKey('$prefix-secondary-underline-${index + 1}'),
                decoration: BoxDecoration(
                  color: secondaryColors[index],
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: 2),
              ),
            ),
        ],
      ),
    );
  }
}
