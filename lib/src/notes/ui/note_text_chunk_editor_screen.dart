import 'package:flutter/material.dart';

import '../models/note_document.dart';

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

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _controller = TextEditingController(text: widget.block.text);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(NoteTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _block = widget.block;
    if (oldWidget.block.id != widget.block.id ||
        widget.block.text != _controller.text) {
      _syncControllerText(widget.block.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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

  void _handleTextChanged(String value) {
    if (_syncingController) {
      return;
    }
    final nextBlock = _block.copyWith(
      text: value,
      rangeTags: const <NoteTextRangeTag>[],
      paragraphStyles: const <NoteTextParagraphStyle>[],
      clearIndex: true,
    );
    setState(() => _block = nextBlock);
    widget.onChanged(nextBlock);
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final title = _block.title?.trim().isNotEmpty == true
        ? _block.title!.trim()
        : (_block.type == NoteBlockType.heading ? 'Címsor' : 'Szöveg');
    return Scaffold(
      key: const ValueKey('note-text-chunk-editor'),
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              tooltip: 'Törlés',
              onPressed: _deleteChunk,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Container(
        key: const ValueKey('note-text-chunk-body'),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: TextField(
            key: const ValueKey('note-text-plain-field'),
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            minLines: null,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(color: Color(0xFF111827), fontSize: 16),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Írj valamit...',
            ),
            onChanged: _handleTextChanged,
          ),
        ),
      ),
    );
  }
}
