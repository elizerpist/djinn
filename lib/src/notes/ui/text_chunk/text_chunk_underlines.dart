import 'package:flutter/material.dart';

import '../../models/note_document.dart';

const double textChunkUnderlineLaneHeight = 4;
const double textChunkUnderlineTopGap = 3;

int textChunkSecondaryUnderlineLaneCount(List<NoteTextRangeTag> rangeTags) {
  var result = 0;
  for (final tag in rangeTags) {
    final lanes = tag.resolvedTags.length - 1;
    if (lanes > result) {
      result = lanes;
    }
  }
  return result < 0 ? 0 : result;
}

class TextChunkSecondaryUnderlineOverlay extends StatelessWidget {
  const TextChunkSecondaryUnderlineOverlay({
    super.key,
    required this.editableKey,
    required this.rangeTags,
    required this.textLength,
  });

  final GlobalKey<EditableTextState> editableKey;
  final List<NoteTextRangeTag> rangeTags;
  final int textLength;

  @override
  Widget build(BuildContext context) {
    if (textChunkSecondaryUnderlineLaneCount(rangeTags) == 0) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        key: const ValueKey('note-text-secondary-underline-overlay'),
        painter: _TextChunkSecondaryUnderlinePainter(
          editableKey: editableKey,
          rangeTags: rangeTags,
          textLength: textLength,
        ),
      ),
    );
  }
}

class _TextChunkSecondaryUnderlinePainter extends CustomPainter {
  const _TextChunkSecondaryUnderlinePainter({
    required this.editableKey,
    required this.rangeTags,
    required this.textLength,
  });

  final GlobalKey<EditableTextState> editableKey;
  final List<NoteTextRangeTag> rangeTags;
  final int textLength;

  @override
  void paint(Canvas canvas, Size size) {
    final renderEditable = editableKey.currentState?.renderEditable;
    if (renderEditable == null || textLength <= 0) {
      return;
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (final rawRangeTag in rangeTags) {
      final rangeTag = rawRangeTag.clampToTextLength(textLength);
      final tags = rangeTag.resolvedTags;
      if (!rangeTag.isValid || tags.length < 2) {
        continue;
      }
      final boxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: rangeTag.start, extentOffset: rangeTag.end),
      );
      for (final box in boxes) {
        if (box.left == box.right) {
          continue;
        }
        for (var lane = 1; lane < tags.length; lane += 1) {
          paint.color = Color(tags[lane].resolvedColorValue);
          final y =
              box.bottom +
              textChunkUnderlineTopGap +
              ((lane - 1) * textChunkUnderlineLaneHeight);
          if (y > size.height) {
            continue;
          }
          canvas.drawLine(Offset(box.left, y), Offset(box.right, y), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TextChunkSecondaryUnderlinePainter oldDelegate) {
    return oldDelegate.rangeTags != rangeTags ||
        oldDelegate.textLength != textLength ||
        oldDelegate.editableKey != editableKey;
  }
}
