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
  }

  void _updateCell(int row, int column, String value) {
    _rows[row][column] = value;
    _emitChange();
  }

  NoteBlock _currentBlock() {
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
      final width = _rows.isEmpty ? 2 : _rows.first.length;
      _rows.add(List.filled(width, ''));
    });
    _emitChange();
  }

  void _addColumn() {
    setState(() {
      if (_rows.isEmpty) {
        _rows.add(['']);
        return;
      }
      for (final row in _rows) {
        row.add('');
      }
    });
    _emitChange();
  }

  void _deleteRow(int index) {
    if (_rows.length == 1) {
      return;
    }
    setState(() => _rows.removeAt(index));
    _emitChange();
  }

  void _deleteColumn(int index) {
    if (_rows.isEmpty || _rows.first.length == 1) {
      return;
    }
    setState(() {
      for (final row in _rows) {
        row.removeAt(index);
      }
    });
    _emitChange();
  }

  void _save() {
    Navigator.of(context).pop(_currentBlock());
  }

  @override
  Widget build(BuildContext context) {
    final columnCount = _rows.isEmpty ? 0 : _rows.first.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Táblázat szerkesztő'),
        actions: [
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
                            initialValue: _rows[row][column],
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
