import 'dart:async';

import 'package:flutter/material.dart';

import '../../debug/debug_console.dart';
import '../models/note_document.dart';
import 'native_selection_rail_bridge.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';
import 'text_chunk_canvas_editor.dart';
import 'text_chunk_text_editing.dart';

String _editorBlockSignature(NoteBlock block) {
  return [
    block.id,
    block.type.wireName,
    block.text,
    block.title ?? '',
    block.tags.map(_tagSignature).join('\u001e'),
    block.rangeTags.map(_rangeTagSignature).join('\u001e'),
  ].join('\u001f');
}

String _rangeTagSignature(NoteTextRangeTag rangeTag) {
  return [
    rangeTag.id,
    rangeTag.start,
    rangeTag.end,
    rangeTag.resolvedTags.map(_tagSignature).join('\u001d'),
  ].join(':');
}

String _tagSignature(NoteKnowledgeTag tag) {
  return [
    NoteKnowledgeTagTypes.normalize(tag.type),
    tag.label.trim(),
    tag.colorValue ?? '',
  ].join(':');
}

class NoteTextChunkEditorScreen extends StatefulWidget {
  const NoteTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
    this.availableTags = const [],
    this.onDelete,
    this.nativeSelectionRailController,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final List<NoteKnowledgeTag> availableTags;
  final VoidCallback? onDelete;
  final NativeSelectionRailController? nativeSelectionRailController;

  @override
  State<NoteTextChunkEditorScreen> createState() =>
      _NoteTextChunkEditorScreenState();
}

class _NoteTextChunkEditorScreenState extends State<NoteTextChunkEditorScreen> {
  late NoteBlock _block;
  late final TextChunkNativeEditingController _controller;
  late final FocusNode _focusNode;
  late final NativeSelectionRailController _nativeSelectionRailController;
  late final bool _ownsNativeSelectionRailController;
  bool _syncingController = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railGreyBackground = false;
  bool _railBorderVisible = true;
  TextRange? _activeRailRange;
  bool _selectionCanDeleteTag = false;

