import 'package:flutter/material.dart';

import '../../knowledge/models/local_extraction.dart';
import '../data/note_repository.dart';
import '../models/note_document.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';
import 'note_document_editor_screen.dart';

class NoteCreationSheet extends StatefulWidget {
  const NoteCreationSheet({
    super.key,
    required this.repository,
    required this.folders,
    this.activeFolderId,
    this.initialNote,
  });

  final NoteRepository repository;
  final List<NoteFolder> folders;
  final String? activeFolderId;
  final NoteItem? initialNote;

  @override
  State<NoteCreationSheet> createState() => _NoteCreationSheetState();
}

class _NoteCreationSheetState extends State<NoteCreationSheet> {
  final _titleController = TextEditingController();
  late NoteDocument _document;
  String? _folderId;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final initialNote = widget.initialNote;
    _folderId = initialNote?.folderId ?? widget.activeFolderId;
    _titleController.text = initialNote?.title ?? '';
    _document = initialNote?.document ?? NoteDocument.empty();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _openFullEditor() async {
    final result = await Navigator.of(context).push<NoteDocumentEditorResult>(
      MaterialPageRoute(
        builder: (_) => NoteDocumentEditorScreen(
          title: _titleController.text.trim(),
          document: _document,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _titleController.text = result.title;
      _document = result.document;
      _errorText = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _document.plainText.trim().isEmpty) {
      setState(() => _errorText = 'A cím és a tartalom kötelező.');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final initialNote = widget.initialNote;
      if (initialNote == null) {
        await widget.repository.createDocumentNote(
          title: title,
          document: _document,
          folderId: _folderId,
        );
      } else {
        await widget.repository.updateNoteDocument(
          initialNote.id,
          title: title,
          document: _document,
          auditState: LocalAuditState.edited,
          reason: initialNote.reason,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _errorText = 'A jegyzet mentése nem sikerült: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _document.preview;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.initialNote == null ? 'Új jegyzet' : 'Jegyzet szerkesztése',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              if (widget.folders.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  key: const ValueKey('note-create-folder-field'),
                  initialValue: _folderId,
                  decoration: const InputDecoration(
                    labelText: 'Mappa',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Nincs mappa'),
                    ),
                    for (final folder in widget.folders)
                      DropdownMenuItem<String?>(
                        value: folder.id,
                        child: Text(folder.title),
                      ),
                  ],
                  onChanged: (value) => setState(() => _folderId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('note-create-title-field'),
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Név',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                key: const ValueKey('note-create-preview-box'),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Előnézet',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        preview.isEmpty
                            ? 'Nyisd meg a teljes editort, és írj szöveget vagy adj hozzá táblázatot/flowchartot.'
                            : preview,
                        maxLines: 8,
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Mégse'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('note-create-open-editor'),
                      onPressed: _saving ? null : _openFullEditor,
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('Teljes editor'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('note-create-save'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Mentés'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
