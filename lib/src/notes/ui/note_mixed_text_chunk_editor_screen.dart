import 'dart:async';

import 'package:flutter/material.dart';

import '../data/tag_repository.dart';
import '../models/note_document.dart';
import '../models/note_list_hierarchy_markers.dart';
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
  static const double _defaultColumnWidth = 150;
  static const double _defaultRowHeight = 52;
  static const double _rowHeadWidth = 52;

  late final TagRepository _tagRepository =
      widget.tagRepository ?? MemoryTagRepository();
  late NoteBlock _block;
  late List<NoteMixedSection> _sections;
  final Map<String, TextEditingController> _textControllers = {};
  _MixedSelectionTarget? _selection;
  String? _activeTextControllerKey;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  _MixedRailPanel? _railPanel;

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

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
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

  TextEditingController _controllerFor(String key, String text) {
    final existing = _textControllers[key];
    if (existing != null) {
      if (existing.text != text && key != _activeTextControllerKey) {
        existing.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      return existing;
    }
    final controller = TextEditingController(text: text);
    _textControllers[key] = controller;
    return controller;
  }

  void _activateTextTarget(String controllerKey, _MixedSelectionTarget target) {
    setState(() {
      _activeTextControllerKey = controllerKey;
      _selection = target;
    });
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

  void _addTableSection() {
    final section = NoteMixedSection(
      id: _nextId('table'),
      type: NoteMixedSectionType.table,
      rows: const [
        ['', ''],
        ['', ''],
      ],
    );
    final next = [..._sections];
    next.insert(_insertIndexAfterSelection(), section);
    _commitSections(
      next,
      selection: _MixedSelectionTarget.tableCell(section.id, 0, 0),
    );
  }

  int _insertIndexAfterSelection() {
    final selection = _selection;
    if (selection == null) {
      return _sections.length;
    }
    final index = _sections.indexWhere(
      (section) => section.id == selection.sectionId,
    );
    return index < 0 ? _sections.length : index + 1;
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

  void _updateParagraph(NoteMixedSection section, String text) {
    _replaceSection(section.copyWith(text: text));
  }

  List<NoteListItem> _itemsFor(NoteMixedSection section) {
    if (section.listItems.isNotEmpty) {
      return section.listItems;
    }
    return [NoteListItem(id: _nextId('item'), text: section.text)];
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

  double _tableColumnWidth(NoteMixedSection section, int column) {
    if (column >= 0 && column < section.tableColumnWidths.length) {
      return section.tableColumnWidths[column];
    }
    return _defaultColumnWidth;
  }

  double _tableRowHeight(NoteMixedSection section, int row) {
    if (row >= 0 && row < section.tableRowHeights.length) {
      return section.tableRowHeights[row];
    }
    return _defaultRowHeight;
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

  void _setSelectedParagraphRole(NoteMixedParagraphRole role) {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.paragraph) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null || section.type != NoteMixedSectionType.paragraph) {
      return;
    }
    _replaceSection(
      section.copyWith(
        paragraphRole: role,
        headingLevel: role == NoteMixedParagraphRole.heading
            ? section.headingLevel
            : 1,
      ),
      selection: _MixedSelectionTarget.paragraph(section.id),
    );
  }

  void _setSelectedHeadingLevel(int level) {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.paragraph) {
      setState(() => _railPanel = null);
      return;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null || section.type != NoteMixedSectionType.paragraph) {
      setState(() => _railPanel = null);
      return;
    }
    _replaceSection(
      section.copyWith(
        paragraphRole: NoteMixedParagraphRole.heading,
        headingLevel: level.clamp(1, 3).toInt(),
      ),
      selection: _MixedSelectionTarget.paragraph(section.id),
    );
    setState(() => _railPanel = null);
  }

  void _toggleRailPanel(_MixedRailPanel panel) {
    setState(() => _railPanel = _railPanel == panel ? null : panel);
  }

  void _applySelectedColor(int colorValue) {
    final panel = _railPanel;
    final selection = _selection;
    if (panel == null || selection == null) {
      setState(() => _railPanel = null);
      return;
    }
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      setState(() => _railPanel = null);
      return;
    }
    final nextSection = switch (panel) {
      _MixedRailPanel.textColor => section.copyWith(textColorValue: colorValue),
      _MixedRailPanel.underlineColor => section.copyWith(
        underlineColorValue: colorValue,
      ),
      _MixedRailPanel.backgroundColor => section.copyWith(
        backgroundColorValue: colorValue,
      ),
      _MixedRailPanel.heading => section,
    };
    _replaceSection(nextSection, selection: selection);
    setState(() => _railPanel = null);
  }

  void _convertSelectedParagraphToList(NoteListLayoutMode mode) {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.paragraph) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null || section.type != NoteMixedSectionType.paragraph) {
      return;
    }
    final lines = section.text
        .split('\n')
        .map(_cleanListInputLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final items = lines.isEmpty
        ? [NoteListItem(id: _nextId('item'), text: '')]
        : [
            for (final line in lines)
              NoteListItem(id: _nextId('item'), text: line),
          ];
    final next = section.copyWith(
      type: NoteMixedSectionType.list,
      text: '',
      paragraphRole: NoteMixedParagraphRole.paragraph,
      listLayoutMode: mode,
      listItems: items,
    );
    _replaceSection(
      next,
      selection: _MixedSelectionTarget.listItem(next.id, items.first.id),
    );
  }

  String _cleanListInputLine(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^([\-*•]|\d+[\.)])\s+'), '')
        .trim();
  }

  void _toggleBoldInActiveText() {
    _toggleWrappedInActiveText('**', '**');
  }

  void _toggleItalicInActiveText() {
    _toggleWrappedInActiveText('_', '_');
  }

  void _toggleWrappedInActiveText(String prefix, String suffix) {
    final key = _activeTextControllerKey;
    final controller = key == null ? null : _textControllers[key];
    if (key == null || controller == null) {
      return;
    }
    final text = controller.text;
    if (text.isEmpty) {
      return;
    }
    final selection = controller.selection;
    final start = selection.isValid && !selection.isCollapsed
        ? selection.start
        : 0;
    final end = selection.isValid && !selection.isCollapsed
        ? selection.end
        : text.length;
    if (start < 0 || end > text.length || start >= end) {
      return;
    }
    final selectedText = text.substring(start, end);
    final hasBoldMarkers =
        selectedText.startsWith(prefix) &&
        selectedText.endsWith(suffix) &&
        selectedText.length > prefix.length + suffix.length;
    final replacement = hasBoldMarkers
        ? selectedText.substring(
            prefix.length,
            selectedText.length - suffix.length,
          )
        : '$prefix$selectedText$suffix';
    final nextText = text.replaceRange(start, end, replacement);
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection(
        baseOffset: start,
        extentOffset: start + replacement.length,
      ),
    );
    _applyActiveText(nextText);
  }

  void _applyActiveText(String text) {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      return;
    }
    switch (selection.kind) {
      case _MixedSelectionKind.paragraph:
        _updateParagraph(section, text);
        return;
      case _MixedSelectionKind.listItem:
        final item = _selectedListItem();
        if (item != null) {
          _replaceListItem(section, item.copyWith(text: text));
        }
        return;
      case _MixedSelectionKind.tableCell:
        _updateTableCell(
          section,
          selection.rowIndex ?? 0,
          selection.columnIndex ?? 0,
          text,
        );
        return;
    }
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
    if (selection == null) {
      return;
    }
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      return;
    }
    if (selection.kind == _MixedSelectionKind.paragraph) {
      _replaceSection(
        section.copyWith(
          paragraphIndentLevel: section.paragraphIndentLevel + 1,
        ),
        selection: _MixedSelectionTarget.paragraph(section.id),
      );
      return;
    }
    if (selection.kind == _MixedSelectionKind.listItem) {
      final item = _selectedListItem();
      if (item == null) {
        return;
      }
      _changeListIndent(section, item, 1);
    }
  }

  void _handleRailOutdent() {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      return;
    }
    if (selection.kind == _MixedSelectionKind.paragraph) {
      _replaceSection(
        section.copyWith(
          paragraphIndentLevel: section.paragraphIndentLevel - 1,
        ),
        selection: _MixedSelectionTarget.paragraph(section.id),
      );
      return;
    }
    if (selection.kind == _MixedSelectionKind.listItem) {
      final item = _selectedListItem();
      if (item == null) {
        return;
      }
      _changeListIndent(section, item, -1);
    }
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

  void _deleteSelectedTable() {
    final selection = _selection;
    if (selection?.kind != _MixedSelectionKind.tableCell) {
      return;
    }
    final section = _sectionById(selection!.sectionId);
    if (section == null || section.type != NoteMixedSectionType.table) {
      return;
    }
    _deleteSection(section);
  }

  void _convertSelectedListMode(NoteListLayoutMode mode) {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    final section = _sectionById(selection.sectionId);
    if (section == null) {
      return;
    }
    if (section.type == NoteMixedSectionType.paragraph) {
      _convertSelectedParagraphToList(mode);
      return;
    }
    if (section.type == NoteMixedSectionType.list) {
      _replaceSection(
        section.copyWith(listLayoutMode: mode),
        selection: selection,
      );
    }
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
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _sections.length,
                    itemBuilder: (context, index) {
                      final section = _sections[index];
                      return _buildSection(section);
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MixedRailPopover(
                                panel: _railPanel,
                                onHeadingLevel: _setSelectedHeadingLevel,
                                onColor: _applySelectedColor,
                              ),
                              _MixedKeyboardRail(
                                tags: _selectedTags,
                                selectionKind: _selection!.kind,
                                bottomRowExpanded: _railBottomExpanded,
                                roundedCard: _railRoundedCard,
                                transparentBackground:
                                    _railTransparentBackground,
                                showBorder: _railBorderVisible,
                                onToggleBottomRow: () => setState(
                                  () => _railBottomExpanded =
                                      !_railBottomExpanded,
                                ),
                                onText: () => _setSelectedParagraphRole(
                                  NoteMixedParagraphRole.paragraph,
                                ),
                                onHeading: () =>
                                    _toggleRailPanel(_MixedRailPanel.heading),
                                onBold: _toggleBoldInActiveText,
                                onItalic: _toggleItalicInActiveText,
                                onTextColor: () =>
                                    _toggleRailPanel(_MixedRailPanel.textColor),
                                onUnderlineColor: () => _toggleRailPanel(
                                  _MixedRailPanel.underlineColor,
                                ),
                                onBackgroundColor: () => _toggleRailPanel(
                                  _MixedRailPanel.backgroundColor,
                                ),
                                onDynamicList: () => _convertSelectedListMode(
                                  NoteListLayoutMode.hierarchy,
                                ),
                                onStaticList: () => _convertSelectedListMode(
                                  NoteListLayoutMode.checkbox,
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
                                  (section, row, column) =>
                                      _addTableRow(section),
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
                                onDeleteTable: _deleteSelectedTable,
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
                                  () =>
                                      _railBorderVisible = !_railBorderVisible,
                                ),
                              ),
                            ],
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

  Widget _buildSection(NoteMixedSection section) {
    return Padding(
      key: ValueKey('note-mixed-section-${section.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: switch (section.type) {
        NoteMixedSectionType.paragraph => _buildParagraphSection(section),
        NoteMixedSectionType.list => _buildListSection(section),
        NoteMixedSectionType.table => _buildTableSection(section),
      },
    );
  }

  Widget _buildParagraphSection(NoteMixedSection section) {
    final key = 'paragraph:${section.id}';
    final controller = _controllerFor(key, section.text);
    return Padding(
      padding: EdgeInsets.only(left: section.paragraphIndentLevel * 22.0),
      child: TextField(
        key: ValueKey('note-mixed-paragraph-${section.id}'),
        controller: controller,
        minLines: 1,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: _textStyleForSection(section),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          hintText: section.paragraphRole == NoteMixedParagraphRole.heading
              ? 'Cím'
              : 'Bekezdés',
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onTap: () => _activateTextTarget(
          key,
          _MixedSelectionTarget.paragraph(section.id),
        ),
        onChanged: (value) => _updateParagraph(section, value),
      ),
    );
  }

  TextStyle _textStyleForSection(NoteMixedSection section) {
    final isHeading = section.paragraphRole == NoteMixedParagraphRole.heading;
    final headingLevel = section.headingLevel.clamp(1, 3).toInt();
    final base = Theme.of(context).textTheme.bodyLarge ?? const TextStyle();
    final fontSize = isHeading
        ? switch (headingLevel) {
            1 => 24.0,
            2 => 21.0,
            _ => 18.0,
          }
        : 17.0;
    final lineHeight = isHeading
        ? switch (headingLevel) {
            1 => 1.16,
            2 => 1.22,
            _ => 1.30,
          }
        : 1.38;
    return base.copyWith(
      color: section.textColorValue == null
          ? const Color(0xFF111827)
          : Color(section.textColorValue!),
      fontSize: fontSize,
      height: lineHeight,
      fontWeight: isHeading ? FontWeight.w800 : FontWeight.w400,
      backgroundColor: section.backgroundColorValue == null
          ? null
          : Color(section.backgroundColorValue!).withValues(alpha: 0.35),
      decoration: section.underlineColorValue == null
          ? TextDecoration.none
          : TextDecoration.underline,
      decorationColor: section.underlineColorValue == null
          ? null
          : Color(section.underlineColorValue!),
      decorationThickness: section.underlineColorValue == null ? null : 2,
    );
  }

  Widget _buildListSection(NoteMixedSection section) {
    final items = _itemsFor(section);
    final markers = section.listLayoutMode == NoteListLayoutMode.hierarchy
        ? noteHierarchyMarkersForItems(items)
        : const <String, String>{};
    return Column(
      key: ValueKey('note-mixed-list-items-${section.id}'),
      children: [
        for (var index = 0; index < items.length; index += 1)
          _MixedListItemRow(
            key: ValueKey('note-mixed-list-row-${items[index].id}'),
            controller: _controllerFor(
              'list:${section.id}:${items[index].id}',
              items[index].text,
            ),
            item: items[index],
            selected:
                _selection?.kind == _MixedSelectionKind.listItem &&
                _selection?.sectionId == section.id &&
                _selection?.itemId == items[index].id,
            marker: markers[items[index].id],
            layoutMode: section.listLayoutMode,
            style: _textStyleForSection(section),
            onSelect: () => _activateTextTarget(
              'list:${section.id}:${items[index].id}',
              _MixedSelectionTarget.listItem(section.id, items[index].id),
            ),
            onChanged: (value) =>
                _replaceListItem(section, items[index].copyWith(text: value)),
            onCheckedChanged: (checked) => _replaceListItem(
              section,
              items[index].copyWith(checked: checked ?? false),
            ),
            onSubmit: () => _insertListItemAfter(section, items[index]),
          ),
      ],
    );
  }

  Widget _buildTableSection(NoteMixedSection section) {
    final rows = _normalizedRows(section);
    final width = _columnCount(rows);
    final columnWidths = [
      for (var column = 0; column < width; column += 1)
        _tableColumnWidth(section, column),
    ];
    final tableWidth =
        _rowHeadWidth +
        4 +
        columnWidths.fold<double>(0, (sum, item) => sum + item + 4);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _MixedTableHeadCell(
                  key: ValueKey('note-mixed-table-corner-head'),
                  width: _rowHeadWidth,
                  height: _defaultRowHeight,
                  label: '',
                  icon: Icons.grid_on_outlined,
                  selected: false,
                ),
                for (var column = 0; column < width; column += 1)
                  _MixedTableHeadCell(
                    key: ValueKey('note-mixed-table-column-head-$column'),
                    width: columnWidths[column],
                    height: _defaultRowHeight,
                    label: 'Oszlop ${column + 1}',
                    selected:
                        _selection?.kind == _MixedSelectionKind.tableCell &&
                        _selection?.sectionId == section.id &&
                        _selection?.columnIndex == column,
                  ),
              ],
            ),
            for (var row = 0; row < rows.length; row += 1)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MixedTableHeadCell(
                    key: ValueKey('note-mixed-table-row-head-$row'),
                    width: _rowHeadWidth,
                    height: _tableRowHeight(section, row),
                    label: '${row + 1}',
                    icon: Icons.table_rows_outlined,
                    selected:
                        _selection?.kind == _MixedSelectionKind.tableCell &&
                        _selection?.sectionId == section.id &&
                        _selection?.rowIndex == row,
                  ),
                  for (var column = 0; column < width; column += 1)
                    _MixedTableCell(
                      width: columnWidths[column],
                      height: _tableRowHeight(section, row),
                      selected:
                          _selection?.kind == _MixedSelectionKind.tableCell &&
                          _selection?.sectionId == section.id &&
                          _selection?.rowIndex == row &&
                          _selection?.columnIndex == column,
                      child: TextField(
                        key: ValueKey(
                          'note-mixed-table-cell-${section.id}-$row-$column',
                        ),
                        controller: _controllerFor(
                          'table:${section.id}:$row:$column',
                          rows[row][column],
                        ),
                        minLines: 1,
                        maxLines: null,
                        style: _textStyleForSection(
                          section,
                        ).copyWith(fontSize: 15, height: 1.35),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onTap: () => _activateTextTarget(
                          'table:${section.id}:$row:$column',
                          _MixedSelectionTarget.tableCell(
                            section.id,
                            row,
                            column,
                          ),
                        ),
                        onChanged: (value) =>
                            _updateTableCell(section, row, column, value),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

enum _MixedSelectionKind { paragraph, listItem, tableCell }

enum _MixedRailPanel { heading, textColor, underlineColor, backgroundColor }

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
    required this.controller,
    required this.item,
    required this.selected,
    required this.marker,
    required this.layoutMode,
    required this.style,
    required this.onSelect,
    required this.onChanged,
    required this.onCheckedChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final NoteListItem item;
  final bool selected;
  final String? marker;
  final NoteListLayoutMode layoutMode;
  final TextStyle style;
  final VoidCallback onSelect;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool?> onCheckedChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: item.level * 18.0, bottom: 8),
      decoration: selected
          ? const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF2563EB), width: 3),
              ),
            )
          : null,
      child: Row(
        children: [
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
            child: TextField(
              key: ValueKey('note-mixed-list-item-${item.id}'),
              controller: controller,
              style: style,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              textInputAction: TextInputAction.next,
              onTap: onSelect,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MixedTableHeadCell extends StatelessWidget {
  const _MixedTableHeadCell({
    super.key,
    required this.width,
    required this.height,
    required this.label,
    required this.selected,
    this.icon,
  });

  final double width;
  final double height;
  final String label;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height),
      alignment: Alignment.center,
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      decoration: BoxDecoration(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? colorScheme.primary : const Color(0xFFE5E7EB),
        ),
      ),
      child: icon != null && label.isEmpty
          ? Icon(icon, size: 18, color: const Color(0xFF475569))
          : Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? colorScheme.primary : const Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _MixedTableCell extends StatelessWidget {
  const _MixedTableCell({
    required this.width,
    required this.height,
    required this.selected,
    required this.child,
  });

  final double width;
  final double height;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(minHeight: height),
      margin: const EdgeInsets.only(right: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Stack(
        children: [
          if (selected)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF2563EB), width: 2),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _MixedRailPopover extends StatelessWidget {
  const _MixedRailPopover({
    required this.panel,
    required this.onHeadingLevel,
    required this.onColor,
  });

  static const List<int> _colors = [
    0xFF111827,
    0xFF2563EB,
    0xFF16A34A,
    0xFFDC2626,
    0xFFD97706,
    0xFF7C3AED,
    0xFFFFF7ED,
    0xFFEFF6FF,
  ];

  final _MixedRailPanel? panel;
  final ValueChanged<int> onHeadingLevel;
  final ValueChanged<int> onColor;

  @override
  Widget build(BuildContext context) {
    final panel = this.panel;
    if (panel == null) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        key: panel == _MixedRailPanel.heading
            ? const ValueKey('note-mixed-rail-heading-popover')
            : const ValueKey('note-mixed-rail-color-popover'),
        color: Colors.white,
        elevation: 4,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: panel == _MixedRailPanel.heading
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var level = 1; level <= 3; level += 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          key: ValueKey('note-mixed-rail-heading-level-$level'),
                          onPressed: () => onHeadingLevel(level),
                          child: Text('H$level'),
                        ),
                      ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final colorValue in _colors)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: InkWell(
                          key: ValueKey(
                            'note-mixed-rail-color-'
                            '0x${colorValue.toRadixString(16).padLeft(8, '0')}',
                          ),
                          onTap: () => onColor(colorValue),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(colorValue),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MixedRailSeparator extends StatelessWidget {
  const _MixedRailSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 28,
      child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE5E7EB))),
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
    required this.onText,
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onTextColor,
    required this.onUnderlineColor,
    required this.onBackgroundColor,
    required this.onDynamicList,
    required this.onStaticList,
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
    required this.onDeleteTable,
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
  final VoidCallback onText;
  final VoidCallback onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onTextColor;
  final VoidCallback onUnderlineColor;
  final VoidCallback onBackgroundColor;
  final VoidCallback onDynamicList;
  final VoidCallback onStaticList;
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
  final VoidCallback onDeleteTable;
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
        const _MixedRailSeparator(
          key: ValueKey('note-mixed-rail-separator-tags'),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-heading'),
          tooltip: 'Címsor',
          onPressed: selectionKind == _MixedSelectionKind.paragraph
              ? onHeading
              : null,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.title, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-bold'),
          tooltip: 'Félkövér',
          onPressed: onBold,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_bold, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-italic'),
          tooltip: 'Dőlt',
          onPressed: onItalic,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_italic, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-text-color'),
          tooltip: 'Betűszín',
          onPressed: onTextColor,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_color_text, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-underline-color'),
          tooltip: 'Aláhúzás színe',
          onPressed: onUnderlineColor,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_underlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-background-color'),
          tooltip: 'Szöveg háttérszín',
          onPressed: onBackgroundColor,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_color_fill, size: 18),
        ),
        const _MixedRailSeparator(
          key: ValueKey('note-mixed-rail-separator-format'),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-text'),
          tooltip: 'Szöveg',
          onPressed: selectionKind == _MixedSelectionKind.paragraph
              ? onText
              : null,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.subject, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-list-dynamic'),
          tooltip: 'Hierarchikus lista',
          onPressed: selectionKind == _MixedSelectionKind.tableCell
              ? null
              : onDynamicList,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_list_numbered, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-list-static'),
          tooltip: 'Nem dinamikus lista',
          onPressed: selectionKind == _MixedSelectionKind.tableCell
              ? null
              : onStaticList,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.check_box_outlined, size: 18),
        ),
        const _MixedRailSeparator(
          key: ValueKey('note-mixed-rail-separator-list'),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-outdent'),
          tooltip: 'Kijjebb',
          onPressed: selectionKind == _MixedSelectionKind.tableCell
              ? null
              : onOutdent,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_indent_decrease, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-indent'),
          tooltip: 'Beljebb',
          onPressed: selectionKind == _MixedSelectionKind.tableCell
              ? null
              : onIndent,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.format_indent_increase, size: 18),
        ),
        if (selectionKind == _MixedSelectionKind.listItem) ...[
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
          const _MixedRailSeparator(
            key: ValueKey('note-mixed-rail-separator-table'),
          ),
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
            key: const ValueKey('note-mixed-rail-delete-table'),
            tooltip: 'Táblázat törlése',
            onPressed: onDeleteTable,
            constraints: constraints,
            padding: padding,
            icon: const Icon(Icons.table_chart, size: 18),
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
        const _MixedRailSeparator(
          key: ValueKey('note-mixed-rail-separator-design'),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-rounded'),
          tooltip: roundedCard ? 'Vonalas rail' : 'Cellaszerű rail',
          onPressed: onToggleRounded,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.crop_square_outlined, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-transparent'),
          tooltip: transparentBackground ? 'Fehér háttér' : 'Szürke háttér',
          onPressed: onToggleTransparent,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.opacity, size: 18),
        ),
        IconButton(
          key: const ValueKey('note-mixed-rail-toggle-border'),
          tooltip: showBorder ? 'Border nélkül' : 'Borderrel',
          onPressed: onToggleBorder,
          constraints: constraints,
          padding: padding,
          icon: const Icon(Icons.border_outer, size: 18),
        ),
      ],
    );
  }
}
