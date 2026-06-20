import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../debug/debug_console.dart';
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
  late List<_TextLine> _lines;
  final Map<String, _TextLineEditingController> _lineControllers =
      <String, _TextLineEditingController>{};
  final Map<String, FocusNode> _lineFocusNodes = <String, FocusNode>{};
  bool _syncingLineText = false;
  bool _selectionCanDeleteTag = false;
  bool _selectionHasRange = false;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  String? _activeLineId;
  TextRange? _activeRailRange;
  int _lineCounter = 0;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _lines = _linesFromText(widget.block.text);
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id) {
      _disposeLineEditors();
      _block = widget.block;
      _lines = _linesFromText(widget.block.text);
      _activeLineId = null;
      _activeRailRange = null;
      _selectionCanDeleteTag = false;
      _selectionHasRange = false;
    }
  }

  @override
  void dispose() {
    _disposeLineEditors();
    super.dispose();
  }

  void _disposeLineEditors() {
    for (final controller in _lineControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _lineFocusNodes.values) {
      focusNode.dispose();
    }
    _lineControllers.clear();
    _lineFocusNodes.clear();
  }

  List<_TextLine> _linesFromText(String text) {
    final parts = text.split(RegExp(r'\n{2,}'));
    return [for (final part in parts) _TextLine(id: _nextLineId(), text: part)];
  }

  String _nextLineId() {
    _lineCounter += 1;
    return 'line-${DateTime.now().microsecondsSinceEpoch}-$_lineCounter';
  }

  String get _joinedLineText => _lines.map((line) => line.text).join('\n\n');

  bool get _shouldUseWebEditor {
    return defaultTargetPlatform == TargetPlatform.android &&
        NoteTextChunkWebEditor.isPlatformAvailable;
  }

  int _lineIndexById(String lineId) {
    return _lines.indexWhere((line) => line.id == lineId);
  }

  int _lineStartForIndex(int index) {
    var offset = 0;
    for (var i = 0; i < index; i += 1) {
      offset += _lines[i].text.length + 2;
    }
    return offset;
  }

  int _lineStartForId(String lineId) {
    final index = _lineIndexById(lineId);
    return index < 0 ? 0 : _lineStartForIndex(index);
  }

  _TextLineEditingController _controllerForLine(_TextLine line) {
    return _lineControllers.putIfAbsent(line.id, () {
      final controller = _TextLineEditingController(
        text: line.text,
        lineStart: _lineStartForId(line.id),
        rangeTags: _block.rangeTags,
      );
      controller.addListener(() => _handleLineControllerChanged(line.id));
      return controller;
    });
  }

  FocusNode _focusNodeForLine(String lineId) {
    return _lineFocusNodes.putIfAbsent(lineId, FocusNode.new);
  }

  void _configureLineController(_TextLine line) {
    final controller = _controllerForLine(line);
    controller.setTagContext(
      lineStart: _lineStartForId(line.id),
      rangeTags: _block.rangeTags,
    );
    if (controller.text != line.text) {
      _syncingLineText = true;
      try {
        controller.value = TextEditingValue(
          text: line.text,
          selection: TextSelection.collapsed(offset: line.text.length),
        );
      } finally {
        _syncingLineText = false;
      }
    }
  }

  void _handleLineControllerChanged(String lineId) {
    if (_syncingLineText) {
      return;
    }
    final controller = _lineControllers[lineId];
    final index = _lineIndexById(lineId);
    if (controller == null || index < 0) {
      return;
    }
    final value = controller.text;
    if (RegExp(r'\n{2,}').hasMatch(value)) {
      _splitLineAtNewlines(lineId, value);
      return;
    }
    final oldText = _block.text;
    if (_lines[index].text != value) {
      setState(() {
        _lines = [
          for (final line in _lines)
            if (line.id == lineId) line.copyWith(text: value) else line,
        ];
      });
      _emitJoinedText(oldText: oldText, source: 'lineChanged');
    }
    _updateSelectionState(lineId, source: 'controllerChanged');
  }

  void _splitLineAtNewlines(String lineId, String rawValue) {
    final index = _lineIndexById(lineId);
    final controller = _lineControllers[lineId];
    if (index < 0 || controller == null) {
      return;
    }
    final oldText = _block.text;
    final parts = rawValue.split(RegExp(r'\n{2,}'));
    final inserted = [
      _lines[index].copyWith(text: parts.first),
      for (final part in parts.skip(1))
        _TextLine(id: _nextLineId(), text: part),
    ];
    final focusTarget = inserted.last;
    setState(() {
      final next = [..._lines];
      next
        ..removeAt(index)
        ..insertAll(index, inserted);
      _lines = next;
      _activeLineId = focusTarget.id;
    });
    _syncingLineText = true;
    try {
      controller.value = TextEditingValue(
        text: parts.first,
        selection: TextSelection.collapsed(offset: parts.first.length),
      );
    } finally {
      _syncingLineText = false;
    }
    _emitJoinedText(oldText: oldText, source: 'splitLine');
    _requestLineFocus(focusTarget.id, offset: focusTarget.text.length);
    DebugConsole.log(
      '[TextChunk] split line parts=${parts.length} activeLine=$index',
    );
  }

  void _requestLineFocus(String lineId, {int? offset}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusNode = _lineFocusNodes[lineId];
      final controller = _lineControllers[lineId];
      if (focusNode == null || controller == null) {
        return;
      }
      final nextOffset = (offset ?? controller.text.length)
          .clamp(0, controller.text.length)
          .toInt();
      controller.selection = TextSelection.collapsed(offset: nextOffset);
      focusNode.requestFocus();
      _updateSelectionState(lineId, source: 'requestFocus');
    });
  }

  void _emitJoinedText({required String oldText, required String source}) {
    final value = _joinedLineText;
    if (value == _block.text && oldText == value) {
      return;
    }
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
    _refreshControllerTagContexts();
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk] text changed source=$source chars=${value.length} '
      'ranges=${rangeTags.length}',
    );
  }

  void _handleWebTextChanged(String value) {
    if (value == _block.text) {
      return;
    }
    final oldText = _block.text;
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
      _lines = _linesFromText(value);
    });
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk/Web] text changed chars=${value.length} '
      'ranges=${rangeTags.length}',
    );
  }

  void _handleWebRangeTagsChanged(List<NoteTextRangeTag> rangeTags) {
    setState(() {
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
    });
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk/Web] range tags changed count=${rangeTags.length}',
    );
  }

  Future<List<NoteKnowledgeTag>?> _tagWebSelection(
    TextRange range,
    List<NoteKnowledgeTag> initialTags,
  ) async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: initialTags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt rész tagje',
    );
    if (tags == null || tags.isEmpty) {
      DebugConsole.log('[TextChunk/Web] tag request cancelled');
      return null;
    }
    DebugConsole.log(
      '[TextChunk/Web] tag request start=${range.start} end=${range.end} '
      'tags=${tags.length}',
    );
    return tags;
  }

  void _refreshControllerTagContexts() {
    for (final line in _lines) {
      final controller = _lineControllers[line.id];
      if (controller == null) {
        continue;
      }
      controller.setTagContext(
        lineStart: _lineStartForId(line.id),
        rangeTags: _block.rangeTags,
      );
    }
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
    DebugConsole.log('[TextChunk] chunk tag deleted tag=${tag.metadataText}');
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
    _refreshControllerTagContexts();
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

  bool _sameTextRange(TextRange? a, TextRange? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.start == b.start && a.end == b.end;
  }

  TextRange? _selectionTargetRange() {
    final lineId = _activeLineId;
    if (lineId == null) {
      return null;
    }
    return _selectionTargetRangeForLine(lineId);
  }

  TextRange? _selectionTargetRangeForLine(String lineId) {
    final controller = _lineControllers[lineId];
    if (controller == null || _block.text.isEmpty) {
      return null;
    }
    final selection = controller.selection;
    if (!selection.isValid) {
      return null;
    }
    final lineStart = _lineStartForId(lineId);
    if (!selection.isCollapsed) {
      final start = selection.start < selection.end
          ? selection.start
          : selection.end;
      final end = selection.start < selection.end
          ? selection.end
          : selection.start;
      return TextRange(
        start: (lineStart + start).clamp(0, _block.text.length).toInt(),
        end: (lineStart + end).clamp(0, _block.text.length).toInt(),
      );
    }
    final offset = (lineStart + selection.extentOffset)
        .clamp(0, _block.text.length)
        .toInt();
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
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
      _selectionCanDeleteTag = _selectionHasTag();
      _selectionHasRange = _selectionTargetRange() != null;
      if (!_selectionHasRange) {
        _activeRailRange = null;
      }
    });
    _refreshControllerTagContexts();
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk] range tags cleared start=${targetRange.start} '
      'end=${targetRange.end}',
    );
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
    _refreshControllerTagContexts();
    widget.onChanged(_block);
    DebugConsole.log(
      '[TextChunk] single range tag deleted ${tag.metadataText}',
    );
  }

  void _focusTaggedRange(int direction) {
    if (_block.rangeTags.isEmpty) {
      return;
    }
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
    final lineId = _lineIdForOffset(target.start);
    if (lineId == null) {
      return;
    }
    final localOffset = target.start - _lineStartForId(lineId);
    setState(() {
      _activeLineId = lineId;
      _activeRailRange = TextRange(start: target.start, end: target.end);
      _selectionCanDeleteTag = true;
      _selectionHasRange = true;
    });
    _requestLineFocus(lineId, offset: localOffset);
    DebugConsole.log(
      '[TextChunk] focus tagged direction=$direction start=${target.start} '
      'end=${target.end}',
    );
  }

  String? _lineIdForOffset(int offset) {
    for (var index = 0; index < _lines.length; index += 1) {
      final start = _lineStartForIndex(index);
      final end = start + _lines[index].text.length;
      if (offset >= start && offset <= end) {
        return _lines[index].id;
      }
    }
    return _lines.isEmpty ? null : _lines.last.id;
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

  void _updateSelectionState(String lineId, {required String source}) {
    final nextRailRange = _selectionTargetRangeForLine(lineId);
    final previousRange = _activeRailRange;
    final nextCanDelete = nextRailRange != null && _rangeHasTag(nextRailRange);
    final nextHasRange = nextRailRange != null;
    if (nextCanDelete == _selectionCanDeleteTag &&
        nextHasRange == _selectionHasRange &&
        _sameTextRange(nextRailRange, _activeRailRange) &&
        _activeLineId == (nextHasRange ? lineId : _activeLineId)) {
      return;
    }
    setState(() {
      _activeLineId = nextHasRange ? lineId : null;
      _activeRailRange = nextRailRange;
      _selectionCanDeleteTag = nextCanDelete;
      _selectionHasRange = nextHasRange;
    });
    DebugConsole.log(
      '[TextChunk] selection source=$source line=${_lineIndexById(lineId)} '
      'range=${nextRailRange == null ? 'none' : '${nextRailRange.start}-${nextRailRange.end}'} '
      'previous=${previousRange == null ? 'none' : '${previousRange.start}-${previousRange.end}'}',
    );
  }

  bool _rangeHasTag(TextRange range) {
    return _block.rangeTags.any(
      (tag) => tag.start < range.end && tag.end > range.start,
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

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _changeParagraphIndent(int delta) {
    final activeLineId = _activeLineId;
    if (activeLineId == null) {
      return;
    }
    final index = _lineIndexById(activeLineId);
    if (index < 0) {
      return;
    }
    if (_lines[index].text.trim().isEmpty) {
      return;
    }
    final oldText = _block.text;
    setState(() {
      _lines = [
        for (var i = 0; i < _lines.length; i += 1)
          if (i == index)
            _lines[i].copyWith(text: _indentedLine(_lines[i].text, delta))
          else
            _lines[i],
      ];
    });
    _emitJoinedText(oldText: oldText, source: 'indent');
  }

  String _indentedLine(String text, int delta) {
    if (text.trim().isEmpty) {
      return text;
    }
    if (text.contains('\n')) {
      return text
          .split('\n')
          .map((line) => _indentedLine(line, delta))
          .join('\n');
    }
    if (delta > 0) {
      return '  $text';
    }
    if (text.startsWith('  ')) {
      return text.substring(2);
    }
    if (text.startsWith(' ')) {
      return text.substring(1);
    }
    return text;
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
              child: _shouldUseWebEditor
                  ? NoteTextChunkWebEditor(
                      block: _block,
                      onTextChanged: _handleWebTextChanged,
                      onRangeTagsChanged: _handleWebRangeTagsChanged,
                      onTagRequested: _tagWebSelection,
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var index = 0; index < _lines.length; index += 1)
                            _buildLineEditor(index),
                          const SizedBox(height: 220),
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

  Widget _buildLineEditor(int index) {
    final line = _lines[index];
    _configureLineController(line);
    final selected = _activeLineId == line.id && _selectionHasRange;
    final controller = _controllerForLine(line);
    return Padding(
      key: ValueKey('note-text-line-shell-${line.id}'),
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: ValueKey(
              index == 0
                  ? 'note-text-chunk-field'
                  : 'note-text-chunk-field-$index',
            ),
            controller: controller,
            focusNode: _focusNodeForLine(line.id),
            autofocus: index == 0 && line.text.isEmpty,
            minLines: 1,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            cursorColor: const Color(0xFF111827),
            decoration: InputDecoration(
              hintText: index == 0 ? 'Írd ide a chunk tartalmát' : null,
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 2),
            ),
            style: const TextStyle(color: Color(0xFF111827), fontSize: 16),
            onTap: () {
              _activeLineId = line.id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _updateSelectionState(line.id, source: 'tap');
                }
              });
            },
          ),
          _TextLineSecondaryUnderlines(
            lineText: line.text,
            lineStart: _lineStartForId(line.id),
            lineTextLength: line.text.length,
            rangeTags: _block.rangeTags,
          ),
          if (selected)
            Padding(
              key: const ValueKey('note-text-inline-selection-rail'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _buildSelectionRail(),
            ),
        ],
      ),
    );
  }
}

