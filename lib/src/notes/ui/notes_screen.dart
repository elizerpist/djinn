import 'package:flutter/material.dart';

import '../../shared/chunks/chunk_card.dart';
import '../../shared/chunks/chunk_validation_card.dart';
import '../../shared/ui/draggable_bottom_card.dart';
import '../data/note_repository.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';
import 'note_creation_sheet.dart';

enum _NoteSortMode { newestFirst, oldestFirst, titleAsc, titleDesc }

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.repository});

  final NoteRepository repository;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteFolder> _folders = const [];
  List<NoteItem> _notes = const [];
  String? _activeFolderId;
  bool _showFolderBar = false;
  _NoteSortMode _sortMode = _NoteSortMode.newestFirst;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.repository.load();
    final folders = await widget.repository.listFolders();
    final notes = await widget.repository.listNotes(folderId: _activeFolderId);
    if (!mounted) {
      return;
    }
    setState(() {
      _folders = folders;
      _notes = _sort(notes);
      if (_activeFolderId != null && !folders.any((f) => f.id == _activeFolderId)) {
        _activeFolderId = null;
      }
    });
  }

  List<NoteItem> _sort(List<NoteItem> notes) {
    final sorted = [...notes];
    sorted.sort((a, b) {
      return switch (_sortMode) {
        _NoteSortMode.newestFirst => b.updatedAt.compareTo(a.updatedAt),
        _NoteSortMode.oldestFirst => a.updatedAt.compareTo(b.updatedAt),
        _NoteSortMode.titleAsc => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        _NoteSortMode.titleDesc => b.title.toLowerCase().compareTo(a.title.toLowerCase()),
      };
    });
    return sorted;
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Új mappa'),
        content: TextField(
          key: const ValueKey('notes-folder-name-field'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mappa neve',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    await widget.repository.createFolder(trimmed);
    await _load();
  }

  Future<void> _openValidationCard(NoteItem note) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableBottomCard(
        onDismiss: () => Navigator.of(context).pop(),
        child: ChunkValidationCard(
          title: note.title,
          initialText: note.plainText,
          initialAuditState: note.auditState,
          initialReason: note.reason,
          onCancel: () => Navigator.of(context).pop(),
          onSave: (result) async {
            await widget.repository.updateNoteValidation(
              note.id,
              auditState: result.auditState,
              plainText: result.text,
              payloadJson: note.payloadJson,
              reason: result.reason,
            );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
            await _load();
          },
        ),
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => NoteCreationSheet(
        repository: widget.repository,
        folders: _folders,
        activeFolderId: _activeFolderId,
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  void _setSort(_NoteSortMode mode) {
    setState(() {
      _sortMode = mode;
      _notes = _sort(_notes);
    });
  }

  List<PopupMenuEntry<Object>> _menuItems() {
    return [
      PopupMenuItem<String>(
        value: 'toggle-folders',
        child: Text(_showFolderBar ? 'Mappasáv elrejtése' : 'Mappasáv mutatása'),
      ),
      const PopupMenuItem<String>(value: 'new-folder', child: Text('Új mappa')),
      const PopupMenuDivider(),
      const PopupMenuItem<_NoteSortMode>(
        value: _NoteSortMode.newestFirst,
        child: Text('Rendezés: legújabb elöl'),
      ),
      const PopupMenuItem<_NoteSortMode>(
        value: _NoteSortMode.titleAsc,
        child: Text('Rendezés: cím A-Z'),
      ),
    ];
  }

  Future<void> _handleMenu(Object value) async {
    if (value == 'toggle-folders') {
      setState(() => _showFolderBar = !_showFolderBar);
      return;
    }
    if (value == 'new-folder') {
      await _createFolder();
      return;
    }
    if (value is _NoteSortMode) {
      _setSort(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jegyzetek'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          PopupMenuButton<Object>(
            key: const ValueKey('notes-header-menu'),
            tooltip: 'Jegyzetek menü',
            onSelected: _handleMenu,
            itemBuilder: (context) => _menuItems(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showFolderBar) _FolderBar(
            folders: _folders,
            activeFolderId: _activeFolderId,
            onSelected: (folderId) async {
              setState(() => _activeFolderId = folderId);
              await _load();
            },
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('notes-create-fab'),
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Új jegyzet'),
      ),
    );
  }

  Widget _buildList() {
    if (_notes.isEmpty) {
      return const Center(
        child: Text(
          'Nincs mentett jegyzet',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: _notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _NoteCard(
        note: _notes[index],
        onValidate: () => _openValidationCard(_notes[index]),
      ),
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.folders,
    required this.activeFolderId,
    required this.onSelected,
  });

  final List<NoteFolder> folders;
  final String? activeFolderId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('notes-folder-bar'),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Összes'),
              selected: activeFolderId == null,
              onSelected: (_) => onSelected(null),
            ),
            for (final folder in folders) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(folder.title),
                selected: activeFolderId == folder.id,
                onSelected: (_) => onSelected(folder.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onValidate});

  final NoteItem note;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    return ChunkCard(
      viewModel: ChunkCardViewModel(
        id: 'note-${note.id}',
        title: note.title,
        preview: note.plainText,
        kind: _kindForType(note.type),
        auditState: note.auditState,
        sourceLabel: 'Jegyzet',
        pipelineLabel: 'Manuális',
      ),
      onLongPress: onValidate,
      metadata:
          '${note.type.label} - ${note.updatedAt.year}.${note.updatedAt.month.toString().padLeft(2, '0')}.${note.updatedAt.day.toString().padLeft(2, '0')}',
      expandedChild: SelectableText(note.plainText),
    );
  }

  ChunkCardKind _kindForType(NoteItemType type) {
    return switch (type) {
      NoteItemType.text => ChunkCardKind.text,
      NoteItemType.table => ChunkCardKind.table,
      NoteItemType.flowchart => ChunkCardKind.flowchart,
    };
  }
}
