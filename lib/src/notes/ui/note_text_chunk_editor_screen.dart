import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'tag_manager_sheet.dart';

class NoteTextChunkEditorScreen extends StatefulWidget {
  const NoteTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;

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
      singleSelection: true,
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
      appBar: AppBar(
        title: Text(_block.type == NoteBlockType.heading ? 'Címsor szerkesztése' : 'Szöveg szerkesztése'),
        actions: [
          IconButton(
            key: const ValueKey('note-text-tag-selection'),
            tooltip: 'Kijelölt rész tagelése',
            onPressed: () => unawaited(_tagSelection()),
            icon: const Icon(Icons.label_outline),
          ),
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          );
        }
        final replacementEnd = newSuffix;
        if (tag.start >= prefix && tag.end <= oldSuffix) {
          return NoteTextRangeTag(
            id: tag.id,
            start: prefix,
            end: replacementEnd,
            tag: tag.tag,
          );
        }
        return NoteTextRangeTag(
          id: tag.id,
          start: tag.start < prefix ? tag.start : prefix,
          end: (tag.end + delta) > replacementEnd
              ? tag.end + delta
              : replacementEnd,
          tag: tag.tag,
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
            rangeTag.tag.resolvedColorValue,
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
