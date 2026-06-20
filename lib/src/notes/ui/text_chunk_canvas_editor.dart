import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'text_chunk_layout_model.dart';

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
  final Map<int, GlobalKey> _lineKeys = {};
  TextChunkLayout? _latestLayout;
  int? _selectionAnchor;
  bool _draggingSelectionHandle = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerSelectionChanged);
    widget.focusNode.addListener(_handleControllerSelectionChanged);
  }

  @override
  void didUpdateWidget(TextChunkCanvasEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerSelectionChanged);
      widget.controller.addListener(_handleControllerSelectionChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleControllerSelectionChanged);
      widget.focusNode.addListener(_handleControllerSelectionChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerSelectionChanged);
    widget.focusNode.removeListener(_handleControllerSelectionChanged);
    super.dispose();
  }

  void _handleControllerSelectionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualSelection = _visualSelection();
        final layout = buildTextChunkLayout(
          text: widget.controller.text,
          maxWidth: constraints.maxWidth - 56,
          textStyle: widget.textStyle,
          textScaler: textScaler,
          rangeTags: widget.rangeTags,
          selection: visualSelection,
          railHeight: 96,
        );
        _latestLayout = layout;
        return GestureDetector(
          key: const ValueKey('note-text-chunk-field'),
          behavior: HitTestBehavior.translucent,
          onTap: () => widget.focusNode.requestFocus(),
          child: SingleChildScrollView(
            key: const ValueKey('note-text-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 1,
                  height: 1,
                  child: Opacity(
                    opacity: 0,
                    child: EditableText(
                      key: const ValueKey('note-text-input-bridge'),
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      style: widget.textStyle,
                      cursorColor: const Color(0xFF111827),
                      backgroundCursorColor: Colors.transparent,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  ),
                ),
                for (final line in layout.lines) ...[
                  Padding(
                    key: ValueKey('note-text-line-indent-${line.index}'),
                    padding: EdgeInsets.only(
                      left: line.indentLevel * textChunkIndentWidth,
                    ),
                    child: Listener(
                      onPointerMove: (event) =>
                          _handleActiveSelectionMove(event.position),
                      child: GestureDetector(
                        key: ValueKey('note-text-line-${line.index}'),
                        behavior: HitTestBehavior.translucent,
                        onTapDown: (details) =>
                            _handleLineTapDown(line, details),
                        onLongPressStart: (details) =>
                            _handleLineLongPressStart(line, details),
                        onLongPressMoveUpdate: (details) =>
                            _handleActiveSelectionMove(details.globalPosition),
                        onLongPressEnd: (_) => _finishSelectionDrag(),
                        onLongPressCancel: _finishSelectionDrag,
                        child: _TextChunkLineView(
                          key: _lineKey(line.index),
                          line: line,
                          textStyle: widget.textStyle,
                          selection: visualSelection,
                          focused: widget.focusNode.hasFocus,
                          onSelectionHandleDragStart: _startSelectionHandleDrag,
                          onSelectionHandleDragUpdate:
                              _handleSelectionHandleDragUpdate,
                          onSelectionHandleDragEnd: _finishSelectionHandleDrag,
                        ),
                      ),
                    ),
                  ),
                  if (layout.railLineIndex == line.index &&
                      widget.selectionRail != null &&
                      _selectionAnchor == null &&
                      !_draggingSelectionHandle)
                    KeyedSubtree(
                      key: const ValueKey('note-text-inline-selection-rail'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 10),
                        child: widget.selectionRail!,
                      ),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  GlobalKey _lineKey(int index) =>
      _lineKeys.putIfAbsent(index, () => GlobalKey());

  TextRange? _visualSelection() {
    final selection = widget.controller.selection;
    if (!selection.isValid) {
      return widget.activeRange;
    }
    return TextRange(start: selection.baseOffset, end: selection.extentOffset);
  }

  void _handleLineTapDown(TextChunkVisualLine line, TapDownDetails details) {
    _selectionAnchor = null;
    _setSelection(
      TextSelection.collapsed(
        offset: _offsetForLinePosition(line, details.localPosition),
      ),
    );
  }

  void _handleLineLongPressStart(
    TextChunkVisualLine line,
    LongPressStartDetails details,
  ) {
    final offset = _offsetForLinePosition(line, details.localPosition);
    final word = _wordRangeAt(offset);
    setState(() => _selectionAnchor = word.start);
    _setSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
  }

  void _handleActiveSelectionMove(Offset globalPosition) {
    final anchor = _selectionAnchor;
    if (anchor == null) {
      return;
    }
    final offset = _offsetForGlobalPosition(globalPosition);
    _setSelection(TextSelection(baseOffset: anchor, extentOffset: offset));
  }

  void _setSelection(TextSelection selection) {
    widget.controller.selection = selection;
    widget.focusNode.requestFocus();
  }

  void _startSelectionHandleDrag() {
    if (!_draggingSelectionHandle) {
      setState(() => _draggingSelectionHandle = true);
    }
  }

  void _handleSelectionHandleDragUpdate({
    required bool startHandle,
    required Offset globalPosition,
  }) {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    final start = selection.start;
    final end = selection.end;
    final offset = _offsetForGlobalPosition(globalPosition);
    _setSelection(
      startHandle
          ? TextSelection(baseOffset: end, extentOffset: offset)
          : TextSelection(baseOffset: start, extentOffset: offset),
    );
  }

  void _finishSelectionHandleDrag() {
    if (!_draggingSelectionHandle) {
      return;
    }
    setState(() => _draggingSelectionHandle = false);
  }

  void _finishSelectionDrag() {
    if (_selectionAnchor == null) {
      return;
    }
    setState(() => _selectionAnchor = null);
  }

  int _offsetForGlobalPosition(Offset globalPosition) {
    final layout = _latestLayout;
    if (layout == null || layout.lines.isEmpty) {
      return 0;
    }
    TextChunkVisualLine? nearestLine;
    Offset? nearestLocalPosition;
    var nearestDistance = double.infinity;
    for (final line in layout.lines) {
      final keyContext = _lineKeys[line.index]?.currentContext;
      final renderObject = keyContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        continue;
      }
      final topLeft = renderObject.localToGlobal(Offset.zero);
      final rect = topLeft & renderObject.size;
      if (rect.contains(globalPosition)) {
        return _offsetForLinePosition(
          line,
          renderObject.globalToLocal(globalPosition),
        );
      }
      final distance = globalPosition.dy < rect.top
          ? rect.top - globalPosition.dy
          : globalPosition.dy - rect.bottom;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestLine = line;
        nearestLocalPosition = renderObject.globalToLocal(globalPosition);
      }
    }
    if (nearestLine == null || nearestLocalPosition == null) {
      return layout.lines.last.end;
    }
    return _offsetForLinePosition(nearestLine, nearestLocalPosition);
  }

  int _offsetForLinePosition(TextChunkVisualLine line, Offset localPosition) {
    if (line.text.isEmpty) {
      return line.start;
    }
    final painter = TextPainter(
      text: TextSpan(text: line.text, style: widget.textStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final x = localPosition.dx.clamp(0, painter.width).toDouble();
    return line.start + painter.getPositionForOffset(Offset(x, 0)).offset;
  }

  TextRange _wordRangeAt(int offset) {
    final text = widget.controller.text;
    if (text.isEmpty) {
      return const TextRange(start: 0, end: 0);
    }
    final clamped = offset.clamp(0, text.length).toInt();
    var start = clamped;
    while (start > 0 && !_isBoundary(text.codeUnitAt(start - 1))) {
      start -= 1;
    }
    var end = clamped;
    while (end < text.length && !_isBoundary(text.codeUnitAt(end))) {
      end += 1;
    }
    return TextRange(start: start, end: end);
  }

  bool _isBoundary(int codeUnit) =>
      codeUnit == 9 || codeUnit == 10 || codeUnit == 13 || codeUnit == 32;
}

class _TextChunkLineView extends StatelessWidget {
  const _TextChunkLineView({
    super.key,
    required this.line,
    required this.textStyle,
    required this.selection,
    required this.focused,
    required this.onSelectionHandleDragStart,
    required this.onSelectionHandleDragUpdate,
    required this.onSelectionHandleDragEnd,
  });

  final TextChunkVisualLine line;
  final TextStyle textStyle;
  final TextRange? selection;
  final bool focused;
  final VoidCallback onSelectionHandleDragStart;
  final void Function({
    required bool startHandle,
    required Offset globalPosition,
  })
  onSelectionHandleDragUpdate;
  final VoidCallback onSelectionHandleDragEnd;

  @override
  Widget build(BuildContext context) {
    final pieces = _piecesForLine(line);
    final textRow = pieces.isEmpty
        ? Text(' ', style: textStyle)
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final piece in pieces)
                piece.segment == null
                    ? _PlainPieceView(
                        piece: piece,
                        lineIndex: line.index,
                        textStyle: textStyle,
                      )
                    : _SelectionPieceFrame(
                        selected: piece.selected,
                        lineIndex: line.index,
                        segmentIndex: piece.index,
                        child: _TaggedPieceView(
                          text: piece.text,
                          segment: piece.segment!,
                          lineIndex: line.index,
                          segmentIndex: piece.index,
                          textStyle: textStyle,
                        ),
                      ),
            ],
          );
    return Padding(
      padding: EdgeInsets.only(
        bottom: line.underlineLanes.isEmpty
            ? 0
            : 4 + (line.underlineLanes.length * 3),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          textRow,
          if (_showsCaret) _caret(),
          if (_showsStartHandle) _selectionHandle(startHandle: true),
          if (_showsEndHandle) _selectionHandle(startHandle: false),
        ],
      ),
    );
  }

  bool get _showsCaret {
    final current = selection;
    if (!focused || current == null || current.start != current.end) {
      return false;
    }
    return _lineContainsOffset(current.start);
  }

  bool get _showsStartHandle {
    final current = selection;
    if (current == null || current.start == current.end) {
      return false;
    }
    return _lineContainsOffset(
      current.start < current.end ? current.start : current.end,
    );
  }

  bool get _showsEndHandle {
    final current = selection;
    if (current == null || current.start == current.end) {
      return false;
    }
    return _lineContainsOffset(
      current.start < current.end ? current.end : current.start,
    );
  }

  bool _lineContainsOffset(int offset) {
    if (line.start == line.end) {
      return offset == line.start;
    }
    return offset >= line.start && offset <= line.end;
  }

  Widget _caret() {
    return Positioned(
      key: ValueKey('note-text-caret-${line.index}'),
      left: _xForOffset(selection!.start),
      top: 1,
      child: Container(
        width: 2,
        height: _lineHeight,
        color: const Color(0xFF2563EB),
      ),
    );
  }

  Widget _selectionHandle({required bool startHandle}) {
    final current = selection!;
    final normalizedStart = current.start < current.end
        ? current.start
        : current.end;
    final normalizedEnd = current.start < current.end
        ? current.end
        : current.start;
    final offset = startHandle ? normalizedStart : normalizedEnd;
    return Positioned(
      left: _xForOffset(offset) - 6,
      top: _lineHeight - 1,
      child: GestureDetector(
        key: ValueKey(
          startHandle
              ? 'note-text-selection-handle-start'
              : 'note-text-selection-handle-end',
        ),
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onSelectionHandleDragStart(),
        onPanUpdate: (details) => onSelectionHandleDragUpdate(
          startHandle: startHandle,
          globalPosition: details.globalPosition,
        ),
        onPanEnd: (_) => onSelectionHandleDragEnd(),
        onPanCancel: onSelectionHandleDragEnd,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  double get _lineHeight {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.height;
  }

  double _xForOffset(int offset) {
    final localOffset = (offset - line.start)
        .clamp(0, line.text.length)
        .toInt();
    if (localOffset == 0 || line.text.isEmpty) {
      return 0;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: line.text.substring(0, localOffset),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  List<_LinePiece> _piecesForLine(TextChunkVisualLine line) {
    if (line.start >= line.end) {
      return const [];
    }
    final breakpoints = <int>{line.start, line.end};
    for (final segment in line.tagSegments) {
      breakpoints.add(segment.start);
      breakpoints.add(segment.end);
    }
    for (final segment in line.selectionSegments) {
      breakpoints.add(segment.start);
      breakpoints.add(segment.end);
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
          text: line.text.substring(start - line.start, end - line.start),
          segment: _segmentForRange(line.tagSegments, start, end),
          selected: _isSelectionSegment(line.selectionSegments, start, end),
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

  bool _isSelectionSegment(
    List<TextChunkSelectionSegment> segments,
    int start,
    int end,
  ) {
    for (final segment in segments) {
      if (segment.start <= start && segment.end >= end) {
        return true;
      }
    }
    return false;
  }
}

class _PlainPieceView extends StatelessWidget {
  const _PlainPieceView({
    required this.piece,
    required this.lineIndex,
    required this.textStyle,
  });

  final _LinePiece piece;
  final int lineIndex;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return _SelectionPieceFrame(
      selected: piece.selected,
      lineIndex: lineIndex,
      segmentIndex: piece.index,
      child: Text(piece.text, style: textStyle),
    );
  }
}

class _SelectionPieceFrame extends StatelessWidget {
  const _SelectionPieceFrame({
    required this.selected,
    required this.lineIndex,
    required this.segmentIndex,
    required this.child,
  });

  final bool selected;
  final int lineIndex;
  final int segmentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return child;
    }
    return ColoredBox(
      key: ValueKey('note-text-selection-highlight-$lineIndex-$segmentIndex'),
      color: const Color(0xFFBFDBFE),
      child: child,
    );
  }
}

class _TaggedPieceView extends StatelessWidget {
  const _TaggedPieceView({
    required this.text,
    required this.segment,
    required this.lineIndex,
    required this.segmentIndex,
    required this.textStyle,
  });

  final String text;
  final TextChunkTagSegment segment;
  final int lineIndex;
  final int segmentIndex;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    final primary = segment.tags.first;
    final secondary = segment.tags.skip(1).toList(growable: false);
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            key: ValueKey(
              'note-text-primary-highlight-${segment.rangeId}-$lineIndex-$segmentIndex',
            ),
            color: Color(primary.resolvedColorValue).withValues(alpha: 0.22),
            child: Text(
              text,
              style: textStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (var index = 0; index < secondary.length; index += 1)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 2 : 3),
              child: Container(
                key: ValueKey(
                  'note-text-secondary-underline-${segment.rangeId}-${index + 1}-$lineIndex-$segmentIndex',
                ),
                height: 2,
                color: Color(secondary[index].resolvedColorValue),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinePiece {
  const _LinePiece({
    required this.index,
    required this.text,
    required this.segment,
    required this.selected,
  });

  final int index;
  final String text;
  final TextChunkTagSegment? segment;
  final bool selected;
}
