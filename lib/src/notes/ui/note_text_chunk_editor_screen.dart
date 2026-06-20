import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteTextChunkEditorScreen extends StatefulWidget {
  const NoteTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
    this.availableTags = const [],
    this.onDelete,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final List<NoteKnowledgeTag> availableTags;
  final VoidCallback? onDelete;

  @override
  State<NoteTextChunkEditorScreen> createState() =>
      _NoteTextChunkEditorScreenState();
}

class _NoteTextChunkEditorScreenState extends State<NoteTextChunkEditorScreen> {
  late NoteBlock _block;
  late final _TextChunkEditingController _controller;
  late final FocusNode _focusNode;
  bool _syncingController = false;
  bool _selectionCanDeleteTag = false;
  bool _selectionHasRange = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  TextRange? _activeRailRange;
  double _lastTextLayoutWidth = 0;
  List<_VisualTextLine> _lastVisualLines = const [];
  String? _lastLayoutLogSignature;
  String? _lastRailLogSignature;
  String? _lastUnderlineLogSignature;
  String? _lastParagraphLogSignature;

  static const _textStyle = TextStyle(color: Color(0xFF111827), fontSize: 16);
  static const _textContentPadding = EdgeInsets.symmetric(vertical: 2);
  static const _railTopTextGap = 10.0;
  static const _railBottomTextGap = 10.0;
  static const _collapsedRailHeight = 64.0;
  static const _expandedRailHeight = 113.0;
  static const _editorBottomSlack = 12.0;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _focusNode = FocusNode();
    _controller = _TextChunkEditingController(
      text: widget.block.text,
      rangeTags: widget.block.rangeTags,
    )..addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _block = widget.block;
      _activeRailRange = null;
      _selectionCanDeleteTag = false;
      _selectionHasRange = false;
      _syncControllerText(widget.block.text);
      _controller.setRangeTags(widget.block.rangeTags);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _syncControllerText(String text) {
    _syncingController = true;
    try {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    } finally {
      _syncingController = false;
    }
  }

  void _handleControllerChanged() {
    if (_syncingController) {
      return;
    }
    final oldText = _block.text;
    final value = _controller.text;
    if (oldText != value) {
      final rangeTags = _adjustRangeTagsForEdit(
        oldText: oldText,
        newText: value,
        tags: _block.rangeTags,
      );
      setState(() {
        _block = _block.copyWith(
          text: value,
          rangeTags: rangeTags,
          clearIndex: true,
        );
      });
      _controller.setRangeTags(rangeTags);
      widget.onChanged(_block);
      DebugConsole.log(
        '[TextChunk] text changed chars=${value.length} '
        'ranges=${rangeTags.length}',
      );
    }
    _updateSelectionState(source: 'controllerChanged');
  }

  void _emitTitle(String value) {
    setState(() {
      _block = _block.copyWith(title: value.trim(), clearIndex: true);
    });
    widget.onChanged(_block);
  }

