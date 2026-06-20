import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

const double _railReservedHeight = 118;

class TextChunkNativeEditingController extends TextEditingController {
  TextChunkNativeEditingController({super.text});

  List<NoteTextRangeTag> _rangeTags = const [];
  Widget? _inlineRail;
  int? _railInsertionOffset;
  double _railWidth = 0;

  void configureTextChunkPresentation({
    required List<NoteTextRangeTag> rangeTags,
    required Widget? inlineRail,
    required int? railInsertionOffset,
    required double railWidth,
  }) {
    _rangeTags = rangeTags;
    _inlineRail = inlineRail;
    _railInsertionOffset = railInsertionOffset;
    _railWidth = railWidth;
  }

  TextSelection normalizeNativeSelection(TextSelection selection) {
    final insertionOffset = _railInsertionOffset;
    if (!selection.isValid || insertionOffset == null || _inlineRail == null) {
      return selection;
    }
    int normalizeOffset(int offset) {
      if (offset < 0) {
        return offset;
      }
      final normalized = offset > insertionOffset ? offset - 1 : offset;
      return normalized.clamp(0, text.length).toInt();
    }

    return TextSelection(
      baseOffset: normalizeOffset(selection.baseOffset),
      extentOffset: normalizeOffset(selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final railOffset = _validRailOffset();
    final breakpoints = <int>{0, text.length};
    if (railOffset != null) {
      breakpoints.add(railOffset);
    }
    for (final rawTag in _rangeTags) {
      final tag = rawTag.clampToTextLength(text.length);
      if (!tag.isValid) {
        continue;
      }
      breakpoints
        ..add(tag.start)
        ..add(tag.end);
    }
    final sortedBreakpoints = breakpoints.toList()..sort();
    final children = <InlineSpan>[];

    for (var index = 0; index < sortedBreakpoints.length - 1; index += 1) {
      final start = sortedBreakpoints[index];
      final end = sortedBreakpoints[index + 1];
      if (railOffset == start) {
        children.add(_railSpan());
      }
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
    if (railOffset == text.length) {
      children.add(_railSpan());
    }

    return TextSpan(style: baseStyle, children: children);
  }

  int? _validRailOffset() {
    final rail = _inlineRail;
    final offset = _railInsertionOffset;
    if (rail == null || offset == null) {
      return null;
    }
    return offset.clamp(0, text.length).toInt();
  }

  InlineSpan _railSpan() {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(
        key: const ValueKey('note-text-inline-selection-spacer'),
        width: _railWidth <= 0 ? 1 : _railWidth,
        height: _railReservedHeight,
      ),
    );
  }

  TextStyle _styleForRange(TextStyle baseStyle, int start, int end) {
    final tag = _tagForRange(start, end);
    if (tag == null || tag.tags.isEmpty) {
      return baseStyle;
    }
    var nextStyle = baseStyle.copyWith(
      backgroundColor: Color(
        tag.tags.first.resolvedColorValue,
      ).withValues(alpha: 0.18),
    );
    if (tag.tags.length > 1) {
      nextStyle = nextStyle.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: Color(tag.tags[1].resolvedColorValue),
        decorationThickness: 1.5,
      );
    }
    return nextStyle;
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

class TextChunkCanvasEditor extends StatefulWidget {
  const TextChunkCanvasEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.rangeTags,
    required this.activeRange,
    required this.selectionRail,
    required this.textStyle,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<NoteTextRangeTag> rangeTags;
  final TextRange? activeRange;
  final Widget? selectionRail;
  final TextStyle textStyle;

  @override
  State<TextChunkCanvasEditor> createState() => _TextChunkCanvasEditorState();
}

class _TextChunkCanvasEditorState extends State<TextChunkCanvasEditor> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleEditorChanged);
    widget.focusNode.addListener(_handleEditorChanged);
  }

