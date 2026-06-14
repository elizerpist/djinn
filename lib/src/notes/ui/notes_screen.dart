import 'package:flutter/material.dart';

import '../../shared/chunks/chunk_validation_card.dart';
import '../../shared/ui/draggable_bottom_card.dart';
import '../data/note_chunk_builder.dart';
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
  bool _showFolderBar = true;
  bool _hasAnyNotes = false;
  _NoteSortMode _sortMode = _NoteSortMode.newestFirst;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.repository.load();
    final folders = await widget.repository.listFolders();
    final allNotes = await widget.repository.listNotes();
    final notes = await widget.repository.listNotes(folderId: _activeFolderId);
    if (!mounted) {
      return;
    }
    setState(() {
      _folders = folders;
      _notes = _sort(notes);
      _hasAnyNotes = allNotes.isNotEmpty;
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
    controller.dispose();
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

  Future<void> _openCreateSheet({NoteItem? note}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => NoteCreationSheet(
        repository: widget.repository,
        folders: _folders,
        activeFolderId: _activeFolderId,
        initialNote: note,
      ),
    );
    if (saved == true) {
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
    final showFolderBar = _showFolderBar && (_folders.isNotEmpty || _hasAnyNotes);
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
          if (showFolderBar)
            _FolderBar(
              folders: _folders,
              activeFolderId: _activeFolderId,
              showAll: _hasAnyNotes,
              onSelected: (folderId) async {
                setState(() => _activeFolderId = folderId);
                await _load();
              },
            ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('notes-create-fab'),
        tooltip: 'Új jegyzet',
        onPressed: () => _openCreateSheet(),
        child: const Icon(Icons.note_add_outlined),
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
      itemBuilder: (context, index) => _NoteBox(
        note: _notes[index],
        onOpen: () => _openCreateSheet(note: _notes[index]),
        onValidate: () => _openValidationCard(_notes[index]),
      ),
    );
  }
}

class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.folders,
    required this.activeFolderId,
    required this.showAll,
    required this.onSelected,
  });

  final List<NoteFolder> folders;
  final String? activeFolderId;
  final bool showAll;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('notes-folder-bar'),
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.white,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              if (showAll)
                ChoiceChip(
                  key: const ValueKey('notes-folder-pill-all'),
                  label: const Text('Összes'),
                  selected: activeFolderId == null,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSelected(null),
                ),
              for (final folder in folders) ...[
                if (showAll || folder != folders.first) const SizedBox(width: 8),
                ChoiceChip(
                  key: ValueKey('notes-folder-pill-${folder.id}'),
                  avatar: const Icon(Icons.folder_outlined, size: 18),
                  label: Text(
                    folder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: activeFolderId == folder.id,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onSelected(folder.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({
    required this.note,
    required this.onOpen,
    required this.onValidate,
  });

  final NoteItem note;
  final VoidCallback onOpen;
  final VoidCallback onValidate;

  @override
  Widget build(BuildContext context) {
    final chunks = const NoteChunkBuilder().build(
      noteId: note.id,
      noteTitle: note.title,
      document: note.document,
    );
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        key: ValueKey('note-box-${note.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        onLongPress: onValidate,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFFEAF1FF),
                    foregroundColor: Color(0xFF155EEF),
                    child: Icon(Icons.note_alt_outlined, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(label: note.auditState.label),
                  _StatusChip(label: '${chunks.length} chunk'),
                  const _StatusChip(label: 'Saját jegyzet'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                note.preview,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              Text(
                '${note.updatedAt.year}.${note.updatedAt.month.toString().padLeft(2, '0')}.${note.updatedAt.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
