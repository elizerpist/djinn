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
  bool _selectionCanDeleteTag = false;
  bool _selectionHasRange = false;
  bool _syncingRangeTags = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  int _activeParagraphIndex = 0;
  final Map<int, _TaggedTextEditingController> _paragraphControllers =
      <int, _TaggedTextEditingController>{};
  final Map<int, FocusNode> _paragraphFocusNodes = <int, FocusNode>{};

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = _TaggedTextEditingController(
      text: widget.block.text,
      rangeTags: widget.block.rangeTags,
    );
    _controller.addListener(_handleControllerChanged);
    _selectionCanDeleteTag = _selectionHasTag();
    _selectionHasRange = _selectionIsTaggable();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    for (final controller in _paragraphControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _paragraphFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _handleControllerChanged() {
    if (_syncingRangeTags) {
      return;
    }
    final nextCanDelete = _selectionHasTag();
    final nextHasRange = _selectionIsTaggable();
    if (nextCanDelete == _selectionCanDeleteTag &&
        nextHasRange == _selectionHasRange) {
      return;
    }
    if (!mounted) {
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
      return;
    }
    setState(() {
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
    });
  }

  void _emitText(String value) {
    final rangeTags = _adjustRangeTagsForEdit(
      oldText: _block.text,
      newText: value,
      tags: _block.rangeTags,
    );
    _setControllerRangeTags(rangeTags);
    _syncParagraphRangeTags();
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

  TextRange? _selectionTargetRange() {
    final selection = _activeParagraphController?.selection;
    final segment = _activeParagraphSegment;
    if (selection == null ||
        segment == null ||
        !selection.isValid ||
        _controller.text.isEmpty) {
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
        start: (segment.start + start)
            .clamp(0, _controller.text.length)
            .toInt(),
        end: (segment.start + end).clamp(0, _controller.text.length).toInt(),
      );
    }
    final collapsedRange = _collapsedTaggedRange();
    if (collapsedRange == null) {
      return null;
    }
    return TextRange(start: collapsedRange.start, end: collapsedRange.end);
  }

  NoteTextRangeTag? _collapsedTaggedRange() {
    final selection = _activeParagraphController?.selection;
    final segment = _activeParagraphSegment;
    if (selection == null ||
        segment == null ||
        !selection.isValid ||
        !selection.isCollapsed) {
      return null;
    }
    final offset = (segment.start + selection.extentOffset)
        .clamp(0, _controller.text.length)
        .toInt();
    for (final tag in _block.rangeTags) {
      final range = tag.clampToTextLength(_controller.text.length);
      if (!range.isValid) {
        continue;
      }
      if (offset >= range.start && offset <= range.end) {
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
    final segments = _segments;
    final paragraphIndex = segments.indexWhere(
      (segment) => target.start >= segment.start && target.start <= segment.end,
    );
    if (paragraphIndex >= 0) {
      final segment = segments[paragraphIndex];
      _activeParagraphIndex = paragraphIndex;
      _paragraphControllers[paragraphIndex]?.selection = TextSelection(
        baseOffset: (target.start - segment.start)
            .clamp(0, segment.text.length)
            .toInt(),
        extentOffset: (target.end - segment.start)
            .clamp(0, segment.text.length)
            .toInt(),
      );
      _paragraphFocusNodes[paragraphIndex]?.requestFocus();
    }
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

  List<_TextParagraphSegment> get _segments =>
      _TextParagraphSegment.fromText(_controller.text);

  _TextParagraphSegment? get _activeParagraphSegment {
    final segments = _segments;
    if (_activeParagraphIndex < 0 || _activeParagraphIndex >= segments.length) {
      return segments.isEmpty ? null : segments.first;
    }
    return segments[_activeParagraphIndex];
  }

  _TaggedTextEditingController? get _activeParagraphController =>
      _paragraphControllers[_activeParagraphIndex];

  _TaggedTextEditingController _paragraphControllerFor(
    int index,
    _TextParagraphSegment segment,
  ) {
    final controller = _paragraphControllers.putIfAbsent(index, () {
      final created = _TaggedTextEditingController(
        text: segment.text,
        rangeTags: _localRangeTagsForSegment(segment),
      );
      created.addListener(() {
        _activeParagraphIndex = index;
        _handleControllerChanged();
      });
      return created;
    });
    if (controller.text != segment.text &&
        !(_paragraphFocusNodes[index]?.hasFocus ?? false)) {
      controller.value = TextEditingValue(
        text: segment.text,
        selection: TextSelection.collapsed(
          offset: segment.text.length.clamp(0, segment.text.length).toInt(),
        ),
      );
    }
    controller.setRangeTags(_localRangeTagsForSegment(segment));
    return controller;
  }

  FocusNode _paragraphFocusNodeFor(int index) {
    return _paragraphFocusNodes.putIfAbsent(index, FocusNode.new);
  }

  List<NoteTextRangeTag> _localRangeTagsForSegment(
    _TextParagraphSegment segment,
  ) {
    final localTags = <NoteTextRangeTag>[];
    for (final rangeTag in _block.rangeTags) {
      final tag = rangeTag.clampToTextLength(_controller.text.length);
      final start = tag.start > segment.start ? tag.start : segment.start;
      final end = tag.end < segment.end ? tag.end : segment.end;
      if (end <= start) {
        continue;
      }
      localTags.add(
        NoteTextRangeTag(
          id: tag.id,
          start: start - segment.start,
          end: end - segment.start,
          tag: tag.tag,
          tags: tag.tags,
        ),
      );
    }
    return localTags;
  }

  void _syncParagraphRangeTags() {
    final segments = _segments;
    for (var i = 0; i < segments.length; i += 1) {
      _paragraphControllers[i]?.setRangeTags(
        _localRangeTagsForSegment(segments[i]),
      );
    }
  }

  void _emitParagraphText(
    int index,
    _TextParagraphSegment segment,
    String value,
  ) {
    final text = _controller.text;
    final next =
        '${text.substring(0, segment.start)}$value${text.substring(segment.end)}';
    _controller.value = _controller.value.copyWith(text: next);
    _emitText(next);
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
        color: const Color(0xFFF3F4F6),
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
                    for (final entry in _segments.indexed) ...[
                      if (entry.$1 > 0) const SizedBox(height: 12),
                      Container(
                        key: ValueKey('note-text-paragraph-box-${entry.$1}'),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: TextField(
                          key: entry.$1 == 0
                              ? const ValueKey('note-text-chunk-field')
                              : ValueKey('note-text-chunk-field-${entry.$1}'),
                          controller: _paragraphControllerFor(
                            entry.$1,
                            entry.$2,
                          ),
                          focusNode: _paragraphFocusNodeFor(entry.$1),
                          autofocus: entry.$1 == 0,
                          maxLines: null,
                          minLines: 1,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: 'Írd ide a chunk tartalmát',
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 16, height: 1.45),
                          onTap: () {
                            _activeParagraphIndex = entry.$1;
                            _handleControllerChanged();
                          },
                          onChanged: (value) =>
                              _emitParagraphText(entry.$1, entry.$2, value),
                        ),
                      ),
                      if (_selectionHasRange &&
                          _activeParagraphIndex == entry.$1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildSelectionRail(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (_block.rangeTags.isNotEmpty)
              const SizedBox.shrink(key: ValueKey('note-text-range-highlight')),
            Container(
              key: const ValueKey('note-text-tip-bar'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Írj szöveget, jelöld ki a részt, majd a hárompontos menüből taggeld.',
                style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextParagraphSegment {
  const _TextParagraphSegment({
    required this.start,
    required this.end,
    required this.text,
  });

  final int start;
  final int end;
  final String text;

  static List<_TextParagraphSegment> fromText(String text) {
    if (text.isEmpty) {
      return const [_TextParagraphSegment(start: 0, end: 0, text: '')];
    }
    final segments = <_TextParagraphSegment>[];
    var start = 0;
    for (final match in RegExp(r'\n{2,}').allMatches(text)) {
      segments.add(
        _TextParagraphSegment(
          start: start,
          end: match.start,
          text: text.substring(start, match.start),
        ),
      );
      start = match.end;
    }
    segments.add(
      _TextParagraphSegment(
        start: start,
        end: text.length,
        text: text.substring(start),
      ),
    );
    return segments.isEmpty
        ? const [_TextParagraphSegment(start: 0, end: 0, text: '')]
        : segments;
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
    final spans = <TextSpan>[];
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
          style: _taggedTextStyle(rangeTag.resolvedTags, alpha: 0.22),
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
