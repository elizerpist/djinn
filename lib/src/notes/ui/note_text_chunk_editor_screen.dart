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

  static const _textStyle = TextStyle(color: Color(0xFF111827), fontSize: 16);

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
    final paragraph = oldText.substring(
      paragraphRange.start,
      paragraphRange.end,
    );
    final nextParagraph = paragraph
        .split('\n')
        .map((line) => _indentedLine(line, delta))
        .join('\n');
    final nextText =
        oldText.substring(0, paragraphRange.start) +
        nextParagraph +
        oldText.substring(paragraphRange.end);
    if (nextText == oldText) {
      return;
    }
    final rangeTags = _adjustRangeTagsForEdit(
      oldText: oldText,
      newText: nextText,
      tags: _block.rangeTags,
    );
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
          offset: (offset + (nextText.length - oldText.length))
              .clamp(0, nextText.length)
              .toInt(),
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

  String _indentedLine(String text, int delta) {
    if (text.trim().isEmpty) {
      return text;
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(),
                    if (_selectionHasRange)
                      Padding(
                        key: const ValueKey('note-text-inline-selection-rail'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _buildSelectionRail(),
                      ),
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

  Widget _buildTextField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            TextField(
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
                contentPadding: EdgeInsets.symmetric(vertical: 2),
              ),
              style: _textStyle,
              onTap: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _updateSelectionState(source: 'tap');
                  }
                });
              },
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _TextSecondaryUnderlinePainter(
                    text: _controller.text,
                    rangeTags: _block.rangeTags,
                    textStyle: _textStyle,
                    maxWidth: constraints.maxWidth,
                  ),
                ),
              ),
            ),
            for (final marker in _secondaryUnderlineMarkers(_block.rangeTags))
              Positioned(
                key: ValueKey(
                  'note-text-secondary-underline-${marker.id}-${marker.index}',
                ),
                left: 0,
                top: 0,
                child: const SizedBox.shrink(),
              ),
          ],
        );
      },
    );
  }
}

class _TextChunkEditingController extends TextEditingController {
  _TextChunkEditingController({
    required String text,
    required List<NoteTextRangeTag> rangeTags,
  }) : _rangeTags = rangeTags,
       super(text: text);

  List<NoteTextRangeTag> _rangeTags;

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
    final textValue = text;
    if (textValue.isEmpty) {
      return TextSpan(style: style, text: textValue);
    }
    final breakpoints = <int>{0, textValue.length};
    for (final rawTag in _rangeTags) {
      final range = rawTag.clampToTextLength(textValue.length);
      if (!range.isValid) {
        continue;
      }
      breakpoints.add(range.start);
      breakpoints.add(range.end);
    }
    final sorted = breakpoints.toList()..sort();
    final spans = <InlineSpan>[];
    for (var i = 0; i < sorted.length - 1; i += 1) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start >= end) {
        continue;
      }
      final tags = _tagsForSegment(_rangeTags, start, end, textValue.length);
      spans.add(
        TextSpan(
          text: textValue.substring(start, end),
          style: tags.isEmpty ? null : _taggedTextStyle(tags, alpha: 0.22),
        ),
      );
    }
    return TextSpan(style: style, children: spans);
  }
}

class _TextSecondaryUnderlinePainter extends CustomPainter {
  const _TextSecondaryUnderlinePainter({
    required this.text,
    required this.rangeTags,
    required this.textStyle,
    required this.maxWidth,
  });

  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final TextStyle textStyle;
  final double maxWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty || rangeTags.isEmpty || maxWidth <= 0) {
      return;
    }
    final groups = _mergedTextTagGroups(
      rangeTags: rangeTags,
      textLength: text.length,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    for (final group in groups) {
      if (group.tags.length <= 1) {
        continue;
      }
      final boxes = textPainter.getBoxesForSelection(
        TextSelection(baseOffset: group.start, extentOffset: group.end),
      );
      for (var index = 1; index < group.tags.length; index += 1) {
        final paint = Paint()
          ..color = Color(group.tags[index].resolvedColorValue)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (final box in boxes) {
          final y = box.bottom + 2 + ((index - 1) * 4.0);
          canvas.drawLine(Offset(box.left, y), Offset(box.right, y), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TextSecondaryUnderlinePainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.rangeTags != rangeTags ||
        oldDelegate.textStyle != textStyle ||
        oldDelegate.maxWidth != maxWidth;
  }
}

List<({String id, int index})> _secondaryUnderlineMarkers(
  List<NoteTextRangeTag> rangeTags,
) {
  final groups = _mergedTextTagGroups(
    rangeTags: rangeTags,
    textLength: rangeTags.fold<int>(
      0,
      (max, range) => range.end > max ? range.end : max,
    ),
  );
  return [
    for (final group in groups)
      if (group.tags.length > 1)
        for (var index = 1; index < group.tags.length; index += 1)
          (id: group.id, index: index),
  ];
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