  @override
  void didUpdateWidget(TextChunkCanvasEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleEditorChanged);
      widget.controller.addListener(_handleEditorChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleEditorChanged);
      widget.focusNode.addListener(_handleEditorChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleEditorChanged);
    widget.focusNode.removeListener(_handleEditorChanged);
    super.dispose();
  }

  void _handleEditorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = (constraints.maxWidth - 32)
            .clamp(1, double.infinity)
            .toDouble();
        final selection = _visualSelection();
        final layout = buildTextChunkLayout(
          text: widget.controller.text,
          maxWidth: contentWidth,
          textStyle: widget.textStyle,
          textScaler: textScaler,
          rangeTags: widget.rangeTags,
          selection: selection,
          railHeight: _railReservedHeight,
        );
        final railLine = _railLine(layout);
        final railInsertionOffset = railLine?.end;
        final lineHeight = _lineHeight(context);
        final contentHeight =
            (layout.lines.length * lineHeight) +
            (railLine == null ? 0 : _railReservedHeight) +
            48;
        _configureController(
          inlineRail: railLine == null ? null : widget.selectionRail,
          railInsertionOffset: railInsertionOffset,
          railWidth: contentWidth,
        );

        return GestureDetector(
          key: const ValueKey('note-text-chunk-field'),
          behavior: HitTestBehavior.translucent,
          onTap: () => widget.focusNode.requestFocus(),
          child: SingleChildScrollView(
            key: const ValueKey('note-text-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: SizedBox(
              key: const ValueKey('note-text-native-editable-layout'),
              width: contentWidth,
              height: contentHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final highlight in _tagHighlightGeometries(
                    layout,
                    lineHeight,
                    railLine?.index,
                  ))
                    highlight.toWidget(),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: EditableText(
                      key: const ValueKey('note-text-input-bridge'),
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      style: widget.textStyle,
                      cursorColor: const Color(0xFF2563EB),
                      backgroundCursorColor: Colors.transparent,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      selectionColor: const Color(0x552563EB),
                      selectionControls: materialTextSelectionControls,
                      contextMenuBuilder: (context, editableTextState) =>
                          AdaptiveTextSelectionToolbar.editableText(
                            editableTextState: editableTextState,
                          ),
                      onSelectionChanged: _handleNativeSelectionChanged,
                    ),
                  ),
                  if (railLine != null && widget.selectionRail != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _railTop(railLine.index, lineHeight),
                      child: KeyedSubtree(
                        key: const ValueKey('note-text-inline-selection-rail'),
                        child: widget.selectionRail!,
                      ),
                    ),
                  for (final line in layout.lines)
                    _LineMarker(
                      line: line,
                      lineHeight: lineHeight,
                      railLineIndex: railLine?.index,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextRange? _visualSelection() {
    final selection = widget.controller.selection;
    if (selection.isValid) {
      return TextRange(
        start: selection.baseOffset,
        end: selection.extentOffset,
      );
    }
    return widget.activeRange;
  }

  TextChunkVisualLine? _railLine(TextChunkLayout layout) {
    if (widget.selectionRail == null || layout.railLineIndex == null) {
      return null;
    }
    for (final line in layout.lines) {
      if (line.index == layout.railLineIndex) {
        return line;
      }
    }
    return null;
  }

  void _configureController({
    required Widget? inlineRail,
    required int? railInsertionOffset,
    required double railWidth,
  }) {
    final controller = widget.controller;
    if (controller is TextChunkNativeEditingController) {
      controller.configureTextChunkPresentation(
        rangeTags: widget.rangeTags,
        inlineRail: inlineRail,
        railInsertionOffset: railInsertionOffset,
        railWidth: railWidth,
      );
    }
  }

  void _handleNativeSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final controller = widget.controller;
    if (cause == null || controller is! TextChunkNativeEditingController) {
      return;
    }
    final normalized = controller.normalizeNativeSelection(selection);
    if (normalized.baseOffset != selection.baseOffset ||
        normalized.extentOffset != selection.extentOffset) {
      controller.selection = normalized;
    }
  }

  double _lineHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: widget.textStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }

  List<_TagHighlightGeometry> _tagHighlightGeometries(
    TextChunkLayout layout,
    double lineHeight,
    int? railLineIndex,
  ) {
    final geometries = <_TagHighlightGeometry>[];
    for (final line in layout.lines) {
      final pieces = _piecesForLine(line);
      for (final piece in pieces) {
        final segment = piece.segment;
        if (segment == null || segment.tags.isEmpty) {
          continue;
        }
        final left =
            (line.indentLevel * textChunkIndentWidth) +
            _textWidth(line.text.substring(0, piece.start - line.start));
        final width = _textWidth(
          piece.text,
        ).clamp(1, double.infinity).toDouble();
        final top = _lineTop(line.index, lineHeight, railLineIndex);
        geometries.add(
          _TagHighlightGeometry(
            key: ValueKey(
              'note-text-primary-highlight-${segment.rangeId}-${line.index}-${piece.index}',
            ),
            color: Color(
              segment.tags.first.resolvedColorValue,
            ).withValues(alpha: 0.18),
            left: left,
            top: top,
            width: width,
            height: lineHeight,
          ),
        );
        for (var tagIndex = 1; tagIndex < segment.tags.length; tagIndex += 1) {
          geometries.add(
            _TagHighlightGeometry(
              key: ValueKey(
                'note-text-secondary-underline-${segment.rangeId}-$tagIndex-${line.index}-${piece.index}',
              ),
              color: Color(segment.tags[tagIndex].resolvedColorValue),
              left: left,
              top: top + lineHeight + ((tagIndex - 1) * 4),
              width: width,
              height: 2,
            ),
          );
        }
      }
    }
    return geometries;
  }

  List<_LinePiece> _piecesForLine(TextChunkVisualLine line) {
    if (line.start >= line.end) {
      return const [];
    }
    final breakpoints = <int>{line.start, line.end};
    for (final segment in line.tagSegments) {
      breakpoints
        ..add(segment.start)
        ..add(segment.end);
    }
    final sorted = breakpoints.toList()..sort();
    final pieces = <_LinePiece>[];
    for (var index = 0; index < sorted.length - 1; index += 1) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start >= end) {
        continue;
      }
      pieces.add(
        _LinePiece(
          index: pieces.length,
          start: start,
          end: end,
          text: line.text.substring(start - line.start, end - line.start),
          segment: _segmentForRange(line.tagSegments, start, end),
        ),
      );
    }
    return pieces;
  }

  TextChunkTagSegment? _segmentForRange(
    List<TextChunkTagSegment> segments,
    int start,
    int end,
  ) {
    for (final segment in segments) {
      if (segment.start <= start && segment.end >= end) {
        return segment;
      }
    }
    return null;
  }

  double _textWidth(String text) {
    if (text.isEmpty) {
      return 1;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: widget.textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }
}

