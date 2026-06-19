import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_text_chunk_web_editor.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteTextChunkEditorScreen extends StatefulWidget {
  const NoteTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
    this.availableTags = const [],
    this.onDelete,
    this.useWebEditor = false,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final List<NoteKnowledgeTag> availableTags;
  final VoidCallback? onDelete;
  final bool useWebEditor;

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

  void _emitWebText(String value) {
    if (value == _block.text) {
      return;
    }
    setState(() {
      _block = _block.copyWith(text: value, clearIndex: true);
    });
    widget.onChanged(_block);
  }

  void _emitWebRangeTags(List<NoteTextRangeTag> rangeTags) {
    setState(() {
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _setControllerRangeTags(rangeTags);
      _selectionCanDeleteTag = false;
      _selectionHasRange = false;
      _activeRailRange = null;
    });
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

  Future<List<NoteKnowledgeTag>?> _tagWebSelection(
    TextRange range,
    List<NoteKnowledgeTag> initialTags,
  ) {
    return showTagManagerSheet(
      context,
      initialTags: initialTags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt rész tagje',
    );
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
                    if (widget.useWebEditor &&
                        NoteTextChunkWebEditor.isPlatformAvailable)
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height - 140,
                        child: NoteTextChunkWebEditor(
                          block: _block,
                          onTextChanged: _emitWebText,
                          onRangeTagsChanged: _emitWebRangeTags,
                          onTagRequested: _tagWebSelection,
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, _) {
                          const textStyle = TextStyle(
                            fontSize: 16,
                            height: 1.45,
                          );
                          final showVisualLayer = _selectionHasRange;
                          _controller.paintTagStyles = !showVisualLayer;
                          final textField = TextField(
                            key: const ValueKey('note-text-chunk-field'),
                            controller: _controller,
                            focusNode: _focusNode,
                            autofocus: true,
                            maxLines: null,
                            minLines: 12,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            cursorColor: const Color(0xFF111827),
                            decoration: const InputDecoration(
                              hintText: 'Írd ide a chunk tartalmát',
                              border: InputBorder.none,
                            ),
                            style: showVisualLayer
                                ? textStyle.copyWith(
                                    color: Colors.transparent,
                                    decorationColor: Colors.transparent,
                                  )
                                : textStyle,
                            onTap: _handleTextFieldTap,
                            onChanged: _emitText,
                          );
                          if (!showVisualLayer) {
                            return textField;
                          }
                          return Stack(
                            alignment: Alignment.topLeft,
                            children: [
                              textField,
                              _TaggedTextVisualLayer(
                                key: const ValueKey(
                                  'note-text-visual-selection-layout',
                                ),
                                text: _controller.text,
                                rangeTags: _block.rangeTags,
                                activeRailRange: _selectionHasRange
                                    ? _activeRailRange
                                    : null,
                                rail: _selectionHasRange
                                    ? _buildSelectionRail()
                                    : null,
                                baseStyle: textStyle.copyWith(
                                  color: const Color(0xFF111827),
                                ),
                              ),
                            ],
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
  bool paintTagStyles = true;

  set rangeTags(List<NoteTextRangeTag> value) {
    setRangeTags(value);
    notifyListeners();
  }

  void setRangeTags(List<NoteTextRangeTag> value) {
    _rangeTags = value;
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
      return TextSpan(style: style, text: textValue);
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final rangeTag in validTags) {
      if (rangeTag.start < cursor) {
        continue;
      }
      if (rangeTag.start > cursor) {
        spans.add(TextSpan(text: textValue.substring(cursor, rangeTag.start)));
      }
      spans.add(
        TextSpan(
          text: textValue.substring(rangeTag.start, rangeTag.end),
          style: paintTagStyles
              ? _taggedTextStyle(rangeTag.resolvedTags, alpha: 0.22)
              : null,
        ),
      );
      cursor = rangeTag.end;
    }
    if (cursor < textValue.length) {
      spans.add(TextSpan(text: textValue.substring(cursor)));
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TaggedTextVisualLayer extends StatelessWidget {
  const _TaggedTextVisualLayer({
    super.key,
    required this.text,
    required this.rangeTags,
    required this.baseStyle,
    this.activeRailRange,
    this.rail,
  });

  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final TextRange? activeRailRange;
  final Widget? rail;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final range = activeRailRange;
    final railWidget = rail;
    if (range == null || railWidget == null || !range.isValid) {
      return IgnorePointer(
        child: _TaggedTextVisualSegment(
          text: text,
          start: 0,
          end: text.length,
          rangeTags: rangeTags,
          baseStyle: baseStyle,
        ),
      );
    }
    final railOffset = range.end.clamp(0, text.length).toInt();
    return Column(
      key: const ValueKey('note-text-visual-selection-column'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        IgnorePointer(
          child: _TaggedTextVisualSegment(
            text: text,
            start: 0,
            end: railOffset,
            rangeTags: rangeTags,
            baseStyle: baseStyle,
          ),
        ),
        Padding(
          key: const ValueKey('note-text-visual-selection-rail'),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: railWidget,
        ),
        IgnorePointer(
          child: _TaggedTextVisualSegment(
            text: text,
            start: railOffset,
            end: text.length,
            rangeTags: rangeTags,
            baseStyle: baseStyle,
          ),
        ),
      ],
    );
  }
}

class _TaggedTextVisualSegment extends StatelessWidget {
  const _TaggedTextVisualSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.rangeTags,
    required this.baseStyle,
  });

  final String text;
  final int start;
  final int end;
  final List<NoteTextRangeTag> rangeTags;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _taggedVisualSpans(
          textValue: text,
          start: start,
          end: end,
          rangeTags: rangeTags,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

List<InlineSpan> _taggedVisualSpans({
  required String textValue,
  required int start,
  required int end,
  required List<NoteTextRangeTag> rangeTags,
  required TextStyle baseStyle,
}) {
  final clampedStart = start.clamp(0, textValue.length).toInt();
  final clampedEnd = end.clamp(clampedStart, textValue.length).toInt();
  if (clampedEnd <= clampedStart) {
    return const [];
  }
  final validTags = _mergeVisualRangeTags(rangeTags, textValue.length).where((
    tag,
  ) {
    return tag.isValid && tag.start < clampedEnd && tag.end > clampedStart;
  }).toList()..sort((a, b) => a.start.compareTo(b.start));
  if (validTags.isEmpty) {
    return [TextSpan(text: textValue.substring(clampedStart, clampedEnd))];
  }
  final spans = <InlineSpan>[];
  var cursor = clampedStart;
  for (final rangeTag in validTags) {
    final tagStart = rangeTag.start < clampedStart
        ? clampedStart
        : rangeTag.start;
    final tagEnd = rangeTag.end > clampedEnd ? clampedEnd : rangeTag.end;
    if (tagStart < cursor) {
      continue;
    }
    if (tagStart > cursor) {
      spans.add(TextSpan(text: textValue.substring(cursor, tagStart)));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _TaggedInlineText(
          rangeId: rangeTag.id,
          text: textValue.substring(tagStart, tagEnd),
          tags: rangeTag.resolvedTags,
          baseStyle: baseStyle,
        ),
      ),
    );
    cursor = tagEnd;
  }
  if (cursor < clampedEnd) {
    spans.add(TextSpan(text: textValue.substring(cursor, clampedEnd)));
  }
  return spans;
}

List<NoteTextRangeTag> _mergeVisualRangeTags(
  List<NoteTextRangeTag> rangeTags,
  int textLength,
) {
  final merged = <String, NoteTextRangeTag>{};
  for (final rawTag in rangeTags) {
    final rangeTag = rawTag.clampToTextLength(textLength);
    if (!rangeTag.isValid) {
      continue;
    }
    final key = '${rangeTag.start}:${rangeTag.end}';
    final existing = merged[key];
    if (existing == null) {
      merged[key] = rangeTag;
      continue;
    }
    final nextTags = [...existing.resolvedTags];
    for (final tag in rangeTag.resolvedTags) {
      if (!nextTags.any(
        (current) => current.metadataText == tag.metadataText,
      )) {
        nextTags.add(tag);
      }
    }
    merged[key] = NoteTextRangeTag(
      id: existing.id,
      start: existing.start,
      end: existing.end,
      tag: nextTags.first,
      tags: nextTags,
    );
  }
  return merged.values.toList(growable: false);
}

class _TaggedInlineText extends StatelessWidget {
  const _TaggedInlineText({
    required this.rangeId,
    required this.text,
    required this.tags,
    required this.baseStyle,
  });

  final String rangeId;
  final String text;
  final List<NoteKnowledgeTag> tags;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Text(text, style: baseStyle);
    }
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            text,
            style: baseStyle.copyWith(
              backgroundColor: Color(
                tags.first.resolvedColorValue,
              ).withValues(alpha: 0.22),
              fontWeight: FontWeight.w600,
            ),
          ),
          for (var index = 1; index < tags.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 1 ? 1 : 2),
              child: DecoratedBox(
                key: ValueKey('note-text-secondary-underline-$rangeId-$index'),
                decoration: BoxDecoration(
                  color: Color(tags[index].resolvedColorValue),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(height: 2),
              ),
            ),
        ],
      ),
    );
  }
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
