import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteListChunkEditorScreen extends StatefulWidget {
  const NoteListChunkEditorScreen({
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
  State<NoteListChunkEditorScreen> createState() => _NoteListChunkEditorScreenState();
}

class _NoteListChunkEditorScreenState extends State<NoteListChunkEditorScreen> {
  late NoteBlock _block;
  late List<NoteListItem> _items;
  late final TextEditingController _titleController;
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _titleController = TextEditingController(text: widget.block.title ?? '');
    _items = widget.block.listItems.isEmpty
        ? [NoteListItem(id: _nextItemId(), text: widget.block.text)]
        : widget.block.listItems.toList();
  }

  String _nextItemId() {
    return 'item-${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _emit() {
    _block = _block.copyWith(
      type: NoteBlockType.listItem,
      text: '',
      title: _titleController.text.trim(),
      listItems: _items,
      clearIndex: true,
    );
    widget.onChanged(_block);
  }

  void _emitTitle(String value) {
    _titleController.text = value;
    _emit();
  }

  void _replaceItem(NoteListItem item) {
    setState(() {
      _items = [
        for (final current in _items)
          if (current.id == item.id) item else current,
      ];
    });
    _emit();
  }

  Future<void> _tagChunk() async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: _block.tags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Chunk tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() => _block = _block.copyWith(tags: tags, clearIndex: true));
    widget.onChanged(_block);
  }

  Future<void> _tagSelection() async {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz ki egy listaelemet a tageléshez')),
      );
      return;
    }
    final item = _items.firstWhere(
      (candidate) => candidate.id == selectedId,
      orElse: () => _items.first,
    );
    await _tagItem(item);
  }

  Future<void> _tagItem(NoteListItem item) async {
    final tags = await showTagManagerSheet(
      context,
      initialTags: item.tags,
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Listaelem tagjei',
    );
    if (tags == null) {
      return;
    }
    _replaceItem(item.copyWith(tags: tags));
  }

  bool get _selectedItemHasTags {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      return false;
    }
    return _items.any(
      (item) => item.id == selectedId && item.tags.isNotEmpty,
    );
  }

  void _deleteSelectedTag() {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      return;
    }
    final item = _items.firstWhere(
      (candidate) => candidate.id == selectedId,
      orElse: () => _items.first,
    );
    _replaceItem(item.copyWith(tags: const []));
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _addItem() {
    setState(() => _items = [..._items, NoteListItem(id: _nextItemId(), text: '')]);
    _emit();
  }

  void _deleteItem(NoteListItem item) {
    if (_items.length == 1) {
      _replaceItem(
        item.copyWith(text: '', level: 0, checked: false, tags: const []),
      );
      return;
    }
    setState(() => _items = _items.where((candidate) => candidate.id != item.id).toList());
    _emit();
  }

  void _changeIndent(NoteListItem item, int delta) {
    _replaceItem(item.copyWith(level: (item.level + delta).clamp(0, 8).toInt()));
  }

  void _reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final next = [..._items];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() => _items = next);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('note-list-chunk-editor'),
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: 'Lista',
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selectedItemHasTags,
        trailingActions: [
          IconButton(
            key: const ValueKey('note-list-header-add-item'),
            tooltip: 'Új listaelem',
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_block.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NoteTagPills(tags: _block.tags),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              itemCount: _items.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (oldIndex >= _items.length || newIndex > _items.length) {
                  return;
                }
                _reorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return _ListItemRow(
                  key: ValueKey('note-list-item-shell-${item.id}'),
                  index: index,
                  item: item,
                  selected: _selectedItemId == item.id,
                  onSelect: () => setState(() => _selectedItemId = item.id),
                  onChanged: _replaceItem,
                  onTag: () => unawaited(_tagItem(item)),
                  onDelete: () => _deleteItem(item),
                  onIndent: () => _changeIndent(item, 1),
                  onOutdent: () => _changeIndent(item, -1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListItemRow extends StatelessWidget {
  const _ListItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
    required this.onTag,
    required this.onDelete,
    required this.onIndent,
    required this.onOutdent,
  });

  final int index;
  final NoteListItem item;
  final bool selected;
  final VoidCallback onSelect;
  final ValueChanged<NoteListItem> onChanged;
  final VoidCallback onTag;
  final VoidCallback onDelete;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;

  @override
  Widget build(BuildContext context) {
    final tagColor =
        item.tags.isEmpty ? null : Color(item.tags.first.resolvedColorValue).withValues(alpha: 0.22);
    return GestureDetector(
      key: ValueKey('note-list-row-${item.id}'),
      behavior: HitTestBehavior.translucent,
      onTap: onSelect,
      child: Padding(
        padding: EdgeInsets.only(left: 16.0 * item.level.clamp(0, 8).toDouble(), bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const SizedBox.square(
                        dimension: 36,
                        child: Icon(Icons.drag_indicator, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                    Checkbox(
                      value: item.checked,
                      onChanged: (value) => onChanged(item.copyWith(checked: value ?? false)),
                    ),
                    Expanded(
                      child: Container(
                        key: item.tags.isEmpty
                            ? null
                            : ValueKey('note-list-item-tag-highlight-${item.id}'),
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextFormField(
                          key: ValueKey('note-list-item-${item.id}'),
                          initialValue: item.text,
                          decoration: const InputDecoration(
                            hintText: 'Listaelem',
                            border: InputBorder.none,
                          ),
                          style: TextStyle(backgroundColor: tagColor),
                          onTap: onSelect,
                          onChanged: (value) => onChanged(item.copyWith(text: value)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(52, 4, 8, 8),
                    child: NoteSelectionActionRail(
                      tags: item.tags,
                      label: 'Listaelem',
                      pillPrefix: 'note-list-rail-pill-${item.id}',
                      actions: [
                        IconButton(
                          key: ValueKey('note-list-rail-tag-${item.id}'),
                          tooltip: 'Listaelem tagelése',
                          onPressed: onTag,
                          icon: const Icon(Icons.sell_outlined, size: 20),
                        ),
                        IconButton(
                          key: ValueKey('note-list-rail-outdent-${item.id}'),
                          tooltip: 'Kijjebb',
                          onPressed: onOutdent,
                          icon: const Icon(Icons.format_indent_decrease, size: 20),
                        ),
                        IconButton(
                          key: ValueKey('note-list-rail-indent-${item.id}'),
                          tooltip: 'Beljebb',
                          onPressed: onIndent,
                          icon: const Icon(Icons.format_indent_increase, size: 20),
                        ),
                        IconButton(
                          key: ValueKey('note-list-rail-delete-${item.id}'),
                          tooltip: 'Listaelem törlése',
                          onPressed: onDelete,
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void unawaited(Future<void> future) {}