class _TextLine {
  const _TextLine({required this.id, required this.text});

  final String id;
  final String text;

  _TextLine copyWith({String? text}) {
    return _TextLine(id: id, text: text ?? this.text);
  }
}

class _TextLineEditingController extends TextEditingController {
  _TextLineEditingController({
    required String text,
    required int lineStart,
    required List<NoteTextRangeTag> rangeTags,
  }) : _lineStart = lineStart,
       _rangeTags = rangeTags,
       super(text: text);

  int _lineStart;
  List<NoteTextRangeTag> _rangeTags;

  void setTagContext({
    required int lineStart,
    required List<NoteTextRangeTag> rangeTags,
  }) {
    _lineStart = lineStart;
    _rangeTags = rangeTags;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textValue = text;
    if (textValue.isEmpty) {
      return TextSpan(style: style, text: textValue);
    }
    final lineEnd = _lineStart + textValue.length;
    final breakpoints = <int>{0, textValue.length};
    for (final rawTag in _rangeTags) {
      final range = rawTag.clampToTextLength(lineEnd);
      if (!range.isValid || range.start >= lineEnd || range.end <= _lineStart) {
        continue;
      }
      breakpoints.add(
        (range.start - _lineStart).clamp(0, textValue.length).toInt(),
      );
      breakpoints.add(
        (range.end - _lineStart).clamp(0, textValue.length).toInt(),
      );
    }
    final sorted = breakpoints.toList()..sort();
    final spans = <InlineSpan>[];
    for (var i = 0; i < sorted.length - 1; i += 1) {
      final localStart = sorted[i];
      final localEnd = sorted[i + 1];
      if (localStart >= localEnd) {
        continue;
      }
      final tags = _tagsForSegment(
        _rangeTags,
        _lineStart + localStart,
        _lineStart + localEnd,
        lineEnd,
      );
      spans.add(
        TextSpan(
          text: textValue.substring(localStart, localEnd),
          style: tags.isEmpty ? null : _taggedTextStyle(tags, alpha: 0.22),
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TextLineSecondaryUnderlines extends StatelessWidget {
  const _TextLineSecondaryUnderlines({
    required this.lineText,
    required this.lineStart,
    required this.lineTextLength,
    required this.rangeTags,
  });

  final String lineText;
  final int lineStart;
  final int lineTextLength;
  final List<NoteTextRangeTag> rangeTags;

  @override
  Widget build(BuildContext context) {
    final groups = _mergedLineTagGroups(
      rangeTags: rangeTags,
      lineStart: lineStart,
      lineEnd: lineStart + lineTextLength,
    );
    final underlineEntries =
        <({String id, int start, int end, List<NoteKnowledgeTag> tags})>[
          for (final group in groups)
            if (group.tags.length > 1) group,
        ];
    if (underlineEntries.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxSecondaryCount = underlineEntries
        .map((group) => group.tags.length - 1)
        .fold<int>(0, (max, count) => count > max ? count : max);
    return SizedBox(
      height: maxSecondaryCount * 4 + 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              for (final group in underlineEntries)
                for (var index = 1; index < group.tags.length; index += 1)
                  CustomPaint(
                    key: ValueKey(
                      'note-text-secondary-underline-${group.id}-$index',
                    ),
                    painter: _TextSegmentUnderlinePainter(
                      text: lineText,
                      rangeStart: group.start - lineStart,
                      rangeEnd: group.end - lineStart,
                      color: Color(group.tags[index].resolvedColorValue),
                      underlineIndex: index - 1,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _TextSegmentUnderlinePainter extends CustomPainter {
  const _TextSegmentUnderlinePainter({
    required this.text,
    required this.rangeStart,
    required this.rangeEnd,
    required this.color,
    required this.underlineIndex,
  });

  final String text;
  final int rangeStart;
  final int rangeEnd;
  final Color color;
  final int underlineIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || rangeStart >= rangeEnd) {
      return;
    }
    final start = rangeStart.clamp(0, text.length).toInt();
    final end = rangeEnd.clamp(0, text.length).toInt();
    if (start >= end) {
      return;
    }
    final textDirection = TextDirection.ltr;
    final baseStyle = const TextStyle(fontSize: 16, color: Color(0xFF111827));
    final beforePainter = TextPainter(
      text: TextSpan(text: text.substring(0, start), style: baseStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    final segmentPainter = TextPainter(
      text: TextSpan(text: text.substring(start, end), style: baseStyle),
      textDirection: textDirection,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    final left = beforePainter.width.clamp(0.0, size.width).toDouble();
    final right = (left + segmentPainter.width)
        .clamp(left, size.width)
        .toDouble();
    if (right <= left) {
      return;
    }
    final y = 2.0 + underlineIndex * 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), paint);
  }

  @override
  bool shouldRepaint(covariant _TextSegmentUnderlinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.rangeStart != rangeStart ||
        oldDelegate.rangeEnd != rangeEnd ||
        oldDelegate.color != color ||
        oldDelegate.underlineIndex != underlineIndex;
  }
}

List<({String id, int start, int end, List<NoteKnowledgeTag> tags})>
_mergedLineTagGroups({
  required List<NoteTextRangeTag> rangeTags,
  required int lineStart,
  required int lineEnd,
}) {
  final groups =
      <
        String,
        ({String id, int start, int end, List<NoteKnowledgeTag> tags})
      >{};
  for (final rawTag in rangeTags) {
    final range = rawTag.clampToTextLength(lineEnd);
    if (!range.isValid || range.start >= lineEnd || range.end <= lineStart) {
      continue;
    }
    final start = range.start < lineStart ? lineStart : range.start;
    final end = range.end > lineEnd ? lineEnd : range.end;
    final key = '$start:$end';
    final existing = groups[key];
    final tags = existing == null ? <NoteKnowledgeTag>[] : [...existing.tags];
    for (final tag in range.resolvedTags) {
      if (!tags.any((current) => current.metadataText == tag.metadataText)) {
        tags.add(tag);
      }
    }
    groups[key] = (
      id: existing?.id ?? range.id,
      start: start,
      end: end,
      tags: tags,
    );
  }
  return groups.values.toList(growable: false);
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
