import 'package:flutter/material.dart';

import '../models/note_document.dart';

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
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = TextEditingController(text: widget.block.text);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _emitText(String value) {
    _block = _block.copyWith(text: value, clearIndex: true);
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