  Future<void> _tagChunk() async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: _block.tags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Chunk tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() => _block = _block.copyWith(tags: tags, clearIndex: true));
    widget.onChanged(_block);
    DebugConsole.log('[TextChunk] chunk tags changed count=${tags.length}');
  }

  void _deleteChunkTag(NoteKnowledgeTag tag) {
    setState(() {
      _block = _block.copyWith(
        tags: _block.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
        clearIndex: true,
      );
    });
    widget.onChanged(_block);
  }

  Future<void> _tagSelection() async {
    final targetRange = _selectionTargetRange();
    if (targetRange == null || _block.text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jelölj ki egy szövegrészt a tageléshez')),
      );
      DebugConsole.log('[TextChunk] tag request skipped reason=no_selection');
      return;
    }
    final tags = await showTagManagerSheet(
      context,
      initialTags: _selectionTags(),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt rész tagje',
    );
    if (tags == null || tags.isEmpty) {
      DebugConsole.log('[TextChunk] tag request cancelled');
      return;
    }
    final existing = _exactRangeTag(targetRange);
    final rangeTag = NoteTextRangeTag(
      id: existing?.id ?? 'range-${DateTime.now().microsecondsSinceEpoch}',
      start: targetRange.start.clamp(0, _block.text.length).toInt(),
      end: targetRange.end.clamp(0, _block.text.length).toInt(),
      tag: tags.first,
      tags: tags,
    );
    if (!rangeTag.isValid) {
      return;
    }
    setState(() {
      final rangeTags = existing == null
          ? [..._block.rangeTags, rangeTag]
          : [
              for (final current in _block.rangeTags)
                if (current.id == existing.id) rangeTag else current,
            ];
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionTargetRange() != null;
    });
    _controller.setRangeTags(_block.rangeTags);
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk] range tagged start=${rangeTag.start} end=${rangeTag.end} '
      'tags=${tags.length}',
    );
  }

  NoteTextRangeTag? _exactRangeTag(TextRange range) {
    for (final tag in _block.rangeTags) {
      final clamped = tag.clampToTextLength(_block.text.length);
      if (clamped.isValid &&
          clamped.start == range.start &&
          clamped.end == range.end) {
        return clamped;
      }
    }
    return null;
  }

  TextRange? _selectionTargetRange() {
    if (_block.text.isEmpty) {
      return null;
    }
    final selection = _controller.selection;
    if (!selection.isValid) {
      return null;
    }
    if (!selection.isCollapsed) {
      final start = selection.start < selection.end
          ? selection.start
          : selection.end;
      final end = selection.start < selection.end
          ? selection.end
          : selection.start;
      return TextRange(
        start: start.clamp(0, _block.text.length).toInt(),
        end: end.clamp(0, _block.text.length).toInt(),
      );
    }
    final offset = selection.extentOffset.clamp(0, _block.text.length).toInt();
    final collapsedRange = _collapsedTaggedRangeAt(offset);
    if (collapsedRange == null) {
      return null;
    }
    return TextRange(start: collapsedRange.start, end: collapsedRange.end);
  }

  NoteTextRangeTag? _collapsedTaggedRangeAt(int offset) {
    for (final tag in _block.rangeTags) {
      final range = tag.clampToTextLength(_block.text.length);
      if (!range.isValid) {
        continue;
      }
      if (offset >= range.start && offset < range.end) {
        return range;
      }
    }
    return null;
  }

  bool _selectionHasTag() {
    final targetRange = _selectionTargetRange();
    if (targetRange == null) {
      return false;
    }
    return _rangeHasTag(targetRange);
  }

  bool _rangeHasTag(TextRange range) {
    return _block.rangeTags.any(
      (tag) => tag.start < range.end && tag.end > range.start,
    );
  }

  void _deleteSelectedTag() {
    final targetRange = _selectionTargetRange();
    if (targetRange == null) {
      return;
    }
    setState(() {
      final rangeTags = _block.rangeTags
          .where(
            (tag) =>
                !(tag.start < targetRange.end && tag.end > targetRange.start),
          )
          .toList(growable: false);
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionTargetRange() != null;
      if (!_selectionHasRange) {
        _activeRailRange = null;
      }
    });
    _controller.setRangeTags(_block.rangeTags);
    widget.onChanged(_block);
  }

  void _deleteSingleSelectedTag(NoteKnowledgeTag tag) {
    final targetRange = _selectionTargetRange();
    if (targetRange == null) {
      return;
    }
    setState(() {
      final rangeTags = <NoteTextRangeTag>[];
      for (final rangeTag in _block.rangeTags) {
        if (rangeTag.start >= targetRange.end ||
            rangeTag.end <= targetRange.start) {
          rangeTags.add(rangeTag);
          continue;
        }
        final nextTags = rangeTag.resolvedTags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false);
        if (nextTags.isNotEmpty) {
          rangeTags.add(
            NoteTextRangeTag(
              id: rangeTag.id,
              start: rangeTag.start,
              end: rangeTag.end,
              tag: nextTags.first,
              tags: nextTags,
            ),
          );
        }
      }
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionTargetRange() != null;
    });
    _controller.setRangeTags(_block.rangeTags);
    widget.onChanged(_block);
  }

  void _changeRailParagraphIndent(int delta) {
    _changeParagraphIndent(delta);
  }

  void _focusTaggedRange(int direction) {
    final ranges =
        [
            for (final range in _block.rangeTags)
              range.clampToTextLength(_block.text.length),
          ].where((range) => range.isValid).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    if (ranges.isEmpty) {
      return;
    }
    final currentOffset = _activeRailRange?.start ?? -1;
    final target = direction >= 0
        ? ranges.firstWhere(
            (range) => range.start > currentOffset,
            orElse: () => ranges.first,
          )
        : ranges.reversed.firstWhere(
            (range) => range.start < currentOffset,
            orElse: () => ranges.last,
          );
    setState(() {
      _activeRailRange = TextRange(start: target.start, end: target.end);
      _selectionCanDeleteTag = true;
      _selectionHasRange = true;
    });
    _controller.selection = TextSelection.collapsed(offset: target.start);
    _focusNode.requestFocus();
  }

  List<NoteKnowledgeTag> _selectionTags() {
    final targetRange = _selectionTargetRange();
    if (targetRange == null) {
      return const [];
    }
    final tags = <NoteKnowledgeTag>[];
    for (final rangeTag in _block.rangeTags) {
      if (rangeTag.start >= targetRange.end ||
          rangeTag.end <= targetRange.start) {
        continue;
      }
      for (final tag in rangeTag.resolvedTags) {
        if (!tags.any((current) => current.metadataText == tag.metadataText)) {
          tags.add(tag);
        }
      }
    }
    return tags;
  }

  bool _sameTextRange(TextRange? a, TextRange? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.start == b.start && a.end == b.end;
  }

  void _updateSelectionState({required String source}) {
    final nextRailRange = _selectionTargetRange();
    final previousRange = _activeRailRange;
    final nextCanDelete = nextRailRange != null && _rangeHasTag(nextRailRange);
    final nextHasRange = nextRailRange != null;
    if (nextCanDelete == _selectionCanDeleteTag &&
        nextHasRange == _selectionHasRange &&
        _sameTextRange(nextRailRange, _activeRailRange)) {
      return;
    }
    setState(() {
      _activeRailRange = nextRailRange;
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
    });
    DebugConsole.log(
      '[TextChunk] selection source=$source '
      'range=${nextRailRange == null ? 'none' : '${nextRailRange.start}-${nextRailRange.end}'} '
      'previous=${previousRange == null ? 'none' : '${previousRange.start}-${previousRange.end}'}',
    );
  }

  Widget _buildSelectionRail() {
    return NoteSelectionActionRail(
      key: const ValueKey('note-text-selection-rail'),
      tags: _selectionTags(),
      label: 'Kijelölt szöveg',
      pillPrefix: 'note-text-selection-rail-pill',
      bottomRowExpanded: _railBottomExpanded,
      onToggleBottomRow: () =>
          setState(() => _railBottomExpanded = !_railBottomExpanded),
      onDeleteTag: _deleteSingleSelectedTag,
      roundedCard: _railRoundedCard,
      transparentBackground: _railTransparentBackground,
      showBorder: _railBorderVisible,
      showBottomBorder: false,
      contentPadding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      actions: [
        IconButton(
          key: const ValueKey('note-text-selection-rail-outdent'),
          tooltip: 'Bekezdés kijjebb',
          onPressed: () => _changeRailParagraphIndent(-1),
          icon: const Icon(Icons.format_indent_decrease, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-indent'),
          tooltip: 'Bekezdés beljebb',
          onPressed: () => _changeRailParagraphIndent(1),
          icon: const Icon(Icons.format_indent_increase, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-tag'),
          tooltip: 'Kijelölt rész tagelése',
          onPressed: () => unawaited(_tagSelection()),
          icon: const Icon(Icons.sell_outlined, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-clear-tags'),
          tooltip: 'Minden tag törlése',
          onPressed: _selectionHasRange ? _deleteSelectedTag : null,
          icon: const Icon(Icons.delete_outline, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-prev'),
          tooltip: 'Előző tag',
          onPressed: _block.rangeTags.isEmpty
              ? null
              : () => _focusTaggedRange(-1),
          icon: const Icon(Icons.chevron_left, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-next'),
          tooltip: 'Következő tag',
          onPressed: _block.rangeTags.isEmpty
              ? null
              : () => _focusTaggedRange(1),
          icon: const Icon(Icons.chevron_right, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-rounded'),
          tooltip: _railRoundedCard ? 'Vonalas rail' : 'Cellaszerű rail',
          onPressed: () => setState(() => _railRoundedCard = !_railRoundedCard),
          icon: const Icon(Icons.crop_square_outlined, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-transparent'),
          tooltip: _railTransparentBackground
              ? 'Fehér rail háttér'
              : 'Szürke rail háttér',
          onPressed: () => setState(
            () => _railTransparentBackground = !_railTransparentBackground,
          ),
          icon: const Icon(Icons.opacity, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-border'),
          tooltip: _railBorderVisible ? 'Rail border nélkül' : 'Rail borderrel',
          onPressed: () =>
              setState(() => _railBorderVisible = !_railBorderVisible),
          icon: const Icon(Icons.border_outer, size: 20),
        ),
      ],
    );
  }

  double get _selectionRailHeight =>
      _railBottomExpanded ? _expandedRailHeight : _collapsedRailHeight;

  double get _selectionRailReservedHeight =>
      _selectionRailHeight + _railTopTextGap + _railBottomTextGap;

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _changeParagraphIndent(int delta) {
    if (_block.text.trim().isEmpty) {
      return;
    }
    final selection = _controller.selection;
    final offset =
        _activeRailRange?.start ??
        (selection.isValid ? selection.extentOffset : 0);
    final paragraphRange = _paragraphRangeForOffset(_block.text, offset);
    if (paragraphRange == null) {
      return;
    }
    final oldText = _block.text;
    final lineStarts = _visualLineStartsForParagraph(oldText, paragraphRange);
    final edits = _paragraphIndentEdits(
      oldText,
      lineStarts: lineStarts,
      delta: delta,
    );
    final logSignature =
        '${paragraphRange.start}:${paragraphRange.end}:$delta:'
        '${lineStarts.join(',')}:${edits.length}';
    if (_lastParagraphLogSignature != logSignature) {
      _lastParagraphLogSignature = logSignature;
      DebugConsole.log(
        '[TextChunkLayout] paragraph step delta=$delta '
        'range=${paragraphRange.start}-${paragraphRange.end} '
        'visualLines=${lineStarts.length} edits=${edits.length} '
        'layoutWidth=${_lastTextLayoutWidth.toStringAsFixed(1)}',
      );
    }
    if (edits.isEmpty) {
      return;
    }
    final result = _applyTextEdits(
      text: oldText,
      rangeTags: _block.rangeTags,
      edits: edits,
    );
    final nextText = result.text;
    final rangeTags = result.rangeTags;
    setState(() {
      _block = _block.copyWith(
        text: nextText,
        rangeTags: rangeTags,
        clearIndex: true,
      );
    });
    _syncingController = true;
    try {
      _controller.setRangeTags(rangeTags);
      _controller.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: _offsetAfterTextEdits(
            offset,
            edits,
          ).clamp(0, nextText.length).toInt(),
        ),
      );
    } finally {
      _syncingController = false;
    }
    widget.onChanged(_block);
  }

  TextRange? _paragraphRangeForOffset(String text, int rawOffset) {
    if (text.isEmpty) {
      return null;
    }
    final offset = rawOffset.clamp(0, text.length).toInt();
    final before = offset <= 0 ? -1 : text.lastIndexOf('\n\n', offset - 1);
    final after = text.indexOf('\n\n', offset);
    final start = before < 0 ? 0 : before + 2;
    final end = after < 0 ? text.length : after;
    if (start >= end) {
      return null;
    }
    return TextRange(start: start, end: end);
  }

  List<int> _visualLineStartsForParagraph(String text, TextRange paragraph) {
    final measured =
        _lastVisualLines
            .where(
              (line) =>
                  line.start < paragraph.end && line.end > paragraph.start,
            )
            .map(
              (line) =>
                  line.start.clamp(paragraph.start, paragraph.end).toInt(),
            )
            .where((offset) => offset < paragraph.end)
            .toSet()
            .toList()
          ..sort();
    if (measured.isNotEmpty) {
      return measured;
    }
    final starts = <int>[paragraph.start];
    var cursor = paragraph.start;
    while (cursor < paragraph.end) {
      final newline = text.indexOf('\n', cursor);
      if (newline < 0 || newline + 1 >= paragraph.end) {
        break;
      }
      starts.add(newline + 1);
      cursor = newline + 1;
    }
    return starts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-text-chunk-editor'),
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: _block.type == NoteBlockType.heading
            ? 'Címsor'
            : 'Szöveg',
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selectionCanDeleteTag,
        trailingActions: [
          IconButton(
            key: const ValueKey('note-text-outdent'),
            tooltip: 'Bekezdés kijjebb',
            onPressed: () => _changeParagraphIndent(-1),
            icon: const Icon(Icons.format_indent_decrease),
          ),
          IconButton(
            key: const ValueKey('note-text-indent'),
            tooltip: 'Bekezdés beljebb',
            onPressed: () => _changeParagraphIndent(1),
            icon: const Icon(Icons.format_indent_increase),
          ),
        ],
      ),
      body: Container(
        key: const ValueKey('note-text-chunk-body'),
        color: Colors.white,
        child: Column(
          children: [
            if (_block.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NoteTagPills(
                    tags: _block.tags,
                    onDeleted: _deleteChunkTag,
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_buildTextField(), const SizedBox(height: 220)],
                ),
              ),
            ),
            if (_block.rangeTags.isNotEmpty)
              const SizedBox.shrink(key: ValueKey('note-text-range-highlight')),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final activeRailRange = _selectionHasRange ? _activeRailRange : null;
        final activeRailGapPx = activeRailRange == null
            ? 0.0
            : _selectionRailReservedHeight;
        _controller
          ..activeRailRange = activeRailRange
          ..activeRailGapPx = activeRailGapPx;
        final textForLayout = _controller.text.isEmpty ? ' ' : _controller.text;
        final baseTextPainter = _plainTextPainter(
          text: textForLayout,
          textStyle: _textStyle,
          maxWidth: constraints.maxWidth,
          textScaler: textScaler,
        );
        final baseLineMetrics = baseTextPainter.computeLineMetrics();
        final lineGaps = baseLineMetrics.isEmpty
            ? const <double>[]
            : _lineExtraGaps(
                textPainter: baseTextPainter,
                lineMetrics: baseLineMetrics,
                textLength: textForLayout.length,
                rangeTags: _block.rangeTags,
                activeRailRange: activeRailRange,
                activeRailGapPx: activeRailGapPx,
              );
        final textPainter = _richTextPainter(
          text: textForLayout,
          textStyle: _textStyle,
          maxWidth: constraints.maxWidth,
          textScaler: textScaler,
          rangeTags: _block.rangeTags,
          activeRailRange: activeRailRange,
          activeRailGapPx: activeRailGapPx,
        );
        final lineMetrics = textPainter.computeLineMetrics();
        final visualLines = _visualTextLines(
          textPainter: textPainter,
          lineMetrics: lineMetrics,
          textLength: textForLayout.length,
        );
        final editorHeight =
            _textContentPadding.vertical +
            textPainter.height +
            _editorBottomSlack;
        _lastTextLayoutWidth = constraints.maxWidth;
        _lastVisualLines = visualLines;
        final underlineMarkers = _secondaryUnderlineMarkers(
          text: _controller.text,
          rangeTags: _block.rangeTags,
          textStyle: _textStyle,
          maxWidth: constraints.maxWidth,
          textScaler: textScaler,
          contentPadding: _textContentPadding,
          activeRailRange: activeRailRange,
          activeRailGapPx: activeRailGapPx,
        );
        final railPlacement = _selectionRailPlacement(
          text: _controller.text,
          textStyle: _textStyle,
          maxWidth: constraints.maxWidth,
          textScaler: textScaler,
          contentPadding: _textContentPadding,
          railTopTextGap: _railTopTextGap,
          rangeTags: _block.rangeTags,
          activeRailRange: activeRailRange,
          activeRailGapPx: activeRailGapPx,
        );
        _logTextLayout(
          textLength: _controller.text.length,
          maxWidth: constraints.maxWidth,
          editorHeight: editorHeight,
          lineCount: lineMetrics.length,
          visualLineCount: visualLines.length,
          lineGaps: lineGaps,
          activeRailRange: activeRailRange,
          activeRailGapPx: activeRailGapPx,
          textScaler: textScaler,
        );
        _logRailPlacement(railPlacement);
        _logUnderlineMarkers(underlineMarkers);
        return SizedBox(
          height: editorHeight,
          child: Stack(
            key: const ValueKey('note-text-field-layout-stack'),
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TextField(
                  key: const ValueKey('note-text-chunk-field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: _block.text.isEmpty,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  cursorColor: const Color(0xFF111827),
                  decoration: const InputDecoration(
                    hintText: 'Írd ide a chunk tartalmát',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: _textContentPadding,
                  ),
                  style: _textStyle,
                  scrollPhysics: const NeverScrollableScrollPhysics(),
                  selectionHeightStyle: BoxHeightStyle.tight,
                  selectionWidthStyle: BoxWidthStyle.tight,
                  onTap: () {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _updateSelectionState(source: 'tap');
                      }
                    });
                  },
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _TextSecondaryUnderlinePainter(
                      text: _controller.text,
                      rangeTags: _block.rangeTags,
                      textStyle: _textStyle,
                      maxWidth: constraints.maxWidth,
                      textScaler: textScaler,
                      contentPadding: _textContentPadding,
                      activeRailRange: activeRailRange,
                      activeRailGapPx: activeRailGapPx,
                    ),
                  ),
                ),
              ),
              for (final marker in underlineMarkers)
                Positioned(
                  key: ValueKey(
                    marker.boxIndex == 0
                        ? 'note-text-secondary-underline-${marker.id}-${marker.index}'
                        : 'note-text-secondary-underline-${marker.id}-${marker.index}-${marker.boxIndex}',
                  ),
                  left: marker.left,
                  top: marker.top,
                  child: SizedBox(width: marker.width, height: 2),
                ),
              if (railPlacement != null)
                Positioned(
                  key: const ValueKey('note-text-inline-selection-rail'),
                  left: 0,
                  right: 0,
                  top: railPlacement.top,
                  child: _buildSelectionRail(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _logTextLayout({
    required int textLength,
    required double maxWidth,
    required double editorHeight,
    required int lineCount,
    required int visualLineCount,
    required List<double> lineGaps,
    required TextRange? activeRailRange,
    required double activeRailGapPx,
    required TextScaler textScaler,
  }) {
    final nonZeroGaps = <String>[];
    for (var index = 0; index < lineGaps.length; index += 1) {
      final gap = lineGaps[index];
      if (gap > 0) {
        nonZeroGaps.add('$index:${gap.toStringAsFixed(1)}');
      }
    }
    final signature =
        '$textLength:${maxWidth.toStringAsFixed(1)}:'
        '${editorHeight.toStringAsFixed(1)}:$lineCount:$visualLineCount:'
        '${activeRailRange?.start}-${activeRailRange?.end}:'
        '${activeRailGapPx.toStringAsFixed(1)}:${nonZeroGaps.join('|')}:'
        '${textScaler.scale(_textStyle.fontSize ?? 16).toStringAsFixed(1)}';
    if (_lastLayoutLogSignature == signature) {
      return;
    }
    _lastLayoutLogSignature = signature;
    DebugConsole.log(
      '[TextChunkLayout] build chars=$textLength '
      'width=${maxWidth.toStringAsFixed(1)} '
      'height=${editorHeight.toStringAsFixed(1)} '
      'lines=$lineCount visualLines=$visualLineCount '
      'scaledFont=${textScaler.scale(_textStyle.fontSize ?? 16).toStringAsFixed(1)} '
      'rail=${activeRailRange == null ? 'none' : '${activeRailRange.start}-${activeRailRange.end}'} '
      'railGap=${activeRailGapPx.toStringAsFixed(1)} '
      'lineGaps=${nonZeroGaps.isEmpty ? 'none' : nonZeroGaps.join(',')}',
    );
  }

  void _logRailPlacement(({double top})? placement) {
    final signature = placement == null
        ? 'none'
        : '${placement.top.toStringAsFixed(1)}:${_selectionRailHeight.toStringAsFixed(1)}';
    if (_lastRailLogSignature == signature) {
      return;
    }
    _lastRailLogSignature = signature;
    DebugConsole.log(
      '[TextChunkLayout] rail placement '
      '${placement == null ? 'none' : 'top=${placement.top.toStringAsFixed(1)} height=${_selectionRailHeight.toStringAsFixed(1)} reserved=${_selectionRailReservedHeight.toStringAsFixed(1)}'}',
    );
  }

  void _logUnderlineMarkers(
    List<
      ({
        String id,
        int index,
        int boxIndex,
        double left,
        double top,
        double width,
        Color color,
      })
    >
    markers,
  ) {
    final first = markers.isEmpty
        ? 'none'
        : '${markers.first.id}:${markers.first.index}:'
              '${markers.first.left.toStringAsFixed(1)},'
              '${markers.first.top.toStringAsFixed(1)},'
              '${markers.first.width.toStringAsFixed(1)}';
    final signature = '${markers.length}:$first';
    if (_lastUnderlineLogSignature == signature) {
      return;
    }
    _lastUnderlineLogSignature = signature;
    DebugConsole.log(
      '[TextChunkLayout] underline markers count=${markers.length} first=$first',
    );
  }
}

class _VisualTextLine {
  const _VisualTextLine({
    required this.index,
    required this.start,
    required this.end,
    required this.top,
    required this.bottom,
  });

  final int index;
  final int start;
  final int end;
  final double top;
  final double bottom;
}

class _TextEdit {
  const _TextEdit({
    required this.offset,
    required this.deleteCount,
    required this.insertText,
  });

  final int offset;
  final int deleteCount;
  final String insertText;
}

({String text, List<NoteTextRangeTag> rangeTags}) _applyTextEdits({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required List<_TextEdit> edits,
}) {
  var currentText = text;
  var currentTags = rangeTags;
  var shift = 0;
  final sorted = [...edits]..sort((a, b) => a.offset.compareTo(b.offset));
  for (final edit in sorted) {
    final start = (edit.offset + shift).clamp(0, currentText.length).toInt();
    final end = (start + edit.deleteCount)
        .clamp(start, currentText.length)
        .toInt();
    final nextText = currentText.replaceRange(start, end, edit.insertText);
    currentTags = _adjustRangeTagsForEdit(
      oldText: currentText,
      newText: nextText,
      tags: currentTags,
    );
    shift += edit.insertText.length - edit.deleteCount;
    currentText = nextText;
  }
  return (text: currentText, rangeTags: currentTags);
}

int _offsetAfterTextEdits(int offset, List<_TextEdit> edits) {
  var result = offset;
  for (final edit in edits) {
    if (edit.offset <= offset) {
      result += edit.insertText.length - edit.deleteCount;
    }
  }
  return result;
}

List<_TextEdit> _paragraphIndentEdits(
  String text, {
  required List<int> lineStarts,
  required int delta,
}) {
  final edits = <_TextEdit>[];
  final uniqueStarts = lineStarts.toSet().toList()..sort();
  for (final offset in uniqueStarts) {
    if (offset < 0 || offset >= text.length) {
      continue;
    }
    if (text.codeUnitAt(offset) == 10) {
      continue;
    }
    if (delta > 0) {
      edits.add(_TextEdit(offset: offset, deleteCount: 0, insertText: '  '));
      continue;
    }
    if (delta < 0 && text.startsWith('  ', offset)) {
      edits.add(_TextEdit(offset: offset, deleteCount: 2, insertText: ''));
      continue;
    }
    if (delta < 0 && text.startsWith(' ', offset)) {
      edits.add(_TextEdit(offset: offset, deleteCount: 1, insertText: ''));
    }
  }
  return edits;
}

class _TextChunkEditingController extends TextEditingController {
  _TextChunkEditingController({
    required String text,
    required List<NoteTextRangeTag> rangeTags,
  }) : _rangeTags = rangeTags,
       super(text: text);

  List<NoteTextRangeTag> _rangeTags;
  TextRange? activeRailRange;
  double activeRailGapPx = 0;

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
    return _buildTextChunkTextSpan(
      textValue: text,
      baseStyle: style,
      rangeTags: _rangeTags,
      activeRailRange: activeRailRange,
      activeRailGapPx: activeRailGapPx,
      textScaler: MediaQuery.textScalerOf(context),
    );
  }
}

class _TextSecondaryUnderlinePainter extends CustomPainter {
  const _TextSecondaryUnderlinePainter({
    required this.text,
    required this.rangeTags,
    required this.textStyle,
    required this.maxWidth,
    required this.textScaler,
    required this.contentPadding,
    required this.activeRailRange,
    required this.activeRailGapPx,
  });

  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final TextStyle textStyle;
  final double maxWidth;
  final TextScaler textScaler;
  final EdgeInsets contentPadding;
  final TextRange? activeRailRange;
  final double activeRailGapPx;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || rangeTags.isEmpty || maxWidth <= 0) {
      return;
    }
    final markers = _secondaryUnderlineMarkers(
      text: text,
      rangeTags: rangeTags,
      textStyle: textStyle,
      maxWidth: maxWidth,
      textScaler: textScaler,
      contentPadding: contentPadding,
      activeRailRange: activeRailRange,
      activeRailGapPx: activeRailGapPx,
    );
    for (final marker in markers) {
      final paint = Paint()
        ..color = marker.color
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(marker.left, marker.top),
        Offset(marker.left + marker.width, marker.top),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TextSecondaryUnderlinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.rangeTags != rangeTags ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.maxWidth != maxWidth ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.contentPadding != contentPadding ||
        oldDelegate.activeRailRange != activeRailRange ||
        oldDelegate.activeRailGapPx != activeRailGapPx;
  }
}

List<
  ({
    String id,
    int index,
    int boxIndex,
    double left,
    double top,
    double width,
    Color color,
  })
>
_secondaryUnderlineMarkers({
  required String text,
  required List<NoteTextRangeTag> rangeTags,
  required TextStyle textStyle,
  required double maxWidth,
  required TextScaler textScaler,
  required EdgeInsets contentPadding,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
}) {
  if (text.isEmpty || rangeTags.isEmpty || maxWidth <= 0) {
    return const [];
  }
  final textPainter = _richTextPainter(
    text: text,
    textStyle: textStyle,
    maxWidth: maxWidth,
    textScaler: textScaler,
    rangeTags: rangeTags,
    activeRailRange: activeRailRange,
    activeRailGapPx: activeRailGapPx,
  );
  final lineMetrics = textPainter.computeLineMetrics();
  if (lineMetrics.isEmpty) {
    return const [];
  }
  final groups = _mergedTextTagGroups(
    rangeTags: rangeTags,
    textLength: text.length,
  );
  final markers =
      <
        ({
          String id,
          int index,
          int boxIndex,
          double left,
          double top,
          double width,
          Color color,
        })
      >[];
  for (final group in groups) {
    if (group.tags.length <= 1) {
      continue;
    }
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: group.start, extentOffset: group.end),
      boxHeightStyle: BoxHeightStyle.tight,
      boxWidthStyle: BoxWidthStyle.tight,
    );
    for (var index = 1; index < group.tags.length; index += 1) {
      for (var boxIndex = 0; boxIndex < boxes.length; boxIndex += 1) {
        final box = boxes[boxIndex];
        markers.add((
          id: group.id,
          index: index,
          boxIndex: boxIndex,
          left: box.left,
          top: contentPadding.top + box.bottom + 2 + ((index - 1) * 4.0),
          width: box.right - box.left,
          color: Color(group.tags[index].resolvedColorValue),
        ));
      }
    }
  }
  return markers;
}

List<({String id, int start, int end, List<NoteKnowledgeTag> tags})>
_mergedTextTagGroups({
  required List<NoteTextRangeTag> rangeTags,
  required int textLength,
}) {
  final groups =
      <
        String,
        ({String id, int start, int end, List<NoteKnowledgeTag> tags})
      >{};
  for (final rawTag in rangeTags) {
    final range = rawTag.clampToTextLength(textLength);
    if (!range.isValid) {
      continue;
    }
    final key = '${range.start}:${range.end}';
    final existing = groups[key];
    final tags = existing == null ? <NoteKnowledgeTag>[] : [...existing.tags];
    for (final tag in range.resolvedTags) {
      if (!tags.any((current) => current.metadataText == tag.metadataText)) {
        tags.add(tag);
      }
    }
    groups[key] = (
      id: existing?.id ?? range.id,
      start: range.start,
      end: range.end,
      tags: tags,
    );
  }
  return groups.values.toList(growable: false);
}

TextSpan _buildTextChunkTextSpan({
  required String textValue,
  required TextStyle? baseStyle,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
  required TextScaler textScaler,
}) {
  if (textValue.isEmpty) {
    return TextSpan(style: baseStyle, text: textValue);
  }
  final breakpoints = <int>{0, textValue.length};
  for (final rawTag in rangeTags) {
    final range = rawTag.clampToTextLength(textValue.length);
    if (!range.isValid) {
      continue;
    }
    breakpoints.add(range.start);
    breakpoints.add(range.end);
  }
  final railRange = _validTextRange(
    activeRailRange,
    textLength: textValue.length,
  );
  if (railRange != null) {
    breakpoints.add(railRange.start);
    breakpoints.add(railRange.end);
  }
  final sorted = breakpoints.toList()..sort();
  final spans = <InlineSpan>[];
  for (var i = 0; i < sorted.length - 1; i += 1) {
    final start = sorted[i];
    final end = sorted[i + 1];
    if (start >= end) {
      continue;
    }
    final tags = _tagsForSegment(rangeTags, start, end, textValue.length);
    final extraHeight = _extraHeightForSegment(
      tags: tags,
      start: start,
      end: end,
      activeRailRange: railRange,
      activeRailGapPx: activeRailGapPx,
    );
    spans.add(
      TextSpan(
        text: textValue.substring(start, end),
        style: _segmentTextStyle(
          tags: tags,
          extraHeightPx: extraHeight,
          baseStyle: baseStyle,
          textScaler: textScaler,
        ),
      ),
    );
  }
  return TextSpan(style: baseStyle, children: spans);
}

TextStyle? _segmentTextStyle({
  required List<NoteKnowledgeTag> tags,
  required double extraHeightPx,
  required TextStyle? baseStyle,
  required TextScaler textScaler,
}) {
  final taggedStyle = tags.isEmpty ? null : _taggedTextStyle(tags, alpha: 0.22);
  final gapStyle = extraHeightPx <= 0
      ? null
      : TextStyle(
          height: _lineHeightMultiplier(
            extraHeightPx: extraHeightPx,
            baseStyle: baseStyle,
            textScaler: textScaler,
          ),
        );
  if (taggedStyle == null) {
    return gapStyle;
  }
  return taggedStyle.merge(gapStyle);
}

double _lineHeightMultiplier({
  required double extraHeightPx,
  required TextStyle? baseStyle,
  required TextScaler textScaler,
}) {
  final fontSize = baseStyle?.fontSize ?? 16.0;
  final scaledFontSize = textScaler.scale(fontSize);
  return (scaledFontSize + extraHeightPx) / scaledFontSize;
}

double _extraHeightForSegment({
  required List<NoteKnowledgeTag> tags,
  required int start,
  required int end,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
}) {
  var extra = tags.length > 1 ? _secondaryUnderlineGap(tags.length) : 0.0;
  if (activeRailRange != null &&
      activeRailRange.start < end &&
      activeRailRange.end > start) {
    extra = extra > activeRailGapPx ? extra : activeRailGapPx;
  }
  return extra;
}

double _secondaryUnderlineGap(int tagCount) {
  if (tagCount <= 1) {
    return 0;
  }
  return 8 + ((tagCount - 1) * 4.0);
}

TextPainter _plainTextPainter({
  required String text,
  required TextStyle textStyle,
  required double maxWidth,
  required TextScaler textScaler,
}) {
  return TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
}

TextPainter _richTextPainter({
  required String text,
  required TextStyle textStyle,
  required double maxWidth,
  required TextScaler textScaler,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
}) {
  return TextPainter(
    text: _buildTextChunkTextSpan(
      textValue: text,
      baseStyle: textStyle,
      rangeTags: rangeTags,
      activeRailRange: activeRailRange,
      activeRailGapPx: activeRailGapPx,
      textScaler: textScaler,
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
  )..layout(maxWidth: maxWidth);
}

({double top})? _selectionRailPlacement({
  required String text,
  required TextStyle textStyle,
  required double maxWidth,
  required TextScaler textScaler,
  required EdgeInsets contentPadding,
  required double railTopTextGap,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
}) {
  final range = _validTextRange(activeRailRange, textLength: text.length);
  if (range == null || maxWidth <= 0) {
    return null;
  }
  final textPainter = _richTextPainter(
    text: text,
    textStyle: textStyle,
    maxWidth: maxWidth,
    textScaler: textScaler,
    rangeTags: rangeTags,
    activeRailRange: range,
    activeRailGapPx: activeRailGapPx,
  );
  final lineMetrics = textPainter.computeLineMetrics();
  if (lineMetrics.isEmpty) {
    return null;
  }
  final boxes = textPainter.getBoxesForSelection(
    TextSelection(baseOffset: range.start, extentOffset: range.end),
    boxHeightStyle: BoxHeightStyle.tight,
    boxWidthStyle: BoxWidthStyle.tight,
  );
  if (boxes.isEmpty) {
    return null;
  }
  final firstBox = boxes.first;
  return (top: contentPadding.top + firstBox.bottom + railTopTextGap);
}

List<_VisualTextLine> _visualTextLines({
  required TextPainter textPainter,
  required List<LineMetrics> lineMetrics,
  required int textLength,
}) {
  final lines = <_VisualTextLine>[];
  if (textLength <= 0) {
    return lines;
  }
  for (var index = 0; index < lineMetrics.length; index += 1) {
    final line = lineMetrics[index];
    final top = line.baseline - line.ascent;
    final bottom = line.baseline + line.descent;
    final position = textPainter.getPositionForOffset(
      Offset(0, (top + bottom) / 2),
    );
    final boundary = textPainter.getLineBoundary(position);
    final start = boundary.start.clamp(0, textLength).toInt();
    final end = boundary.end.clamp(0, textLength).toInt();
    if (start >= end) {
      continue;
    }
    lines.add(
      _VisualTextLine(
        index: index,
        start: start,
        end: end,
        top: top,
        bottom: bottom,
      ),
    );
  }
  return lines;
}

List<double> _lineExtraGaps({
  required TextPainter textPainter,
  required List<LineMetrics> lineMetrics,
  required int textLength,
  required List<NoteTextRangeTag> rangeTags,
  required TextRange? activeRailRange,
  required double activeRailGapPx,
}) {
  final gaps = List<double>.filled(lineMetrics.length, 0);
  final railRange = _validTextRange(activeRailRange, textLength: textLength);
  if (railRange != null && activeRailGapPx > 0) {
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: railRange.start, extentOffset: railRange.end),
      boxHeightStyle: BoxHeightStyle.tight,
      boxWidthStyle: BoxWidthStyle.tight,
    );
    if (boxes.isNotEmpty) {
      final lineIndex = _lineIndexForBox(lineMetrics, boxes.first);
      gaps[lineIndex] = gaps[lineIndex] > activeRailGapPx
          ? gaps[lineIndex]
          : activeRailGapPx;
    }
  }
  for (final group in _mergedTextTagGroups(
    rangeTags: rangeTags,
    textLength: textLength,
  )) {
    if (group.tags.length <= 1) {
      continue;
    }
    final underlineGap = _secondaryUnderlineGap(group.tags.length);
    final boxes = textPainter.getBoxesForSelection(
      TextSelection(baseOffset: group.start, extentOffset: group.end),
      boxHeightStyle: BoxHeightStyle.tight,
      boxWidthStyle: BoxWidthStyle.tight,
    );
    for (final box in boxes) {
      final lineIndex = _lineIndexForBox(lineMetrics, box);
      gaps[lineIndex] = gaps[lineIndex] > underlineGap
          ? gaps[lineIndex]
          : underlineGap;
    }
  }
  return gaps;
}

int _lineIndexForBox(List<LineMetrics> lineMetrics, TextBox box) {
  final centerY = (box.top + box.bottom) / 2;
  for (var index = 0; index < lineMetrics.length; index += 1) {
    final line = lineMetrics[index];
    final top = line.baseline - line.ascent;
    final bottom = line.baseline + line.descent;
    if (centerY >= top - 0.5 && centerY <= bottom + 0.5) {
      return index;
    }
  }
  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var index = 0; index < lineMetrics.length; index += 1) {
    final line = lineMetrics[index];
    final top = line.baseline - line.ascent;
    final bottom = line.baseline + line.descent;
    final distance = centerY < top ? top - centerY : centerY - bottom;
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearestIndex = index;
    }
  }
  return nearestIndex;
}

