import 'package:flutter/material.dart';

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
  late final _TaggedTextEditingController _controller;
  late final FocusNode _focusNode;
  bool _selectionCanDeleteTag = false;
  bool _selectionHasRange = false;
  bool _syncingRangeTags = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  TextRange? _activeRailRange;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = _TaggedTextEditingController(
      text: widget.block.text,
      rangeTags: widget.block.rangeTags,
    );
    _focusNode = FocusNode();
    _controller.addListener(_handleControllerChanged);
    _selectionCanDeleteTag = _selectionHasTag();
    _selectionHasRange = _selectionIsTaggable();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_syncingRangeTags) {
      return;
    }
    final nextRailRange = _selectionTargetRange();
    final nextCanDelete = _selectionHasTag();
    final nextHasRange = nextRailRange != null;
    if (nextCanDelete == _selectionCanDeleteTag &&
        nextHasRange == _selectionHasRange &&
        _sameTextRange(nextRailRange, _activeRailRange)) {
      return;
    }
    if (!mounted) {
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
      _activeRailRange = nextRailRange;
      return;
    }
    setState(() {
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
      _activeRailRange = nextRailRange;
    });
  }

  void _emitText(String value) {
    final rangeTags = _adjustRangeTagsForEdit(
      oldText: _block.text,
      newText: value,
      tags: _block.rangeTags,
    );
    _setControllerRangeTags(rangeTags);
    _block = _block.copyWith(
      text: value,
      rangeTags: rangeTags,
      clearIndex: true,
    );
    _handleControllerChanged();
    widget.onChanged(_block);
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
    final text = _controller.text;
    final targetRange = _selectionTargetRange();
    if (targetRange == null || text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jelölj ki egy szövegrészt a tageléshez')),
      );
      return;
    }
    final selectedExistingRange = _collapsedTaggedRange();
    final tags = await showTagManagerSheet(
      context,
      initialTags: selectedExistingRange?.resolvedTags ?? const [],
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt rész tagje',
    );
    if (tags == null || tags.isEmpty) {
      return;
    }
    final rangeTag = NoteTextRangeTag(
      id:
          selectedExistingRange?.id ??
          'range-${DateTime.now().microsecondsSinceEpoch}',
      start: targetRange.start.clamp(0, text.length).toInt(),
      end: targetRange.end.clamp(0, text.length).toInt(),
      tag: tags.first,
      tags: tags,
    );
    if (!rangeTag.isValid) {
      return;
    }
    setState(() {
      final rangeTags = selectedExistingRange == null
          ? [..._block.rangeTags, rangeTag]
          : [
              for (final current in _block.rangeTags)
                if (current.id == selectedExistingRange.id)
                  rangeTag
                else
                  current,
            ];
      _setControllerRangeTags(rangeTags);
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionIsTaggable();
    });
    widget.onChanged(_block);
  }

  bool _selectionIsTaggable() {
    return _selectionTargetRange() != null;
  }

  bool _sameTextRange(TextRange? a, TextRange? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.start == b.start && a.end == b.end;
  }

  TextRange? _selectionTargetRange() {
    final selection = _controller.selection;
    if (!selection.isValid || _controller.text.isEmpty) {
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
        start: start.clamp(0, _controller.text.length).toInt(),
        end: end.clamp(0, _controller.text.length).toInt(),
      );
    }
    final collapsedRange = _collapsedTaggedRange();
    if (collapsedRange == null) {
      return null;
    }
    return TextRange(start: collapsedRange.start, end: collapsedRange.end);
  }

  NoteTextRangeTag? _collapsedTaggedRange() {
    final selection = _controller.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return null;
    }
    final offset = selection.extentOffset
        .clamp(0, _controller.text.length)
        .toInt();
    for (final tag in _block.rangeTags) {
      final range = tag.clampToTextLength(_controller.text.length);
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
    return _block.rangeTags.any(
      (tag) => tag.start < targetRange.end && tag.end > targetRange.start,
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
      _setControllerRangeTags(rangeTags);
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionIsTaggable();
    });
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
      _setControllerRangeTags(rangeTags);
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionIsTaggable();
    });
    widget.onChanged(_block);
  }

  void _focusTaggedRange(int direction) {
    if (_block.rangeTags.isEmpty) {
      return;
    }
    final ranges =
        [
            for (final range in _block.rangeTags)
              range.clampToTextLength(_controller.text.length),
          ].where((range) => range.isValid).toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    if (ranges.isEmpty) {
      return;
    }
    final currentOffset = _controller.selection.isValid
        ? (_controller.selection.baseOffset < _controller.selection.extentOffset
              ? _controller.selection.baseOffset
              : _controller.selection.extentOffset)
        : -1;
    NoteTextRangeTag target;
    if (direction >= 0) {
      target = ranges.firstWhere(
        (range) => range.start > currentOffset,
        orElse: () => ranges.first,
      );
    } else {
      target = ranges.reversed.firstWhere(
        (range) => range.start < currentOffset,
        orElse: () => ranges.last,
      );
    }
    _controller.selection = TextSelection(
      baseOffset: target.start,
      extentOffset: target.end,
    );
    _focusNode.requestFocus();
    _handleControllerChanged();
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
        if (!tags.any(
          (current) => current.type == tag.type && current.label == tag.label,
        )) {
          tags.add(tag);
        }
      }
    }
    return tags;
  }

  void _setControllerRangeTags(List<NoteTextRangeTag> rangeTags) {
    _syncingRangeTags = true;
    try {
      _controller.rangeTags = rangeTags;
    } finally {
      _syncingRangeTags = false;
    }
  }

  void _handleTextFieldTap() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final taggedRange = _collapsedTaggedRange();
      if (taggedRange != null) {
        _controller.selection = TextSelection(
          baseOffset: taggedRange.start,
          extentOffset: taggedRange.end,
        );
      }
      _handleControllerChanged();
    });
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
      actions: [
        IconButton(
          key: const ValueKey('note-text-selection-rail-tag'),
          tooltip: 'Kijelölt rész tagelése',
          onPressed: () => unawaited(_tagSelection()),
          icon: const Icon(Icons.sell_outlined, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-clear-tags'),
          tooltip: 'Minden tag törlése',
          onPressed: _selectionCanDeleteTag ? _deleteSelectedTag : null,
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
              : 'Átlátszó rail háttér',
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

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _changeParagraphIndent(int delta) {
    final text = _controller.text;
    if (text.isEmpty) {
      return;
    }
    final selection = _controller.selection;
    final anchor = selection.baseOffset.clamp(0, text.length).toInt();
    var start = text.lastIndexOf('\n\n', anchor == 0 ? 0 : anchor - 1);
    start = start == -1 ? 0 : start + 2;
    var end = text.indexOf('\n\n', anchor);
    end = end == -1 ? text.length : end;
    final before = text.substring(0, start);
    final paragraph = text.substring(start, end);
    final after = text.substring(end);
    final lines = paragraph.split('\n');
    final changed = [
      for (final line in lines)
        if (delta > 0)
          line.trim().isEmpty ? line : '  $line'
        else if (line.startsWith('  '))
          line.substring(2)
        else if (line.startsWith(' '))
          line.substring(1)
        else
          line,
    ].join('\n');
    final next = '$before$changed$after';
    final diff = next.length - text.length;
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(
        offset: (anchor + diff).clamp(0, next.length).toInt(),
      ),
    );
    _emitText(next);
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        _controller.setInlineRail(
                          range: _selectionHasRange ? _activeRailRange : null,
                          rail: _selectionHasRange
                              ? _buildSelectionRail()
                              : null,
                          width: constraints.maxWidth,
                        );
                        return TextField(
                          key: const ValueKey('note-text-chunk-field'),
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          maxLines: null,
                          minLines: 12,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Írd ide a chunk tartalmát',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.45),
                          onTap: _handleTextFieldTap,
                          onChanged: _emitText,
                        );
                      },
                    ),
                  ],
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

