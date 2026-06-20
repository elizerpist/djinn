import 'dart:async';

import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';
import 'text_chunk_canvas_editor.dart';
import 'text_chunk_text_editing.dart';

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
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _syncingController = false;
  bool _railBottomExpanded = true;
  TextRange? _activeRailRange;
  bool _selectionCanDeleteTag = false;

  static const _textStyle = TextStyle(color: Color(0xFF111827), fontSize: 16);

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = TextEditingController(text: widget.block.text)
      ..addListener(_handleControllerChanged);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _block = widget.block;
      _activeRailRange = null;
      _selectionCanDeleteTag = false;
      _syncControllerText(widget.block.text);
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
    final nextText = _controller.text;
    if (nextText != _block.text) {
      final edit = _editFromTextChange(_block.text, nextText);
      final rangeTags = adjustTextChunkRangeTagsForEdit(
        oldTextLength: _block.text.length,
        rangeTags: _block.rangeTags,
        edit: edit,
      );
      setState(() {
        _block = _block.copyWith(
          text: nextText,
          rangeTags: rangeTags,
          clearIndex: true,
        );
      });
      widget.onChanged(_block);
      DebugConsole.log(
        '[TextChunkNative] text changed chars=${nextText.length} ranges=${rangeTags.length}',
      );
    }
    _updateSelectionState();
  }

  TextChunkTextEdit _editFromTextChange(String oldText, String newText) {
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
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix -= 1;
      newSuffix -= 1;
    }
    return TextChunkTextEdit(
      offset: prefix,
      deleteCount: oldSuffix - prefix,
      insertText: newText.substring(prefix, newSuffix),
    );
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
    final targetRange = _selectionTargetRange();
    if (targetRange == null || targetRange.isCollapsed) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jelölj ki egy szövegrészt a tageléshez')),
      );
      return;
    }
    final tags = await showTagManagerSheet(
      context,
      initialTags: _selectionTags(),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt rész tagje',
    );
    if (tags == null || tags.isEmpty) {
      return;
    }
    final existing = _exactRangeTag(targetRange);
    final rangeTag = NoteTextRangeTag(
      id: existing?.id ?? 'range-${DateTime.now().microsecondsSinceEpoch}',
      start: targetRange.start,
      end: targetRange.end,
      tag: tags.first,
      tags: tags,
    );
    setState(() {
      _block = _block.copyWith(
        rangeTags: existing == null
            ? [..._block.rangeTags, rangeTag]
            : [
                for (final current in _block.rangeTags)
                  if (current.id == existing.id) rangeTag else current,
              ],
        clearIndex: true,
      );
      _activeRailRange = TextRange(start: rangeTag.start, end: rangeTag.end);
      _selectionCanDeleteTag = true;
    });
    widget.onChanged(_block);
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
    final selection = _controller.selection;
    if (!selection.isValid || _block.text.isEmpty) {
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
    for (final tag in _block.rangeTags) {
      final range = tag.clampToTextLength(_block.text.length);
      if (range.isValid && offset >= range.start && offset < range.end) {
        return TextRange(start: range.start, end: range.end);
      }
    }
    return null;
  }

  void _updateSelectionState() {
    final nextRange = _selectionTargetRange();
    final nextCanDelete = nextRange != null && _rangeHasTag(nextRange);
    if (_sameRange(_activeRailRange, nextRange) &&
        nextCanDelete == _selectionCanDeleteTag) {
      return;
    }
    setState(() {
      _activeRailRange = nextRange;
      _selectionCanDeleteTag = nextCanDelete;
    });
  }

  bool _sameRange(TextRange? a, TextRange? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.start == b.start && a.end == b.end;
  }

  bool _rangeHasTag(TextRange range) {
    return _block.rangeTags.any(
      (tag) => tag.start < range.end && tag.end > range.start,
    );
  }

  List<NoteKnowledgeTag> _selectionTags() {
    final range = _selectionTargetRange();
    if (range == null) {
      return const [];
    }
    final tags = <NoteKnowledgeTag>[];
    for (final rangeTag in _block.rangeTags) {
      if (rangeTag.start >= range.end || rangeTag.end <= range.start) {
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

  void _deleteSelectedTag() {
    final range = _selectionTargetRange();
    if (range == null) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        rangeTags: _block.rangeTags
            .where((tag) => tag.start >= range.end || tag.end <= range.start)
            .toList(growable: false),
        clearIndex: true,
      );
      _selectionCanDeleteTag = false;
    });
    widget.onChanged(_block);
  }

  void _deleteSingleSelectedTag(NoteKnowledgeTag tag) {
    final range = _selectionTargetRange();
    if (range == null) {
      return;
    }
    final updated = <NoteTextRangeTag>[];
    for (final rangeTag in _block.rangeTags) {
      if (rangeTag.start >= range.end || rangeTag.end <= range.start) {
        updated.add(rangeTag);
        continue;
      }
      final tags = rangeTag.resolvedTags
          .where((current) => current.metadataText != tag.metadataText)
          .toList(growable: false);
      if (tags.isNotEmpty) {
        updated.add(
          NoteTextRangeTag(
            id: rangeTag.id,
            start: rangeTag.start,
            end: rangeTag.end,
            tag: tags.first,
            tags: tags,
          ),
        );
      }
    }
    setState(() {
      _block = _block.copyWith(rangeTags: updated, clearIndex: true);
      _selectionCanDeleteTag =
          _selectionTargetRange() != null &&
          _rangeHasTag(_selectionTargetRange()!);
    });
    widget.onChanged(_block);
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
      _controller.selection = TextSelection(
        baseOffset: target.start,
        extentOffset: target.end,
      );
    });
    _focusNode.requestFocus();
  }

  void _changeParagraphIndent(int delta) {
    final selection = _controller.selection;
    final offset =
        _activeRailRange?.start ??
        (selection.isValid ? selection.extentOffset : 0);
    final result = applyTextChunkParagraphStep(
      text: _block.text,
      rangeTags: _block.rangeTags,
      offset: offset,
      delta: delta,
      maxWidth: MediaQuery.sizeOf(context).width - 32,
      textStyle: _textStyle,
      textScaler: MediaQuery.textScalerOf(context),
    );
    if (result.text == _block.text) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        text: result.text,
        rangeTags: result.rangeTags,
        clearIndex: true,
      );
    });
    _syncingController = true;
    try {
      _controller.value = TextEditingValue(
        text: result.text,
        selection: TextSelection.collapsed(
          offset: result.selectionOffset.clamp(0, result.text.length).toInt(),
        ),
      );
    } finally {
      _syncingController = false;
    }
    widget.onChanged(_block);
  }

  Widget _buildSelectionRail() {
    return NoteSelectionActionRail(
      key: const ValueKey('note-text-selection-rail'),
      tags: _selectionTags(),
      pillPrefix: 'note-text-selection-rail-pill',
      bottomRowExpanded: _railBottomExpanded,
      onToggleBottomRow: () =>
          setState(() => _railBottomExpanded = !_railBottomExpanded),
      onDeleteTag: _deleteSingleSelectedTag,
      showBottomBorder: false,
      contentPadding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      actions: [
        IconButton(
          key: const ValueKey('note-text-selection-rail-outdent'),
          tooltip: 'Bekezdés kijjebb',
          onPressed: () => _changeParagraphIndent(-1),
          icon: const Icon(Icons.format_indent_decrease, size: 20),
        ),
        IconButton(
          key: const ValueKey('note-text-selection-rail-indent'),
          tooltip: 'Bekezdés beljebb',
          onPressed: () => _changeParagraphIndent(1),
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
      ],
    );
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
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
              child: TextChunkCanvasEditor(
                controller: _controller,
                focusNode: _focusNode,
                rangeTags: _block.rangeTags,
                activeRange: _activeRailRange,
                selectionRail: _activeRailRange == null
                    ? null
                    : _buildSelectionRail(),
                textStyle: _textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