TextRange? _validTextRange(TextRange? range, {required int textLength}) {
  if (range == null || textLength <= 0) {
    return null;
  }
  final start = range.start.clamp(0, textLength).toInt();
  final end = range.end.clamp(0, textLength).toInt();
  if (end <= start) {
    return null;
  }
  return TextRange(start: start, end: end);
}

List<NoteKnowledgeTag> _tagsForSegment(
  List<NoteTextRangeTag> rangeTags,
  int start,
  int end,
  int textLength,
) {
  final tags = <NoteKnowledgeTag>[];
  for (final rawTag in rangeTags) {
    final range = rawTag.clampToTextLength(textLength);
    if (!range.isValid || range.start >= end || range.end <= start) {
      continue;
    }
    for (final tag in range.resolvedTags) {
      if (!tags.any((current) => current.metadataText == tag.metadataText)) {
        tags.add(tag);
      }
    }
  }
  return tags;
}

TextStyle _taggedTextStyle(
  List<NoteKnowledgeTag> tags, {
  required double alpha,
}) {
  if (tags.isEmpty) {
    return const TextStyle();
  }
  return TextStyle(
    backgroundColor: Color(
      tags.first.resolvedColorValue,
    ).withValues(alpha: alpha),
    fontWeight: FontWeight.w600,
  );
}

