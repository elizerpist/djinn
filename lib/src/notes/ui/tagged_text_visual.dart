import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/note_document.dart';

class NoteTaggedTextVisualStyle {
  const NoteTaggedTextVisualStyle({required this.primaryBackground});

  final Color? primaryBackground;
}

enum NoteTaggedTextCountMarkerMode { fixedCorner, adaptiveClamp, countOnly }

class NoteTaggedTextCountMarkerRun {
  const NoteTaggedTextCountMarkerRun({
    required this.start,
    required this.end,
    required this.tagCount,
    required this.colorValue,
  });

  final int start;
  final int end;
  final int tagCount;
  final int colorValue;
}

NoteTaggedTextVisualStyle noteTaggedTextVisualStyle(
  List<NoteKnowledgeTag> tags,
) {
  if (tags.isEmpty) {
    return const NoteTaggedTextVisualStyle(primaryBackground: null);
  }
  return NoteTaggedTextVisualStyle(
    primaryBackground: Color(tags.first.resolvedColorValue),
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
        style: TextStyle(backgroundColor: primary?.withValues(alpha: alpha)),
      ),
    );
    cursor = rangeTag.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: children);
}

List<NoteTaggedTextCountMarkerRun> noteTaggedTextCountMarkerRuns({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
}) {
  final runs = <NoteTaggedTextCountMarkerRun>[];
  for (final rangeTag in _validRangeTags(text, rangeTags)) {
    final tagCount = rangeTag.resolvedTags.length;
    if (tagCount <= 1) {
      continue;
    }
    runs.add(
      NoteTaggedTextCountMarkerRun(
        start: rangeTag.start,
        end: rangeTag.end,
        tagCount: tagCount,
        colorValue: rangeTag.resolvedTags.first.resolvedColorValue,
      ),
    );
  }
  return runs;
}

String noteTaggedTextCountMarkerLabel({
  required NoteTaggedTextCountMarkerMode mode,
  required int tagCount,
  required double rangeWidth,
}) {
  if (tagCount <= 1) {
    return '';
  }
  if (mode == NoteTaggedTextCountMarkerMode.countOnly) {
    return '$tagCount';
  }
  if (mode == NoteTaggedTextCountMarkerMode.fixedCorner) {
    return '$tagCount+';
  }
  if (rangeWidth >= 28) {
    return '$tagCount+';
  }
  if (rangeWidth >= 14) {
    return '+';
  }
  return '•';
}

Color noteTaggedTextCountMarkerFillColor(
  NoteTaggedTextCountMarkerRun run, {
  double alpha = 0.72,
}) {
  return Color(run.colorValue).withValues(alpha: alpha);
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

class NoteTaggedTextCountMarkerPainter extends CustomPainter {
  const NoteTaggedTextCountMarkerPainter({
    required this.text,
    required this.runs,
    required this.mode,
    required this.textStyle,
    required this.textDirection,
    this.scrollOffset = 0,
    this.renderEditable,
    this.editableOffset = Offset.zero,
  });

  final String text;
  final List<NoteTaggedTextCountMarkerRun> runs;
  final NoteTaggedTextCountMarkerMode mode;
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
        _paintCountMarkerBoxes(
          canvas: canvas,
          boxes: editable.getBoxesForSelection(
            TextSelection(baseOffset: run.start, extentOffset: run.end),
          ),
          run: run,
          mode: mode,
          textDirection: textDirection,
          visibleTop: -editableOffset.dy - 16,
          visibleBottom: -editableOffset.dy + size.height + 16,
          canvasWidth: size.width - editableOffset.dx,
        );
      }
      canvas.restore();
      return;
    }

    final painter = TextPainter(
      text: TextSpan(style: textStyle, text: text),
      textDirection: textDirection,
    )..layout(maxWidth: size.width);

    canvas.save();
    canvas.translate(0, -scrollOffset);
    for (final run in runs) {
      _paintCountMarkerBoxes(
        canvas: canvas,
        boxes: painter.getBoxesForSelection(
          TextSelection(baseOffset: run.start, extentOffset: run.end),
        ),
        run: run,
        mode: mode,
        textDirection: textDirection,
        visibleTop: scrollOffset - 16,
        visibleBottom: scrollOffset + size.height + 16,
        canvasWidth: size.width,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NoteTaggedTextCountMarkerPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.runs != runs ||
        oldDelegate.mode != mode ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.renderEditable != renderEditable ||
        oldDelegate.editableOffset != editableOffset;
  }
}

void _paintCountMarkerBoxes({
  required Canvas canvas,
  required List<TextBox> boxes,
  required NoteTaggedTextCountMarkerRun run,
  required NoteTaggedTextCountMarkerMode mode,
  required TextDirection textDirection,
  required double visibleTop,
  required double visibleBottom,
  required double canvasWidth,
}) {
  if (boxes.isEmpty) {
    return;
  }
  final box = boxes.first;
  final rangeWidth = box.right - box.left;
  if (rangeWidth <= 0) {
    return;
  }
  final label = noteTaggedTextCountMarkerLabel(
    mode: mode,
    tagCount: run.tagCount,
    rangeWidth: rangeWidth,
  );
  if (label.isEmpty) {
    return;
  }
  final textPainter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: textDirection,
  )..layout();
  final width = (textPainter.width + 8).clamp(12.0, 24.0).toDouble();
  const height = 14.0;
  var left = box.right - width + 2;
  if (mode == NoteTaggedTextCountMarkerMode.adaptiveClamp) {
    final maxLeft = box.right - width;
    final minLeft = box.left;
    left = maxLeft < minLeft ? minLeft : maxLeft;
  }
  final boundedCanvasRight = (canvasWidth - width)
      .clamp(0.0, canvasWidth)
      .toDouble();
  left = left.clamp(0.0, boundedCanvasRight).toDouble();
  final top = box.top - 8;
  if (top < visibleTop || top > visibleBottom) {
    return;
  }
  final rect = Rect.fromLTWH(left, top, width, height);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(999));
  canvas.drawRRect(
    rrect,
    Paint()..color = noteTaggedTextCountMarkerFillColor(run),
  );
  textPainter.paint(
    canvas,
    Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top + (rect.height - textPainter.height) / 2,
    ),
  );
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
