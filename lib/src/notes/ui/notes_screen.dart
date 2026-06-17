import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../debug/debug_console.dart';
import '../../shared/chunks/chunk_validation_card.dart';
import '../../shared/ui/draggable_bottom_card.dart';
import '../data/note_chunk_builder.dart';
import '../data/note_repository.dart';
import '../models/note_document.dart';
import '../models/note_folder.dart';
import '../models/note_item.dart';
import 'note_editor_route.dart';
import 'tag_manager_sheet.dart';

typedef ImportNotesForTest = Future<List<NoteItem>?> Function();

enum _NoteSortMode { newestFirst, oldestFirst, titleAsc, titleDesc }

class NotesScreen extends StatefulWidget {
  const NotesScreen({
    super.key,
    required this.repository,
    this.importNotesForTest,
  });

  final NoteRepository repository;
  final ImportNotesForTest? importNotesForTest;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteFolder> _folders = const [];
  List<NoteItem> _notes = const [];
  Set<String> _selectedNoteIds = <String>{};
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
      final existingIds = allNotes.map((note) => note.id).toSet();
      _selectedNoteIds = _selectedNoteIds.intersection(existingIds);
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

  List<NoteItem> get _selectedNotes =>
      _notes.where((note) => _selectedNoteIds.contains(note.id)).toList(growable: false);