class _LineMarker extends StatelessWidget {
  const _LineMarker({
    required this.line,
    required this.lineHeight,
    required this.railLineIndex,
  });

  final TextChunkVisualLine line;
  final double lineHeight;
  final int? railLineIndex;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _lineTop(line.index, lineHeight, railLineIndex),
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Padding(
          key: ValueKey('note-text-line-indent-${line.index}'),
          padding: EdgeInsets.only(
            left: line.indentLevel * textChunkIndentWidth,
          ),
          child: SizedBox(
            key: ValueKey('note-text-line-${line.index}'),
            height: lineHeight,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _TagHighlightGeometry {
  const _TagHighlightGeometry({
    required this.key,
    required this.color,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final Key key;
  final Color color;
  final double left;
  final double top;
  final double width;
  final double height;

  Widget toWidget() {
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Container(key: key, width: width, height: height, color: color),
      ),
    );
  }
}

class _LinePiece {
  const _LinePiece({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
    required this.segment,
  });

  final int index;
  final int start;
  final int end;
  final String text;
  final TextChunkTagSegment? segment;
}

double _lineTop(int lineIndex, double lineHeight, int? railLineIndex) {
  final railOffset = railLineIndex != null && lineIndex > railLineIndex
      ? _railReservedHeight
      : 0;
  return (lineIndex * lineHeight) + railOffset;
}

double _railTop(int lineIndex, double lineHeight) {
  return (lineIndex * lineHeight) + lineHeight + 8;
}
