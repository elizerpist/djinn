import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

const double _underlineFirstLaneInset = 0.5;
const double _underlineLaneStep = 3.0;

class TextChunkNativeEditingController extends TextEditingController {
  TextChunkNativeEditingController({super.text});

  List<NoteTextRangeTag> _rangeTags = const [];

  void _configureTextChunkPresentation({
    required List<NoteTextRangeTag> rangeTags,
  }) {
    _rangeTags = rangeTags;
  }

  TextSelection normalizeNativeSelection(TextSelection selection) {
    return selection;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    final breakpoints = <int>{0, text.length};
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
    var nextStyle = baseStyle;
    if (tag != null && tag.tags.isNotEmpty) {
      nextStyle = nextStyle.copyWith(
        backgroundColor: Color(
          tag.tags.first.resolvedColorValue,
        ).withValues(alpha: 0.18),
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
    required this.textStyle,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<NoteTextRangeTag> rangeTags;
  final TextRange? activeRange;
  final TextStyle textStyle;

  @override
  State<TextChunkCanvasEditor> createState() => _TextChunkCanvasEditorState();
}

class _TextChunkCanvasEditorState extends State<TextChunkCanvasEditor> {
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  final GlobalKey _layoutKey = GlobalKey();
  String? _lastDebugSignature;
  String? _lastNativeGeometrySignature;
  List<_TagHighlightGeometry> _nativeTagGeometries = const [];

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
        final effectiveTextStyle = widget.textStyle;
        final lineHeight = _lineHeight(context, effectiveTextStyle);
        final selection = _visualSelection();
        final layout = buildTextChunkLayout(
          text: widget.controller.text,
          maxWidth: contentWidth,
          textStyle: effectiveTextStyle,
          textScaler: textScaler,
          rangeTags: widget.rangeTags,
          selection: selection,
        );
        final visualUnderlineSpacerPlans = _underlineSpacerPlans(
          layout.lines,
          lineHeight,
        );
        final underlineSpacerPlans = visualUnderlineSpacerPlans;
        final underlineSpacerHeights = {
          for (final plan in underlineSpacerPlans) plan.lineIndex: plan.height,
        };
        final maxUnderlineSpacerHeight = underlineSpacerHeights.values.fold(
          0.0,
          math.max,
        );
        final nativeLineSpacerHeights = maxUnderlineSpacerHeight > 0
            ? {
                for (final line in layout.lines)
                  line.index: maxUnderlineSpacerHeight,
              }
            : underlineSpacerHeights;
        final nativeLineHeight = lineHeight + maxUnderlineSpacerHeight;
        final fontSize = effectiveTextStyle.fontSize ?? nativeLineHeight;
        final strutStyle = maxUnderlineSpacerHeight > 0 && fontSize > 0
            ? StrutStyle(
                fontSize: fontSize,
                height: nativeLineHeight / fontSize,
                forceStrutHeight: true,
              )
            : null;
        final lineTops = _lineTops(
          layout.lines,
          lineHeight,
          nativeLineSpacerHeights,
        );
        final contentHeight = (layout.lines.length * nativeLineHeight) + 48;
        _configureController();
        _scheduleNativeGeometrySync(baseLineHeight: baseLineHeight);
        _logLayoutUpdate(
          layout: layout,
          selection: selection,
          railLine: null,
          railInsertionOffset: null,
          lineHeight: lineHeight,
          baseLineHeight: baseLineHeight,
          maxUnderlineLanes: maxUnderlineLanes,
          contentWidth: contentWidth,
          contentHeight: contentHeight,
          railHeight: 0,
          railTargetSpacerHeight: 0,
          railNativeSpacerHeight: 0,
          railLineBreakCount: 0,
          railHasLeadingUnderlineSpacer: false,
          railNeedsSoftWrapTerminator: false,
          railNativeLineCount: 0,
          underlineSpacerPlans: underlineSpacerPlans,
          underlineSpacerHeights: nativeLineSpacerHeights,
          totalPlaceholderCount: 0,
          railPlaceholderCount: 0,
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
                key: _layoutKey,
                clipBehavior: Clip.none,
                children: [
                  for (final highlight in _nativeTagGeometries)
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
                        strutStyle: strutStyle,
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
                  for (final line in layout.lines)
                    _LineMarker(
                      line: line,
                      lineHeight: lineHeight,
                      lineTops: lineTops,
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

  int _maxUnderlineLanes() {
    var lanes = 0;
    for (final tag in widget.rangeTags) {
      lanes = math.max(lanes, tag.resolvedTags.length - 1);
    }
    return lanes < 0 ? 0 : lanes;
  }

  void _configureController() {
    final controller = widget.controller;
    if (controller is TextChunkNativeEditingController) {
      controller._configureTextChunkPresentation(rangeTags: widget.rangeTags);
    }
  }

  void _handleNativeSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    if (cause == null) {
      return;
    }
    _showNativeToolbarForSelection(selection, cause);
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

  void _scheduleNativeGeometrySync({required double baseLineHeight}) {
    final signature = [
      widget.controller.text.length,
      widget.controller.selection.start,
      widget.controller.selection.end,
      widget.rangeTags
          .map((tag) => '${tag.id}:${tag.start}-${tag.end}:${tag.tags.length}')
          .join(','),
      baseLineHeight.toStringAsFixed(1),
    ].join('|');
    _lastNativeGeometrySignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastNativeGeometrySignature != signature) {
        return;
      }
      final renderEditable = _findRenderEditable(
        _layoutKey.currentContext?.findRenderObject(),
      );
      final layoutBox = _layoutKey.currentContext?.findRenderObject();
      final renderOrigin = renderEditable?.localToGlobal(Offset.zero);
      final layoutOrigin = layoutBox is RenderBox
          ? layoutBox.localToGlobal(Offset.zero)
          : null;
      final nextGeometries = renderEditable == null || layoutBox is! RenderBox
          ? const <_TagHighlightGeometry>[]
          : _nativeUnderlineGeometries(
              renderEditable: renderEditable,
              layoutBox: layoutBox,
              baseLineHeight: baseLineHeight,
            );
      final nextSignature = _geometrySignature(nextGeometries);
      final currentSignature = _geometrySignature(_nativeTagGeometries);
      final geometryChanged = nextSignature != currentSignature;
      DebugConsole.log(
        '[TextChunkLayout] nativeTagGeometry '
        'rangeTags=${widget.rangeTags.length} '
        'rects=${nextGeometries.length} '
        'railMeasured=0.0 '
        'railTargetSpacer=0.0 '
        'railNativeSpacer=0.0 '
        'railRoundedGap=0.0 '
        'railPlaceholderCount=0 '
        'railLeadingUnderlineSpacer=false '
        'railSoftWrapTerminator=false '
        'railNativeLines=0 '
        'railPlaceholderBreaks=0 '
        'placeholderCount=0 '
        'placeholders=[] '
        'nativeOrigins=editable:${_formatOffset(renderOrigin)},layout:${_formatOffset(layoutOrigin)} '
        'tightTagBoxes=true '
        'changedRail=false changedRects=$geometryChanged '
        'underlineRects=[$nextSignature]',
      );
      if (!geometryChanged) {
        return;
      }
      setState(() {
        if (geometryChanged) {
          _nativeTagGeometries = nextGeometries;
        }
      });
    });
  }

  List<_TagHighlightGeometry> _nativeUnderlineGeometries({
    required RenderEditable renderEditable,
    required RenderBox layoutBox,
    required double baseLineHeight,
  }) {
    final renderEditableOrigin = renderEditable.localToGlobal(Offset.zero);
    final layoutOrigin = layoutBox.localToGlobal(Offset.zero);
    final geometries = <_TagHighlightGeometry>[];
    for (final rawTag in widget.rangeTags) {
      final tag = rawTag.clampToTextLength(widget.controller.text.length);
      final tags = tag.resolvedTags;
      if (!tag.isValid || tags.length <= 1) {
        continue;
      }
      final rects = _nativeRectsForControllerRange(
        renderEditable: renderEditable,
        renderEditableOrigin: renderEditableOrigin,
        layoutOrigin: layoutOrigin,
        start: tag.start,
        end: tag.end,
      );
      for (var rectIndex = 0; rectIndex < rects.length; rectIndex += 1) {
        final rect = rects[rectIndex];
        for (var tagIndex = 1; tagIndex < tags.length; tagIndex += 1) {
          geometries.add(
            _TagHighlightGeometry(
              key: ValueKey(
                'note-text-secondary-underline-${tag.id}-$tagIndex-$rectIndex',
              ),
              color: Color(tags[tagIndex].resolvedColorValue),
              left: rect.left,
              top:
                  rect.top +
                  baseLineHeight -
                  _underlineFirstLaneInset +
                  ((tagIndex - 1) * _underlineLaneStep),
              width: rect.width.clamp(1, double.infinity).toDouble(),
              height: 2,
            ),
          );
        }
      }
    }
    return geometries;
  }

  List<Rect> _nativeRectsForControllerRange({
    required RenderEditable renderEditable,
    required Offset renderEditableOrigin,
    required Offset layoutOrigin,
    required int start,
    required int end,
  }) {
    if (start >= end) {
      return const [];
    }
    final rects = <Rect>[];
    final previousWidthStyle = renderEditable.selectionWidthStyle;
    final previousHeightStyle = renderEditable.selectionHeightStyle;
    renderEditable.selectionWidthStyle = ui.BoxWidthStyle.tight;
    renderEditable.selectionHeightStyle = ui.BoxHeightStyle.tight;
    final List<TextBox> boxes;
    try {
      boxes = renderEditable.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end),
      );
    } finally {
      renderEditable.selectionWidthStyle = previousWidthStyle;
      renderEditable.selectionHeightStyle = previousHeightStyle;
    }
    for (final box in boxes) {
      final rect = box.toRect().shift(renderEditableOrigin - layoutOrigin);
      if (rect.width > 0 && rect.height > 0) {
        rects.add(rect);
      }
    }
    return rects;
  }

  String _geometrySignature(List<_TagHighlightGeometry> geometries) {
    return geometries
        .map(
          (geometry) =>
              '${geometry.key}:'
              '${geometry.left.toStringAsFixed(1)},'
              '${geometry.top.toStringAsFixed(1)},'
              '${geometry.width.toStringAsFixed(1)}x'
              '${geometry.height.toStringAsFixed(1)}',
        )
        .join(' ');
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
    required double railHeight,
    required double railTargetSpacerHeight,
    required double railNativeSpacerHeight,
    required int railLineBreakCount,
    required bool railHasLeadingUnderlineSpacer,
    required bool railNeedsSoftWrapTerminator,
    required int railNativeLineCount,
    required List<_LineSpacerPlan> underlineSpacerPlans,
    required Map<int, double> underlineSpacerHeights,
    required int totalPlaceholderCount,
    required int railPlaceholderCount,
  }) {
    final signature = [
      widget.controller.text.length,
      selection?.start,
      selection?.end,
      railLine?.index,
      railInsertionOffset,
      widget.rangeTags
          .map((tag) => '${tag.id}:${tag.start}-${tag.end}:${tag.tags.length}')
          .join(','),
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
    const double? railTop = null;
    const double? railBottom = null;
    const double? railNativeSpacerBottom = null;
    DebugConsole.log(
      '[TextChunkLayout] textLen=${widget.controller.text.length} '
      'selection=${selection == null ? 'null' : '${selection.start}-${selection.end}'} '
      'selectionDragActive=false '
      'focus=${widget.focusNode.hasFocus} '
      'content=${contentWidth.toStringAsFixed(1)}x${contentHeight.toStringAsFixed(1)} '
      'lineHeight=${lineHeight.toStringAsFixed(1)} '
      'baseLineHeight=${baseLineHeight.toStringAsFixed(1)} '
      'maxUnderlineLanes=$maxUnderlineLanes '
      'lineHeights=[${_lineHeightSummary(layout.lines, lineHeight, underlineSpacerHeights)}] '
      'lines=${layout.lines.length} paragraphs=${layout.paragraphs.length} '
      'railLine=${railLine?.index} railInsert=$railInsertionOffset '
      'railTop=${railTop?.toStringAsFixed(1)} '
      'railBottom=${railBottom?.toStringAsFixed(1)} '
      'railGap=null '
      'railHeight=${railLine == null ? 'null' : railHeight.toStringAsFixed(1)} '
      'railTargetSpacer=${railLine == null ? 'null' : railTargetSpacerHeight.toStringAsFixed(1)} '
      'railNativeSpacer=${railLine == null ? 'null' : railNativeSpacerHeight.toStringAsFixed(1)} '
      'railRoundedGap=${railLine == null ? 'null' : (railNativeSpacerHeight - railTargetSpacerHeight).toStringAsFixed(1)} '
      'railNativeSpacerBottom=${railNativeSpacerBottom?.toStringAsFixed(1)} '
      'railLineBreaks=$railLineBreakCount '
      'railLeadingUnderlineSpacer=$railHasLeadingUnderlineSpacer '
      'railSoftWrapTerminator=$railNeedsSoftWrapTerminator '
      'railNativeLines=$railNativeLineCount '
      'railPlaceholderCount=$railPlaceholderCount '
      'placeholderCount=$totalPlaceholderCount '
      'underlineSpacers=[${_lineSpacerSummary(underlineSpacerPlans)}] '
      'rangeTags=${widget.rangeTags.length} lines=[$lineSummary]',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastDebugSignature != signature) {
        return;
      }
      final renderEditable = _findRenderEditable(context.findRenderObject());
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
      DebugConsole.log(
        '[TextChunkLayout] nativeGeometry '
        'editable=${editableSize.width.toStringAsFixed(1)}x${editableSize.height.toStringAsFixed(1)} '
        'plainLen=${plainText.length} controllerLen=${widget.controller.text.length} '
        'placeholderDelta=${plainText.length - widget.controller.text.length} '
        'nativeSelection=${nativeSelection.start}-${nativeSelection.end} '
        'selectionRect=${_formatRect(selectionRect)} '
        'railRect=null',
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

  double _lineHeight(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.height;
  }
}

class _LineMarker extends StatelessWidget {
  const _LineMarker({
    required this.line,
    required this.lineHeight,
    required this.lineTops,
  });

  final TextChunkVisualLine line;
  final double lineHeight;
  final Map<int, double> lineTops;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _lineTop(line.index, lineTops),
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

class _LineSpacerPlan {
  const _LineSpacerPlan({
    required this.lineIndex,
    required this.offset,
    required this.underlineLanes,
    required this.lineBreakCount,
    required this.height,
  });

  final int lineIndex;
  final int offset;
  final int underlineLanes;
  final int lineBreakCount;
  final double height;
}

double _lineTop(int lineIndex, Map<int, double> lineTops) {
  return lineTops[lineIndex] ?? 0;
}

Map<int, double> _lineTops(
  List<TextChunkVisualLine> lines,
  double baseLineHeight,
  Map<int, double> underlineSpacerHeights,
) {
  var top = 0.0;
  final result = <int, double>{};
  for (final line in lines) {
    result[line.index] = top;
    top += baseLineHeight + (underlineSpacerHeights[line.index] ?? 0);
  }
  return result;
}

List<_LineSpacerPlan> _underlineSpacerPlans(
  List<TextChunkVisualLine> lines,
  double baseLineHeight,
) {
  final plans = <_LineSpacerPlan>[];
  for (final line in lines) {
    final lanes = line.underlineLanes.length;
    final nativeLineCount = _underlineNativeLineCountForLanes(lanes);
    if (nativeLineCount <= 0) {
      continue;
    }
    final offset = _insertionOffsetForLine(line);
    plans.add(
      _LineSpacerPlan(
        lineIndex: line.index,
        offset: offset,
        underlineLanes: lanes,
        lineBreakCount: nativeLineCount,
        height: nativeLineCount * baseLineHeight,
      ),
    );
  }
  return plans;
}

int _underlineNativeLineCountForLanes(int lanes) {
  if (lanes <= 1) {
    return 0;
  }
  return ((lanes - 2) ~/ 4) + 1;
}

int _insertionOffsetForLine(TextChunkVisualLine line) {
  return line.hardBreakAfter ? line.end + 1 : line.end;
}

String _lineHeightSummary(
  List<TextChunkVisualLine> lines,
  double baseLineHeight,
  Map<int, double> underlineSpacerHeights,
) {
  return lines
      .map(
        (line) =>
            '#${line.index}:'
            '${(baseLineHeight + (underlineSpacerHeights[line.index] ?? 0)).toStringAsFixed(1)}'
            '/ul${line.underlineLanes.length}',
      )
      .join(' ');
}

String _lineSpacerSummary(List<_LineSpacerPlan> plans) {
  return plans
      .map(
        (plan) =>
            '#${plan.lineIndex}@${plan.offset}:'
            '${plan.height.toStringAsFixed(1)}'
            '/breaks${plan.lineBreakCount}/ul${plan.underlineLanes}',
      )
      .join(' ');
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

String _formatOffset(Offset? offset) {
  if (offset == null) {
    return 'null';
  }
  return '(${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)})';
}
