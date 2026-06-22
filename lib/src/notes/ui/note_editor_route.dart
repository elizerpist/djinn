import 'package:flutter/material.dart';

import '../../ai/ai_client.dart';
import '../../debug/debug_console.dart';
import '../data/note_repository.dart';
import '../data/tag_repository.dart';
import '../models/note_document.dart';
import '../models/note_item.dart';
import 'note_chunk_card.dart';
import 'note_chunk_fab.dart';
import 'note_flowchart_editor_screen.dart';
import 'note_list_chunk_editor_screen.dart';
import 'note_table_editor_screen.dart';
import 'note_text_chunk_editor_screen.dart';
import 'tag_manager_sheet.dart';

class NoteEditorRoute extends StatefulWidget {
  const NoteEditorRoute({
    super.key,
    required this.repository,
    required this.initialNote,
    this.tagRepository,
  });

  final NoteRepository repository;
  final NoteItem initialNote;
  final TagRepository? tagRepository;

  @override
  State<NoteEditorRoute> createState() => _NoteEditorRouteState();
}

class _NoteEditorRouteState extends State<NoteEditorRoute> {
  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  late NoteItem _note;
  late NoteDocument _document;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  final Set<String> _expandedBlockIds = <String>{};
  bool _editingTitle = false;
  bool _persisting = false;
  bool _persistAgain = false;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
    _document = _note.document;
    _titleController = TextEditingController(text: _note.title);
    _titleFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _persist() async {
    if (_persisting) {
      _persistAgain = true;
      return;
    }
    _persisting = true;
    try {
      do {
        _persistAgain = false;
        final updated = await widget.repository.updateNoteDocument(
          _note.id,
          title: _normalizedTitle,
          document: _document,
        );
        if (!mounted) {
          return;
        }
        setState(() => _note = updated);
      } while (_persistAgain);
    } finally {
      _persisting = false;
    }
  }

  String get _normalizedTitle {
    final trimmed = _titleController.text.trim();
    return trimmed.isEmpty ? 'Névtelen jegyzet' : trimmed;
  }

  void _setDocument(NoteDocument document) {
    setState(() => _document = document);
    unawaited(_persist());
  }

  void _replaceBlock(NoteBlock block) {
    _setDocument(
      _document.copyWith(
        blocks: [
          for (final existing in _document.blocks)
            if (existing.id == block.id) block else existing,
        ],
      ),
    );
  }

  void _addBlock(NoteBlockType type) {
    final block = _newBlock(type);
    _setDocument(_document.copyWith(blocks: [..._document.blocks, block]));
    setState(() => _expandedBlockIds.add(block.id));
  }

  NoteBlock _newBlock(NoteBlockType type) {
    final id = 'block-${DateTime.now().microsecondsSinceEpoch}';
    return switch (type) {
      NoteBlockType.heading => NoteBlock(id: id, type: type, text: ''),
      NoteBlockType.paragraph => NoteBlock(id: id, type: type, text: ''),
      NoteBlockType.listItem => NoteBlock(
        id: id,
        type: type,
        listItems: const [NoteListItem(id: 'item-1', text: '')],
      ),
      NoteBlockType.table => NoteBlock(
        id: id,
        type: type,
        rows: const [
          ['', ''],
        ],
      ),
      NoteBlockType.flowchart => NoteBlock(
        id: id,
        type: type,
        title: 'Flowchart',
        nodes: const [
          NoteFlowchartNode(
            id: 'node-1',
            label: 'Kezdés',
            shape: AiFlowchartNodeShape.startEnd,
            order: 1,
          ),
        ],
      ),
    };
  }

