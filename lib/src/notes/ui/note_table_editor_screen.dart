import 'package:flutter/material.dart';

import '../models/note_document.dart';
import 'note_chunk_editor_header.dart';
import 'note_tag_pills.dart';
import 'tag_manager_sheet.dart';

class NoteTableEditorScreen extends StatefulWidget {
  const NoteTableEditorScreen({
    super.key,
    required this.block,
    this.availableTags = const [],
    this.onChanged,
    this.onDelete,
  });

  final NoteBlock block;
  final List<NoteKnowledgeTag> availableTags;
  final ValueChanged<NoteBlock>? onChanged;
  final VoidCallback? onDelete;

  @override
  State<NoteTableEditorScreen> createState() => _NoteTableEditorScreenState();
}

class _NoteTableEditorScreenState extends State<NoteTableEditorScreen> {
  late NoteBlock _block;
  late List<List<String>> _rows;
  late final TextEditingController _titleController;
  final Map<String, TextEditingController> _cellControllers = <String, TextEditingController>{};
  _TableSelection? _selection;

  @override
  void initState() {
    super.initState();
    _block = widget.block;
    _titleController = TextEditingController(text: widget.block.title ?? '');
    _rows = widget.block.rows.isEmpty
        ? [
            ['', ''],
          ]
        : [
            for (final row in widget.block.rows) [...row],
          ];
    _normalizeRows();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _columnCount {
    var width = 0;
    for (final row in _rows) {
      if (row.length > width) {
        width = row.length;
      }
    }
    return width == 0 ? 2 : width;
  }

  void _normalizeRows() {
    if (_rows.isEmpty) {
      _rows.add(['', '']);
      return;
    }
    final width = _columnCount;
    for (final row in _rows) {
      while (row.length < width) {
        row.add('');
      }
      if (row.isEmpty) {
        row.add('');
      }
    }
  }

  void _ensureCell(int row, int column) {
    while (_rows.length <= row) {
      _rows.add(List.filled(_columnCount, ''));
    }
    while (_rows[row].length <= column) {
      _rows[row].add('');
    }
  }

  String _cellControllerKey(int row, int column) => '$row:$column';

  TextEditingController _controllerFor(int row, int column) {
    final key = _cellControllerKey(row, column);
    final value = _rows[row][column];
    final controller = _cellControllers.putIfAbsent(key, () => TextEditingController(text: value));
    if (controller.text != value && !controller.selection.isValid) {
      controller.text = value;
    }
    return controller;
  }

  void _resetCellControllers() {
    final staleControllers = _cellControllers.values.toList(growable: false);
    _cellControllers.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in staleControllers) {
        controller.dispose();
      }
    });
  }

  void _updateCell(int row, int column, String value) {
    _ensureCell(row, column);
    _rows[row][column] = value;
    _emitChange();
  }

  NoteBlock _currentBlock() {
    _normalizeRows();
    return _block.copyWith(
      rows: [
        for (final row in _rows)
          row.map((cell) => cell.trim()).toList(growable: false),
      ],
      clearIndex: true,
    );
  }

  void _emitChange() {
    _block = _currentBlock();
    widget.onChanged?.call(_block);
  }

  void _emitTitle(String value) {
    _titleController.text = value;
    setState(() => _block = _block.copyWith(title: value.trim(), clearIndex: true));
    widget.onChanged?.call(_block);
  }

  void _addRow() {
    setState(() {
      _normalizeRows();
      _rows.add(List.filled(_columnCount, ''));
      _resetCellControllers();
    });
    _emitChange();
  }

  void _addColumn() {
    _insertColumn(_columnCount);
  }

  void _insertColumn(int index) {
    setState(() {
      _normalizeRows();
      final target = index.clamp(0, _columnCount).toInt();
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (tagTarget) => _remapTargetForColumnInsert(tagTarget, target),
        ),
        clearIndex: true,
      );
      for (final row in _rows) {
        row.insert(target, '');
      }
      _selection = null;
      _resetCellControllers();
    });
    _emitChange();
  }

  void _deleteRow(int index) {
    if (_rows.length == 1 || index < 0 || index >= _rows.length) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForRowDelete(target, index),
        ),
        clearIndex: true,
      );
      _rows.removeAt(index);
      _selection = null;
      _resetCellControllers();
    });
    _emitChange();
  }

  void _deleteColumn(int index) {
    _normalizeRows();
    if (_rows.isEmpty || _columnCount == 1 || index < 0 || index >= _columnCount) {
      return;
    }
    setState(() {
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForColumnDelete(target, index),
        ),
        clearIndex: true,
      );
      for (final row in _rows) {
        row.removeAt(index);
      }
      _selection = null;
      _resetCellControllers();
    });
    _emitChange();
  }

  void _save() {
    Navigator.of(context).pop(_currentBlock());
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
    widget.onChanged?.call(_block);
  }

  Future<void> _tagSelection() async {
    final selection = _selection;
    if (selection == null) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Válassz ki sort, oszlopot vagy cellát a tageléshez')),
      );
      return;
    }
    final tags = await showTagManagerSheet(
      context,
      initialTags: _tagsForSelection(selection),
      availableTags: [...widget.availableTags, ..._block.knownTags],
      title: 'Kijelölt táblázatrész tagjei',
    );
    if (tags == null) {
      return;
    }
    setState(() {
      final target = selection.toTagTarget();
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!_sameTarget(assignment.target, target)) assignment,
          if (tags.isNotEmpty)
            NoteScopedTagAssignment(
              id: 'table-tag-${DateTime.now().microsecondsSinceEpoch}',
              target: target,
              tags: tags,
            ),
        ],
        clearIndex: true,
      );
    });
    widget.onChanged?.call(_block);
  }

  void _deleteSelectedTag() {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    final target = selection.toTagTarget();
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!_sameTarget(assignment.target, target)) assignment,
        ],
        clearIndex: true,
      );
    });
    widget.onChanged?.call(_block);
  }

  void _deleteChunk() {
    widget.onDelete?.call();
    Navigator.of(context).maybePop();
  }

  List<NoteKnowledgeTag> _tagsForSelection(_TableSelection selection) {
    final target = selection.toTagTarget();
    for (final assignment in _block.scopedTags) {
      if (_sameTarget(assignment.target, target)) {
        return assignment.tags;
      }
    }
    return const [];
  }

  bool _hasTags(_TableSelection selection) => _tagsForSelection(selection).isNotEmpty;

  List<NoteKnowledgeTag> _tagsForCell(int row, int column) {
    final directTags = <NoteKnowledgeTag>[];
    final rowTags = <NoteKnowledgeTag>[];
    final columnTags = <NoteKnowledgeTag>[];
    for (final assignment in _block.scopedTags) {
      final target = assignment.target;
      switch (target.kind) {
        case NoteTagTargetKind.tableCell:
          if (target.rowIndex == row && target.columnIndex == column) {
            directTags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableRow:
          if (target.rowIndex == row) {
            rowTags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableColumn:
          if (target.columnIndex == column) {
            columnTags.addAll(assignment.tags);
          }
          break;
        default:
          break;
      }
    }
    if (directTags.isNotEmpty) {
      return directTags;
    }
    if (rowTags.isNotEmpty) {
      return rowTags;
    }
    return columnTags;
  }

  Color? _highlightColorForCell(int row, int column) {
    final tags = _tagsForCell(row, column);
    if (tags.isEmpty) {
      return null;
    }
    return Color(tags.first.resolvedColorValue).withValues(alpha: 0.16);
  }

  void _select(_TableSelection selection) {
    setState(() => _selection = selection);
  }

  Widget _railForSelection(_TableSelection selection) {
    return NoteSelectionActionRail(
      tags: _tagsForSelection(selection),
      label: switch (selection.kind) {
        _TableSelectionKind.row => 'Sor ${selection.rowIndex! + 1}',
        _TableSelectionKind.column => 'Oszlop ${selection.columnIndex! + 1}',
        _TableSelectionKind.cell =>
          'Cella ${selection.rowIndex! + 1}:${selection.columnIndex! + 1}',
      },
      actions: _railActions(selection),
    );
  }

  List<Widget> _railActions(_TableSelection selection) {
    const compactConstraints = BoxConstraints.tightFor(width: 34, height: 34);
    const compactPadding = EdgeInsets.zero;
    final actions = <Widget>[
      IconButton(
        key: ValueKey(_tagRailKey(selection)),
        tooltip: 'Tagelés',
        onPressed: () => unawaited(_tagSelection()),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.sell_outlined, size: 18),
      ),
    ];
    if (_hasTags(selection)) {
      actions.add(
        IconButton(
          key: ValueKey('${_tagRailKey(selection)}-delete-tag'),
          tooltip: 'Tag törlése',
          onPressed: _deleteSelectedTag,
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.label_off_outlined, size: 18),
        ),
      );
    }
    if (selection.kind == _TableSelectionKind.row ||
        selection.kind == _TableSelectionKind.cell) {
      final row = selection.rowIndex!;
      actions.add(
        IconButton(
          key: ValueKey('note-table-rail-delete-row-$row'),
          tooltip: 'Sor törlése',
          onPressed: () => _deleteRow(row),
          constraints: compactConstraints,
          padding: compactPadding,
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
      );
    }
    if (selection.kind == _TableSelectionKind.column ||
        selection.kind == _TableSelectionKind.cell) {
      final column = selection.columnIndex!;
      actions
        ..add(
          IconButton(
            key: ValueKey('note-table-rail-insert-column-right-column-$column'),
            tooltip: 'Oszlop beszúrása jobbra',
            onPressed: () => _insertColumn(column + 1),
            constraints: compactConstraints,
            padding: compactPadding,
            icon: const Icon(Icons.add, size: 18),
          ),
        )
        ..add(
          IconButton(
            key: ValueKey('note-table-rail-delete-column-$column'),
            tooltip: 'Oszlop törlése',
            onPressed: () => _deleteColumn(column),
            constraints: compactConstraints,
            padding: compactPadding,
            icon: const Icon(Icons.close, size: 18),
          ),
        );
    }
    return actions;
  }

  String _tagRailKey(_TableSelection selection) {
    return switch (selection.kind) {
      _TableSelectionKind.row => 'note-table-rail-tag-row-${selection.rowIndex}',
      _TableSelectionKind.column =>
        'note-table-rail-tag-column-${selection.columnIndex}',
      _TableSelectionKind.cell =>
        'note-table-rail-tag-cell-${selection.rowIndex}-${selection.columnIndex}',
    };
  }

  List<NoteScopedTagAssignment> _remapScopedTags(
    NoteTagTarget? Function(NoteTagTarget target) remap,
  ) {
    final next = <NoteScopedTagAssignment>[];
    for (final assignment in _block.scopedTags) {
      final target = remap(assignment.target);
      if (target != null) {
        next.add(assignment.copyWith(target: target));
      }
    }
    return next;
  }

  NoteTagTarget? _remapTargetForColumnInsert(
    NoteTagTarget target,
    int insertIndex,
  ) {
    final columnIndex = target.columnIndex;
    if (columnIndex == null || columnIndex < insertIndex) {
      return target;
    }
    if (target.kind == NoteTagTargetKind.tableColumn ||
        target.kind == NoteTagTargetKind.tableCell) {
      return target.copyWith(columnIndex: columnIndex + 1);
    }
    return target;
  }

  NoteTagTarget? _remapTargetForColumnDelete(
    NoteTagTarget target,
    int deleteIndex,
  ) {
    final columnIndex = target.columnIndex;
    if (columnIndex == null) {
      return target;
    }
    if (target.kind != NoteTagTargetKind.tableColumn &&
        target.kind != NoteTagTargetKind.tableCell) {
      return target;
    }
    if (columnIndex == deleteIndex) {
      return null;
    }
    if (columnIndex > deleteIndex) {
      return target.copyWith(columnIndex: columnIndex - 1);
    }
    return target;
  }

  NoteTagTarget? _remapTargetForRowDelete(NoteTagTarget target, int deleteIndex) {
    final rowIndex = target.rowIndex;
    if (rowIndex == null) {
      return target;
    }
    if (target.kind != NoteTagTargetKind.tableRow &&
        target.kind != NoteTagTargetKind.tableCell) {
      return target;
    }
    if (rowIndex == deleteIndex) {
      return null;
    }
    if (rowIndex > deleteIndex) {
      return target.copyWith(rowIndex: rowIndex - 1);
    }
    return target;
  }

  bool _sameTarget(NoteTagTarget left, NoteTagTarget right) {
    return left.kind == right.kind &&
        left.rowIndex == right.rowIndex &&
        left.columnIndex == right.columnIndex &&
        left.elementId == right.elementId &&
        left.listItemId == right.listItemId &&
        left.rangeId == right.rangeId;
  }

  @override
  Widget build(BuildContext context) {
    _normalizeRows();
    final columnCount = _columnCount;
    return Scaffold(
      appBar: NoteChunkEditorHeader(
        title: _block.title,
        fallbackTitle: 'Táblázat',
        onTitleChanged: _emitTitle,
        onTagChunk: () => unawaited(_tagChunk()),
        onTagSelection: () => unawaited(_tagSelection()),
        onDeleteSelectedTag: _deleteSelectedTag,
        onDeleteChunk: _deleteChunk,
        canDeleteSelectedTag: _selection != null && _hasTags(_selection!),
        trailingActions: [
          IconButton(
            key: const ValueKey('note-table-appbar-add-column'),
            tooltip: 'Oszlop hozzáadása',
            onPressed: _addColumn,
            icon: const Icon(Icons.view_column_outlined),
          ),
          IconButton(
            key: const ValueKey('note-table-appbar-add-row'),
            tooltip: 'Sor hozzáadása',
            onPressed: _addRow,
            icon: const Icon(Icons.table_rows_outlined),
          ),
        ],
        saveAction: widget.onChanged == null
            ? TextButton.icon(
                key: const ValueKey('note-table-save'),
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Mentés'),
              )
            : null,
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
            child: _TableGrid(
              columnCount: columnCount,
              rowCount: _rows.length,
              selection: _selection,
              cellControllerFor: _controllerFor,
              highlightColorForCell: _highlightColorForCell,
              onCellChanged: _updateCell,
              onSelect: _select,
              railForSelection: _railForSelection,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableGrid extends StatelessWidget {
  const _TableGrid({
    required this.columnCount,
    required this.rowCount,
    required this.selection,
    required this.cellControllerFor,
    required this.highlightColorForCell,
    required this.onCellChanged,
    required this.onSelect,
    required this.railForSelection,
  });

  static const double _rowHeadWidth = 64;
  static const double _cellWidth = 150;
  static const double _cellHeight = 52;

  final int columnCount;
  final int rowCount;
  final _TableSelection? selection;
  final TextEditingController Function(int row, int column) cellControllerFor;
  final Color? Function(int row, int column) highlightColorForCell;
  final void Function(int row, int column, String value) onCellChanged;
  final ValueChanged<_TableSelection> onSelect;
  final Widget Function(_TableSelection selection) railForSelection;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            for (var row = 0; row < rowCount; row += 1)
              _buildRow(context, row),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final selectedColumn = selection;
    final showColumnRail = selectedColumn?.kind == _TableSelectionKind.column;
    final tableWidth = _rowHeadWidth + columnCount * _cellWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _HeadCell(
              key: const ValueKey('note-table-corner-head'),
              width: _rowHeadWidth,
              label: '',
              icon: Icons.grid_on_outlined,
              selected: false,
              onTap: null,
            ),
            for (var column = 0; column < columnCount; column += 1)
              _ColumnHeadSlot(
                column: column,
                width: _cellWidth,
                selected: selection?.isColumn(column) == true,
                onSelect: onSelect,
              ),
          ],
        ),
        if (showColumnRail)
          SizedBox(
            key: ValueKey('note-table-column-head-expansion-${selectedColumn!.columnIndex}'),
            width: tableWidth,
            child: railForSelection(selectedColumn),
          ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int row) {
    final selectedRow = selection;
    final showRowRail = selectedRow?.kind == _TableSelectionKind.row && selectedRow?.rowIndex == row;
    final showCellRail = selectedRow?.kind == _TableSelectionKind.cell && selectedRow?.rowIndex == row;
    final tableWidth = _rowHeadWidth + columnCount * _cellWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _RowHeadSlot(
              row: row,
              width: _rowHeadWidth,
              selected: selection?.isRow(row) == true,
              onSelect: onSelect,
            ),
            for (var column = 0; column < columnCount; column += 1)
              _CellSlot(
                row: row,
                column: column,
                width: _cellWidth,
                height: _cellHeight,
                controller: cellControllerFor(row, column),
                selected: selection?.isCell(row, column) == true,
                highlightColor: highlightColorForCell(row, column),
                onTap: () => onSelect(_TableSelection.cell(row, column)),
                onChanged: (value) => onCellChanged(row, column, value),
              ),
          ],
        ),
        if (showRowRail)
          SizedBox(
            key: ValueKey('note-table-row-head-expansion-$row'),
            width: tableWidth,
            child: railForSelection(selectedRow!),
          )
        else if (showCellRail)
          SizedBox(
            key: ValueKey('note-table-cell-expansion-$row-${selectedRow!.columnIndex}'),
            width: tableWidth,
            child: railForSelection(selectedRow),
          ),
      ],
    );
  }
}

