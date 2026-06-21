import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

const double _railGap = 8;
const double _defaultRailHeight = 105;
const double _underlineFirstLaneInset = 0.5;
const double _underlineLaneStep = 3.5;
const String _placeholderLineBreakUnit = '\u200B\n';
const String _placeholderIndentUnit = '\u00A0\u00A0';

class _TextChunkNativePlaceholder {
  const _TextChunkNativePlaceholder({
    required this.offset,
    required this.text,
    required this.label,
  });

  final int offset;
  final String text;
  final String label;

  int get length => text.length;
}

class TextChunkNativeEditingController extends TextEditingController {
  TextChunkNativeEditingController({super.text});

  List<NoteTextRangeTag> _rangeTags = const [];
  List<_TextChunkNativePlaceholder> _placeholders = const [];

  void _configureTextChunkPresentation({
    required List<NoteTextRangeTag> rangeTags,
    required List<_TextChunkNativePlaceholder> placeholders,
  }) {
    _rangeTags = rangeTags;
    _placeholders = placeholders;
  }

  TextSelection normalizeNativeSelection(TextSelection selection) {
    final placeholders = _validPlaceholders();
    if (!selection.isValid || placeholders.isEmpty) {
      return selection;
    }
    int normalizeOffset(int offset) {
      if (offset < 0) {
        return offset;
      }
      var removed = 0;
      for (final placeholder in placeholders) {
        final nativeStart = placeholder.offset + removed;
        final nativeEnd = nativeStart + placeholder.length;
        if (offset < nativeStart) {
          break;
        }
        if (offset < nativeEnd) {
          return placeholder.offset.clamp(0, text.length).toInt();
        }
        removed += placeholder.length;
      }
      return (offset - removed).clamp(0, text.length).toInt();
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
    final placeholders = _validPlaceholders();
    final placeholdersByOffset = <int, List<_TextChunkNativePlaceholder>>{};
    for (final placeholder in placeholders) {
      placeholdersByOffset
          .putIfAbsent(
            placeholder.offset,
            () => <_TextChunkNativePlaceholder>[],
          )
          .add(placeholder);
    }
    final breakpoints = <int>{0, text.length};
    for (final placeholder in placeholders) {
      breakpoints.add(placeholder.offset);
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
      children.addAll(
        _placeholderSpans(baseStyle, placeholdersByOffset[start]),
      );
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
    children.addAll(
      _placeholderSpans(baseStyle, placeholdersByOffset[text.length]),
    );

    return TextSpan(style: baseStyle, children: children);
  }

  List<_TextChunkNativePlaceholder> _validPlaceholders() {
    if (_placeholders.isEmpty) {
      return const [];
    }
    final result = [
      for (final placeholder in _placeholders)
        if (placeholder.text.isNotEmpty)
          _TextChunkNativePlaceholder(
            offset: placeholder.offset.clamp(0, text.length).toInt(),
            text: placeholder.text,
            label: placeholder.label,
          ),
    ]..sort((a, b) => a.offset.compareTo(b.offset));
    return result;
  }

  List<InlineSpan> _placeholderSpans(
    TextStyle baseStyle,
    List<_TextChunkNativePlaceholder>? placeholders,
  ) {
    if (placeholders == null || placeholders.isEmpty) {
      return const [];
    }
    return [
      for (final placeholder in placeholders)
        TextSpan(
          text: placeholder.text,
          style: baseStyle.copyWith(
            color: Colors.transparent,
            backgroundColor: Colors.transparent,
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
  final GlobalKey _layoutKey = GlobalKey();
  final GlobalKey _railMeasureKey = GlobalKey();
  String? _lastDebugSignature;
  String? _lastNativeGeometrySignature;
  double _measuredRailHeight = _defaultRailHeight;
  List<_TagHighlightGeometry> _nativeTagGeometries = const [];
  bool _selectionHandleDragActive = false;
  bool _selectionHandleReleaseScheduled = false;
  int? _selectionHandlePointer;

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
    _untrackSelectionHandlePointer();
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
          railHeight: _measuredRailHeight,
        );
        final railLine = _railLine(layout);
        final railInsertionOffset = railLine == null
            ? null
            : _insertionOffsetForLine(railLine);
        final underlineSpacerPlans = _underlineSpacerPlans(
          layout.lines,
          lineHeight,
          trailingIndentSuppressedOffset: railInsertionOffset,
        );
        final underlineSpacerHeights = {
          for (final plan in underlineSpacerPlans) plan.lineIndex: plan.height,
        };
        final railHeight = railLine == null ? 0.0 : _measuredRailHeight;
        final railTargetSpacerHeight = railLine == null
            ? 0.0
            : railHeight + _railGap;
        final railNativeLineCount = railLine == null
            ? 0
            : math.max(1, (railTargetSpacerHeight / lineHeight).ceil());
        final railHasLeadingUnderlineSpacer =
            railInsertionOffset != null &&
            underlineSpacerPlans.any(
              (plan) => plan.offset == railInsertionOffset,
            );
        final railNeedsSoftWrapTerminator =
            railLine != null &&
            !railLine.hardBreakAfter &&
            !railHasLeadingUnderlineSpacer;
        final railLineBreakCount = railLine == null
            ? 0
            : railNativeLineCount + (railNeedsSoftWrapTerminator ? 1 : 0);
        final railNativeSpacerHeight = railNativeLineCount * lineHeight;
        final railPlaceholderText = railLine == null
            ? ''
            : _railPlaceholderTextForLineBreaks(
                railLineBreakCount,
                trailingText: railLine.hardBreakAfter
                    ? ''
                    : _continuationIndentForLine(railLine),
              );
        final railPlaceholderCount = railPlaceholderText.length;
        final occupiedPlaceholderOffsets = <int>{
          for (final plan in underlineSpacerPlans) plan.offset,
          if (railInsertionOffset != null && railPlaceholderText.isNotEmpty)
            railInsertionOffset,
        };
        final softWrapIndentPlaceholders = _softWrapIndentPlaceholders(
          layout.lines,
          occupiedOffsets: occupiedPlaceholderOffsets,
        );
        final nativePlaceholders = [
          for (final plan in underlineSpacerPlans)
            _TextChunkNativePlaceholder(
              offset: plan.offset,
              text: plan.placeholderText,
              label:
                  'underline-line-${plan.lineIndex}-lanes-${plan.underlineLanes}',
            ),
          ...softWrapIndentPlaceholders,
          if (railLine != null && railPlaceholderText.isNotEmpty)
            _TextChunkNativePlaceholder(
              offset: railInsertionOffset ?? 0,
              text: railPlaceholderText,
              label: 'rail-line-${railLine.index}',
            ),
        ];
        final underlineNativeSpacerHeight = underlineSpacerPlans.fold<double>(
          0,
          (total, plan) => total + plan.height,
        );
        final totalPlaceholderCount = nativePlaceholders.fold<int>(
          0,
          (total, placeholder) => total + placeholder.length,
        );
        final lineTops = _lineTops(
          layout.lines,
          lineHeight,
          underlineSpacerHeights,
        );
        final contentHeight =
            (layout.lines.length * lineHeight) +
            underlineNativeSpacerHeight +
            railNativeSpacerHeight +
            48;
        _configureController(placeholders: nativePlaceholders);
        _scheduleNativeGeometrySync(
          railLine: railLine,
          railInsertionOffset: railInsertionOffset,
          nativePlaceholders: nativePlaceholders,
          railHeight: railHeight,
          railTargetSpacerHeight: railTargetSpacerHeight,
          railNativeSpacerHeight: railNativeSpacerHeight,
          railPlaceholderCount: railPlaceholderCount,
          railHasLeadingUnderlineSpacer: railHasLeadingUnderlineSpacer,
          railNeedsSoftWrapTerminator: railNeedsSoftWrapTerminator,
          railNativeLineCount: railNativeLineCount,
          railLineBreakCount: railLineBreakCount,
          baseLineHeight: baseLineHeight,
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
          railHeight: railHeight,
          railTargetSpacerHeight: railTargetSpacerHeight,
          railNativeSpacerHeight: railNativeSpacerHeight,
          railLineBreakCount: railLineBreakCount,
          railHasLeadingUnderlineSpacer: railHasLeadingUnderlineSpacer,
          railNeedsSoftWrapTerminator: railNeedsSoftWrapTerminator,
          railNativeLineCount: railNativeLineCount,
          underlineSpacerPlans: underlineSpacerPlans,
          totalPlaceholderCount: totalPlaceholderCount,
          railPlaceholderCount: railPlaceholderCount,
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
                        showSelectionHandles: true,
                        selectionColor: const Color(0x552563EB),
                        selectionControls: _TextChunkSelectionControls(
                          onHandlePointerDown:
                              _handleSelectionHandlePointerDown,
                          onHandlePointerEnd: _handleSelectionHandlePointerEnd,
                        ),
                        contextMenuBuilder: (context, editableTextState) =>
                            AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            ),
                        onSelectionChanged: _handleNativeSelectionChanged,
                      ),
                    ),
                  ),
                  if (railLine != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top:
                          _railTop(
                            railLine,
                            lineTops,
                            lineHeight,
                            underlineSpacerHeights,
                          ) -
                          _railGap,
                      child: IgnorePointer(
                        child: SizedBox(
                          key: const ValueKey(
                            'note-text-inline-selection-spacer',
                          ),
                          height: railTargetSpacerHeight,
                        ),
                      ),
                    ),
                  if (railLine != null && widget.selectionRail != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _railTop(
                        railLine,
                        lineTops,
                        lineHeight,
                        underlineSpacerHeights,
                      ),
                      child: KeyedSubtree(
                        key: _railMeasureKey,
                        child: KeyedSubtree(
                          key: const ValueKey(
                            'note-text-inline-selection-rail',
                          ),
                          child: widget.selectionRail!,
                        ),
                      ),
                    ),
                  for (final line in layout.lines)
                    _LineMarker(
                      line: line,
                      lineHeight: lineHeight,
                      lineTops: lineTops,
                      railLineIndex: railLine?.index,
                      railSpacerHeight: railNativeSpacerHeight,
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
    if (_selectionHandleDragActive) {
      return null;
    }
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

  void _configureController({
    required List<_TextChunkNativePlaceholder> placeholders,
  }) {
    final controller = widget.controller;
    if (controller is TextChunkNativeEditingController) {
      controller._configureTextChunkPresentation(
        rangeTags: widget.rangeTags,
        placeholders: placeholders,
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
    final normalized =
        cause == SelectionChangedCause.drag &&
            _usesControllerSelectionOffsets(selection)
        ? selection
        : controller.normalizeNativeSelection(selection);
    if (cause == SelectionChangedCause.drag) {
      _handleSelectionHandleDrag();
      if (normalized.baseOffset != selection.baseOffset ||
          normalized.extentOffset != selection.extentOffset) {
        controller.selection = normalized;
      }
      return;
    }
    _cancelSelectionHandleDrag();
    if (normalized.baseOffset != selection.baseOffset ||
        normalized.extentOffset != selection.extentOffset) {
      controller.selection = normalized;
    }
    _showNativeToolbarForSelection(normalized, cause);
  }

  void _handleSelectionHandleDrag() {
    _startSelectionHandleDrag();
  }

  void _handleSelectionHandlePointerDown(PointerDownEvent event) {
    _trackSelectionHandlePointer(event.pointer);
    _startSelectionHandleDrag();
  }

  void _startSelectionHandleDrag() {
    _selectionHandleReleaseScheduled = false;
    _editableTextKey.currentState?.hideToolbar(false);
    if (!_selectionHandleDragActive && mounted) {
      setState(() {
        _selectionHandleDragActive = true;
      });
    }
  }

  void _handleSelectionHandlePointerEnd(PointerUpEvent event) {
    _finishSelectionHandleDrag(pointer: event.pointer);
  }

  void _handleSelectionHandlePointerRoute(PointerEvent event) {
    if (event is PointerUpEvent) {
      _finishSelectionHandleDrag(pointer: event.pointer);
    }
  }

  void _finishSelectionHandleDrag({int? pointer}) {
    if (pointer != null && pointer == _selectionHandlePointer) {
      _untrackSelectionHandlePointer();
    }
    if (!_selectionHandleDragActive || _selectionHandleReleaseScheduled) {
      return;
    }
    _selectionHandleReleaseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _selectionHandleReleaseScheduled = false;
      setState(() {
        _selectionHandleDragActive = false;
      });
      _showNativeToolbarForSelection(
        widget.controller.selection,
        SelectionChangedCause.drag,
      );
    });
  }

  void _trackSelectionHandlePointer(int pointer) {
    if (_selectionHandlePointer == pointer) {
      return;
    }
    _untrackSelectionHandlePointer();
    _selectionHandlePointer = pointer;
    GestureBinding.instance.pointerRouter.addRoute(
      pointer,
      _handleSelectionHandlePointerRoute,
    );
  }

  void _untrackSelectionHandlePointer() {
    final pointer = _selectionHandlePointer;
    if (pointer == null) {
      return;
    }
    GestureBinding.instance.pointerRouter.removeRoute(
      pointer,
      _handleSelectionHandlePointerRoute,
    );
    _selectionHandlePointer = null;
  }

  bool _usesControllerSelectionOffsets(TextSelection selection) {
    final textLength = widget.controller.text.length;
    return selection.isValid &&
        selection.baseOffset <= textLength &&
        selection.extentOffset <= textLength;
  }

  void _cancelSelectionHandleDrag() {
    _selectionHandleReleaseScheduled = false;
    _untrackSelectionHandlePointer();
    if (_selectionHandleDragActive && mounted) {
      setState(() {
        _selectionHandleDragActive = false;
      });
    }
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
          _selectionHandleDragActive ||
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

  void _scheduleNativeGeometrySync({
    required TextChunkVisualLine? railLine,
    required int? railInsertionOffset,
    required List<_TextChunkNativePlaceholder> nativePlaceholders,
    required double railHeight,
    required double railTargetSpacerHeight,
    required double railNativeSpacerHeight,
    required int railPlaceholderCount,
    required bool railHasLeadingUnderlineSpacer,
    required bool railNeedsSoftWrapTerminator,
    required int railNativeLineCount,
    required int railLineBreakCount,
    required double baseLineHeight,
  }) {
    final signature = [
      widget.controller.text.length,
      widget.controller.selection.start,
      widget.controller.selection.end,
      widget.rangeTags
          .map((tag) => '${tag.id}:${tag.start}-${tag.end}:${tag.tags.length}')
          .join(','),
      railLine?.index,
      railInsertionOffset,
      railHeight.toStringAsFixed(1),
      railTargetSpacerHeight.toStringAsFixed(1),
      railNativeSpacerHeight.toStringAsFixed(1),
      railPlaceholderCount,
      railHasLeadingUnderlineSpacer,
      railNeedsSoftWrapTerminator,
      railNativeLineCount,
      railLineBreakCount,
      nativePlaceholders
          .map(
            (placeholder) =>
                '${placeholder.label}@${placeholder.offset}+${placeholder.length}',
          )
          .join(','),
      baseLineHeight.toStringAsFixed(1),
    ].join('|');
    _lastNativeGeometrySignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _lastNativeGeometrySignature != signature) {
        return;
      }
      final measuredRailHeight = railLine == null
          ? _measuredRailHeight
          : (_measureRailHeight() ?? railHeight);
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
              nativePlaceholders: nativePlaceholders,
            );
      final nextSignature = _geometrySignature(nextGeometries);
      final currentSignature = _geometrySignature(_nativeTagGeometries);
      final railChanged =
          railLine != null &&
          (measuredRailHeight - _measuredRailHeight).abs() > 0.5;
      final geometryChanged = nextSignature != currentSignature;
      DebugConsole.log(
        '[TextChunkLayout] nativeTagGeometry '
        'rangeTags=${widget.rangeTags.length} '
        'rects=${nextGeometries.length} '
        'railMeasured=${measuredRailHeight.toStringAsFixed(1)} '
        'railTargetSpacer=${railTargetSpacerHeight.toStringAsFixed(1)} '
        'railNativeSpacer=${railNativeSpacerHeight.toStringAsFixed(1)} '
        'railRoundedGap=${(railNativeSpacerHeight - railTargetSpacerHeight).toStringAsFixed(1)} '
        'railPlaceholderCount=$railPlaceholderCount '
        'railLeadingUnderlineSpacer=$railHasLeadingUnderlineSpacer '
        'railSoftWrapTerminator=$railNeedsSoftWrapTerminator '
        'railNativeLines=$railNativeLineCount '
        'railPlaceholderBreaks=$railLineBreakCount '
        'placeholderCount=${nativePlaceholders.fold<int>(0, (total, placeholder) => total + placeholder.length)} '
        'placeholders=[${_placeholderSummary(nativePlaceholders)}] '
        'nativeOrigins=editable:${_formatOffset(renderOrigin)},layout:${_formatOffset(layoutOrigin)} '
        'tightTagBoxes=true '
        'changedRail=$railChanged changedRects=$geometryChanged '
        'underlineRects=[$nextSignature]',
      );
      if (!railChanged && !geometryChanged) {
        return;
      }
      setState(() {
        if (railChanged) {
          _measuredRailHeight = measuredRailHeight;
        }
        if (geometryChanged) {
          _nativeTagGeometries = nextGeometries;
        }
      });
    });
  }