class _TaggedTextEditingController extends TextEditingController {
  _TaggedTextEditingController({
    required String text,
    required List<NoteTextRangeTag> rangeTags,
  }) : _rangeTags = rangeTags,
       super(text: text);

  List<NoteTextRangeTag> _rangeTags;
  TextRange? _inlineRailRange;
  Widget? _inlineRail;
  double _inlineRailWidth = 0;

  set rangeTags(List<NoteTextRangeTag> value) {
    setRangeTags(value);
    notifyListeners();
  }

  void setRangeTags(List<NoteTextRangeTag> value) {
    _rangeTags = value;
  }

  void setInlineRail({
    required TextRange? range,
    required Widget? rail,
    required double width,
  }) {
    _inlineRailRange = range;
    _inlineRail = rail;
    _inlineRailWidth = width;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textValue = text;
    final validTags =
        _rangeTags
            .map((tag) => tag.clampToTextLength(textValue.length))
            .where((tag) => tag.isValid)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));
    if (validTags.isEmpty) {
      final spans = <InlineSpan>[];
      _appendStyledTextWithRail(
        spans: spans,
        textValue: textValue,
        start: 0,
        end: textValue.length,
        style: null,
        railOffset: _railOffset(textValue.length),
        railSpan: _railSpan(),
      );
      return spans.isEmpty
          ? TextSpan(style: style, text: textValue)
          : TextSpan(style: style, children: spans);
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    final railOffset = _railOffset(textValue.length);
    final railSpan = _railSpan();
    for (final rangeTag in validTags) {
      if (rangeTag.start < cursor) {
        continue;
      }
      if (rangeTag.start > cursor) {
        _appendStyledTextWithRail(
          spans: spans,
          textValue: textValue,
          start: cursor,
          end: rangeTag.start,
          style: null,
          railOffset: railOffset,
          railSpan: railSpan,
        );
      }
      _appendStyledTextWithRail(
        spans: spans,
        textValue: textValue,
        start: rangeTag.start,
        end: rangeTag.end,
        style: _taggedTextStyle(rangeTag.resolvedTags, alpha: 0.22),
        railOffset: railOffset,
        railSpan: railSpan,
      );
      cursor = rangeTag.end;
    }
    if (cursor < textValue.length) {
      _appendStyledTextWithRail(
        spans: spans,
        textValue: textValue,
        start: cursor,
        end: textValue.length,
        style: null,
        railOffset: railOffset,
        railSpan: railSpan,
      );
    } else if (railOffset != null && railOffset == textValue.length) {
      _appendRailIfNeeded(spans, railSpan);
    }
    return TextSpan(style: style, children: spans);
  }

  int? _railOffset(int textLength) {
    final range = _inlineRailRange;
    if (range == null || _inlineRail == null || !range.isValid) {
      return null;
    }
    return range.end.clamp(0, textLength).toInt();
  }

  WidgetSpan? _railSpan() {
    final rail = _inlineRail;
    if (rail == null) {
      return null;
    }
    final width = _inlineRailWidth.isFinite && _inlineRailWidth > 0
        ? _inlineRailWidth
        : 360.0;
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: SizedBox(
        key: const ValueKey('note-text-inline-selection-rail'),
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: rail,
        ),
      ),
    );
  }
}

