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

  Color _colorForSelection(_TableSelection selection) {
    final tags = _tagsForSelection(selection);
    if (tags.isEmpty) {
      return const Color(0xFF2563EB);
    }
    return Color(tags.first.resolvedColorValue);
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    for (var column = 0; column < columnCount; column += 1)
                      DataColumn(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              key: ValueKey('note-table-select-column-$column'),
                              onTap: () => setState(
                                () => _selection = _TableSelection.column(column),
                              ),
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Oszlop ${column + 1}'),
                                  ),
                                  if (_hasTags(_TableSelection.column(column)))
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      top: 0,
                                      child: _TableTopMarker(
                                        color: _colorForSelection(_TableSelection.column(column)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              key: ValueKey('note-table-insert-column-$column'),
                              tooltip: 'Oszlop beszúrása jobbra',
                              onPressed: () => _insertColumn(column + 1),
                              icon: const Icon(Icons.add, size: 16),
                            ),
                            IconButton(
                              key: ValueKey('note-table-delete-column-$column'),
                              tooltip: 'Oszlop törlése',
                              onPressed: () => _deleteColumn(column),
                              icon: const Icon(Icons.close, size: 16),
                            ),
                          ],
                        ),
                      ),
                    const DataColumn(label: Text('Sor')),
                  ],
                  rows: [
                    for (var row = 0; row < _rows.length; row += 1)
                      DataRow(
                        cells: [
                          for (var column = 0; column < columnCount; column += 1)
                            DataCell(
                              SizedBox(
                                width: 150,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (_selection?.isCell(row, column) == true)
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          key: ValueKey('note-table-selected-cell-$row-$column'),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF2563EB),
                                              width: 2,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    TextFormField(
                                      key: ValueKey('note-table-cell-$row-$column'),
                                      controller: _controllerFor(row, column),
                                      decoration: const InputDecoration(border: InputBorder.none),
                                      onChanged: (value) => _updateCell(row, column, value),
                                    ),
                                    Positioned(
                                      right: -6,
                                      top: -4,
                                      child: IconButton(
                                        key: ValueKey('note-table-select-cell-$row-$column'),
                                        tooltip: 'Cella kijelölése',
                                        visualDensity: VisualDensity.compact,
                                        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => setState(
                                          () => _selection = _TableSelection.cell(row, column),
                                        ),
                                        icon: const Icon(Icons.crop_square, size: 14),
                                      ),
                                    ),
                                    if (_hasTags(_TableSelection.cell(row, column)))
                                      Positioned(
                                        key: ValueKey('note-table-cell-tag-marker-$row-$column'),
                                        right: 2,
                                        bottom: 2,
                                        child: _TableCornerMarker(
                                          color: _colorForSelection(_TableSelection.cell(row, column)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  key: ValueKey('note-table-select-row-$row'),
                                  onTap: () => setState(
                                    () => _selection = _TableSelection.row(row),
                                  ),
                                  child: SizedBox(
                                    width: 24,
                                    height: 36,
                                    child: _hasTags(_TableSelection.row(row))
                                        ? _TableRowMarker(
                                            color: _colorForSelection(_TableSelection.row(row)),
                                          )
                                        : const Icon(Icons.table_rows_outlined, size: 16),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('note-table-delete-row-$row'),
                                  tooltip: 'Sor törlése',
                                  onPressed: () => _deleteRow(row),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_selection != null && _tagsForSelection(_selection!).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NoteSelectedTagTray(tags: _tagsForSelection(_selection!)),
              ),
            ),
        ],
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

class _TableCornerMarker extends StatelessWidget {
  const _TableCornerMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox.square(dimension: 8),
    );
  }
}

class _TableTopMarker extends StatelessWidget {
  const _TableTopMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: const SizedBox(height: 4),
    );
  }
}

class _TableRowMarker extends StatelessWidget {
  const _TableRowMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: const SizedBox(width: 4, height: 28),
      ),
    );
  }
}

void unawaited(Future<void> future) {}