class _ColumnHeadSlot extends StatelessWidget {
  const _ColumnHeadSlot({
    required this.column,
    required this.width,
    required this.selected,
    required this.onSelect,
  });

  final int column;
  final double width;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _HeadCell(
        key: ValueKey('note-table-column-head-$column'),
        width: width,
        label: 'Oszlop ${column + 1}',
        selected: selected,
        onTap: () => onSelect(_TableSelection.column(column)),
      ),
    );
  }
}

class _RowHeadSlot extends StatelessWidget {
  const _RowHeadSlot({
    required this.row,
    required this.width,
    required this.selected,
    required this.onSelect,
  });

  final int row;
  final double width;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _HeadCell(
        key: ValueKey('note-table-row-head-$row'),
        width: width,
        label: '${row + 1}',
        icon: Icons.table_rows_outlined,
        selected: selected,
        onTap: () => onSelect(_TableSelection.row(row)),
      ),
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.row,
    required this.column,
    required this.width,
    required this.height,
    required this.controller,
    required this.selected,
    required this.highlightColor,
    required this.onTap,
    required this.onChanged,
  });

  final int row;
  final int column;
  final double width;
  final double height;
  final TextEditingController controller;
  final bool selected;
  final Color? highlightColor;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: _CellField(
        row: row,
        column: column,
        width: width,
        height: height,
        controller: controller,
        selected: selected,
        highlightColor: highlightColor,
        onTap: onTap,
        onChanged: onChanged,
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  const _HeadCell({
    super.key,
    required this.width,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final double width;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          border: Border.all(color: selected ? colorScheme.primary : const Color(0xFFE5E7EB)),
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
      ),
    );
  }
}

