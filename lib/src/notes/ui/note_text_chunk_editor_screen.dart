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
    this.onDelete,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final VoidCallback? onDelete;

  @override
  State<NoteTextChunkEditorScreen> createState() => _NoteTextChunkEditorScreenState();
}

class _NoteTextChunkEditorScreenState extends State<NoteTextChunkEditorScreen> {
  late NoteBlock _block;
  late final _TaggedTextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = _TaggedTextEditingController(
      text: widget.block.text,
      rangeTags: widget.block.rangeTags,
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _emitText(String value) {
    final rangeTags = _adjustRangeTagsForEdit(
      oldText: _block.text,
      newText: value,
      tags: _block.rangeTags,
    );
    _controller.rangeTags = rangeTags;
    _block = _block.copyWith(
      text: value,
      rangeTags: rangeTags,
      clearIndex: true,
    );
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
      title: 'Chunk tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() => _block = _block.copyWith(tags: tags, clearIndex: true));
    widget.onChanged(_block);
  }

  Future<void> _tagSelection() async {
    final text = _controller.text;
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed || text.isEmpty) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jelölj ki egy szövegrészt a tageléshez')),
      );
      return;
    }
    final start = selection.start < selection.end ? selection.start : selection.end;
    final end = selection.start < selection.end ? selection.end : selection.start;
    final tags = await showTagManagerSheet(
      context,
      initialTags: const [],
      title: 'Kijelölt rész tagje',
    );
    if (tags == null || tags.isEmpty) {
      return;
    }
    final rangeTag = NoteTextRangeTag(
      id: 'range-${DateTime.now().microsecondsSinceEpoch}',
      start: start.clamp(0, text.length).toInt(),
      end: end.clamp(0, text.length).toInt(),
      tag: tags.first,
      tags: tags,
    );
    if (!rangeTag.isValid) {
      return;
    }
    setState(() {
      final rangeTags = [..._block.rangeTags, rangeTag];
      _controller.rangeTags = rangeTags;
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
    });
    widget.onChanged(_block);
  }

  bool _selectionHasTag() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return false;
    }
    final start = selection.start < selection.end ? selection.start : selection.end;
    final end = selection.start < selection.end ? selection.end : selection.start;
    return _block.rangeTags.any(
      (tag) => tag.start < end && tag.end > start,
    );
  }

  void _deleteSelectedTag() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      return;
    }
    final start = selection.start < selection.end ? selection.start : selection.end;
    final end = selection.start < selection.end ? selection.end : selection.start;
    setState(() {
      final rangeTags = _block.rangeTags
          .where((tag) => !(tag.start < end && tag.end > start))
          .toList(growable: false);
      _controller.rangeTags = rangeTags;
      _block = _block.copyWith(rangeTags: rangeTags, clearIndex: true);
    });
    widget.onChanged(_block);
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
        fallbackTitle: _block.type == NoteBlockType.heading ? 'Címsor' : 'Szöveg',
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selectionHasTag(),
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
      body: Column(
        children: [
          if (_block.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NoteTagPills(tags: _block.tags),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey('note-text-chunk-field'),
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Írd ide a chunk tartalmát',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16, height: 1.45),
                onChanged: _emitText,
              ),
            ),
          ),
          if (_block.rangeTags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NoteTagPills(
                  tags: [
                    for (final rangeTag in _block.rangeTags)
                      ...rangeTag.resolvedTags,
                  ],
                  prefix: 'note-local-tag-pill',
                ),
              ),
            ),
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
  })  : _rangeTags = rangeTags,
        super(text: text);

  List<NoteTextRangeTag> _rangeTags;

  set rangeTags(List<NoteTextRangeTag> value) {
    _rangeTags = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final textValue = text;
    final validTags = _rangeTags
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
      spans.add(TextSpan(
        text: textValue.substring(rangeTag.start, rangeTag.end),
        style: TextStyle(
          backgroundColor: Color(
            rangeTag.resolvedTags.first.resolvedColorValue,
          ).withValues(alpha: 0.22),
          fontWeight: FontWeight.w600,
        ),
      ));
      cursor = rangeTag.end;
    }
    if (cursor < textValue.length) {
      spans.add(TextSpan(text: textValue.substring(cursor)));
    }
    return TextSpan(style: style, children: spans);
  }
}

void unawaited(Future<void> future) {}