  double? _measureRailHeight() {
    final renderObject = _railMeasureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.size.height;
  }

  List<_TagHighlightGeometry> _nativeUnderlineGeometries({
    required RenderEditable renderEditable,
    required RenderBox layoutBox,
    required List<_TextChunkNativePlaceholder> nativePlaceholders,
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
        nativePlaceholders: nativePlaceholders,
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
                  rect.bottom -
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
    required List<_TextChunkNativePlaceholder> nativePlaceholders,
    required int start,
    required int end,
  }) {
    if (start >= end) {
      return const [];
    }
    final splitPoints = <int>{start, end};
    for (final placeholder in nativePlaceholders) {
      if (placeholder.offset > start && placeholder.offset < end) {
        splitPoints.add(placeholder.offset);
      }
    }
    final sortedSplitPoints = splitPoints.toList()..sort();
    final ranges = <({int start, int end})>[
      for (var index = 0; index < sortedSplitPoints.length - 1; index += 1)
        (start: sortedSplitPoints[index], end: sortedSplitPoints[index + 1]),
    ];
    final rects = <Rect>[];
    for (final range in ranges) {
      if (range.start >= range.end) {
        continue;
      }
      final nativeStart = _nativeOffsetForControllerOffset(
        range.start,
        nativePlaceholders,
        includeAtOffset: true,
      );
      final nativeEnd = _nativeOffsetForControllerOffset(
        range.end,
        nativePlaceholders,
        includeAtOffset: false,
      );
      final previousWidthStyle = renderEditable.selectionWidthStyle;
      final previousHeightStyle = renderEditable.selectionHeightStyle;
      renderEditable.selectionWidthStyle = ui.BoxWidthStyle.tight;
      renderEditable.selectionHeightStyle = ui.BoxHeightStyle.tight;
      final List<TextBox> boxes;
      try {
        boxes = renderEditable.getBoxesForSelection(
          TextSelection(baseOffset: nativeStart, extentOffset: nativeEnd),
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
    }
    return rects;
  }

  int _nativeOffsetForControllerOffset(
    int offset,
    List<_TextChunkNativePlaceholder> nativePlaceholders, {
    required bool includeAtOffset,
  }) {
    var placeholderCount = 0;
    for (final placeholder in nativePlaceholders) {
      final beforeOffset = placeholder.offset < offset;
      final atOffset = includeAtOffset && placeholder.offset == offset;
      if (beforeOffset || atOffset) {
        placeholderCount += placeholder.length;
      }
    }
    return offset + placeholderCount;
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
      _selectionHandleDragActive,
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
    final underlineSpacerHeights = {
      for (final plan in underlineSpacerPlans) plan.lineIndex: plan.height,
    };
    final lineTops = _lineTops(
      layout.lines,
      lineHeight,
      underlineSpacerHeights,
    );
    final railTop = railLine == null
        ? null
        : _railTop(railLine, lineTops, lineHeight, underlineSpacerHeights);
    final railBottom = railTop == null ? null : railTop + railHeight;
    final railNativeSpacerBottom = railTop == null
        ? null
        : railTop + railNativeSpacerHeight;
    DebugConsole.log(
      '[TextChunkLayout] textLen=${widget.controller.text.length} '
      'selection=${selection == null ? 'null' : '${selection.start}-${selection.end}'} '
      'selectionDragActive=$_selectionHandleDragActive '
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
      'railGap=${railLine == null ? 'null' : _railGap.toStringAsFixed(1)} '
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
}

class _TextChunkSelectionControls extends MaterialTextSelectionControls
    with TextSelectionHandleControls {
  _TextChunkSelectionControls({
    required this.onHandlePointerDown,
    required this.onHandlePointerEnd,
  });

  final ValueChanged<PointerDownEvent> onHandlePointerDown;
  final ValueChanged<PointerUpEvent> onHandlePointerEnd;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    return Listener(
      key: ValueKey('note-text-native-selection-handle-${type.name}'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: onHandlePointerDown,
      onPointerUp: onHandlePointerEnd,
      onPointerCancel: (_) {},
      child: super.buildHandle(context, type, textLineHeight, onTap),
    );
  }
}

class _LineMarker extends StatelessWidget {
  const _LineMarker({
    required this.line,
    required this.lineHeight,
    required this.lineTops,
    required this.railLineIndex,
    required this.railSpacerHeight,
  });

  final TextChunkVisualLine line;
  final double lineHeight;
  final Map<int, double> lineTops;
  final int? railLineIndex;
  final double railSpacerHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _lineTop(line.index, lineTops, railLineIndex, railSpacerHeight),
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
    required this.placeholderText,
  });

  final int lineIndex;
  final int offset;
  final int underlineLanes;
  final int lineBreakCount;
  final double height;
  final String placeholderText;
}

double _lineTop(
  int lineIndex,
  Map<int, double> lineTops,
  int? railLineIndex,
  double railSpacerHeight,
) {
  final railOffset = railLineIndex != null && lineIndex > railLineIndex
      ? railSpacerHeight
      : 0;
  return (lineTops[lineIndex] ?? 0) + railOffset;
}

double _railTop(
  TextChunkVisualLine line,
  Map<int, double> lineTops,
  double baseLineHeight,
  Map<int, double> underlineSpacerHeights,
) {
  return (lineTops[line.index] ?? 0) +
      baseLineHeight +
      (underlineSpacerHeights[line.index] ?? 0) +
      _railGap;
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

List<_TextChunkNativePlaceholder> _softWrapIndentPlaceholders(
  List<TextChunkVisualLine> lines, {
  required Set<int> occupiedOffsets,
}) {
  final placeholders = <_TextChunkNativePlaceholder>[];
  for (var index = 0; index + 1 < lines.length; index += 1) {
    final line = lines[index];
    final nextLine = lines[index + 1];
    if (line.indentLevel <= 0 ||
        line.hardBreakAfter ||
        occupiedOffsets.contains(line.end)) {
      continue;
    }
    final isSoftWrapContinuation =
        nextLine.paragraphIndex == line.paragraphIndex &&
        nextLine.lineIndexInParagraph == line.lineIndexInParagraph + 1 &&
        nextLine.start == line.end;
    if (!isSoftWrapContinuation) {
      continue;
    }
    final indent = _continuationIndentForLine(line);
    if (indent.isEmpty) {
      continue;
    }
    placeholders.add(
      _TextChunkNativePlaceholder(
        offset: line.end,
        text: _railPlaceholderTextForLineBreaks(1, trailingText: indent),
        label: 'indent-soft-wrap-${line.index}',
      ),
    );
  }
  return placeholders;
}

List<_LineSpacerPlan> _underlineSpacerPlans(
  List<TextChunkVisualLine> lines,
  double baseLineHeight, {
  int? trailingIndentSuppressedOffset,
}) {
  final plans = <_LineSpacerPlan>[];
  for (final line in lines) {
    final lanes = line.underlineLanes.length;
    final nativeLineCount = _underlineNativeLineCountForLanes(lanes);
    if (nativeLineCount <= 0) {
      continue;
    }
    // The first inserted newline terminates the current visual row. The
    // following newlines are the rows that create visible vertical space.
    final placeholderLineBreakCount = nativeLineCount + 1;
    final offset = _insertionOffsetForLine(line);
    final shouldCarryContinuationIndent =
        !line.hardBreakAfter && offset != trailingIndentSuppressedOffset;
    plans.add(
      _LineSpacerPlan(
        lineIndex: line.index,
        offset: offset,
        underlineLanes: lanes,
        lineBreakCount: placeholderLineBreakCount,
        height: nativeLineCount * baseLineHeight,
        placeholderText: _railPlaceholderTextForLineBreaks(
          placeholderLineBreakCount,
          trailingText: shouldCarryContinuationIndent
              ? _continuationIndentForLine(line)
              : '',
        ),
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

String _continuationIndentForLine(TextChunkVisualLine line) {
  if (line.indentLevel <= 0) {
    return '';
  }
  return _placeholderIndentUnit * line.indentLevel;
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

String _placeholderSummary(List<_TextChunkNativePlaceholder> placeholders) {
  return placeholders
      .map(
        (placeholder) =>
            '${placeholder.label}@${placeholder.offset}+${placeholder.length}',
      )
      .join(' ');
}

String _railPlaceholderTextForLineBreaks(
  int lineBreakCount, {
  String trailingText = '',
}) {
  if (lineBreakCount <= 0) {
    return trailingText;
  }
  final lineBreaks = List.filled(
    lineBreakCount,
    _placeholderLineBreakUnit,
  ).join();
  return '$lineBreaks$trailingText';
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
