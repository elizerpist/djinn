import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tag_repository.dart';
import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteMixedTextChunkEditorScreen extends StatefulWidget {
  const NoteMixedTextChunkEditorScreen({
    super.key,
    required this.block,
    required this.onChanged,
    this.availableTags = const [],
    this.tagRepository,
    this.onDelete,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock> onChanged;
  final List<NoteKnowledgeTag> availableTags;
  final TagRepository? tagRepository;
  final VoidCallback? onDelete;

  @override
  State<NoteMixedTextChunkEditorScreen> createState() =>
      _NoteMixedTextChunkEditorScreenState();
}

class _NoteMixedTextChunkEditorScreenState
    extends State<NoteMixedTextChunkEditorScreen> {
  static const double _keyboardRailReserve = 112;

  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  late NoteBlock _block;
  late List<NoteMixedSection> _sections;
  _MixedSelectionTarget? _selection;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;

  @override
  void initState() {
    super.initState();
    _setBlock(widget.block);
  }

  @override
  void didUpdateWidget(NoteMixedTextChunkEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.id != widget.block.id ||
        oldWidget.block != widget.block) {
      _setBlock(widget.block);
    }
  }

  void _setBlock(NoteBlock block) {
    _block = block.type == NoteBlockType.mixed
        ? block
        : block.copyWith(type: NoteBlockType.mixed, clearIndex: true);
    _sections = _normalizedInitialSections(_block);
  }

  List<NoteMixedSection> _normalizedInitialSections(NoteBlock block) {
    if (block.mixedSections.isNotEmpty) {
      return block.mixedSections.toList(growable: true);
    }
    final fallbackText = block.text.trim();
    return [
      NoteMixedSection(
        id: '${block.id}-paragraph-1',
        type: NoteMixedSectionType.paragraph,
        text: fallbackText,
      ),
    ];
  }

  String _nextId(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _commitSections(
    List<NoteMixedSection> sections, {
    _MixedSelectionTarget? selection,
    bool clearSelection = false,
  }) {
    final nextBlock = _block.copyWith(
      type: NoteBlockType.mixed,
      text: '',
      mixedSections: sections,
      clearIndex: true,
    );
    setState(() {
      _sections = sections;
      _block = nextBlock;
      if (selection != null) {
        _selection = selection;
      } else if (clearSelection) {
        _selection = null;
      }
    });
    widget.onChanged(nextBlock);
  }

  void _commitBlock(NoteBlock block) {
    final nextBlock = block.copyWith(
      type: NoteBlockType.mixed,
      text: '',
      mixedSections: _sections,
      clearIndex: true,
    );
    setState(() => _block = nextBlock);
    widget.onChanged(nextBlock);
  }

  void _replaceSection(
    NoteMixedSection section, {
    _MixedSelectionTarget? selection,
    bool clearSelection = false,
  }) {
    _commitSections(
      [
        for (final current in _sections)
          if (current.id == section.id) section else current,
      ],
      selection: selection,
      clearSelection: clearSelection,
    );
  }

  void _addParagraphSection() {
    final section = NoteMixedSection(
      id: _nextId('paragraph'),
      type: NoteMixedSectionType.paragraph,
    );
    _commitSections([..._sections, section]);
  }

  void _addListSection() {
    final item = NoteListItem(id: _nextId('item'), text: '');
    final section = NoteMixedSection(
      id: _nextId('list'),
      type: NoteMixedSectionType.list,
      listItems: [item],
    );
    _commitSections([
      ..._sections,
      section,
    ], selection: _MixedSelectionTarget.listItem(section.id, item.id));
  }

  void _addTableSection() {
    final section = NoteMixedSection(
      id: _nextId('table'),
      type: NoteMixedSectionType.table,
      rows: const [
        ['', ''],
      ],
    );
    _commitSections([
      ..._sections,
      section,
    ], selection: _MixedSelectionTarget.tableCell(section.id, 0, 0));
  }

  void _deleteSection(NoteMixedSection section) {
    if (_sections.length == 1) {
      final replacement = NoteMixedSection(
        id: section.id,
        type: NoteMixedSectionType.paragraph,
      );
      _commitSections([replacement], clearSelection: true);
      return;
    }
    _commitSections(
      _sections.where((current) => current.id != section.id).toList(),
      clearSelection: true,
    );
  }

  void _reorderSections(int oldIndex, int newIndex) {
    if (oldIndex >= _sections.length || newIndex > _sections.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final next = [..._sections];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    _commitSections(next);
  }

  void _updateParagraph(NoteMixedSection section, String text) {
    _replaceSection(section.copyWith(text: text));
  }

  List<NoteListItem> _itemsFor(NoteMixedSection section) {
    if (section.listItems.isNotEmpty) {
      return section.listItems;
    }
    return [NoteListItem(id: _nextId('item'), text: section.text)];
  }

  Map<String, String> _hierarchyMarkers(NoteMixedSection section) {
    var motherIndex = 0;
    return {
      for (final item in _itemsFor(section))
        item.id: item.level <= 0 ? '${++motherIndex}.' : '-',
    };
  }

  void _replaceListItem(
    NoteMixedSection section,
    NoteListItem item, {
    bool select = true,
  }) {
    final items = [
      for (final current in _itemsFor(section))
        if (current.id == item.id) item else current,
    ];
    _replaceSection(
      section.copyWith(listItems: items),
      selection: select
          ? _MixedSelectionTarget.listItem(section.id, item.id)
          : null,
    );
  }

  void _insertListItemAfter(NoteMixedSection section, NoteListItem item) {
    final newItem = NoteListItem(
      id: _nextId('item'),
      text: '',
      level: item.level,
    );
    final items = [..._itemsFor(section)];
    final index = items.indexWhere((candidate) => candidate.id == item.id);
    items.insert(index < 0 ? items.length : index + 1, newItem);
    _replaceSection(
      section.copyWith(listItems: items),
      selection: _MixedSelectionTarget.listItem(section.id, newItem.id),
    );
  }

  void _deleteListItem(NoteMixedSection section, NoteListItem item) {
    final items = [..._itemsFor(section)];
    if (items.length == 1) {
      _replaceListItem(
        section,
        item.copyWith(text: '', level: 0, checked: false, tags: const []),
      );
      return;
    }
    items.removeWhere((candidate) => candidate.id == item.id);
    _replaceSection(section.copyWith(listItems: items), clearSelection: true);
  }

  void _changeListIndent(
    NoteMixedSection section,
    NoteListItem item,
    int delta,
  ) {
    _replaceListItem(
      section,
      item.copyWith(level: (item.level + delta).clamp(0, 8).toInt()),
    );
  }

  void _moveListItem(NoteMixedSection section, String itemId, int delta) {
    final items = [..._itemsFor(section)];
    final oldIndex = items.indexWhere((item) => item.id == itemId);
    if (oldIndex < 0) {
      return;
    }
    final newIndex = (oldIndex + delta).clamp(0, items.length - 1).toInt();
    if (newIndex == oldIndex) {
      return;
    }
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    _replaceSection(
      section.copyWith(listItems: items),
      selection: _MixedSelectionTarget.listItem(section.id, itemId),
    );
  }

  void _reorderListItems(NoteMixedSection section, int oldIndex, int newIndex) {
    final items = [..._itemsFor(section)];
    if (oldIndex >= items.length || newIndex > items.length) {
      return;
    }
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);
    _replaceSection(section.copyWith(listItems: items));
  }

  int _columnCount(List<List<String>> rows) {
    var count = 0;
    for (final row in rows) {
      if (row.length > count) {
        count = row.length;
      }
    }
    return count == 0 ? 2 : count;
  }

  List<List<String>> _normalizedRows(NoteMixedSection section) {
    final rows = section.rows.isEmpty
        ? [
            ['', ''],
          ]
        : [
            for (final row in section.rows) [...row],
          ];
    final width = _columnCount(rows);
    for (final row in rows) {
      while (row.length < width) {
        row.add('');
      }
    }
    return rows;
  }

  void _updateTableCell(
    NoteMixedSection section,
    int row,
    int column,
    String value,
  ) {
    final rows = _normalizedRows(section);
    while (rows.length <= row) {
      rows.add(List.filled(_columnCount(rows), ''));
    }
    while (rows[row].length <= column) {
      rows[row].add('');
    }
    rows[row][column] = value;
    _replaceSection(
      section.copyWith(rows: rows),
      selection: _MixedSelectionTarget.tableCell(section.id, row, column),
    );
  }

  void _addTableRow(NoteMixedSection section) {
    final rows = _normalizedRows(section);
    rows.add(List.filled(_columnCount(rows), ''));
    _replaceSection(
      section.copyWith(rows: rows),
      selection: _MixedSelectionTarget.tableCell(
        section.id,
        rows.length - 1,
        0,
      ),
    );
  }

  void _addTableColumn(NoteMixedSection section) {
    final rows = _normalizedRows(section);
    for (final row in rows) {
      row.add('');
    }
    _replaceSection(
      section.copyWith(rows: rows),
      selection: _MixedSelectionTarget.tableCell(
        section.id,
        0,
        _columnCount(rows) - 1,
      ),
    );
  }

  void _deleteTableRow(NoteMixedSection section, int rowIndex) {
    final rows = _normalizedRows(section);
    if (rows.length <= 1 || rowIndex < 0 || rowIndex >= rows.length) {
      return;
    }
    rows.removeAt(rowIndex);
    _replaceSection(section.copyWith(rows: rows), clearSelection: true);
  }

  void _deleteTableColumn(NoteMixedSection section, int columnIndex) {
    final rows = _normalizedRows(section);
    final width = _columnCount(rows);
    if (width <= 1 || columnIndex < 0 || columnIndex >= width) {
      return;
    }
    for (final row in rows) {
      row.removeAt(columnIndex);
    }
    _replaceSection(section.copyWith(rows: rows), clearSelection: true);
  }

  void _moveTableRow(NoteMixedSection section, int rowIndex, int delta) {
    final rows = _normalizedRows(section);
    final target = (rowIndex + delta).clamp(0, rows.length - 1).toInt();
    if (target == rowIndex) {
      return;
    }
    final moved = rows.removeAt(rowIndex);
    rows.insert(target, moved);
    _replaceSection(
      section.copyWith(rows: rows),
      selection: _MixedSelectionTarget.tableCell(
        section.id,
        target,
        _selection?.columnIndex ?? 0,
      ),
    );
  }

  void _moveTableColumn(NoteMixedSection section, int columnIndex, int delta) {
    final rows = _normalizedRows(section);
    final width = _columnCount(rows);
    final target = (columnIndex + delta).clamp(0, width - 1).toInt();
    if (target == columnIndex) {
      return;
    }
    for (final row in rows) {
      final moved = row.removeAt(columnIndex);
      row.insert(target, moved);
    }
    _replaceSection(
      section.copyWith(rows: rows),
      selection: _MixedSelectionTarget.tableCell(
        section.id,
        _selection?.rowIndex ?? 0,
        target,
      ),
    );
  }

  NoteMixedSection? _sectionById(String sectionId) {
    for (final section in _sections) {
      if (section.id == sectionId) {
        return section;
      }
    }
    return null;
  }

  NoteListItem? _selectedListItem() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.listItem) {
      return null;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null) {
      return null;
    }
    for (final item in _itemsFor(section)) {
      if (item.id == selection.itemId) {
        return item;
      }
    }
    return null;
  }

  List<NoteKnowledgeTag> get _selectedTags {
    final selection = _selection;
    if (selection == null) {
      return const [];
    }
    switch (selection.kind) {
      case _MixedSelectionKind.paragraph:
        return const [];
      case _MixedSelectionKind.listItem:
        return _selectedListItem()?.tags ?? const [];
      case _MixedSelectionKind.tableCell:
        final section = _sectionById(selection.sectionId);
        if (section == null) {
          return const [];
        }
        for (final assignment in section.scopedTags) {
          if (_sameTableCell(assignment.target, selection)) {
            return assignment.tags;
          }
        }
        return const [];
    }
  }

  Future<void> _tagChunk() async {
    await showTagManagerSheet(
      context,
      initialTags: _block.tags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _commitBlock(_block.copyWith(tags: tags)),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Chunk tagjei',
    );
  }

  void _deleteChunkTag(NoteKnowledgeTag tag) {
    _commitBlock(
      _block.copyWith(
        tags: _block.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
      ),
    );
  }

  Future<void> _tagSelection() async {
    final selection = _selection;
    if (selection == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valassz ki szerkesztheto reszt')),
      );
      return;
    }
    await showTagManagerSheet(
      context,
      initialTags: _selectedTags,
      tagRepository: _tagRepository,
      onChanged: (tags) => _applySelectionTags(selection, tags),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelolt resz tagjei',
    );
  }

  void _applySelectionTags(
    _MixedSelectionTarget selection,
    List<NoteKnowledgeTag> tags,
  ) {
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      return;
    }
    switch (selection.kind) {
      case _MixedSelectionKind.paragraph:
        return;
      case _MixedSelectionKind.listItem:
        final item = _selectedListItem();
        if (item == null) {
          return;
        }
        _replaceListItem(section, item.copyWith(tags: tags));
        return;
      case _MixedSelectionKind.tableCell:
        final target = NoteTagTarget(
          kind: NoteTagTargetKind.tableCell,
          rowIndex: selection.rowIndex,
          columnIndex: selection.columnIndex,
        );
        final assignments = [
          for (final assignment in section.scopedTags)
            if (!_sameTableCell(assignment.target, selection)) assignment,
          if (tags.isNotEmpty)
            NoteScopedTagAssignment(
              id: _nextId('tag'),
              target: target,
              tags: tags,
            ),
        ];
        _replaceSection(section.copyWith(scopedTags: assignments));
        return;
    }
  }

  void _deleteSelectedTag() {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    _applySelectionTags(selection, const []);
  }

  bool _sameTableCell(NoteTagTarget target, _MixedSelectionTarget selection) {
    return target.kind == NoteTagTargetKind.tableCell &&
        target.rowIndex == selection.rowIndex &&
        target.columnIndex == selection.columnIndex;
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  void _handleTitleChanged(String value) {
    _commitBlock(_block.copyWith(title: value.trim()));
  }

  void _handleRailIndent() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.listItem) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    final item = _selectedListItem();
    if (section == null || item == null) {
      return;
    }
    _changeListIndent(section, item, 1);
  }

  void _handleRailOutdent() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.listItem) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    final item = _selectedListItem();
    if (section == null || item == null) {
      return;
    }
    _changeListIndent(section, item, -1);
  }

  void _handleRailAdd() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.listItem) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    final item = _selectedListItem();
    if (section == null || item == null) {
      return;
    }
    _insertListItemAfter(section, item);
  }

  void _handleRailDelete() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.listItem) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    final item = _selectedListItem();
    if (section == null || item == null) {
      return;
    }
    _deleteListItem(section, item);
  }

  void _handleTableRailAction(
    void Function(NoteMixedSection, int, int) action,
  ) {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.tableCell) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null) {
      return;
    }
    action(section, selection.rowIndex ?? 0, selection.columnIndex ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final railVisible = _selection != null;
    return Scaffold(
      key: const ValueKey('note-mixed-text-editor'),
      resizeToAvoidBottomInset: false,
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: 'Szoveg',
        onTitleChanged: _handleTitleChanged,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selectedTags.isNotEmpty,
        canDeleteChunk: widget.onDelete != null,
        trailingActions: [
          IconButton(
            key: const ValueKey('note-mixed-add-paragraph'),
            tooltip: 'Uj bekezdes',
            onPressed: _addParagraphSection,
            icon: const Icon(Icons.subject),
          ),
          IconButton(
            key: const ValueKey('note-mixed-add-list'),
            tooltip: 'Uj lista',
            onPressed: _addListSection,
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            key: const ValueKey('note-mixed-add-table'),
            tooltip: 'Uj tablazat',
            onPressed: _addTableSection,
            icon: const Icon(Icons.table_chart_outlined),
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
            child: Stack(
              children: [
                AnimatedPadding(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(
                    bottom:
                        bottomInset + (railVisible ? _keyboardRailReserve : 0),
                  ),
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _sections.length,
                    buildDefaultDragHandles: false,
                    // ignore: deprecated_member_use
                    onReorder: _reorderSections,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      return _buildSection(section, index);
                    },
                  ),
                ),
                if (railVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 120),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: SafeArea(
                        top: false,
                        child: SizedBox(
                          key: const ValueKey('note-mixed-keyboard-rail'),
                          child: _MixedKeyboardRail(
                            tags: _selectedTags,
                            selectionKind: _selection!.kind,
                            bottomRowExpanded: _railBottomExpanded,
                            roundedCard: _railRoundedCard,
                            transparentBackground: _railTransparentBackground,
                            showBorder: _railBorderVisible,
                            onToggleBottomRow: () => setState(
                              () => _railBottomExpanded = !_railBottomExpanded,
                            ),
                            onTag: () => unawaited(_tagSelection()),
                            onClearTags: _selectedTags.isEmpty
                                ? null
                                : _deleteSelectedTag,
                            onDeleteTag: (_) => _deleteSelectedTag(),
                            onOutdent: _handleRailOutdent,
                            onIndent: _handleRailIndent,
                            onAddListItem: _handleRailAdd,
                            onDeleteListItem: _handleRailDelete,
                            onAddRow: () => _handleTableRailAction(
                              (section, row, column) => _addTableRow(section),
                            ),
                            onAddColumn: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _addTableColumn(section),
                            ),
                            onDeleteRow: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _deleteTableRow(section, row),
                            ),
                            onDeleteColumn: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _deleteTableColumn(section, column),
                            ),
                            onMoveRowUp: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _moveTableRow(section, row, -1),
                            ),
                            onMoveRowDown: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _moveTableRow(section, row, 1),
                            ),
                            onMoveColumnLeft: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _moveTableColumn(section, column, -1),
                            ),
                            onMoveColumnRight: () => _handleTableRailAction(
                              (section, row, column) =>
                                  _moveTableColumn(section, column, 1),
                            ),
                            onToggleRounded: () => setState(
                              () => _railRoundedCard = !_railRoundedCard,
                            ),
                            onToggleTransparent: () => setState(
                              () => _railTransparentBackground =
                                  !_railTransparentBackground,
                            ),
                            onToggleBorder: () => setState(
                              () => _railBorderVisible = !_railBorderVisible,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(NoteMixedSection section, int index) {
    final title = switch (section.type) {
      NoteMixedSectionType.paragraph => 'Bekezdes',
      NoteMixedSectionType.list => 'Lista',
      NoteMixedSectionType.table => 'Tablazat',
    };
    return Card(
      key: ValueKey('note-mixed-section-${section.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.drag_indicator, size: 20),
                  ),
                ),
                Expanded(
                  child: Text(
                    section.title?.trim().isNotEmpty == true
                        ? section.title!.trim()
                        : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Szekcio torlese',
                  onPressed: () => _deleteSection(section),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            switch (section.type) {
              NoteMixedSectionType.paragraph => _buildParagraphSection(section),
              NoteMixedSectionType.list => _buildListSection(section),
              NoteMixedSectionType.table => _buildTableSection(section),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphSection(NoteMixedSection section) {
    return TextFormField(
      key: ValueKey('note-mixed-paragraph-${section.id}'),
      initialValue: section.text,
      minLines: 3,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      onTap: () => setState(
        () => _selection = _MixedSelectionTarget.paragraph(section.id),
      ),
      onChanged: (value) => _updateParagraph(section, value),
    );
  }

  Widget _buildListSection(NoteMixedSection section) {
    final items = _itemsFor(section);
    final markers = section.listLayoutMode == NoteListLayoutMode.hierarchy
        ? _hierarchyMarkers(section)
        : const <String, String>{};
    return ReorderableListView.builder(
      key: ValueKey('note-mixed-list-items-${section.id}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) =>
          _reorderListItems(section, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final item = items[index];
        return _MixedListItemRow(
          key: ValueKey('note-mixed-list-row-${item.id}'),
          item: item,
          index: index,
          selected:
              _selection?.kind == _MixedSelectionKind.listItem &&
              _selection?.sectionId == section.id &&
              _selection?.itemId == item.id,
          marker: markers[item.id],
          layoutMode: section.listLayoutMode,
          onSelect: () => setState(
            () => _selection = _MixedSelectionTarget.listItem(
              section.id,
              item.id,
            ),
          ),
          onChanged: (value) =>
              _replaceListItem(section, item.copyWith(text: value)),
          onCheckedChanged: (checked) => _replaceListItem(
            section,
            item.copyWith(checked: checked ?? false),
          ),
          onMoveUp: () => _moveListItem(section, item.id, -1),
          onMoveDown: () => _moveListItem(section, item.id, 1),
          onSubmit: () => _insertListItemAfter(section, item),
        );
      },
    );
  }

  Widget _buildTableSection(NoteMixedSection section) {
    final rows = _normalizedRows(section);
    final width = _columnCount(rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TextButton.icon(
              key: ValueKey('note-mixed-table-add-row-${section.id}'),
              onPressed: () => _addTableRow(section),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Sor'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              key: ValueKey('note-mixed-table-add-column-${section.id}'),
              onPressed: () => _addTableColumn(section),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Oszlop'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            children: [
              for (var row = 0; row < rows.length; row += 1)
                Row(
                  children: [
                    for (var column = 0; column < width; column += 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 8),
                        child: SizedBox(
                          width: 150,
                          child: TextFormField(
                            key: ValueKey(
                              'note-mixed-table-cell-${section.id}-$row-$column',
                            ),
                            initialValue: rows[row][column],
                            decoration: InputDecoration(
                              isDense: true,
                              border: const OutlineInputBorder(),
                              filled:
                                  _selection?.kind ==
                                      _MixedSelectionKind.tableCell &&
                                  _selection?.sectionId == section.id &&
                                  _selection?.rowIndex == row &&
                                  _selection?.columnIndex == column,
                              fillColor: const Color(0xFFEFF6FF),
                            ),
                            onTap: () => setState(
                              () =>
                                  _selection = _MixedSelectionTarget.tableCell(
                                    section.id,
                                    row,
                                    column,
                                  ),
                            ),
                            onChanged: (value) =>
                                _updateTableCell(section, row, column, value),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _MixedSelectionKind { paragraph, listItem, tableCell }

class _MixedSelectionTarget {
  const _MixedSelectionTarget._({
    required this.kind,
    required this.sectionId,
    this.itemId,
    this.rowIndex,
    this.columnIndex,
  });

  const _MixedSelectionTarget.paragraph(String sectionId)
    : this._(kind: _MixedSelectionKind.paragraph, sectionId: sectionId);

  const _MixedSelectionTarget.listItem(String sectionId, String itemId)
    : this._(
        kind: _MixedSelectionKind.listItem,
        sectionId: sectionId,
        itemId: itemId,
      );

  const _MixedSelectionTarget.tableCell(
    String sectionId,
    int rowIndex,
    int columnIndex,
  ) : this._(
        kind: _MixedSelectionKind.tableCell,
        sectionId: sectionId,
        rowIndex: rowIndex,
        columnIndex: columnIndex,
      );

  final _MixedSelectionKind kind;
  final String sectionId;
  final String? itemId;
  final int? rowIndex;
  final int? columnIndex;
}

class _MixedListItemRow extends StatelessWidget {
  const _MixedListItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.selected,
    required this.marker,
    required this.layoutMode,
    required this.onSelect,
    required this.onChanged,
    required this.onCheckedChanged,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSubmit,
  });

  final NoteListItem item;
  final int index;
  final bool selected;
  final String? marker;
  final NoteListLayoutMode layoutMode;
  final VoidCallback onSelect;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool?> onCheckedChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: item.level * 18.0, bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            key: ValueKey('note-mixed-list-drag-${item.id}'),
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator, size: 18),
            ),
          ),
          if (layoutMode == NoteListLayoutMode.checkbox)
            Checkbox(value: item.checked, onChanged: onCheckedChanged)
          else
            SizedBox(
              width: 32,
              child: Text(
                marker ?? '-',
                key: ValueKey('note-mixed-list-marker-${item.id}'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          Expanded(
            child: TextFormField(
              key: ValueKey('note-mixed-list-item-${item.id}'),
              initialValue: item.text,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
              onTap: onSelect,
              onChanged: onChanged,
              onFieldSubmitted: (_) => onSubmit(),
            ),
          ),
          IconButton(
            key: ValueKey('note-mixed-list-move-up-${item.id}'),
            tooltip: 'Fel',
            onPressed: onMoveUp,
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
          ),
          IconButton(
            key: ValueKey('note-mixed-list-move-down-${item.id}'),
            tooltip: 'Le',
            onPressed: onMoveDown,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          ),
        ],
      ),
    );
  }
}

class _MixedKeyboardRail extends StatelessWidget {
  const _MixedKeyboardRail({
    required this.tags,
    required this.selectionKind,
    required this.bottomRowExpanded,
    required this.roundedCard,
    required this.transparentBackground,
    required this.showBorder,
    required this.onToggleBottomRow,
    required this.onTag,
    required this.onClearTags,
    required this.onDeleteTag,
    required this.onOutdent,
    required this.onIndent,
    required this.onAddListItem,
    required this.onDeleteListItem,
    required this.onAddRow,
    required this.onAddColumn,
    required this.onDeleteRow,
    required this.onDeleteColumn,
    required this.onMoveRowUp,
    required this.onMoveRowDown,
    required this.onMoveColumnLeft,
    required this.onMoveColumnRight,
    required this.onToggleRounded,
    required this.onToggleTransparent,
    required this.onToggleBorder,
  });

  final List<NoteKnowledgeTag> tags;
  final _MixedSelectionKind selectionKind;
  final bool bottomRowExpanded;
  final bool roundedCard;
  final bool transparentBackground;
  final bool showBorder;
  final VoidCallback onToggleBottomRow;
  final VoidCallback onTag;
  final VoidCallback? onClearTags;
  final ValueChanged<NoteKnowledgeTag> onDeleteTag;
  final VoidCallback onOutdent;
  final VoidCallback onIndent;
  final VoidCallback onAddListItem;
  final VoidCallback onDeleteListItem;
  final VoidCallback onAddRow;
  final VoidCallback onAddColumn;
  final VoidCallback onDeleteRow;
  final VoidCallback onDeleteColumn;
  final VoidCallback onMoveRowUp;
  final VoidCallback onMoveRowDown;
  final VoidCallback onMoveColumnLeft;
  final VoidCallback onMoveColumnRight;
  final VoidCallback onToggleRounded;
  final VoidCallback onToggleTransparent;
  final VoidCallback onToggleBorder;

  @override
  Widget build(BuildContext context) {
    const constraints = BoxConstraints.tightFor(width: 34, height: 34);
    const padding = EdgeInsets.zero;
    return NoteSelectionActionRail(
      tags: tags,
      pillPrefix: 'note-mixed-rail-pill',
      bottomRowExpanded: bottomRowExpanded,
      onToggleBottomRow: onToggleBottomRow,
      onDeleteTag: onDeleteTag,
      roundedCard: roundedCard,
      transparentBackground: transparentBackground,
      showBorder: showBorder,
      debugLogPrefix: 'MixedRail',
      actions: [
        IconButton(
          key: const ValueKey('note-mixed-rail-tag'),
          tooltip: 'Tageles',
          onPressed: onTag,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.sell_outlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-clear-tags'),
          tooltip: 'Tagek torlese',
          onPressed: onClearTags,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
        if (selectionKind == _MixedSelectionKind.listItem) ...[
          IconButton(
            key: const ValueKey('note-mixed-rail-outdent'),
            tooltip: 'Kijjebb',
            onPressed: onOutdent,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.format_indent_decrease, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-indent'),
            tooltip: 'Beljebb',
            onPressed: onIndent,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.format_indent_increase, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-add-list-item'),
            tooltip: 'Listaelem hozzaadasa',
            onPressed: onAddListItem,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.add, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-delete-list-item'),
            tooltip: 'Listaelem torlese',
            onPressed: onDeleteListItem,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.remove, size: 18),
          ),
        ],
        if (selectionKind == _MixedSelectionKind.tableCell) ...[
          IconButton(
            key: const ValueKey('note-mixed-rail-add-row'),
            tooltip: 'Sor hozzaadasa',
            onPressed: onAddRow,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.table_rows_outlined, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-add-column'),
            tooltip: 'Oszlop hozzaadasa',
            onPressed: onAddColumn,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.view_column_outlined, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-delete-row'),
            tooltip: 'Sor torlese',
            onPressed: onDeleteRow,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.remove, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-delete-column'),
            tooltip: 'Oszlop torlese',
            onPressed: onDeleteColumn,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.remove_circle_outline, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-row-up'),
            tooltip: 'Sor fel',
            onPressed: onMoveRowUp,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-row-down'),
            tooltip: 'Sor le',
            onPressed: onMoveRowDown,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-column-left'),
            tooltip: 'Oszlop balra',
            onPressed: onMoveColumnLeft,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.chevron_left, size: 18),
          ),
          IconButton(
            key: const ValueKey('note-mixed-rail-column-right'),
            tooltip: 'Oszlop jobbra',
            onPressed: onMoveColumnRight,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.chevron_right, size: 18),
          ),
        ],
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-rounded'),
          tooltip: roundedCard ? 'Vonalas rail' : 'Kartyas rail',
          onPressed: onToggleRounded,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.crop_square_outlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-transparent'),
          tooltip: transparentBackground ? 'Feher hatter' : 'Szurke hatter',
          onPressed: onToggleTransparent,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.opacity, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-border'),
          tooltip: showBorder ? 'Border nelkul' : 'Borderrel',
          onPressed: onToggleBorder,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.border_outer, size: 18),
        ),
      ],
    );
  }
}
