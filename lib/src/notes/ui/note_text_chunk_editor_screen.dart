import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../debug/debug_console.dart';
import '../data/tag_repository.dart';
import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tagged_text_visual.dart';
import 'tag_manager_sheet.dart';

class NoteTextChunkEditorScreen extends StatefulWidget {
  const NoteTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
    this.availableTags = const [],
    this.tagRepository,
    this.onDelete,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final List<NoteKnowledgeTag> availableTags;
  final TagRepository? tagRepository;
  final VoidCallback? onDelete;

  @override
  State<NoteTextChunkEditorScreen> createState() =>
      _NoteTextChunkEditorScreenState();
}

class _NoteTextChunkEditorScreenState extends State<NoteTextChunkEditorScreen> {
  static const double _paragraphIndentWidth = 24;

  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  late NoteBlock _block;
  late final NoteTaggedTextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _textScrollController;
  final GlobalKey _textFieldHostKey = GlobalKey();
  final GlobalKey _tagOverlayKey = GlobalKey();
  TextSelection _selection = const TextSelection.collapsed(offset: -1);
  bool _syncingController = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  bool _tagGeometryRefreshScheduled = false;
  double _textScrollOffset = 0;
  RenderEditable? _tagRenderEditable;
  Offset _tagEditableOffset = Offset.zero;
  String? _lastVisualLogSignature;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = NoteTaggedTextEditingController(
      text: widget.block.text,
      rangeTags: widget.block.rangeTags,
    );
    _selection = _controller.selection;
    _controller.addListener(_handleControllerValueChanged);
    _focusNode = FocusNode();
    _textScrollController = ScrollController()
      ..addListener(_handleTextScrollChanged);
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _block = widget.block;
    if (oldWidget.block.id != widget.block.id ||
        widget.block.text != _controller.text) {
      _syncControllerText(widget.block.text);
    }
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block.rangeTags != widget.block.rangeTags) {
      _controller.setRangeTags(
        _clampRangeTags(widget.block.rangeTags, widget.block.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerValueChanged);
    _controller.dispose();
    _focusNode.dispose();
    _textScrollController.removeListener(_handleTextScrollChanged);
    _textScrollController.dispose();
    super.dispose();
  }

  void _handleTextScrollChanged() {
    final nextOffset = _textScrollController.offset;
    if (nextOffset == _textScrollOffset) {
      return;
    }
    setState(() => _textScrollOffset = nextOffset);
    _scheduleTagGeometryRefresh();
  }

  void _syncControllerText(String text) {
    _syncingController = true;
    try {
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _selection = _controller.selection;
      _lastVisualLogSignature = null;
      _scheduleTagGeometryRefresh();
    } finally {
      _syncingController = false;
    }
  }

  void _handleControllerValueChanged() {
    if (_syncingController) {
      return;
    }
    final value = _controller.value;
    final textChanged = value.text != _block.text;
    final selectionChanged = value.selection != _selection;
    if (!textChanged && !selectionChanged) {
      return;
    }
    var nextBlock = _block;
    if (textChanged) {
      nextBlock = _block.copyWith(
        text: value.text,
        rangeTags: _clampRangeTags(_block.rangeTags, value.text.length),
        paragraphStyles: _clampParagraphStyles(
          _block.paragraphStyles,
          value.text.length,
        ),
        clearIndex: true,
      );
      DebugConsole.log(
        '[TextChunkNative] text changed chars=${value.text.length} '
        'ranges=${nextBlock.rangeTags.length}',
      );
    }
    setState(() {
      _selection = value.selection;
      _block = nextBlock;
    });
    _scheduleTagGeometryRefresh();
    if (textChanged) {
      _controller.setRangeTags(nextBlock.rangeTags);
    }
    if (textChanged) {
      widget.onChanged(nextBlock);
    }
  }

  List<NoteTextRangeTag> _clampRangeTags(
    List<NoteTextRangeTag> tags,
    int textLength,
  ) {
    return tags
        .map((tag) => tag.clampToTextLength(textLength))
        .where((tag) => tag.isValid)
        .toList(growable: false);
  }

  List<NoteTextParagraphStyle> _clampParagraphStyles(
    List<NoteTextParagraphStyle> styles,
    int textLength,
  ) {
    return styles
        .map((style) => style.clampToTextLength(textLength))
        .where((style) => style.isValid && style.level > 0)
        .toList(growable: false);
  }

  void _scheduleTagGeometryRefresh() {
    if (_tagGeometryRefreshScheduled) {
      return;
    }
    _tagGeometryRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tagGeometryRefreshScheduled = false;
      if (!mounted) {
        return;
      }
      final editable = _findRenderEditable(
        _textFieldHostKey.currentContext?.findRenderObject(),
      );
      final layerBox = _tagOverlayKey.currentContext?.findRenderObject();
      var nextOffset = Offset.zero;
      if (editable != null && layerBox is RenderBox && editable.attached) {
        nextOffset =
            editable.localToGlobal(Offset.zero) -
            layerBox.localToGlobal(Offset.zero);
      }
      _logVisualGeometry(editable, nextOffset);
      if (editable != _tagRenderEditable || nextOffset != _tagEditableOffset) {
        setState(() {
          _tagRenderEditable = editable;
          _tagEditableOffset = nextOffset;
        });
      }
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

  void _logVisualGeometry(RenderEditable? editable, Offset editableOffset) {
    final countMarkerRuns = noteTaggedTextCountMarkerRuns(
      text: _controller.text,
      rangeTags: _block.rangeTags,
    );
    final paragraphInset = _visibleParagraphInset();
    final markerLabel = countMarkerRuns
        .map((run) => '${run.start}-${run.end}/x${run.tagCount}')
        .join(' ');
    final boxesLabel = editable == null
        ? 'none'
        : countMarkerRuns
              .map((run) {
                final boxes = editable.getBoxesForSelection(
                  TextSelection(baseOffset: run.start, extentOffset: run.end),
                );
                final first = boxes.isEmpty ? null : boxes.first;
                final firstLabel = first == null
                    ? 'empty'
                    : '${first.left.toStringAsFixed(1)},'
                          '${first.top.toStringAsFixed(1)},'
                          '${first.right.toStringAsFixed(1)},'
                          '${first.bottom.toStringAsFixed(1)}';
                return '${run.start}-${run.end}:${boxes.length}:$firstLabel';
              })
              .join(' ');
    final signature =
        '${_controller.text.length}|${_selectionLabel(_selection)}|'
        '${_block.rangeTags.length}|$markerLabel|'
        '${editableOffset.dx.toStringAsFixed(1)},'
        '${editableOffset.dy.toStringAsFixed(1)}|'
        '${_textScrollOffset.toStringAsFixed(1)}|'
        '${paragraphInset.toStringAsFixed(1)}|'
        '${_paragraphStylesLabel(_block.paragraphStyles)}|$boxesLabel';
    if (signature == _lastVisualLogSignature) {
      return;
    }
    _lastVisualLogSignature = signature;
    DebugConsole.log(
      '[TextChunkVisual] textLen=${_controller.text.length} '
      'selection=${_selectionLabel(_selection)} '
      'ranges=${_block.rangeTags.length} countMarkers=[$markerLabel] '
      'editable=${editable != null} '
      'editableOffset=(${editableOffset.dx.toStringAsFixed(1)},'
      '${editableOffset.dy.toStringAsFixed(1)}) '
      'scroll=${_textScrollOffset.toStringAsFixed(1)} '
      'paragraphInset=${paragraphInset.toStringAsFixed(1)} '
      'paragraphStyles=[${_paragraphStylesLabel(_block.paragraphStyles)}] '
      'boxes=[$boxesLabel]',
    );
  }

  String _selectionLabel(TextSelection selection) {
    if (!selection.isValid) {
      return 'null';
    }
    return '${selection.start}-${selection.end}';
  }

  String _paragraphStylesLabel(List<NoteTextParagraphStyle> styles) {
    return styles
        .map((style) => '${style.start}-${style.end}/l${style.level}')
        .join(' ');
  }

  String _paragraphRangesLabel(List<TextRange> ranges) {
    return ranges.map((range) => '${range.start}-${range.end}').join(' ');
  }

  void _emitBlock(NoteBlock block) {
    _controller.setRangeTags(
      _clampRangeTags(block.rangeTags, _controller.text.length),
    );
    setState(() => _block = block);
    _scheduleTagGeometryRefresh();
    widget.onChanged(block);
  }

  void _emitTitle(String value) {
    _emitBlock(_block.copyWith(title: value, clearIndex: true));
  }

  Future<void> _tagChunk() async {
    await showTagManagerSheet(
      context,
      initialTags: _block.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) {
        _emitBlock(_block.copyWith(tags: tags, clearIndex: true));
      },
      availableTags: widget.availableTags,
      title: 'Chunk tagek',
    );
    if (!mounted) {
      return;
    }
    _focusNode.requestFocus();
  }

  void _deleteChunkTag(NoteKnowledgeTag tag) {
    _emitBlock(
      _block.copyWith(
        tags: _block.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
        clearIndex: true,
      ),
    );
  }

  Future<void> _tagSelection() async {
    final target = _selectionTargetRange();
    if (target == null) {
      return;
    }
    final initialTags = _tagsForRange(target);
    await showTagManagerSheet(
      context,
      initialTags: initialTags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _replaceRangeTags(target, tags),
      availableTags: widget.availableTags,
      title: 'Kijelölt szöveg tagek',
    );
    if (!mounted) {
      return;
    }
    _focusNode.requestFocus();
  }

  void _deleteSelectedTag() {
    final target = _selectionTargetRange();
    if (target == null) {
      return;
    }
    _replaceRangeTags(target, const <NoteKnowledgeTag>[]);
  }

  void _deleteRailTag(NoteKnowledgeTag tag) {
    final target = _selectionTargetRange();
    if (target == null) {
      return;
    }
    final remaining = _tagsForRange(target)
        .where((existing) => existing.metadataText != tag.metadataText)
        .toList(growable: false);
    _replaceRangeTags(target, remaining);
  }

  void _replaceRangeTags(TextRange target, List<NoteKnowledgeTag> tags) {
    final normalized = _normalizeRange(target.start, target.end);
    if (normalized == null) {
      return;
    }
    final retained = _block.rangeTags
        .where(
          (rangeTag) =>
              rangeTag.start != normalized.start ||
              rangeTag.end != normalized.end,
        )
        .toList(growable: true);
    if (tags.isNotEmpty) {
      retained.add(
        NoteTextRangeTag(
          id:
              _existingRangeId(normalized) ??
              'range-${normalized.start}-${normalized.end}',
          start: normalized.start,
          end: normalized.end,
          tag: tags.first,
          tags: tags,
        ),
      );
    }
    retained.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      return startCompare == 0 ? a.end.compareTo(b.end) : startCompare;
    });
    _emitBlock(_block.copyWith(rangeTags: retained, clearIndex: true));
  }

  String? _existingRangeId(TextRange target) {
    for (final rangeTag in _block.rangeTags) {
      if (rangeTag.start == target.start && rangeTag.end == target.end) {
        return rangeTag.id;
      }
    }
    return null;
  }

  List<NoteKnowledgeTag> _tagsForRange(TextRange target) {
    final normalized = _normalizeRange(target.start, target.end);
    if (normalized == null) {
      return const [];
    }
    final byKey = <String, NoteKnowledgeTag>{};
    for (final rangeTag in _block.rangeTags) {
      if (rangeTag.end <= normalized.start ||
          rangeTag.start >= normalized.end) {
        continue;
      }
      for (final tag in rangeTag.resolvedTags) {
        if (tag.metadataText.isNotEmpty) {
          byKey[tag.metadataText] = tag;
        }
      }
    }
    return byKey.values.toList(growable: false);
  }

  List<NoteKnowledgeTag> get _activeRangeTags {
    final target = _selectionTargetRange();
    return target == null ? const [] : _tagsForRange(target);
  }

  TextRange? _selectionTargetRange() {
    if (!_selection.isValid) {
      return null;
    }
    if (!_selection.isCollapsed) {
      return _normalizeRange(_selection.start, _selection.end);
    }
    final offset = _selection.extentOffset;
    for (final rangeTag in _block.rangeTags) {
      if (!rangeTag.isValid) {
        continue;
      }
      if (offset >= rangeTag.start && offset <= rangeTag.end) {
        return TextRange(start: rangeTag.start, end: rangeTag.end);
      }
    }
    return null;
  }

  TextRange? _normalizeRange(int start, int end) {
    final normalizedStart = start.clamp(0, _controller.text.length).toInt();
    final normalizedEnd = end.clamp(0, _controller.text.length).toInt();
    final rangeStart = normalizedStart < normalizedEnd
        ? normalizedStart
        : normalizedEnd;
    final rangeEnd = normalizedStart < normalizedEnd
        ? normalizedEnd
        : normalizedStart;
    if (rangeEnd <= rangeStart) {
      return null;
    }
    return TextRange(start: rangeStart, end: rangeEnd);
  }

  bool get _shouldShowRail {
    if (!_selection.isValid) {
      return false;
    }
    if (!_selection.isCollapsed) {
      return true;
    }
    return _selectionTargetRange() != null;
  }

  void _selectTaggedRange(int direction) {
    final ranges =
        _block.rangeTags
            .where((rangeTag) => rangeTag.isValid)
            .toList(growable: false)
          ..sort((a, b) {
            final startCompare = a.start.compareTo(b.start);
            return startCompare == 0 ? a.end.compareTo(b.end) : startCompare;
          });
    if (ranges.isEmpty) {
      return;
    }
    final current = _selectionTargetRange();
    final currentIndex = current == null
        ? -1
        : ranges.indexWhere(
            (rangeTag) =>
                rangeTag.start == current.start && rangeTag.end == current.end,
          );
    final nextIndex = direction >= 0
        ? (currentIndex < 0 ? 0 : (currentIndex + 1) % ranges.length)
        : (currentIndex <= 0 ? ranges.length - 1 : currentIndex - 1);
    final next = ranges[nextIndex];
    _controller.selection = TextSelection(
      baseOffset: next.start,
      extentOffset: next.end,
    );
    _focusNode.requestFocus();
  }

  void _stepParagraphs(int delta) {
    final affected = _affectedParagraphs();
    if (affected.isEmpty) {
      return;
    }
    final affectedKeys = {
      for (final paragraph in affected) '${paragraph.start}:${paragraph.end}',
    };
    final nextStyles = <NoteTextParagraphStyle>[];
    for (final style in _block.paragraphStyles) {
      final key = '${style.start}:${style.end}';
      if (!affectedKeys.contains(key) && style.isValid && style.level > 0) {
        nextStyles.add(style);
      }
    }
    for (final paragraph in affected) {
      final current = _paragraphStyleFor(paragraph);
      final nextLevel = ((current?.level ?? 0) + delta).clamp(0, 8).toInt();
      if (nextLevel > 0) {
        nextStyles.add(
          NoteTextParagraphStyle(
            id: current?.id ?? 'p-${paragraph.start}-${paragraph.end}',
            start: paragraph.start,
            end: paragraph.end,
            level: nextLevel,
          ),
        );
      }
    }
    nextStyles.sort((a, b) {
      final startCompare = a.start.compareTo(b.start);
      return startCompare == 0 ? a.end.compareTo(b.end) : startCompare;
    });
    DebugConsole.log(
      '[TextChunkParagraph] delta=$delta '
      'selection=${_selectionLabel(_selection)} '
      'affected=[${_paragraphRangesLabel(affected)}] '
      'styles=[${_paragraphStylesLabel(nextStyles)}] '
      'textUnchanged=true',
    );
    _emitBlock(_block.copyWith(paragraphStyles: nextStyles, clearIndex: true));
    _focusNode.requestFocus();
  }

  NoteTextParagraphStyle? _paragraphStyleFor(TextRange paragraph) {
    for (final style in _block.paragraphStyles) {
      if (style.start == paragraph.start && style.end == paragraph.end) {
        return style;
      }
    }
    return null;
  }

  double _visibleParagraphInset() {
    var level = 0;
    for (final style in _block.paragraphStyles) {
      if (style.isValid && style.level > level) {
        level = style.level;
      }
    }
    return level * _paragraphIndentWidth;
  }

  List<TextRange> _affectedParagraphs() {
    final paragraphs = _paragraphRanges(_controller.text);
    if (paragraphs.isEmpty) {
      return const [];
    }
    final range = _selection.isValid
        ? (_selection.isCollapsed
              ? TextRange(
                  start: _selection.extentOffset,
                  end: _selection.extentOffset,
                )
              : TextRange(start: _selection.start, end: _selection.end))
        : TextRange(
            start: _controller.text.length,
            end: _controller.text.length,
          );
    return paragraphs
        .where(
          (paragraph) => range.start == range.end
              ? range.start >= paragraph.start && range.start <= paragraph.end
              : paragraph.start < range.end && paragraph.end > range.start,
        )
        .toList(growable: false);
  }

  List<TextRange> _paragraphRanges(String text) {
    if (text.isEmpty) {
      return const [TextRange(start: 0, end: 0)];
    }
    final ranges = <TextRange>[];
    int? paragraphStart;
    var paragraphEnd = 0;
    var lineStart = 0;
    for (var i = 0; i <= text.length; i++) {
      if (i < text.length && text.codeUnitAt(i) != 10) {
        continue;
      }
      final lineEnd = i;
      final line = text.substring(lineStart, lineEnd);
      if (line.trim().isEmpty) {
        if (paragraphStart != null && paragraphEnd > paragraphStart) {
          ranges.add(TextRange(start: paragraphStart, end: paragraphEnd));
        }
        paragraphStart = null;
      } else {
        paragraphStart ??= lineStart;
        paragraphEnd = lineEnd;
      }
      lineStart = i + 1;
    }
    if (paragraphStart != null && paragraphEnd > paragraphStart) {
      final last = ranges.isNotEmpty ? ranges.last : null;
      if (last == null ||
          last.start != paragraphStart ||
          last.end != paragraphEnd) {
        ranges.add(TextRange(start: paragraphStart, end: paragraphEnd));
      }
    }
    return ranges;
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _block.title?.trim().isNotEmpty == true
        ? _block.title!.trim()
        : (_block.type == NoteBlockType.heading ? 'Címsor' : 'Szöveg');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final railVisible = _shouldShowRail;
    final railHeight = railVisible ? (_railBottomExpanded ? 113.0 : 64.0) : 0.0;
    const editorTextStyle = TextStyle(color: Color(0xFF111827), fontSize: 16);
    final countMarkerRuns = noteTaggedTextCountMarkerRuns(
      text: _controller.text,
      rangeTags: _block.rangeTags,
    );
    final paragraphInset = _visibleParagraphInset();
    _scheduleTagGeometryRefresh();
    return Scaffold(
      key: const ValueKey('note-text-chunk-editor'),
      resizeToAvoidBottomInset: false,
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: title,
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _activeRangeTags.isNotEmpty,
        canDeleteChunk: widget.onDelete != null,
        trailingActions: [
          IconButton(
            key: const ValueKey('note-text-header-outdent'),
            tooltip: 'Kijjebb',
            onPressed: () => _stepParagraphs(-1),
            icon: const Icon(Icons.format_indent_decrease),
          ),
          IconButton(
            key: const ValueKey('note-text-header-indent'),
            tooltip: 'Beljebb',
            onPressed: () => _stepParagraphs(1),
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
                key: const ValueKey('note-text-chunk-tag-row'),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NoteTagPills(
                    tags: _block.tags,
                    prefix: 'note-text-chunk-tag-pill',
                    onDeleted: _deleteChunkTag,
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(
                        bottom: bottomInset + railHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: Padding(
                          padding: EdgeInsets.only(left: paragraphInset),
                          child: Stack(
                            children: [
                              SizedBox.expand(
                                key: _textFieldHostKey,
                                child: TextField(
                                  key: const ValueKey('note-text-plain-field'),
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  scrollController: _textScrollController,
                                  autofocus: true,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  minLines: null,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: editorTextStyle,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Írj valamit...',
                                    isCollapsed: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: SizedBox.expand(
                                    key: _tagOverlayKey,
                                    child: CustomPaint(
                                      key: const ValueKey(
                                        'note-text-range-count-marker-layer',
                                      ),
                                      foregroundPainter:
                                          NoteTaggedTextCountMarkerPainter(
                                            text: _controller.text,
                                            runs: countMarkerRuns,
                                            mode: NoteTaggedTextCountMarkerMode
                                                .fixedCorner,
                                            textStyle: editorTextStyle,
                                            textDirection: Directionality.of(
                                              context,
                                            ),
                                            scrollOffset: _textScrollOffset,
                                            renderEditable: _tagRenderEditable,
                                            editableOffset: _tagEditableOffset,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (railVisible)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: AnimatedPadding(
                        key: const ValueKey('note-text-keyboard-rail-padding'),
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.only(bottom: bottomInset),
                        child: SafeArea(
                          top: false,
                          child: KeyedSubtree(
                            key: const ValueKey('note-text-keyboard-rail'),
                            child: _TextKeyboardRail(
                              tags: _activeRangeTags,
                              bottomRowExpanded: _railBottomExpanded,
                              roundedCard: _railRoundedCard,
                              transparentBackground: _railTransparentBackground,
                              showBorder: _railBorderVisible,
                              onToggleBottomRow: () => setState(
                                () =>
                                    _railBottomExpanded = !_railBottomExpanded,
                              ),
                              onTag: () => unawaited(_tagSelection()),
                              onClearTags: _activeRangeTags.isEmpty
                                  ? null
                                  : _deleteSelectedTag,
                              onDeleteTag: _deleteRailTag,
                              onPreviousTagged: () => _selectTaggedRange(-1),
                              onNextTagged: () => _selectTaggedRange(1),
                              onOutdent: () => _stepParagraphs(-1),
                              onIndent: () => _stepParagraphs(1),
                              onToggleRounded: () => setState(
                                () => _railRoundedCard = !_railRoundedCard,
                              ),
                              onToggleTransparent: () => setState(
                                () => _railTransparentBackground =
                                    !_railTransparentBackground,
                              ),
                              onToggleBorder: () => setState(
                                () => _railBorderVisible = !_railBorderVisible,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextKeyboardRail extends StatelessWidget {
  const _TextKeyboardRail({
    required this.tags,
    required this.bottomRowExpanded,
    required this.roundedCard,
    required this.transparentBackground,
    required this.showBorder,
    required this.onToggleBottomRow,
    required this.onTag,
    required this.onClearTags,
    required this.onDeleteTag,
    required this.onPreviousTagged,
    required this.onNextTagged,
    required this.onOutdent,
    required this.onIndent,
    required this.onToggleRounded,
    required this.onToggleTransparent,
    required this.onToggleBorder,
  });

  final List<NoteKnowledgeTag> tags;
  final bool bottomRowExpanded;
  final bool roundedCard;
  final bool transparentBackground;
  final bool showBorder;
  final VoidCallback onToggleBottomRow;
  final VoidCallback onTag;
  final VoidCallback? onClearTags;
  final ValueChanged<NoteKnowledgeTag> onDeleteTag;
  final VoidCallback onPreviousTagged;
  final VoidCallback onNextTagged;
  final VoidCallback onOutdent;
  final VoidCallback onIndent;
  final VoidCallback onToggleRounded;
  final VoidCallback onToggleTransparent;
  final VoidCallback onToggleBorder;

  @override
  Widget build(BuildContext context) {
    const compactConstraints = BoxConstraints.tightFor(width: 34, height: 34);
    const compactPadding = EdgeInsets.zero;
    return NoteSelectionActionRail(
      tags: tags,
      pillPrefix: 'note-text-rail-pill',
      bottomRowExpanded: bottomRowExpanded,
      onToggleBottomRow: onToggleBottomRow,
      onDeleteTag: onDeleteTag,
      roundedCard: roundedCard,
      transparentBackground: transparentBackground,
      showBorder: showBorder,
      debugLogPrefix: 'TextRail',
      actions: [
        IconButton(
          key: const ValueKey('note-text-rail-tag'),
          tooltip: 'Tagelés',
          onPressed: onTag,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.sell_outlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-clear-tags'),
          tooltip: 'Kijelölt tagek törlése',
          onPressed: onClearTags,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-prev'),
          tooltip: 'Előző tag',
          onPressed: onPreviousTagged,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.chevron_left, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-next'),
          tooltip: 'Következő tag',
          onPressed: onNextTagged,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.chevron_right, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-outdent'),
          tooltip: 'Kijjebb',
          onPressed: onOutdent,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.format_indent_decrease, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-indent'),
          tooltip: 'Beljebb',
          onPressed: onIndent,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.format_indent_increase, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-rounded'),
          tooltip: roundedCard ? 'Vonalas rail' : 'Cellaszerű rail',
          onPressed: onToggleRounded,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.crop_square_outlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-transparent'),
          tooltip: transparentBackground
              ? 'Fehér rail háttér'
              : 'Szürke rail háttér',
          onPressed: onToggleTransparent,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.opacity, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-text-rail-toggle-border'),
          tooltip: showBorder ? 'Rail border nélkül' : 'Rail borderrel',
          onPressed: onToggleBorder,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.border_outer, size: 18),
        ),
      ],
    );
  }
}
