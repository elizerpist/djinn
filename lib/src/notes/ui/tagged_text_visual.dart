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
  return const NoteTaggedTextVisualStyle(primaryBackground: null);
}

TextStyle noteTaggedEditableTextStyle(
  List<NoteKnowledgeTag> tags, {
  double alpha = 0.22,
}) {
  return const TextStyle();
}

TextSpan noteTaggedEditableTextSpan({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  TextStyle? baseStyle,
  double alpha = 0.22,
}) {
  return TextSpan(style: baseStyle, text: text);
}

List<NoteTaggedTextCountMarkerRun> noteTaggedTextCountMarkerRuns({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
}) {
  return const [];
}

TextSpan noteTextFillEditableTextSpan({
  required String text,
  required List<NoteTextFill> fills,
  TextStyle? baseStyle,
}) {
  final validFills =
      fills
          .map((fill) => fill.clampToTextLength(text.length))
          .where((fill) => fill.isValid)
          .toList(growable: false)
        ..sort((left, right) {
          final start = left.start.compareTo(right.start);
          return start == 0 ? left.end.compareTo(right.end) : start;
        });
  if (validFills.isEmpty) {
    return TextSpan(style: baseStyle, text: text);
  }

  final children = <InlineSpan>[];
  var cursor = 0;
  for (final fill in validFills) {
    if (fill.start < cursor) {
      continue;
    }
    if (fill.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, fill.start)));
    }
    children.add(
      TextSpan(
        text: text.substring(fill.start, fill.end),
        style: TextStyle(backgroundColor: Color(fill.colorValue)),
      ),
    );
    cursor = fill.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }
  return TextSpan(style: baseStyle, children: children);
}

class NoteRichTextEditingController extends TextEditingController {
  NoteRichTextEditingController({
    super.text,
    List<NoteTextFill> fills = const [],
  }) : _fills = fills;

  List<NoteTextFill> _fills;

  List<NoteTextFill> get fills => _fills;

  void setFills(List<NoteTextFill> fills) {
    if (_sameFills(_fills, fills)) {
      return;
    }
    _fills = fills;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return noteTextFillEditableTextSpan(
      text: text,
      fills: _fills,
      baseStyle: style,
    );
  }
}

bool _sameFills(List<NoteTextFill> left, List<NoteTextFill> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    final a = left[index];
    final b = right[index];
    if (a.id != b.id ||
        a.start != b.start ||
        a.end != b.end ||
        a.colorValue != b.colorValue ||
        a.targetKey != b.targetKey) {
      return false;
    }
  }
  return true;
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
