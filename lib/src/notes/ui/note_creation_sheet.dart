import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/note_repository.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';

class NoteCreationSheet extends StatefulWidget {
  const NoteCreationSheet({
    super.key,
    required this.repository,
    required this.folders,
    this.activeFolderId,
  });

  final NoteRepository repository;
  final List<NoteFolder> folders;
  final String? activeFolderId;

  @override
  State<NoteCreationSheet> createState() => _NoteCreationSheetState();
}

class _NoteCreationSheetState extends State<NoteCreationSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  NoteItemType _type = NoteItemType.text;
  String? _folderId;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _folderId = widget.activeFolderId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _errorText = 'A cím és a tartalom kötelező.');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await widget.repository.createNote(
        type: _type,
        title: title,
        plainText: _plainText(content),
        payloadJson: _payloadJson(content),
        folderId: _folderId,
      );
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

  String _plainText(String content) {
    return switch (_type) {
      NoteItemType.text => content,
      NoteItemType.table => content
          .split('\n')
          .map((line) => line.split('|').map((cell) => cell.trim()).join(' | '))
          .join('\n'),
      NoteItemType.flowchart => content,
    };
  }

  String _payloadJson(String content) {
    return switch (_type) {
      NoteItemType.text => jsonEncode({'type': 'text', 'text': content}),
      NoteItemType.table => jsonEncode({
          'type': 'table',
          'rows': content
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) => line.split('|').map((cell) => cell.trim()).toList())
              .toList(),
        }),
      NoteItemType.flowchart => jsonEncode({
          'type': 'flowchart',
          'lines': content
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(),
        }),
    };
  }

  String get _contentLabel {
    return switch (_type) {
      NoteItemType.text => 'Kinyert tartalom',
      NoteItemType.table => 'Táblázat sorai (cellák: |)',
      NoteItemType.flowchart => 'Flowchart lépések / kapcsolatok',
    };
  }

  String get _contentHint {
    return switch (_type) {
      NoteItemType.text => 'Írd be vagy illeszd be a kézi chunkot.',
      NoteItemType.table => 'Gyógyszer | Dózis\nASA | 250 mg',
      NoteItemType.flowchart => 'Start -> Döntés [igen]\nDöntés -> Szállítás [nem]',
    };
  }

  @override
  Widget build(BuildContext context) {
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
                'Új jegyzet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<NoteItemType>(
                key: const ValueKey('note-create-type-dropdown'),
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Mit szeretnél létrehozni?',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: NoteItemType.text,
                    child: Text('Szöveges chunk'),
                  ),
                  DropdownMenuItem(
                    value: NoteItemType.table,
                    child: Text('Táblázat'),
                  ),
                  DropdownMenuItem(
                    value: NoteItemType.flowchart,
                    child: Text('Flowchart'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
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
                  labelText: 'Cím',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('note-create-content-field'),
                controller: _contentController,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: _contentLabel,
                  hintText: _contentHint,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
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
                  const SizedBox(width: 10),
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
