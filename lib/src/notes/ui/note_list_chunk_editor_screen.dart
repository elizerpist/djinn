import 'package:flutter/material.dart';

import '../models/note_document.dart';

class NoteListChunkEditorScreen extends StatefulWidget {
  const NoteListChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;

  @override
  State<NoteListChunkEditorScreen> createState() => _NoteListChunkEditorScreenState();
}

class _NoteListChunkEditorScreenState extends State<NoteListChunkEditorScreen> {
  late NoteBlock _block;
  late List<NoteListItem> _items;
  late final TextEditingController _titleController;

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

  void _replaceItem(NoteListItem item) {
    setState(() {
      _items = [
        for (final current in _items)
          if (current.id == item.id) item else current,
      ];
    });
    _emit();
  }

  void _addItem() {
    setState(() => _items = [..._items, NoteListItem(id: _nextItemId(), text: '')]);
    _emit();
  }

  void _deleteItem(NoteListItem item) {
    if (_items.length == 1) {
      _replaceItem(item.copyWith(text: '', level: 0, checked: false));
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
      appBar: AppBar(title: const Text('Lista szerkesztése')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('note-list-title-field'),
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Lista neve',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _emit(),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              itemCount: _items.length + 1,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                if (oldIndex >= _items.length || newIndex > _items.length) {
                  return;
                }
                _reorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                if (index == _items.length) {
                  return Padding(
                    key: const ValueKey('note-list-add-row'),
                    padding: const EdgeInsets.only(left: 44, top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton.filledTonal(
                        key: const ValueKey('note-list-add-item'),
                        tooltip: 'Új listaelem',
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                      ),
                    ),
                  );
                }
                final item = _items[index];
                return _ListItemRow(
                  key: ValueKey('note-list-row-${item.id}'),
                  index: index,
                  item: item,
                  onChanged: _replaceItem,
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
    required this.onChanged,
    required this.onDelete,
    required this.onIndent,
    required this.onOutdent,
  });

  final int index;
  final NoteListItem item;
  final ValueChanged<NoteListItem> onChanged;
  final VoidCallback onDelete;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * item.level.clamp(0, 8).toDouble(), bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          child: Row(
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
                child: TextFormField(
                  key: ValueKey('note-list-item-${item.id}'),
                  initialValue: item.text,
                  decoration: const InputDecoration(
                    hintText: 'Listaelem',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => onChanged(item.copyWith(text: value)),
                ),
              ),
              IconButton(
                tooltip: 'Kijjebb',
                onPressed: onOutdent,
                icon: const Icon(Icons.format_indent_decrease, size: 20),
              ),
              IconButton(
                tooltip: 'Beljebb',
                onPressed: onIndent,
                icon: const Icon(Icons.format_indent_increase, size: 20),
              ),
              IconButton(
                key: ValueKey('note-list-delete-${item.id}'),
                tooltip: 'Listaelem törlése',
                onPressed: onDelete,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
