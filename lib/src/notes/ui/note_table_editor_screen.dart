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
  late List<double> _columnWidths;
  late List<double> _rowHeights;
  late final TextEditingController _titleController;
  final Map<String, TextEditingController> _cellControllers = <String, TextEditingController>{};
  _TableSelection? _selection;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;
  bool _layoutDirty = false;

  static const double _defaultColumnWidth = 150;
  static const double _defaultRowHeight = 52;
  static const double _minimumColumnWidth = 92;
  static const double _maximumColumnWidth = 360;
  static const double _minimumRowHeight = 52;
  static const double _maximumRowHeight = 260;

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
    _columnWidths = [...widget.block.tableColumnWidths];
    _rowHeights = [...widget.block.tableRowHeights];
    _normalizeLayout();
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

  void _normalizeLayout() {
    final width = _columnCount;
    while (_columnWidths.length < width) {
      _columnWidths.add(_defaultColumnWidth);
    }
    if (_columnWidths.length > width) {
      _columnWidths = _columnWidths.take(width).toList(growable: true);
    }
    for (var i = 0; i < _columnWidths.length; i += 1) {
      _columnWidths[i] = _columnWidths[i].clamp(
        _minimumColumnWidth,
        _maximumColumnWidth,
      ).toDouble();
    }

    while (_rowHeights.length < _rows.length) {
      _rowHeights.add(_defaultRowHeight);
    }
    if (_rowHeights.length > _rows.length) {
      _rowHeights = _rowHeights.take(_rows.length).toList(growable: true);
    }
    for (var i = 0; i < _rowHeights.length; i += 1) {
      _rowHeights[i] = _rowHeights[i].clamp(
        _minimumRowHeight,
        _maximumRowHeight,
      ).toDouble();
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
    _normalizeLayout();
    return _block.copyWith(
      rows: [
        for (final row in _rows)
          row.map((cell) => cell.trim()).toList(growable: false),
      ],
      tableColumnWidths: _hasCustomColumnWidths ? [..._columnWidths] : const [],
      tableRowHeights: _hasCustomRowHeights ? [..._rowHeights] : const [],
      clearIndex: true,
    );
  }

  bool get _hasCustomColumnWidths {
    return _columnWidths.any((width) => (width - _defaultColumnWidth).abs() > 0.1);
  }

  bool get _hasCustomRowHeights {
    return _rowHeights.any((height) => (height - _defaultRowHeight).abs() > 0.1);
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
    _insertRow(_rows.length);
  }

  void _addColumn() {
    _insertColumn(_columnCount);
  }

  void _insertRow(int index) {
    setState(() {
      _normalizeRows();
      _normalizeLayout();
      final target = index.clamp(0, _rows.length).toInt();
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (tagTarget) => _remapTargetForRowInsert(tagTarget, target),
        ),
        clearIndex: true,
      );
      _rows.insert(target, List.filled(_columnCount, ''));
      _rowHeights.insert(target, _defaultRowHeight);
      _selection = null;
      _resetCellControllers();
    });
    _emitChange();
  }

  void _insertColumn(int index) {
    setState(() {
      _normalizeRows();
      _normalizeLayout();
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
      _columnWidths.insert(target, _defaultColumnWidth);
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
      _normalizeLayout();
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForRowDelete(target, index),
        ),
        clearIndex: true,
      );
      _rows.removeAt(index);
      _rowHeights.removeAt(index);
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
      _normalizeLayout();
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForColumnDelete(target, index),
        ),
        clearIndex: true,
      );
      for (final row in _rows) {
        row.removeAt(index);
      }
      _columnWidths.removeAt(index);
      _selection = null;
      _resetCellControllers();
    });
    _emitChange();
  }

  void _moveRow(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _rows.length ||
        toIndex >= _rows.length) {
      return;
    }
    setState(() {
      _normalizeRows();
      _normalizeLayout();
      final row = _rows.removeAt(fromIndex);
      _rows.insert(toIndex, row);
      final height = _rowHeights.removeAt(fromIndex);
      _rowHeights.insert(toIndex, height);
      _selection = _remapSelectionForRowMove(_selection, fromIndex, toIndex);
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForRowMove(target, fromIndex, toIndex),
        ),
        clearIndex: true,
      );
      _resetCellControllers();
    });
    _emitChange();
  }

  void _moveColumn(int fromIndex, int toIndex) {
    _normalizeRows();
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _columnCount ||
        toIndex >= _columnCount) {
      return;
    }
    setState(() {
      _normalizeRows();
      _normalizeLayout();
      for (final row in _rows) {
        final cell = row.removeAt(fromIndex);
        row.insert(toIndex, cell);
      }
      final width = _columnWidths.removeAt(fromIndex);
      _columnWidths.insert(toIndex, width);
      _selection = _remapSelectionForColumnMove(_selection, fromIndex, toIndex);
      _block = _block.copyWith(
        scopedTags: _remapScopedTags(
          (target) => _remapTargetForColumnMove(target, fromIndex, toIndex),
        ),
        clearIndex: true,
      );
      _resetCellControllers();
    });
    _emitChange();
  }

  void _resizeColumn(int column, double delta) {
    if (column < 0 || column >= _columnCount || delta == 0) {
      return;
    }
    setState(() {
      _normalizeLayout();
      final nextWidth = (_columnWidths[column] + delta).clamp(
        _minimumColumnWidth,
        _maximumColumnWidth,
      ).toDouble();
      if ((nextWidth - _columnWidths[column]).abs() > 0.1) {
        _columnWidths[column] = nextWidth;
        _layoutDirty = true;
      }
    });
  }

  void _resizeRow(int row, double delta) {
    if (row < 0 || row >= _rows.length || delta == 0) {
      return;
    }
    setState(() {
      _normalizeLayout();
      final nextHeight = (_rowHeights[row] + delta).clamp(
        _minimumRowHeight,
        _maximumRowHeight,
      ).toDouble();
      if ((nextHeight - _rowHeights[row]).abs() > 0.1) {
        _rowHeights[row] = nextHeight;
        _layoutDirty = true;
      }
    });
  }

  void _commitLayoutChange() {
    if (!_layoutDirty) {
      return;
    }
    _layoutDirty = false;
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

  void _deleteChunkTag(NoteKnowledgeTag tag) {
    setState(() {
      _block = _block.copyWith(
        tags: _block.tags
            .where((current) => current.metadataText != tag.metadataText)
            .toList(growable: false),
        clearIndex: true,
      );
    });
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
    final affectedTargets = _affectedTargetsForSelection(selection);
    final targetsToWrite = _targetsToWriteForSelection(selection);
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!affectedTargets.any((target) => _sameTarget(assignment.target, target)))
              assignment,
          if (tags.isNotEmpty)
            for (final target in targetsToWrite)
              NoteScopedTagAssignment(
                id: 'table-tag-${DateTime.now().microsecondsSinceEpoch}-${target.rowIndex ?? 'x'}-${target.columnIndex ?? 'x'}',
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
    final affectedTargets = _affectedTargetsForSelection(selection);
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!affectedTargets.any((target) => _sameTarget(assignment.target, target)))
              assignment,
        ],
        clearIndex: true,
      );
    });
    widget.onChanged?.call(_block);
  }

  void _deleteSingleSelectedTag(NoteKnowledgeTag tag) {
    final selection = _selection;
    if (selection == null) {
      return;
    }
    final affectedTargets = _affectedTargetsForSelection(selection);
    setState(() {
      _block = _block.copyWith(
        scopedTags: [
          for (final assignment in _block.scopedTags)
            if (!affectedTargets.any((target) => _sameTarget(assignment.target, target)))
              assignment
            else
              ..._assignmentWithoutTag(assignment, tag),
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
    final tags = <NoteKnowledgeTag>[];
    void addAll(List<NoteKnowledgeTag> next) {
      for (final tag in next) {
        if (!tags.any((current) => current.metadataText == tag.metadataText)) {
          tags.add(tag);
        }
      }
    }
    final affectedTargets = _affectedTargetsForSelection(selection);
    for (final assignment in _block.scopedTags) {
      if (affectedTargets.any((target) => _sameTarget(assignment.target, target))) {
        addAll(assignment.tags);
      }
    }
    return tags;
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

  void _focusTaggedSelection(int direction) {
    final selections = <_TableSelection>[];
    for (final assignment in _block.scopedTags) {
      final target = assignment.target;
      switch (target.kind) {
        case NoteTagTargetKind.tableCell:
          if (target.rowIndex != null && target.columnIndex != null) {
            selections.add(_TableSelection.cell(target.rowIndex!, target.columnIndex!));
          }
          break;
        case NoteTagTargetKind.tableRow:
          if (target.rowIndex != null) {
            selections.add(_TableSelection.row(target.rowIndex!));
          }
          break;
        case NoteTagTargetKind.tableColumn:
          if (target.columnIndex != null) {
            selections.add(_TableSelection.column(target.columnIndex!));
          }
          break;
        default:
          break;
      }
    }
    if (selections.isEmpty) {
      return;
    }
    selections.sort((a, b) {
      final rowCompare = (a.rowIndex ?? -1).compareTo(b.rowIndex ?? -1);
      if (rowCompare != 0) {
        return rowCompare;
      }
      return (a.columnIndex ?? -1).compareTo(b.columnIndex ?? -1);
    });
    final currentIndex = selections.indexWhere((candidate) => _sameSelection(candidate, _selection));
    final nextIndex = direction >= 0
        ? (currentIndex < 0 ? 0 : (currentIndex + 1) % selections.length)
        : (currentIndex <= 0 ? selections.length - 1 : currentIndex - 1);
    setState(() => _selection = selections[nextIndex]);
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
      bottomRowExpanded: _railBottomExpanded,
      onToggleBottomRow: () => setState(
        () => _railBottomExpanded = !_railBottomExpanded,
      ),
      onDeleteTag: _deleteSingleSelectedTag,
      roundedCard: _railRoundedCard,
      transparentBackground: _railTransparentBackground,
      showBorder: _railBorderVisible,
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
    if (selection.kind == _TableSelectionKind.row ||
        selection.kind == _TableSelectionKind.cell) {
      final row = selection.rowIndex!;
      actions
        ..add(
          IconButton(
            key: ValueKey('note-table-rail-insert-row-below-$row'),
            tooltip: 'Sor beszúrása alá',
            onPressed: () => _insertRow(row + 1),
            constraints: compactConstraints,
            padding: compactPadding,
            icon: const Icon(Icons.add, size: 18),
          ),
        )
        ..add(
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
    actions.addAll([
      IconButton(
        key: ValueKey('${_tagRailKey(selection)}-clear-tags'),
        tooltip: 'Összes tag törlése',
        onPressed: _hasTags(selection) ? _deleteSelectedTag : null,
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.delete_outline, size: 18),
      ),
      IconButton(
        key: ValueKey('${_tagRailKey(selection)}-prev'),
        tooltip: 'Előző tag',
        onPressed: _block.scopedTags.isEmpty ? null : () => _focusTaggedSelection(-1),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.chevron_left, size: 18),
      ),
      IconButton(
        key: ValueKey('${_tagRailKey(selection)}-next'),
        tooltip: 'Következő tag',
        onPressed: _block.scopedTags.isEmpty ? null : () => _focusTaggedSelection(1),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.chevron_right, size: 18),
      ),
      IconButton(
        key: const ValueKey('note-table-rail-toggle-rounded'),
        tooltip: _railRoundedCard ? 'Vonalas rail' : 'Cellaszerű rail',
        onPressed: () => setState(() => _railRoundedCard = !_railRoundedCard),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.crop_square_outlined, size: 18),
      ),
      IconButton(
        key: const ValueKey('note-table-rail-toggle-transparent'),
        tooltip: _railTransparentBackground ? 'Fehér rail háttér' : 'Átlátszó rail háttér',
        onPressed: () => setState(
          () => _railTransparentBackground = !_railTransparentBackground,
        ),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.opacity, size: 18),
      ),
      IconButton(
        key: const ValueKey('note-table-rail-toggle-border'),
        tooltip: _railBorderVisible ? 'Rail border nélkül' : 'Rail borderrel',
        onPressed: () => setState(() => _railBorderVisible = !_railBorderVisible),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.border_outer, size: 18),
      ),
    ]);
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

  NoteTagTarget? _remapTargetForRowInsert(
    NoteTagTarget target,
    int insertIndex,
  ) {
    final rowIndex = target.rowIndex;
    if (rowIndex == null || rowIndex < insertIndex) {
      return target;
    }
    if (target.kind == NoteTagTargetKind.tableRow ||
        target.kind == NoteTagTargetKind.tableCell) {
      return target.copyWith(rowIndex: rowIndex + 1);
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

  NoteTagTarget? _remapTargetForRowMove(
    NoteTagTarget target,
    int fromIndex,
    int toIndex,
  ) {
    if (target.kind != NoteTagTargetKind.tableRow &&
        target.kind != NoteTagTargetKind.tableCell) {
      return target;
    }
    final rowIndex = target.rowIndex;
    final nextIndex = _remapMovedIndex(rowIndex, fromIndex, toIndex);
    return nextIndex == rowIndex ? target : target.copyWith(rowIndex: nextIndex);
  }

  NoteTagTarget? _remapTargetForColumnMove(
    NoteTagTarget target,
    int fromIndex,
    int toIndex,
  ) {
    if (target.kind != NoteTagTargetKind.tableColumn &&
        target.kind != NoteTagTargetKind.tableCell) {
      return target;
    }
    final columnIndex = target.columnIndex;
    final nextIndex = _remapMovedIndex(columnIndex, fromIndex, toIndex);
    return nextIndex == columnIndex
        ? target
        : target.copyWith(columnIndex: nextIndex);
  }

  int? _remapMovedIndex(int? index, int fromIndex, int toIndex) {
    if (index == null || fromIndex == toIndex) {
      return index;
    }
    if (index == fromIndex) {
      return toIndex;
    }
    if (fromIndex < toIndex && index > fromIndex && index <= toIndex) {
      return index - 1;
    }
    if (fromIndex > toIndex && index >= toIndex && index < fromIndex) {
      return index + 1;
    }
    return index;
  }

  _TableSelection? _remapSelectionForRowMove(
    _TableSelection? selection,
    int fromIndex,
    int toIndex,
  ) {
    if (selection == null || selection.rowIndex == null) {
      return selection;
    }
    final nextRow = _remapMovedIndex(selection.rowIndex, fromIndex, toIndex);
    if (nextRow == null || nextRow == selection.rowIndex) {
      return selection;
    }
    return switch (selection.kind) {
      _TableSelectionKind.row => _TableSelection.row(nextRow),
      _TableSelectionKind.cell => _TableSelection.cell(nextRow, selection.columnIndex!),
      _TableSelectionKind.column => selection,
    };
  }

  _TableSelection? _remapSelectionForColumnMove(
    _TableSelection? selection,
    int fromIndex,
    int toIndex,
  ) {
    if (selection == null || selection.columnIndex == null) {
      return selection;
    }
    final nextColumn = _remapMovedIndex(selection.columnIndex, fromIndex, toIndex);
    if (nextColumn == null || nextColumn == selection.columnIndex) {
      return selection;
    }
    return switch (selection.kind) {
      _TableSelectionKind.column => _TableSelection.column(nextColumn),
      _TableSelectionKind.cell => _TableSelection.cell(selection.rowIndex!, nextColumn),
      _TableSelectionKind.row => selection,
    };
  }

  bool _sameTarget(NoteTagTarget left, NoteTagTarget right) {
    return left.kind == right.kind &&
        left.rowIndex == right.rowIndex &&
        left.columnIndex == right.columnIndex &&
        left.elementId == right.elementId &&
        left.listItemId == right.listItemId &&
        left.rangeId == right.rangeId;
  }

  bool _sameSelection(_TableSelection? left, _TableSelection? right) {
    return left?.kind == right?.kind &&
        left?.rowIndex == right?.rowIndex &&
        left?.columnIndex == right?.columnIndex;
  }

  List<NoteScopedTagAssignment> _assignmentWithoutTag(
    NoteScopedTagAssignment assignment,
    NoteKnowledgeTag tag,
  ) {
    final tags = assignment.tags
        .where((current) => current.metadataText != tag.metadataText)
        .toList(growable: false);
    if (tags.isEmpty) {
      return const [];
    }
    return [assignment.copyWith(tags: tags)];
  }

  List<NoteTagTarget> _affectedTargetsForSelection(_TableSelection selection) {
    final targets = <NoteTagTarget>[selection.toTagTarget()];
    switch (selection.kind) {
      case _TableSelectionKind.row:
        final row = selection.rowIndex!;
        for (var column = 0; column < _columnCount; column += 1) {
          targets.add(NoteTagTarget(
            kind: NoteTagTargetKind.tableCell,
            rowIndex: row,
            columnIndex: column,
          ));
        }
        break;
      case _TableSelectionKind.column:
        final column = selection.columnIndex!;
        for (var row = 0; row < _rows.length; row += 1) {
          targets.add(NoteTagTarget(
            kind: NoteTagTargetKind.tableCell,
            rowIndex: row,
            columnIndex: column,
          ));
        }
        break;
      case _TableSelectionKind.cell:
        break;
    }
    return targets;
  }

  List<NoteTagTarget> _targetsToWriteForSelection(_TableSelection selection) {
    switch (selection.kind) {
      case _TableSelectionKind.cell:
        return [selection.toTagTarget()];
      case _TableSelectionKind.row:
      case _TableSelectionKind.column:
        return _affectedTargetsForSelection(selection)
            .where((target) => target.kind == NoteTagTargetKind.tableCell)
            .toList(growable: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _normalizeRows();
    _normalizeLayout();
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
                child: NoteTagPills(
                  tags: _block.tags,
                  onDeleted: _deleteChunkTag,
                ),
              ),
            ),
          Expanded(
            child: _TableGrid(
              columnCount: columnCount,
              rowCount: _rows.length,
              columnWidths: _columnWidths,
              rowHeights: _rowHeights,
              selection: _selection,
              cellControllerFor: _controllerFor,
              highlightColorForCell: _highlightColorForCell,
              onCellChanged: _updateCell,
              onSelect: _select,
              onMoveRow: _moveRow,
              onMoveColumn: _moveColumn,
              onResizeColumn: _resizeColumn,
              onResizeRow: _resizeRow,
              onCommitLayoutChange: _commitLayoutChange,
              railForSelection: _railForSelection,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableGrid extends StatefulWidget {
  const _TableGrid({
    required this.columnCount,
    required this.rowCount,
    required this.columnWidths,
    required this.rowHeights,
    required this.selection,
    required this.cellControllerFor,
    required this.highlightColorForCell,
    required this.onCellChanged,
    required this.onSelect,
    required this.onMoveRow,
    required this.onMoveColumn,
    required this.onResizeColumn,
    required this.onResizeRow,
    required this.onCommitLayoutChange,
    required this.railForSelection,
  });

  static const double _rowHeadWidth = 64;
  static const double _cellHeight = 52;

  final int columnCount;
  final int rowCount;
  final List<double> columnWidths;
  final List<double> rowHeights;
  final _TableSelection? selection;
  final TextEditingController Function(int row, int column) cellControllerFor;
  final Color? Function(int row, int column) highlightColorForCell;
  final void Function(int row, int column, String value) onCellChanged;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveRow;
  final void Function(int fromIndex, int toIndex) onMoveColumn;
  final void Function(int column, double delta) onResizeColumn;
  final void Function(int row, double delta) onResizeRow;
  final VoidCallback onCommitLayoutChange;
  final Widget Function(_TableSelection selection) railForSelection;

  @override
  State<_TableGrid> createState() => _TableGridState();
}

class _TableGridState extends State<_TableGrid> {
  late final ScrollController _horizontalController;
  final Map<int, Offset> _activePointerPositions = <int, Offset>{};
  double _viewportWidth = 0;
  double _scale = 1;
  double _pinchStartScale = 1;
  double? _pinchStartDistance;
  bool _railPointerActive = false;

  static const double _minimumScale = 0.55;
  static const double _maximumScale = 1;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        final tableWidth = _tableWidth;
        return Listener(
          key: const ValueKey('note-table-zoom-gesture'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerEnd,
          onPointerCancel: _handlePointerEnd,
          child: StretchingOverscrollIndicator(
            key: const ValueKey('note-table-horizontal-rubber-band'),
            axisDirection: AxisDirection.right,
            child: SingleChildScrollView(
              controller: _horizontalController,
              physics: _railPointerActive
                  ? const NeverScrollableScrollPhysics()
                  : const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Transform.scale(
                  key: const ValueKey('note-table-zoom-transform'),
                  alignment: Alignment.topLeft,
                  scale: _scale,
                  child: SizedBox(
                    key: const ValueKey('note-table-zoomable-content'),
                    width: tableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        for (var row = 0; row < widget.rowCount; row += 1)
                          _buildRow(context, row),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointerPositions[event.pointer] = event.localPosition;
    if (_activePointerPositions.length == 2) {
      _pinchStartScale = _scale;
      _pinchStartDistance = _currentPointerDistance;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointerPositions.containsKey(event.pointer)) {
      return;
    }
    _activePointerPositions[event.pointer] = event.localPosition;
    if (_activePointerPositions.length != 2) {
      return;
    }
    final startDistance = _pinchStartDistance;
    final currentDistance = _currentPointerDistance;
    if (startDistance == null ||
        currentDistance == null ||
        startDistance <= 0 ||
        currentDistance <= 0) {
      _pinchStartScale = _scale;
      _pinchStartDistance = currentDistance;
      return;
    }
    final nextScale = (_pinchStartScale * currentDistance / startDistance)
        .clamp(_minimumScale, _maximumScale)
        .toDouble();
    if ((nextScale - _scale).abs() < 0.001) {
      return;
    }
    setState(() => _scale = nextScale);
  }

  void _handlePointerEnd(PointerEvent event) {
    _activePointerPositions.remove(event.pointer);
    if (_activePointerPositions.length == 2) {
      _pinchStartScale = _scale;
      _pinchStartDistance = _currentPointerDistance;
    } else {
      _pinchStartDistance = null;
    }
  }

  double? get _currentPointerDistance {
    if (_activePointerPositions.length < 2) {
      return null;
    }
    final positions = _activePointerPositions.values.take(2).toList(growable: false);
    return (positions.first - positions.last).distance;
  }

  void _setRailPointerActive(bool active) {
    if (_railPointerActive == active) {
      return;
    }
    setState(() => _railPointerActive = active);
  }

  double get _tableWidth {
    return _TableGrid._rowHeadWidth +
        widget.columnWidths.fold<double>(0, (total, width) => total + width);
  }

  double _columnWidth(int column) {
    if (column < 0 || column >= widget.columnWidths.length) {
      return _NoteTableEditorScreenState._defaultColumnWidth;
    }
    return widget.columnWidths[column];
  }

  double _rowHeight(int row) {
    if (row < 0 || row >= widget.rowHeights.length) {
      return _TableGrid._cellHeight;
    }
    return widget.rowHeights[row];
  }

  Widget _stickyRail({
    required Key key,
    required double width,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _horizontalController,
      builder: (context, _) {
        final viewportWidth = _viewportWidth <= 0 ? width : _viewportWidth;
        final scaledViewportWidth = (viewportWidth / _scale).clamp(0, width).toDouble();
        final maxLeft = (width - scaledViewportWidth).clamp(0, width).toDouble();
        final left = _horizontalController.hasClients
            ? _horizontalController.offset.clamp(0, maxLeft).toDouble()
            : 0.0;
        return SizedBox(
          key: key,
          width: width,
          child: Padding(
            padding: EdgeInsets.only(left: left),
            child: SizedBox(
              width: scaledViewportWidth,
              child: Listener(
                key: const ValueKey('note-table-rail-pointer-shield'),
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => _setRailPointerActive(true),
                onPointerUp: (_) => _setRailPointerActive(false),
                onPointerCancel: (_) => _setRailPointerActive(false),
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: width,
                    maxWidth: width,
                    child: SizedBox(
                      width: width,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final selectedColumn = widget.selection;
    final showColumnRail = selectedColumn?.kind == _TableSelectionKind.column;
    final tableWidth = _tableWidth;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeadCell(
                key: const ValueKey('note-table-corner-head'),
                width: _TableGrid._rowHeadWidth,
                label: '',
                icon: Icons.grid_on_outlined,
                selected: false,
                onTap: null,
              ),
              for (var column = 0; column < widget.columnCount; column += 1)
                _ColumnHeadSlot(
                  column: column,
                  width: _columnWidth(column),
                  selected: widget.selection?.isColumn(column) == true,
                  onSelect: widget.onSelect,
                  onMoveColumn: widget.onMoveColumn,
                  onResizeColumn: widget.onResizeColumn,
                  onCommitResize: widget.onCommitLayoutChange,
                ),
            ],
          ),
        ),
        if (showColumnRail)
          _stickyRail(
            key: ValueKey('note-table-column-head-expansion-${selectedColumn!.columnIndex}'),
            width: tableWidth,
            child: widget.railForSelection(selectedColumn),
          ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int row) {
    final selectedRow = widget.selection;
    final showRowRail = selectedRow?.kind == _TableSelectionKind.row && selectedRow?.rowIndex == row;
    final showCellRail = selectedRow?.kind == _TableSelectionKind.cell && selectedRow?.rowIndex == row;
    final tableWidth = _tableWidth;
    final rowHeight = _rowHeight(row);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RowHeadSlot(
                row: row,
                width: _TableGrid._rowHeadWidth,
                height: rowHeight,
                selected: widget.selection?.isRow(row) == true,
                onSelect: widget.onSelect,
                onMoveRow: widget.onMoveRow,
                onResizeRow: widget.onResizeRow,
                onCommitResize: widget.onCommitLayoutChange,
              ),
              for (var column = 0; column < widget.columnCount; column += 1)
                _CellSlot(
                  row: row,
                  column: column,
                  width: _columnWidth(column),
                  height: rowHeight,
                  controller: widget.cellControllerFor(row, column),
                  selected: widget.selection?.isCell(row, column) == true,
                  highlightColor: widget.highlightColorForCell(row, column),
                  onTap: () => widget.onSelect(_TableSelection.cell(row, column)),
                  onChanged: (value) => widget.onCellChanged(row, column, value),
                ),
            ],
          ),
        ),
        if (showRowRail)
          _stickyRail(
            key: ValueKey('note-table-row-head-expansion-$row'),
            width: tableWidth,
            child: widget.railForSelection(selectedRow!),
          )
        else if (showCellRail)
          _stickyRail(
            key: ValueKey('note-table-cell-expansion-$row-${selectedRow!.columnIndex}'),
            width: tableWidth,
            child: widget.railForSelection(selectedRow),
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
    required this.onMoveColumn,
    required this.onResizeColumn,
    required this.onCommitResize,
  });

  final int column;
  final double width;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveColumn;
  final void Function(int column, double delta) onResizeColumn;
  final VoidCallback onCommitResize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != column,
        onAcceptWithDetails: (details) => onMoveColumn(details.data, column),
        builder: (context, candidateData, rejectedData) {
          return LongPressDraggable<int>(
            data: column,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                height: _TableGrid._cellHeight,
                child: _HeadCell(
                  width: width,
                  label: 'Oszlop ${column + 1}',
                  selected: true,
                  onTap: null,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: _ColumnHeadContent(
                column: column,
                width: width,
                selected: selected,
                resizeEnabled: selected,
                onSelect: onSelect,
                onResizeColumn: onResizeColumn,
                onCommitResize: onCommitResize,
              ),
            ),
            child: _ColumnHeadContent(
              column: column,
              width: width,
              selected: selected || candidateData.isNotEmpty,
              resizeEnabled: selected,
              onSelect: onSelect,
              onResizeColumn: onResizeColumn,
              onCommitResize: onCommitResize,
            ),
          );
        },
      ),
    );
  }
}

class _ColumnHeadContent extends StatelessWidget {
  const _ColumnHeadContent({
    required this.column,
    required this.width,
    required this.selected,
    required this.resizeEnabled,
    required this.onSelect,
    required this.onResizeColumn,
    required this.onCommitResize,
  });

  final int column;
  final double width;
  final bool selected;
  final bool resizeEnabled;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int column, double delta) onResizeColumn;
  final VoidCallback onCommitResize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(width: width, height: _TableGrid._cellHeight),
        Positioned.fill(
          child: _HeadCell(
            key: ValueKey('note-table-column-head-$column'),
            width: width,
            label: 'Oszlop ${column + 1}',
            selected: selected,
            onTap: () => onSelect(_TableSelection.column(column)),
          ),
        ),
        if (resizeEnabled)
          Positioned(
            top: 4,
            right: 3,
            bottom: 4,
            width: 24,
            child: GestureDetector(
              key: ValueKey('note-table-column-resize-$column'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) => onResizeColumn(column, details.delta.dx),
              onHorizontalDragEnd: (_) => onCommitResize(),
              onHorizontalDragCancel: onCommitResize,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.drag_indicator,
                  key: ValueKey('note-table-column-resize-icon-$column'),
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RowHeadSlot extends StatelessWidget {
  const _RowHeadSlot({
    required this.row,
    required this.width,
    required this.height,
    required this.selected,
    required this.onSelect,
    required this.onMoveRow,
    required this.onResizeRow,
    required this.onCommitResize,
  });

  final int row;
  final double width;
  final double height;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveRow;
  final void Function(int row, double delta) onResizeRow;
  final VoidCallback onCommitResize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != row,
        onAcceptWithDetails: (details) => onMoveRow(details.data, row),
        builder: (context, candidateData, rejectedData) {
          return LongPressDraggable<int>(
            data: row,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                height: height,
                child: _HeadCell(
                  width: width,
                  label: '${row + 1}',
                  icon: Icons.table_rows_outlined,
                  selected: true,
                  onTap: null,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.25,
              child: _RowHeadContent(
                row: row,
                width: width,
                height: height,
                selected: selected,
                resizeEnabled: selected,
                onSelect: onSelect,
                onResizeRow: onResizeRow,
                onCommitResize: onCommitResize,
              ),
            ),
            child: _RowHeadContent(
              row: row,
              width: width,
              height: height,
              selected: selected || candidateData.isNotEmpty,
              resizeEnabled: selected,
              onSelect: onSelect,
              onResizeRow: onResizeRow,
              onCommitResize: onCommitResize,
            ),
          );
        },
      ),
    );
  }
}

class _RowHeadContent extends StatelessWidget {
  const _RowHeadContent({
    required this.row,
    required this.width,
    required this.height,
    required this.selected,
    required this.resizeEnabled,
    required this.onSelect,
    required this.onResizeRow,
    required this.onCommitResize,
  });

  final int row;
  final double width;
  final double height;
  final bool selected;
  final bool resizeEnabled;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int row, double delta) onResizeRow;
  final VoidCallback onCommitResize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(width: width, height: height),
        Positioned.fill(
          child: _HeadCell(
            key: ValueKey('note-table-row-head-$row'),
            width: width,
            label: '${row + 1}',
            icon: Icons.table_rows_outlined,
            selected: selected,
            onTap: () => onSelect(_TableSelection.row(row)),
          ),
        ),
        if (resizeEnabled)
          Positioned(
            left: 4,
            right: 4,
            bottom: 3,
            height: 24,
            child: GestureDetector(
              key: ValueKey('note-table-row-resize-$row'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) => onResizeRow(row, details.delta.dy),
              onVerticalDragEnd: (_) => onCommitResize(),
              onVerticalDragCancel: onCommitResize,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: Icon(
                    Icons.drag_indicator,
                    key: ValueKey('note-table-row-resize-icon-$row'),
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
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
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
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
        key: ValueKey('note-table-cell-container-$row-$column'),
        width: width,
        constraints: BoxConstraints(minHeight: height),
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
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
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