List<NoteTextRangeTag> _adjustRangeTagsForEdit({
  required String oldText,
  required String newText,
  required List<NoteTextRangeTag> tags,
}) {
  if (oldText == newText) {
    return tags
        .map((tag) => tag.clampToTextLength(newText.length))
        .where((tag) => tag.isValid)
        .toList(growable: false);
  }
  var prefix = 0;
  while (prefix < oldText.length &&
      prefix < newText.length &&
      oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
    prefix += 1;
  }
  var oldSuffix = oldText.length;
  var newSuffix = newText.length;
  while (oldSuffix > prefix &&
      newSuffix > prefix &&
      oldText.codeUnitAt(oldSuffix - 1) == newText.codeUnitAt(newSuffix - 1)) {
    oldSuffix -= 1;
    newSuffix -= 1;
  }
  final delta = (newSuffix - prefix) - (oldSuffix - prefix);
  return tags
      .map((tag) {
        if (tag.end <= prefix) {
          return tag;
        }
        if (tag.start >= oldSuffix) {
          return NoteTextRangeTag(
            id: tag.id,
            start: tag.start + delta,
            end: tag.end + delta,
            tag: tag.tag,
            tags: tag.tags,
          );
        }
        final replacementEnd = newSuffix;
        if (tag.start >= prefix && tag.end <= oldSuffix) {
          return NoteTextRangeTag(
            id: tag.id,
            start: prefix,
            end: replacementEnd,
            tag: tag.tag,
            tags: tag.tags,
          );
        }
        return NoteTextRangeTag(
          id: tag.id,
          start: tag.start < prefix ? tag.start : prefix,
          end: (tag.end + delta) > replacementEnd
              ? tag.end + delta
              : replacementEnd,
          tag: tag.tag,
          tags: tag.tags,
        );
      })
      .map((tag) => tag.clampToTextLength(newText.length))
      .where((tag) => tag.isValid)
      .toList(growable: false);
}

void unawaited(Future<void> future) {}