  static const _textStyle = TextStyle(color: Color(0xFF111827), fontSize: 16);

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = TextChunkNativeEditingController(text: widget.block.text)
      ..addListener(_handleControllerChanged);
    _focusNode = FocusNode();
    _nativeSelectionRailController =
        widget.nativeSelectionRailController ?? NativeSelectionRailController();
    _ownsNativeSelectionRailController =
        widget.nativeSelectionRailController == null;
    _nativeSelectionRailController.onAction = _handleNativeRailAction;
    _syncNativeRailState();
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idChanged = oldWidget.block.id != widget.block.id;
    final blockPayloadChanged =
        _editorBlockSignature(oldWidget.block) !=
        _editorBlockSignature(widget.block);
    if (blockPayloadChanged) {
      final nextBlock = widget.block;
      _block = nextBlock;
      if (idChanged) {
        _activeRailRange = null;
      } else if (_activeRailRange != null) {
        final start = _activeRailRange!.start
            .clamp(0, nextBlock.text.length)
            .toInt();
        final end = _activeRailRange!.end.clamp(start, nextBlock.text.length);
        _activeRailRange = TextRange(start: start, end: end.toInt());
      }
      _selectionCanDeleteTag =
          _selectionTargetRange() != null &&
          _rangeHasTag(_selectionTargetRange()!);
      if (_controller.text != nextBlock.text) {
        _syncControllerText(nextBlock.text);
      }
    }
    if (idChanged) {
      _activeRailRange = null;
      _selectionCanDeleteTag = false;
    }
    _syncNativeRailState();
  }

  @override
  void dispose() {
    _nativeSelectionRailController.onAction = null;
    _sendNativeRailUpdate(_nativeSelectionRailController.hide());
    if (_ownsNativeSelectionRailController) {
      _nativeSelectionRailController.dispose();
    }
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

  void _sendNativeRailUpdate(Future<void> update) {
    unawaited(update.catchError((_) {}));
  }

  void _syncNativeRailState() {
    final range = _activeRailRange;
    if (range == null) {
      _sendNativeRailUpdate(_nativeSelectionRailController.hide());
      return;
    }
    _sendNativeRailUpdate(
      _nativeSelectionRailController.setStateModel(
        NativeSelectionRailState.visible(
          rangeStart: range.start,
          rangeEnd: range.end,
          tags: _nativeRailTagsForRange(range),
          canDeleteTag: _selectionCanDeleteTag,
          hasTaggedRanges: _block.rangeTags.isNotEmpty,
          bottomRowExpanded: _railBottomExpanded,
          roundedCard: _railRoundedCard,
          greyBackground: _railGreyBackground,
          borderVisible: _railBorderVisible,
        ),
      ),
    );
  }

  Future<void> _handleNativeRailAction(NativeSelectionRailAction action) async {
    switch (action.type) {
      case NativeSelectionRailActionType.toggleTags:
        setState(() => _railBottomExpanded = !_railBottomExpanded);
        _syncNativeRailState();
        return;
      case NativeSelectionRailActionType.outdent:
        _changeParagraphIndent(-1);
        return;
      case NativeSelectionRailActionType.indent:
        _changeParagraphIndent(1);
        return;
      case NativeSelectionRailActionType.tagSelection:
        unawaited(_tagSelection());
        return;
      case NativeSelectionRailActionType.clearTags:
        _deleteSelectedTag();
        return;
      case NativeSelectionRailActionType.previousTag:
        _focusTaggedRange(-1);
        return;
      case NativeSelectionRailActionType.nextTag:
        _focusTaggedRange(1);
        return;
      case NativeSelectionRailActionType.toggleRounded:
        setState(() => _railRoundedCard = !_railRoundedCard);
        _syncNativeRailState();
        return;
      case NativeSelectionRailActionType.toggleGrey:
        setState(() => _railGreyBackground = !_railGreyBackground);
        _syncNativeRailState();
        return;
      case NativeSelectionRailActionType.toggleBorder:
        setState(() => _railBorderVisible = !_railBorderVisible);
        _syncNativeRailState();
        return;
      case NativeSelectionRailActionType.deleteTag:
        final tag = _tagById(action.tagId);
        if (tag != null) {
          _deleteSingleSelectedTag(tag);
        }
        return;
    }
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
    _syncNativeRailState();
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
    _syncNativeRailState();
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
    _syncNativeRailState();
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
      _syncNativeRailState();
      return;
    }
    setState(() {
      _activeRailRange = nextRange;
      _selectionCanDeleteTag = nextCanDelete;
    });
    _syncNativeRailState();
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
    return _tagsForRange(range);
  }

  List<NativeSelectionRailTag> _nativeRailTagsForRange(TextRange range) {
    return _tagsForRange(range)
        .map(
          (tag) => NativeSelectionRailTag(
            id: tag.metadataText,
            label: tag.label,
            colorValue: tag.colorValue,
          ),
        )
        .toList(growable: false);
  }

  NoteKnowledgeTag? _tagById(String? tagId) {
    if (tagId == null) {
      return null;
    }
    for (final tag in _tagsForRange(_activeRailRange)) {
      if (tag.metadataText == tagId) {
        return tag;
      }
    }
    return null;
  }

  List<NoteKnowledgeTag> _tagsForRange(TextRange? range) {
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
    _syncNativeRailState();
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
    _syncNativeRailState();
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
    _syncNativeRailState();
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
    DebugConsole.log(
      '[TextChunkStep] delta=$delta offset=$offset '
      'oldLen=${_block.text.length} newLen=${result.text.length} '
      'oldRanges=${_block.rangeTags.length} newRanges=${result.rangeTags.length} '
      'selection=${result.selectionOffset} '
      'changed=${result.text != _block.text}',
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
    _syncNativeRailState();
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
                textStyle: _textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