class _CellField extends StatelessWidget {
  const _CellField({
    required this.row,
    required this.column,
    required this.width,
    required this.height,
    required this.controller,
    required this.selected,
    required this.highlightColor,
    required this.onTap,
    required this.onChanged,
  });

  final int row;
  final int column;
  final double width;
  final double height;
  final TextEditingController controller;
  final bool selected;
  final Color? highlightColor;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  key: ValueKey('note-table-selected-cell-$row-$column'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF2563EB),
                      width: 2,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: KeyedSubtree(
                key: highlightColor == null
                    ? null
                    : ValueKey('note-table-cell-highlight-$row-$column'),
                child: TextFormField(
                key: ValueKey('note-table-cell-$row-$column'),
                controller: controller,
                decoration: const InputDecoration(border: InputBorder.none),
                style: TextStyle(backgroundColor: highlightColor),
                onTap: onTap,
                onChanged: onChanged,
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _TableSelectionKind { row, column, cell }

class _TableSelection {
  const _TableSelection._(this.kind, {this.rowIndex, this.columnIndex});

  factory _TableSelection.row(int rowIndex) {
    return _TableSelection._(_TableSelectionKind.row, rowIndex: rowIndex);
  }

  factory _TableSelection.column(int columnIndex) {
    return _TableSelection._(_TableSelectionKind.column, columnIndex: columnIndex);
  }

  factory _TableSelection.cell(int rowIndex, int columnIndex) {
    return _TableSelection._(
      _TableSelectionKind.cell,
      rowIndex: rowIndex,
      columnIndex: columnIndex,
    );
  }

  final _TableSelectionKind kind;
  final int? rowIndex;
  final int? columnIndex;

  bool isRow(int row) {
    return kind == _TableSelectionKind.row && rowIndex == row;
  }

  bool isColumn(int column) {
    return kind == _TableSelectionKind.column && columnIndex == column;
  }

  bool isCell(int row, int column) {
    return kind == _TableSelectionKind.cell &&
        rowIndex == row &&
        columnIndex == column;
  }

  NoteTagTarget toTagTarget() {
    return switch (kind) {
      _TableSelectionKind.row => NoteTagTarget(
          kind: NoteTagTargetKind.tableRow,
          rowIndex: rowIndex,
        ),
      _TableSelectionKind.column => NoteTagTarget(
          kind: NoteTagTargetKind.tableColumn,
          columnIndex: columnIndex,
        ),
      _TableSelectionKind.cell => NoteTagTarget(
          kind: NoteTagTargetKind.tableCell,
          rowIndex: rowIndex,
          columnIndex: columnIndex,
        ),
    };
  }
}

void unawaited(Future<void> future) {}
