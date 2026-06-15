import 'package:flutter/material.dart';

import '../models/note_document.dart';

class NoteTableEditorScreen extends StatefulWidget {
  const NoteTableEditorScreen({
    super.key,
    required this.block,
    this.onChanged,
  });

  final NoteBlock block;
  final ValueChanged<NoteBlock>? onChanged;

  @override
  State<NoteTableEditorScreen> createState() => _NoteTableEditorScreenState();
}

class _NoteTableEditorScreenState extends State<NoteTableEditorScreen> {
  late List<List<String>> _rows;
  final Map<String, TextEditingController> _cellControllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
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
    return widget.block.copyWith(
      rows: [
        for (final row in _rows)
          row.map((cell) => cell.trim()).toList(growable: false),
      ],
      clearIndex: true,
    );
  }

  void _emitChange() {
    widget.onChanged?.call(_currentBlock());
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
      for (final row in _rows) {
        row.insert(target, '');
      }
      _resetCellControllers();
    });
    _emitChange();
  }

  void _deleteRow(int index) {
    if (_rows.length == 1) {
      return;
    }
    setState(() {
      _rows.removeAt(index);
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
      for (final row in _rows) {
        row.removeAt(index);
      }
      _resetCellControllers();
    });
    _emitChange();
  }

  void _save() {
    Navigator.of(context).pop(_currentBlock());
  }

  @override
  Widget build(BuildContext context) {
    _normalizeRows();
    final columnCount = _columnCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Táblázat szerkesztő'),
        actions: [
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
          if (widget.onChanged == null)
            TextButton.icon(
              key: const ValueKey('note-table-save'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Mentés'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              for (var column = 0; column < columnCount; column += 1)
                DataColumn(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Oszlop ${column + 1}'),
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
                          width: 140,
                          child: TextFormField(
                            key: ValueKey('note-table-cell-$row-$column'),
                            controller: _controllerFor(row, column),
                            decoration: const InputDecoration(border: InputBorder.none),
                            onChanged: (value) => _updateCell(row, column, value),
                          ),
                        ),
                      ),
                    DataCell(
                      IconButton(
                        tooltip: 'Sor törlése',
                        onPressed: () => _deleteRow(row),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            key: const ValueKey('note-table-add-column'),
            heroTag: 'note-table-add-column',
            onPressed: _addColumn,
            child: const Icon(Icons.view_column_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            key: const ValueKey('note-table-add-row'),
            heroTag: 'note-table-add-row',
            onPressed: _addRow,
            icon: const Icon(Icons.table_rows_outlined),
            label: const Text('Sor'),
          ),
        ],
      ),
    );
  }
}