  void _deleteBlock(NoteBlock block) {
    final index = _document.blocks.indexWhere(
      (candidate) => candidate.id == block.id,
    );
    if (index == -1) {
      return;
    }
    final nextBlocks = [..._document.blocks]..removeAt(index);
    setState(() {
      _document = _document.copyWith(blocks: nextBlocks);
      _expandedBlockIds.remove(block.id);
    });
    unawaited(_persist());
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Chunk törölve'),
        action: SnackBarAction(
          label: 'Visszavonás',
          onPressed: () => _restoreDeletedBlock(block, index),
        ),
      ),
    );
  }

  void _restoreDeletedBlock(NoteBlock block, int index) {
    final nextBlocks = [..._document.blocks];
    final targetIndex = index.clamp(0, nextBlocks.length).toInt();
    nextBlocks.insert(targetIndex, block);
    setState(() => _document = _document.copyWith(blocks: nextBlocks));
    unawaited(_persist());
  }

  void _reorderBlocks(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final nextBlocks = [..._document.blocks];
    final moved = nextBlocks.removeAt(oldIndex);
    nextBlocks.insert(newIndex, moved);
    _setDocument(_document.copyWith(blocks: nextBlocks));
  }

  Future<void> _handleMenu(String value) async {
    if (value == 'index') {
      final ids = _document.blocks
          .where((block) => block.hasContent)
          .map((block) => block.id)
          .toList();
      if (ids.isEmpty) {
        return;
      }
      final updated = await widget.repository.markNoteBlocksIndexed(
        _note.id,
        ids,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _note = updated;
        _document = updated.document;
      });
      return;
    }
    if (value == 'chunks') {
      setState(
        () =>
            _expandedBlockIds.addAll(_document.blocks.map((block) => block.id)),
      );
      return;
    }
    if (value == 'tags') {
      await _showDocumentTagDialog();
      return;
    }
    if (value == 'delete') {
      await widget.repository.deleteNotes([_note.id]);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _startTitleEdit() {
    setState(() => _editingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection.collapsed(
        offset: _titleController.text.length,
      );
    });
  }

  void _finishTitleEdit() {
    if (!_editingTitle) {
      return;
    }
    setState(() => _editingTitle = false);
    unawaited(_persist());
  }

  Widget _buildHeaderTitle(BuildContext context) {
    if (_editingTitle) {
      return TextField(
        key: const ValueKey('note-editor-title-field'),
        controller: _titleController,
        focusNode: _titleFocusNode,
        autofocus: true,
        textInputAction: TextInputAction.done,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: 'Jegyzet címe',
        ),
        onChanged: (_) => unawaited(_persist()),
        onSubmitted: (_) => _finishTitleEdit(),
        onTapOutside: (_) => _finishTitleEdit(),
      );
    }
    return InkWell(
      key: const ValueKey('note-editor-title-display'),
      borderRadius: BorderRadius.circular(6),
      onTap: _startTitleEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Text(
          _normalizedTitle,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _openBlockEditor(NoteBlock block) async {
    final availableTags = _document.knownTags;
    DebugConsole.log(
      '[NoteEditor] open chunk type=${block.type.wireName} '
      'blocks=${_document.blocks.length} knownTags=${availableTags.length}',
    );
    Widget editorFor(NoteBlock current) {
      return switch (current.type) {
        NoteBlockType.heading ||
        NoteBlockType.paragraph => NoteTextChunkEditorScreen(
          block: current,
          availableTags: availableTags,
          tagRepository: _tagRepository,
          onChanged: _replaceBlock,
          onDelete: () => _deleteBlock(current),
        ),
        NoteBlockType.listItem => NoteListChunkEditorScreen(
          block: current,
          availableTags: availableTags,
          tagRepository: _tagRepository,
          onChanged: _replaceBlock,
          onDelete: () => _deleteBlock(current),
        ),
        NoteBlockType.table => NoteTableEditorScreen(
          block: current,
          availableTags: availableTags,
          tagRepository: _tagRepository,
          onChanged: _replaceBlock,
          onDelete: () => _deleteBlock(current),
        ),
        NoteBlockType.flowchart => NoteFlowchartEditorScreen(
          block: current,
          availableTags: availableTags,
          tagRepository: _tagRepository,
          onChanged: _replaceBlock,
          onDelete: () => _deleteBlock(current),
        ),
      };
    }

    final result = await Navigator.of(context).push<NoteBlock>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            editorFor(block),
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
    if (result != null && mounted) {
      _replaceBlock(result);
    }
  }

  Future<void> _showBlockTagDialog(NoteBlock block) async {
    await showTagManagerSheet(
      context,
      initialTags: block.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _replaceBlock(
        block.copyWith(tags: tags, clearIndex: true),
      ),
      availableTags: _document.knownTags,
      title: 'Chunk tagek',
    );
  }

  Future<void> _showDocumentTagDialog() async {
    await showTagManagerSheet(
      context,
      initialTags: _document.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _setDocument(_document.copyWith(tags: tags)),
      availableTags: _document.knownTags,
      title: 'Jegyzet tagek',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-editor-route'),
      appBar: AppBar(
        title: _buildHeaderTitle(context),
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('note-editor-menu'),
            tooltip: 'Jegyzet menü',
            onSelected: (value) => unawaited(_handleMenu(value)),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'index',
                child: Text('Indexelés / újraindexelés'),
              ),
              PopupMenuItem(value: 'tags', child: Text('Tagek')),
              PopupMenuItem(value: 'chunks', child: Text('Chunkok kinyitása')),
              PopupMenuItem(value: 'delete', child: Text('Törlés')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
              itemCount: _document.blocks.length,
              // ignore: deprecated_member_use
              onReorder: _reorderBlocks,
              itemBuilder: (context, index) {
                final block = _document.blocks[index];
                return Padding(
                  key: ValueKey('note-chunk-row-${block.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NoteChunkCard(
                    block: block,
                    expanded: _expandedBlockIds.contains(block.id),
                    inheritedTags: _document.tags,
                    dragHandle: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(
                        Icons.drag_indicator,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    onToggleExpanded: () {
                      setState(() {
                        if (!_expandedBlockIds.add(block.id)) {
                          _expandedBlockIds.remove(block.id);
                        }
                      });
                    },
                    onOpenEditor: () => unawaited(_openBlockEditor(block)),
                    onEditTags: () => unawaited(_showBlockTagDialog(block)),
                    onDelete: () => _deleteBlock(block),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: NoteChunkFab(
        onAddText: () => _addBlock(NoteBlockType.paragraph),
        onAddList: () => _addBlock(NoteBlockType.listItem),
        onAddTable: () => _addBlock(NoteBlockType.table),
        onAddFlowchart: () => _addBlock(NoteBlockType.flowchart),
      ),
    );
  }
}

void unawaited(Future<void> future) {}
