import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

const double _railReservedHeight = 168;
const int _railPlaceholderCount = 7;

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
      final normalized = offset > insertionOffset
          ? offset - _railPlaceholderCount
          : offset;
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
        children.addAll(_railSpans());
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
      children.addAll(_railSpans());
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

  List<InlineSpan> _railSpans() {
    return [
      for (var index = 0; index < _railPlaceholderCount; index += 1)
        WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: SizedBox(
            key: ValueKey(
              index == 0
                  ? 'note-text-inline-selection-spacer'
                  : 'note-text-inline-selection-spacer-$index',
            ),
            width: _railWidth <= 0 ? 1 : _railWidth,
            height: _railReservedHeight,
          ),
        ),
    ];
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
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  String? _lastDebugSignature;

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
        final maxUnderlineLanes = _maxUnderlineLanes();
        final baseLineHeight = _lineHeight(context, widget.textStyle);
        final effectiveTextStyle = _textStyleWithUnderlineLineHeight(
          widget.textStyle,
          baseLineHeight,
          maxUnderlineLanes,
        );
        final lineHeight = _lineHeight(context, effectiveTextStyle);
        final selection = _visualSelection();
        final layout = buildTextChunkLayout(
          text: widget.controller.text,
          maxWidth: contentWidth,
          textStyle: effectiveTextStyle,
          textScaler: textScaler,
          rangeTags: widget.rangeTags,
          selection: selection,
          railHeight: _railReservedHeight,
        );
        final railLine = _railLine(layout);
        final railInsertionOffset = railLine == null
            ? null
            : (railLine.hardBreakAfter ? railLine.end + 1 : railLine.end);
        final contentHeight =
            (layout.lines.length * lineHeight) +
            (railLine == null ? 0 : _railReservedHeight) +
            48;
        _configureController(
          inlineRail: railLine == null ? null : widget.selectionRail,
          railInsertionOffset: railInsertionOffset,
          railWidth: contentWidth,
        );
        _logLayoutUpdate(
          layout: layout,
          selection: selection,
          railLine: railLine,
          railInsertionOffset: railInsertionOffset,
          lineHeight: lineHeight,
          baseLineHeight: baseLineHeight,
          maxUnderlineLanes: maxUnderlineLanes,
          contentWidth: contentWidth,
          contentHeight: contentHeight,
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
                    baseLineHeight,
                    lineHeight,
                    railLine?.index,
                  ))
                    highlight.toWidget(),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: KeyedSubtree(
                      key: const ValueKey('note-text-input-bridge'),
                      child: EditableText(
                        key: _editableTextKey,
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        style: effectiveTextStyle,
                        cursorColor: const Color(0xFF2563EB),
                        backgroundCursorColor: Colors.transparent,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        showSelectionHandles: true,
                        selectionColor: const Color(0x552563EB),
                        selectionControls: materialTextSelectionHandleControls,
                        contextMenuBuilder: (context, editableTextState) =>
                            AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            ),
                        onSelectionChanged: _handleNativeSelectionChanged,
                      ),
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

  int _maxUnderlineLanes() {
    var lanes = 0;
    for (final tag in widget.rangeTags) {
      lanes = math.max(lanes, tag.resolvedTags.length - 1);
    }
    return lanes < 0 ? 0 : lanes;
  }

  TextStyle _textStyleWithUnderlineLineHeight(
    TextStyle style,
    double baseLineHeight,
    int underlineLanes,
  ) {
    if (underlineLanes <= 0 || baseLineHeight <= 0) {
      return style;
    }
    final extraHeight = 12 + ((underlineLanes - 1) * 4.0);
    final targetLineHeight = baseLineHeight + extraHeight;
    final baseMultiplier = style.height ?? 1.0;
    return style.copyWith(
      height: baseMultiplier * (targetLineHeight / baseLineHeight),
    );
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
    _showNativeToolbarForSelection(normalized, cause);
  }

  void _showNativeToolbarForSelection(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    if (selection.isCollapsed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !widget.focusNode.hasFocus ||
          widget.controller.selection.isCollapsed) {
        return;
      }
      final shown = _editableTextKey.currentState?.showToolbar();
      DebugConsole.log(
        '[TextChunkLayout] nativeToolbar requested '
        'selection=${widget.controller.selection.start}-${widget.controller.selection.end} '
        'cause=$cause shown=$shown',
      );
    });
  }

  void _logLayoutUpdate({
    required TextChunkLayout layout,
    required TextRange? selection,
    required TextChunkVisualLine? railLine,
    required int? railInsertionOffset,
    required double lineHeight,
    required double baseLineHeight,
    required int maxUnderlineLanes,
    required double contentWidth,
    required double contentHeight,
  }) {
    final signature = [
      widget.controller.text.length,
      selection?.start,
      selection?.end,
      railLine?.index,
      railInsertionOffset,
      widget.rangeTags.length,
      contentWidth.toStringAsFixed(1),
    ].join('|');
    if (_lastDebugSignature == signature) {
      return;
    }
    _lastDebugSignature = signature;

    final lineSummary = layout.lines
        .map(
          (line) =>
              '#${line.index}{p=${line.paragraphIndex},'
              'r=${line.start}-${line.end},'
              'indent=${line.indentLevel},'
              'hard=${line.hardBreakAfter},'
              'tags=${line.tagSegments.length},'
              'ul=${line.underlineLanes.length}}',
        )
        .join(' ');
    final railTop = railLine == null
        ? null
        : _railTop(railLine.index, lineHeight);
    final railBottom = railTop == null ? null : railTop + _railReservedHeight;
    DebugConsole.log(
      '[TextChunkLayout] textLen=${widget.controller.text.length} '
      'selection=${selection == null ? 'null' : '${selection.start}-${selection.end}'} '
      'focus=${widget.focusNode.hasFocus} '
      'content=${contentWidth.toStringAsFixed(1)}x${contentHeight.toStringAsFixed(1)} '
      'lineHeight=${lineHeight.toStringAsFixed(1)} '
      'baseLineHeight=${baseLineHeight.toStringAsFixed(1)} '
      'maxUnderlineLanes=$maxUnderlineLanes '
      'lines=${layout.lines.length} paragraphs=${layout.paragraphs.length} '
      'railLine=${railLine?.index} railInsert=$railInsertionOffset '
      'railTop=${railTop?.toStringAsFixed(1)} '
      'railBottom=${railBottom?.toStringAsFixed(1)} '
      'placeholderCount=$_railPlaceholderCount '
      'rangeTags=${widget.rangeTags.length} lines=[$lineSummary]',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastDebugSignature != signature) {
        return;
      }
      final renderEditable = _findRenderEditable(context.findRenderObject());
      final railBox = _findRenderBoxByKey(
        context.findRenderObject(),
        const ValueKey('note-text-inline-selection-rail'),
      );
      if (renderEditable == null) {
        DebugConsole.log(
          '[TextChunkLayout] nativeGeometry renderEditable=null',
        );
        return;
      }
      final plainText = renderEditable.text?.toPlainText() ?? '';
      Rect? selectionRect;
      final nativeSelection = widget.controller.selection;
      if (nativeSelection.isValid && !nativeSelection.isCollapsed) {
        final boxes = renderEditable.getBoxesForSelection(nativeSelection);
        if (boxes.isNotEmpty) {
          selectionRect = boxes
              .map((box) => box.toRect())
              .reduce((value, element) => value.expandToInclude(element));
        }
      }
      final editableSize = renderEditable.size;
      final railRect = railBox == null
          ? null
          : MatrixUtils.transformRect(
              railBox.getTransformTo(renderEditable),
              Offset.zero & railBox.size,
            );
      DebugConsole.log(
        '[TextChunkLayout] nativeGeometry '
        'editable=${editableSize.width.toStringAsFixed(1)}x${editableSize.height.toStringAsFixed(1)} '
        'plainLen=${plainText.length} controllerLen=${widget.controller.text.length} '
        'placeholderDelta=${plainText.length - widget.controller.text.length} '
        'nativeSelection=${nativeSelection.start}-${nativeSelection.end} '
        'selectionRect=${_formatRect(selectionRect)} '
        'railRect=${_formatRect(railRect)}',
      );
    });
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    if (root == null) {
      return null;
    }
    if (root is RenderEditable) {
      return root;
    }
    RenderEditable? result;
    root.visitChildren((child) {
      result ??= _findRenderEditable(child);
    });
    return result;
  }

  RenderBox? _findRenderBoxByKey(RenderObject? root, Key key) {
    if (root == null) {
      return null;
    }
    final debugCreator = root.debugCreator;
    if (root is RenderBox &&
        debugCreator is DebugCreator &&
        debugCreator.element.widget.key == key) {
      return root;
    }
    RenderBox? result;
    root.visitChildren((child) {
      result ??= _findRenderBoxByKey(child, key);
    });
    return result;
  }

  double _lineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }

  List<_TagHighlightGeometry> _tagHighlightGeometries(
    TextChunkLayout layout,
    double baseLineHeight,
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
            height: baseLineHeight,
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
              top: top + baseLineHeight + ((tagIndex - 1) * 4),
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

String _formatRect(Rect? rect) {
  if (rect == null) {
    return 'null';
  }
  return '(${rect.left.toStringAsFixed(1)},'
      '${rect.top.toStringAsFixed(1)},'
      '${rect.width.toStringAsFixed(1)}x'
      '${rect.height.toStringAsFixed(1)})';
}