  Future<void> _openEditor({NoteItem? note}) async {
    final target = note ??
        await widget.repository.createDocumentNote(
          title: 'Névtelen jegyzet',
          document: NoteDocument.empty(),
          folderId: _activeFolderId,
        );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => NoteEditorRoute(
          repository: widget.repository,
          initialNote: target,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
    await _load();
  }

  void _enterSelection(String noteId) {
    setState(() => _selectedNoteIds = {noteId});
  }

  void _selectNote(String noteId, bool selected) {
    setState(() {
      final next = Set<String>.of(_selectedNoteIds);
      if (selected) {
        next.add(noteId);
      } else {
        next.remove(noteId);
      }
      _selectedNoteIds = next;
    });
  }

  void _exitSelection() {
    setState(() => _selectedNoteIds = <String>{});
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
      const PopupMenuItem<String>(value: 'import', child: Text('Import')),
      const PopupMenuItem<String>(value: 'tags', child: Text('Tagek')),
      if (_notes.isNotEmpty) const PopupMenuItem<String>(value: 'select-all', child: Text('Összes kijelölése')),
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

  List<PopupMenuEntry<String>> _selectionMenuItems() {
    final count = _selectedNoteIds.length;
    if (count == 1) {
      return const [
        PopupMenuItem(value: 'edit', child: Text('Szerkesztés')),
        PopupMenuItem(value: 'chunks', child: Text('Chunkok megtekintése')),
        PopupMenuItem(value: 'index', child: Text('Indexelés / újraindexelés')),
        PopupMenuItem(value: 'audit', child: Text('Kinyert tartalom audit')),
        PopupMenuItem(value: 'tags', child: Text('Tagek')),
        PopupMenuItem(value: 'move', child: Text('Mozgatás mappába')),
        PopupMenuItem(value: 'export', child: Text('Export')),
        PopupMenuItem(value: 'share', child: Text('Megosztás')),
        PopupMenuItem(value: 'rename', child: Text('Átnevezés')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'delete', child: Text('Törlés')),
      ];
    }
    return const [
      PopupMenuItem(value: 'index', child: Text('Indexelés / újraindexelés')),
      PopupMenuItem(value: 'move', child: Text('Mozgatás mappába')),
      PopupMenuItem(value: 'export', child: Text('Export')),
      PopupMenuItem(value: 'share', child: Text('Megosztás')),
      PopupMenuDivider(),
      PopupMenuItem(value: 'delete', child: Text('Törlés')),
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
    if (value == 'import') {
      await _importNotes();
      return;
    }
    if (value == 'tags') {
      await _showTagGuideDialog();
      return;
    }
    if (value == 'select-all') {
      setState(() => _selectedNoteIds = _notes.map((note) => note.id).toSet());
      return;
    }
    if (value is _NoteSortMode) {
      _setSort(value);
    }
  }

  Future<void> _handleSelectionMenu(String value) async {
    final selected = _selectedNotes;
    if (selected.isEmpty) {
      return;
    }
    if (value == 'edit' || value == 'chunks') {
      final note = selected.single;
      _exitSelection();
      await _openEditor(note: note);
      return;
    }
    if (value == 'audit') {
      final note = selected.single;
      _exitSelection();
      await _openValidationCard(note);
      return;
    }
    if (value == 'tags') {
      await _showNoteTagDialog(selected.single);
      return;
    }
    if (value == 'index') {
      await _indexNotes(selected);
      return;
    }
    if (value == 'move') {
      await _showMoveDialog(selected);
      return;
    }
    if (value == 'export') {
      await _exportNotes(selected);
      return;
    }
    if (value == 'share') {
      await _shareNotes(selected);
      return;
    }
    if (value == 'rename') {
      await _renameNote(selected.single);
      return;
    }
    if (value == 'delete') {
      await _deleteNotes(selected);
    }
  }

  Future<void> _indexNotes(List<NoteItem> notes) async {
    for (final note in notes) {
      final ids = note.document.blocks.where((block) => block.hasContent).map((block) => block.id).toList();
      if (ids.isNotEmpty) {
        await widget.repository.markNoteBlocksIndexed(note.id, ids);
      }
    }
    await _load();
  }

  Future<void> _showMoveDialog(List<NoteItem> notes) async {
    final folderId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mozgatás mappába'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('__none__'),
            child: const Text('Nincs mappa'),
          ),
          for (final folder in _folders)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(folder.id),
              child: Text(folder.title),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mégse'),
          ),
        ],
      ),
    );
    if (folderId == null) {
      return;
    }
    final targetFolderId = folderId == '__none__' ? null : folderId;
    for (final note in notes) {
      await widget.repository.moveNoteToFolder(note.id, targetFolderId);
    }
    _exitSelection();
    await _load();
  }

  Future<void> _renameNote(NoteItem note) async {
    final controller = TextEditingController(text: note.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Jegyzet átnevezése'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Cím', border: OutlineInputBorder()),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Mégse')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return;
    }
    await widget.repository.updateNoteDocument(note.id, title: trimmed, document: note.document);
    await _load();
  }

  Future<void> _showTagGuideDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('notes-tag-dialog'),
        title: const Text('Tagek'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direct tag'),
            SizedBox(height: 6),
            Text('Örökölt tag'),
            SizedBox(height: 12),
            Text('Formátum: topic:légzési elégtelenség, state:súlyos, type:terápia.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoteTagDialog(NoteItem note) async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: note.document.tags,
      availableTags: note.document.knownTags,
      title: 'Jegyzet tagek',
    );
    if (tags == null) {
      return;
    }
    await widget.repository.updateNoteDocument(
      note.id,
      title: note.title,
      document: note.document.copyWith(tags: tags),
    );
    _exitSelection();
    await _load();
  }

  Future<void> _deleteNotes(List<NoteItem> notes) async {
    await widget.repository.deleteNotes(notes.map((note) => note.id).toList(growable: false));
    _exitSelection();
    await _load();
  }

  Future<void> _importNotes() async {
    try {
      final notes = widget.importNotesForTest != null
          ? await widget.importNotesForTest!()
          : await _pickNotesImportFile();
      if (!mounted || notes == null) {
        return;
      }
      if (notes.isEmpty) {
        DebugConsole.log('[Notes] import skipped empty_file');
        return;
      }
      final imported = await widget.repository.importNotes(notes, folderId: _activeFolderId);
      final folderLabel = _activeFolderId ?? 'none';
      DebugConsole.log('[Notes] import notes=${imported.length} folder=$folderLabel');
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${imported.length} jegyzet importálva')),
      );
    } catch (error) {
      DebugConsole.log('[Notes] import failed error=$error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Jegyzet import sikertelen: $error')),
      );
    }
  }

  Future<List<NoteItem>?> _pickNotesImportFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Jegyzet import',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    final file = result.files.single;
    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      throw const FormatException('A kiválasztott jegyzetfájl nem olvasható.');
    }
    return _notesFromImportBytes(Uint8List.fromList(bytes));
  }

  List<NoteItem> _notesFromImportBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('A jegyzet import nem JSON objektum.');
    }
    final type = decoded['type'];
    if (type != 'djinn_notes') {
      throw const FormatException('Nem Djinn jegyzet export fájl.');
    }
    final rawNotes = decoded['notes'];
    if (rawNotes is! List) {
      throw const FormatException('A jegyzet export nem tartalmaz notes listát.');
    }
    return rawNotes.map((item) {
      if (item is! Map) {
        throw const FormatException('Érvénytelen jegyzet elem az import fájlban.');
      }
      return NoteItem.fromJson(Map<String, Object?>.from(item));
    }).toList(growable: false);
  }

  Future<void> _exportNotes(List<NoteItem> notes) async {
    final bytes = _notesExportBytes(notes);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Jegyzet export',
      fileName: _notesExportFilename(notes),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (!mounted || path == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exportálva: $path')));
  }

  Future<void> _shareNotes(List<NoteItem> notes) async {
    final directory = await getTemporaryDirectory();
    await directory.create(recursive: true);
    final filename = _notesExportFilename(notes);
    final file = File(p.join(directory.path, filename));
    await file.writeAsBytes(_notesExportBytes(notes), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        fileNameOverrides: [filename],
        subject: filename,
      ),
    );
  }

  Uint8List _notesExportBytes(List<NoteItem> notes) {
    final payload = {
      'schemaVersion': 1,
      'type': 'djinn_notes',
      'notes': notes.map((note) => note.toJson()).toList(),
    };
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)));
  }

  String _notesExportFilename(List<NoteItem> notes) {
    if (notes.length == 1) {
      return '${_safeBaseName(notes.single.title)}.djinn-notes.json';
    }
    return 'djinn-jegyzetek-${DateTime.now().millisecondsSinceEpoch}.djinn-notes.json';
  }

  String _safeBaseName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
    return safe.isEmpty ? 'jegyzet' : safe;
  }

  PreferredSizeWidget _buildAppBar() {
    final selectionCount = _selectedNoteIds.length;
    if (selectionCount > 0) {
      return AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          tooltip: 'Kijelölés megszüntetése',
          onPressed: _exitSelection,
          icon: const Icon(Icons.close),
        ),
        title: Text('$selectionCount kijelölve'),
        actions: [
          IconButton(
            key: const ValueKey('notes-share-selected'),
            tooltip: 'Megosztás',
            onPressed: () => unawaited(_shareNotes(_selectedNotes)),
            icon: const Icon(Icons.share),
          ),
          IconButton(
            key: const ValueKey('notes-delete-selected'),
            tooltip: 'Törlés',
            onPressed: () => unawaited(_deleteNotes(_selectedNotes)),
            icon: const Icon(Icons.delete_outline),
          ),
          PopupMenuButton<String>(
            key: const ValueKey('notes-selection-menu'),
            tooltip: 'Kijelölt jegyzetek menü',
            onSelected: (value) => unawaited(_handleSelectionMenu(value)),
            itemBuilder: (context) => _selectionMenuItems(),
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Jegyzetek'),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      actions: [
        PopupMenuButton<Object>(
          key: const ValueKey('notes-header-menu'),
          tooltip: 'Jegyzetek menü',
          onSelected: (value) => unawaited(_handleMenu(value)),
          itemBuilder: (context) => _menuItems(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFolderBar = _showFolderBar && (_folders.isNotEmpty || _hasAnyNotes);
    return Scaffold(
      appBar: _buildAppBar(),
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
        onPressed: () => unawaited(_openEditor()),
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
      itemBuilder: (context, index) {
        final note = _notes[index];
        final selectionMode = _selectedNoteIds.isNotEmpty;
        final selected = _selectedNoteIds.contains(note.id);
        return _NoteBox(
          note: note,
          selectionMode: selectionMode,
          selected: selected,
          onOpen: () {
            if (selectionMode) {
              _selectNote(note.id, !selected);
            } else {
              unawaited(_openEditor(note: note));
            }
          },
          onLongPress: () => _enterSelection(note.id),
          onSelectionChanged: (value) => _selectNote(note.id, value),
        );
      },
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
    required this.selectionMode,
    required this.selected,
    required this.onOpen,
    required this.onLongPress,
    required this.onSelectionChanged,
  });

  final NoteItem note;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectionChanged;

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
        side: BorderSide(color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        key: ValueKey('note-box-${note.id}'),
        borderRadius: BorderRadius.circular(8),
        onTap: onOpen,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectionMode)
                    Checkbox(
                      key: ValueKey('note-checkbox-${note.id}'),
                      value: selected,
                      onChanged: (value) => onSelectionChanged(value ?? false),
                    )
                  else
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
                  if (!selectionMode)
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

void unawaited(Future<void> future) {}
