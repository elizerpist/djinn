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
  State<NoteListChunkEditorScreen> createState() =>
      _NoteListChunkEditorScreenState();
}

class _NoteListChunkEditorScreenState extends State<NoteListChunkEditorScreen> {
  late NoteBlock _block;
  late List<NoteListItem> _items;
  late final TextEditingController _titleController;
  final Map<String, FocusNode> _itemFocusNodes = <String, FocusNode>{};
  String? _selectedItemId;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;

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
    for (final focusNode in _itemFocusNodes.values) {
      focusNode.dispose();
    }
    _titleController.dispose();
    super.dispose();
  }

  FocusNode _focusNodeForItem(String itemId) {
    return _itemFocusNodes.putIfAbsent(itemId, FocusNode.new);
  }

  void _disposeItemFocusNode(String itemId) {
    _itemFocusNodes.remove(itemId)?.dispose();
  }

  void _requestItemFocus(String itemId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _itemFocusNodes[itemId]?.requestFocus();
    });
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

  void _setListLayoutMode(NoteListLayoutMode mode) {
    if (_block.listLayoutMode == mode) {
      return;
    }
    setState(() {
      _block = _block.copyWith(listLayoutMode: mode, clearIndex: true);
    });
    widget.onChanged(_block);
  }

  void _handleExtraMenuSelection(String value) {
    switch (value) {
      case 'list-layout-checkbox':
        _setListLayoutMode(NoteListLayoutMode.checkbox);
        break;
      case 'list-layout-hierarchy':
        _setListLayoutMode(NoteListLayoutMode.hierarchy);
        break;
    }
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

  void _deleteChunkTag(NoteKnowledgeTag tag) {
    setState(() {
      _block = _block.copyWith(
        tags: _block.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
        clearIndex: true,
      );
    });
    widget.onChanged(_block);
  }

  Future<void> _tagSelection() async {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Válassz ki egy listaelemet a tageléshez'),
        ),
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
    return _items.any((item) => item.id == selectedId && item.tags.isNotEmpty);
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

  void _deleteSingleSelectedTag(NoteKnowledgeTag tag) {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      return;
    }
    final item = _items.firstWhere(
      (candidate) => candidate.id == selectedId,
      orElse: () => _items.first,
    );
    _replaceItem(
      item.copyWith(
        tags: item.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
      ),
    );
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _addItem() {
    final newItem = NoteListItem(id: _nextItemId(), text: '');
    setState(() {
      _items = [..._items, newItem];
      _selectedItemId = newItem.id;
    });
    _emit();
    _requestItemFocus(newItem.id);
  }

  void _insertItemAfter(NoteListItem item) {
    final newItem = NoteListItem(
      id: _nextItemId(),
      text: '',
      level: item.level,
    );
    final index = _items.indexWhere((candidate) => candidate.id == item.id);
    setState(() {
      final next = [..._items];
      next.insert(index < 0 ? next.length : index + 1, newItem);
      _items = next;
      _selectedItemId = newItem.id;
    });
    _emit();
    _requestItemFocus(newItem.id);
  }

  void _deleteItem(NoteListItem item) {
    if (_items.length == 1) {
      _replaceItem(
        item.copyWith(text: '', level: 0, checked: false, tags: const []),
      );
      return;
    }
    setState(() {
      _items = _items.where((candidate) => candidate.id != item.id).toList();
      if (_selectedItemId == item.id) {
        _selectedItemId = null;
      }
    });
    _disposeItemFocusNode(item.id);
    _emit();
  }

  void _changeIndent(NoteListItem item, int delta) {
    _replaceItem(
      item.copyWith(level: (item.level + delta).clamp(0, 8).toInt()),
    );
  }

  void _focusTaggedItem(int direction) {
    final taggedItems = _items
        .where((item) => item.tags.isNotEmpty)
        .toList(growable: false);
    if (taggedItems.isEmpty) {
      return;
    }
    final currentIndex = taggedItems.indexWhere(
      (item) => item.id == _selectedItemId,
    );
    final nextIndex = direction >= 0
        ? (currentIndex < 0 ? 0 : (currentIndex + 1) % taggedItems.length)
        : (currentIndex <= 0 ? taggedItems.length - 1 : currentIndex - 1);
    setState(() => _selectedItemId = taggedItems[nextIndex].id);
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

  Map<String, String> _hierarchyMarkers() {
    var motherIndex = 0;
    return {
      for (final item in _items)
        item.id: item.level <= 0 ? '${++motherIndex}.' : '-',
    };
  }

  @override
  Widget build(BuildContext context) {
    final markers = _block.listLayoutMode == NoteListLayoutMode.hierarchy
        ? _hierarchyMarkers()
        : const <String, String>{};
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
        onExtraMenuSelected: _handleExtraMenuSelection,
        extraMenuItems: [
          const PopupMenuDivider(),
          PopupMenuItem(
            key: const ValueKey('note-list-menu-layout-checkbox'),
            value: 'list-layout-checkbox',
            child: _ListLayoutMenuItem(
              selected: _block.listLayoutMode == NoteListLayoutMode.checkbox,
              label: 'Checkbox lista',
            ),
          ),
          PopupMenuItem(
            key: const ValueKey('note-list-menu-layout-hierarchy'),
            value: 'list-layout-hierarchy',
            child: _ListLayoutMenuItem(
              selected: _block.listLayoutMode == NoteListLayoutMode.hierarchy,
              label: 'Hierarchikus számozás',
            ),
          ),
        ],
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
                child: NoteTagPills(
                  tags: _block.tags,
                  onDeleted: _deleteChunkTag,
                ),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
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
                  layoutMode: _block.listLayoutMode,
                  hierarchyMarker: markers[item.id],
                  focusNode: _focusNodeForItem(item.id),
                  onSelect: () => setState(() => _selectedItemId = item.id),
                  onChanged: _replaceItem,
                  onTag: () => unawaited(_tagItem(item)),
                  onClearTags: _selectedItemHasTags ? _deleteSelectedTag : null,
                  onDeleteTag: _deleteSingleSelectedTag,
                  onPreviousTagged:
                      _items.any((candidate) => candidate.tags.isNotEmpty)
                      ? () => _focusTaggedItem(-1)
                      : null,
                  onNextTagged:
                      _items.any((candidate) => candidate.tags.isNotEmpty)
                      ? () => _focusTaggedItem(1)
                      : null,
                  railBottomExpanded: _railBottomExpanded,
                  railRoundedCard: _railRoundedCard,
                  railTransparentBackground: _railTransparentBackground,
                  railBorderVisible: _railBorderVisible,
                  onToggleRailBottom: () => setState(
                    () => _railBottomExpanded = !_railBottomExpanded,
                  ),
                  onToggleRailRounded: () =>
                      setState(() => _railRoundedCard = !_railRoundedCard),
                  onToggleRailTransparent: () => setState(
                    () => _railTransparentBackground =
                        !_railTransparentBackground,
                  ),
                  onToggleRailBorder: () =>
                      setState(() => _railBorderVisible = !_railBorderVisible),
                  onSubmit: () => _insertItemAfter(item),
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

class _ListLayoutMenuItem extends StatelessWidget {
  const _ListLayoutMenuItem({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: selected
              ? const Icon(Icons.check, size: 18)
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class _ListItemRow extends StatelessWidget {
  const _ListItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.selected,
    required this.layoutMode,
    required this.hierarchyMarker,
    required this.focusNode,
    required this.onSelect,
    required this.onChanged,
    required this.onTag,
    required this.onClearTags,
    required this.onDeleteTag,
    required this.onPreviousTagged,
    required this.onNextTagged,
    required this.railBottomExpanded,
    required this.railRoundedCard,
    required this.railTransparentBackground,
    required this.railBorderVisible,
    required this.onToggleRailBottom,
    required this.onToggleRailRounded,
    required this.onToggleRailTransparent,
    required this.onToggleRailBorder,
    required this.onSubmit,
    required this.onDelete,
    required this.onIndent,
    required this.onOutdent,
  });

  final int index;
  final NoteListItem item;
  final bool selected;
  final NoteListLayoutMode layoutMode;
  final String? hierarchyMarker;
  final FocusNode focusNode;
  final VoidCallback onSelect;
  final ValueChanged<NoteListItem> onChanged;
  final VoidCallback onTag;
  final VoidCallback? onClearTags;
  final ValueChanged<NoteKnowledgeTag> onDeleteTag;
  final VoidCallback? onPreviousTagged;
  final VoidCallback? onNextTagged;
  final bool railBottomExpanded;
  final bool railRoundedCard;
  final bool railTransparentBackground;
  final bool railBorderVisible;
  final VoidCallback onToggleRailBottom;
  final VoidCallback onToggleRailRounded;
  final VoidCallback onToggleRailTransparent;
  final VoidCallback onToggleRailBorder;
  final VoidCallback onSubmit;
  final VoidCallback onDelete;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;

  @override
  Widget build(BuildContext context) {
    final textStyle = _taggedListTextStyle(item.tags);
    return GestureDetector(
      key: ValueKey('note-list-row-${item.id}'),
      behavior: HitTestBehavior.translucent,
      onTap: onSelect,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.0 * item.level.clamp(0, 8).toDouble(),
          bottom: 8,
        ),
        child: DecoratedBox(
          key: ValueKey('note-list-item-card-${item.id}'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
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
                        child: Icon(
                          Icons.drag_indicator,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                    if (layoutMode == NoteListLayoutMode.checkbox)
                      Checkbox(
                        value: item.checked,
                        onChanged: (value) =>
                            onChanged(item.copyWith(checked: value ?? false)),
                      )
                    else
                      SizedBox(
                        width: 48,
                        child: Center(
                          child: Text(
                            hierarchyMarker ?? '',
                            key: ValueKey('note-list-marker-${item.id}'),
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        key: item.tags.isEmpty
                            ? null
                            : ValueKey(
                                'note-list-item-tag-highlight-${item.id}',
                              ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: TextFormField(
                          key: ValueKey('note-list-item-${item.id}'),
                          focusNode: focusNode,
                          initialValue: item.text,
                          autofocus: selected && item.text.isEmpty,
                          minLines: 1,
                          maxLines: null,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'Listaelem',
                            border: InputBorder.none,
                          ),
                          style: textStyle,
                          onTap: onSelect,
                          onChanged: (value) =>
                              onChanged(item.copyWith(text: value)),
                          onFieldSubmitted: (_) => onSubmit(),
                        ),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  NoteSelectionActionRail(
                    tags: item.tags,
                    label: 'Listaelem',
                    pillPrefix: 'note-list-rail-pill-${item.id}',
                    bottomRowExpanded: railBottomExpanded,
                    onToggleBottomRow: onToggleRailBottom,
                    onDeleteTag: onDeleteTag,
                    roundedCard: railRoundedCard,
                    transparentBackground: railTransparentBackground,
                    showBorder: railBorderVisible,
                    contentPadding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
                    showBottomBorder: false,
                    actions: [
                      IconButton(
                        key: ValueKey('note-list-rail-tag-${item.id}'),
                        tooltip: 'Listaelem tagelése',
                        onPressed: onTag,
                        icon: const Icon(Icons.sell_outlined, size: 20),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-clear-tags-${item.id}'),
                        tooltip: 'Listaelem összes tagjének törlése',
                        onPressed: onClearTags,
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-prev-${item.id}'),
                        tooltip: 'Előző tag',
                        onPressed: onPreviousTagged,
                        icon: const Icon(Icons.chevron_left, size: 20),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-next-${item.id}'),
                        tooltip: 'Következő tag',
                        onPressed: onNextTagged,
                        icon: const Icon(Icons.chevron_right, size: 20),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-outdent-${item.id}'),
                        tooltip: 'Kijjebb',
                        onPressed: onOutdent,
                        icon: const Icon(
                          Icons.format_indent_decrease,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-indent-${item.id}'),
                        tooltip: 'Beljebb',
                        onPressed: onIndent,
                        icon: const Icon(
                          Icons.format_indent_increase,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        key: ValueKey('note-list-rail-delete-${item.id}'),
                        tooltip: 'Listaelem törlése',
                        onPressed: onDelete,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                      IconButton(
                        key: const ValueKey('note-list-rail-toggle-rounded'),
                        tooltip: railRoundedCard
                            ? 'Vonalas rail'
                            : 'Cellaszerű rail',
                        onPressed: onToggleRailRounded,
                        icon: const Icon(Icons.crop_square_outlined, size: 20),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'note-list-rail-toggle-transparent',
                        ),
                        tooltip: railTransparentBackground
                            ? 'Fehér rail háttér'
                            : 'Átlátszó rail háttér',
                        onPressed: onToggleRailTransparent,
                        icon: const Icon(Icons.opacity, size: 20),
                      ),
                      IconButton(
                        key: const ValueKey('note-list-rail-toggle-border'),
                        tooltip: railBorderVisible
                            ? 'Rail border nélkül'
                            : 'Rail borderrel',
                        onPressed: onToggleRailBorder,
                        icon: const Icon(Icons.border_outer, size: 20),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle _taggedListTextStyle(List<NoteKnowledgeTag> tags) {
  if (tags.isEmpty) {
    return const TextStyle();
  }
  return TextStyle(
    backgroundColor: Color(
      tags.first.resolvedColorValue,
    ).withValues(alpha: 0.22),
    decoration: tags.length > 1
        ? TextDecoration.underline
        : TextDecoration.none,
    decorationStyle: tags.length > 2
        ? TextDecorationStyle.double
        : TextDecorationStyle.solid,
    decorationColor: tags.length > 1 ? Color(tags[1].resolvedColorValue) : null,
    decorationThickness: tags.length > 1 ? 2 : null,
  );
}

void unawaited(Future<void> future) {}