void _appendStyledTextWithRail({
  required List<InlineSpan> spans,
  required String textValue,
  required int start,
  required int end,
  required TextStyle? style,
  required int? railOffset,
  required WidgetSpan? railSpan,
}) {
  if (end <= start) {
    if (railOffset == start) {
      _appendRailIfNeeded(spans, railSpan);
    }
    return;
  }
  if (railOffset != null && railOffset > start && railOffset < end) {
    spans.add(
      TextSpan(text: textValue.substring(start, railOffset), style: style),
    );
    _appendRailIfNeeded(spans, railSpan);
    spans.add(
      TextSpan(text: textValue.substring(railOffset, end), style: style),
    );
    return;
  }
  spans.add(TextSpan(text: textValue.substring(start, end), style: style));
  if (railOffset == end) {
    _appendRailIfNeeded(spans, railSpan);
  }
}

void _appendRailIfNeeded(List<InlineSpan> spans, WidgetSpan? railSpan) {
  if (railSpan == null || spans.any((span) => span is WidgetSpan)) {
    return;
  }
  spans.add(const TextSpan(text: '\n'));
  spans.add(railSpan);
  spans.add(const TextSpan(text: '\n'));
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
    decoration: tags.length > 1
        ? TextDecoration.underline
        : TextDecoration.none,
    decorationStyle: tags.length > 2
        ? TextDecorationStyle.double
        : TextDecorationStyle.solid,
    decorationColor: tags.length > 1 ? Color(tags[1].resolvedColorValue) : null,
    decorationThickness: tags.length > 1 ? 2 : null,
  );
}

void unawaited(Future<void> future) {}
