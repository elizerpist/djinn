import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../models/note_document.dart';
import '../models/note_item.dart';

class NoteEditorRoute extends StatefulWidget {
  const NoteEditorRoute({
    super.key,
    required this.repository,
    required this.initialNote,
  });

  final NoteRepository repository;
  final NoteItem initialNote;

  @override
  State<NoteEditorRoute> createState() => _NoteEditorRouteState();
}

class _NoteEditorRouteState extends State<NoteEditorRoute> {
  late NoteItem _note;
  late NoteDocument _document;
  late final TextEditingController _titleController;
  bool _persisting = false;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _document = _note.document;
    _titleController = TextEditingController(text: _note.title);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_persisting) {
      return;
    }
    _persisting = true;
    try {
      final updated = await widget.repository.updateNoteDocument(
        _note.id,
        title: _normalizedTitle,
        document: _document,
      );
      if (!mounted) {
        return;
      }
      setState(() => _note = updated);
    } finally {
      _persisting = false;
    }
  }

  String get _normalizedTitle {
    final trimmed = _titleController.text.trim();
    return trimmed.isEmpty ? 'Névtelen jegyzet' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-editor-route'),
      appBar: AppBar(
        title: Text(_note.title.trim().isEmpty ? 'Jegyzet' : _note.title),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('note-editor-menu'),
            tooltip: 'Jegyzet menü',
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'index', child: Text('Indexelés / újraindexelés')),
              PopupMenuItem(value: 'chunks', child: Text('Chunkok megtekintése')),
              PopupMenuItem(value: 'delete', child: Text('Törlés')),
            ],
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            key: const ValueKey('note-editor-title-field'),
            controller: _titleController,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            decoration: const InputDecoration(
              hintText: 'Írható inline cím',
              border: InputBorder.none,
            ),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 16),
          for (final block in _document.blocks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TemporaryBlockPreview(block: block),
            ),
        ],
      ),
    );
  }
}

class _TemporaryBlockPreview extends StatelessWidget {
  const _TemporaryBlockPreview({required this.block});

  final NoteBlock block;

  @override
  Widget build(BuildContext context) {
    final text = block.plainText.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text.isEmpty ? 'Üres chunk' : text),
      ),
    );
  }
}
