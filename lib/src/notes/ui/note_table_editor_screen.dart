import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../debug/debug_console.dart';
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
  final Map<String, TextEditingController> _cellControllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _cellFocusNodes = <String, FocusNode>{};
  _TableSelection? _selection;
  bool _railBottomExpanded = true;
  bool _railRoundedCard = false;
  bool _railTransparentBackground = false;
  bool _railBorderVisible = true;

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
    for (final focusNode in _cellFocusNodes.values) {
      focusNode.dispose();
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
      _columnWidths[i] = _columnWidths[i]
          .clamp(_minimumColumnWidth, _maximumColumnWidth)
          .toDouble();
    }

    while (_rowHeights.length < _rows.length) {
      _rowHeights.add(_defaultRowHeight);
    }
    if (_rowHeights.length > _rows.length) {
      _rowHeights = _rowHeights.take(_rows.length).toList(growable: true);
    }
    for (var i = 0; i < _rowHeights.length; i += 1) {
      _rowHeights[i] = _rowHeights[i]
          .clamp(_minimumRowHeight, _maximumRowHeight)
          .toDouble();
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
    final controller = _cellControllers.putIfAbsent(
      key,
      () => TextEditingController(text: value),
    );
    if (controller.text != value && !controller.selection.isValid) {
      controller.text = value;
    }
    return controller;
  }

  FocusNode _focusNodeFor(int row, int column) {
    final key = _cellControllerKey(row, column);
    return _cellFocusNodes.putIfAbsent(key, FocusNode.new);
  }

  void _resetCellControllers() {
    final staleControllers = _cellControllers.values.toList(growable: false);
    final staleFocusNodes = _cellFocusNodes.values.toList(growable: false);
    _cellControllers.clear();
    _cellFocusNodes.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in staleControllers) {
        controller.dispose();
      }
      for (final focusNode in staleFocusNodes) {
        focusNode.dispose();
      }
    });
  }

  void _updateCell(int row, int column, String value) {
    if (row < _rows.length &&
        column < _rows[row].length &&
        _rows[row][column] == value) {
      return;
    }
    setState(() {
      _ensureCell(row, column);
      _rows[row][column] = value;
    });
    _emitChange();
  }

  void _submitCell(int row, int column) {
    final targetRow = row + 1;
    if (targetRow >= _rows.length) {
      _insertRow(_rows.length);
    }
    setState(() {
      _ensureCell(targetRow, column);
      _selection = _TableSelection.cell(targetRow, column);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final focusNode = _focusNodeFor(targetRow, column);
      focusNode.requestFocus();
      final controller = _controllerFor(targetRow, column);
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    });
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
    return _columnWidths.any(
      (width) => (width - _defaultColumnWidth).abs() > 0.1,
    );
  }

  bool get _hasCustomRowHeights {
    return _rowHeights.any(
      (height) => (height - _defaultRowHeight).abs() > 0.1,
    );
  }

  void _emitChange() {
    _block = _currentBlock();
    widget.onChanged?.call(_block);
  }

  void _emitTitle(String value) {
    _titleController.text = value;
    setState(
      () => _block = _block.copyWith(title: value.trim(), clearIndex: true),
    );
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
    if (_rows.isEmpty ||
        _columnCount == 1 ||
        index < 0 ||
        index >= _columnCount) {
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

  void _commitColumnWidth(int column, double width) {
    if (column < 0 || column >= _columnCount) {
      return;
    }
    var changed = false;
    final nextWidth = width
        .clamp(_minimumColumnWidth, _maximumColumnWidth)
        .toDouble();
    setState(() {
      _normalizeLayout();
      if ((nextWidth - _columnWidths[column]).abs() > 0.1) {
        _columnWidths[column] = nextWidth;
        changed = true;
      }
    });
    DebugConsole.log(
      '[TableResize] column commit column=$column width=${nextWidth.toStringAsFixed(1)} '
      'changed=$changed',
    );
    if (changed) {
      _emitChange();
    }
  }

  void _commitRowHeight(int row, double height) {
    if (row < 0 || row >= _rows.length) {
      return;
    }
    var changed = false;
    final nextHeight = height
        .clamp(_minimumRowHeight, _maximumRowHeight)
        .toDouble();
    setState(() {
      _normalizeLayout();
      if ((nextHeight - _rowHeights[row]).abs() > 0.1) {
        _rowHeights[row] = nextHeight;
        changed = true;
      }
    });
    DebugConsole.log(
      '[TableResize] row commit row=$row height=${nextHeight.toStringAsFixed(1)} '
      'changed=$changed',
    );
    if (changed) {
      _emitChange();
    }
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
        const SnackBar(
          content: Text('Válassz ki sort, oszlopot vagy cellát a tageléshez'),
        ),
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
            if (!affectedTargets.any(
              (target) => _sameTarget(assignment.target, target),
            ))
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
            if (!affectedTargets.any(
              (target) => _sameTarget(assignment.target, target),
            ))
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
            if (!affectedTargets.any(
              (target) => _sameTarget(assignment.target, target),
            ))
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
      if (affectedTargets.any(
        (target) => _sameTarget(assignment.target, target),
      )) {
        addAll(assignment.tags);
      }
    }
    return tags;
  }

  bool _hasTags(_TableSelection selection) =>
      _tagsForSelection(selection).isNotEmpty;

  void _select(_TableSelection selection) {
    if (_sameSelection(_selection, selection)) {
      return;
    }
    setState(() => _selection = selection);
  }

  void _focusTaggedSelection(int direction) {
    final selections = <_TableSelection>[];
    for (final assignment in _block.scopedTags) {
      final target = assignment.target;
      switch (target.kind) {
        case NoteTagTargetKind.tableCell:
          if (target.rowIndex != null && target.columnIndex != null) {
            selections.add(
              _TableSelection.cell(target.rowIndex!, target.columnIndex!),
            );
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
    final currentIndex = selections.indexWhere(
      (candidate) => _sameSelection(candidate, _selection),
    );
    final nextIndex = direction >= 0
        ? (currentIndex < 0 ? 0 : (currentIndex + 1) % selections.length)
        : (currentIndex <= 0 ? selections.length - 1 : currentIndex - 1);
    setState(() => _selection = selections[nextIndex]);
  }

  Widget _railForSelection(
    _TableSelection selection, {
    double? stickyViewportLeft,
    double? stickyViewportWidth,
  }) {
    return NoteSelectionActionRail(
      tags: _tagsForSelection(selection),
      label: switch (selection.kind) {
        _TableSelectionKind.row => 'Sor ${selection.rowIndex! + 1}',
        _TableSelectionKind.column => 'Oszlop ${selection.columnIndex! + 1}',
        _TableSelectionKind.cell =>
          'Cella ${selection.rowIndex! + 1}:${selection.columnIndex! + 1}',
      },
      bottomRowExpanded: _railBottomExpanded,
      onToggleBottomRow: () =>
          setState(() => _railBottomExpanded = !_railBottomExpanded),
      onDeleteTag: _deleteSingleSelectedTag,
      roundedCard: _railRoundedCard,
      transparentBackground: _railTransparentBackground,
      showBorder: _railBorderVisible,
      stickyViewportLeft: stickyViewportLeft,
      stickyViewportWidth: stickyViewportWidth,
      debugLogPrefix: 'TableRail',
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
        onPressed: _block.scopedTags.isEmpty
            ? null
            : () => _focusTaggedSelection(-1),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.chevron_left, size: 18),
      ),
      IconButton(
        key: ValueKey('${_tagRailKey(selection)}-next'),
        tooltip: 'Következő tag',
        onPressed: _block.scopedTags.isEmpty
            ? null
            : () => _focusTaggedSelection(1),
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
        tooltip: _railTransparentBackground
            ? 'Fehér rail háttér'
            : 'Átlátszó rail háttér',
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
        onPressed: () =>
            setState(() => _railBorderVisible = !_railBorderVisible),
        constraints: compactConstraints,
        padding: compactPadding,
        icon: const Icon(Icons.border_outer, size: 18),
      ),
    ]);
    return actions;
  }

  String _tagRailKey(_TableSelection selection) {
    return switch (selection.kind) {
      _TableSelectionKind.row =>
        'note-table-rail-tag-row-${selection.rowIndex}',
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

  NoteTagTarget? _remapTargetForRowDelete(
    NoteTagTarget target,
    int deleteIndex,
  ) {
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
    return nextIndex == rowIndex
        ? target
        : target.copyWith(rowIndex: nextIndex);
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
      _TableSelectionKind.cell => _TableSelection.cell(
        nextRow,
        selection.columnIndex!,
      ),
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
    final nextColumn = _remapMovedIndex(
      selection.columnIndex,
      fromIndex,
      toIndex,
    );
    if (nextColumn == null || nextColumn == selection.columnIndex) {
      return selection;
    }
    return switch (selection.kind) {
      _TableSelectionKind.column => _TableSelection.column(nextColumn),
      _TableSelectionKind.cell => _TableSelection.cell(
        selection.rowIndex!,
        nextColumn,
      ),
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
          targets.add(
            NoteTagTarget(
              kind: NoteTagTargetKind.tableCell,
              rowIndex: row,
              columnIndex: column,
            ),
          );
        }
        break;
      case _TableSelectionKind.column:
        final column = selection.columnIndex!;
        for (var row = 0; row < _rows.length; row += 1) {
          targets.add(
            NoteTagTarget(
              kind: NoteTagTargetKind.tableCell,
              rowIndex: row,
              columnIndex: column,
            ),
          );
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
    final tableTagLookup = _TableTagLookup(_block.scopedTags);
    final intrinsicRows = _intrinsicRowsForLayout();
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
              intrinsicRows: intrinsicRows,
              selection: _selection,
              cellControllerFor: _controllerFor,
              cellFocusNodeFor: _focusNodeFor,
              tagsForCell: tableTagLookup.tagsForCell,
              onCellChanged: _updateCell,
              onCellSubmitted: _submitCell,
              onSelect: _select,
              onMoveRow: _moveRow,
              onMoveColumn: _moveColumn,
              onCommitColumnWidth: _commitColumnWidth,
              onCommitRowHeight: _commitRowHeight,
              railForSelection: _railForSelection,
            ),
          ),
        ],
      ),
    );
  }

  Set<int> _intrinsicRowsForLayout() {
    final rows = <int>{};
    for (var row = 0; row < _rows.length; row += 1) {
      final cells = _rows[row];
      for (var column = 0; column < _columnCount; column += 1) {
        final text = column < cells.length ? cells[column] : '';
        if (text.contains('\n')) {
          rows.add(row);
          break;
        }
        final availableWidth = (_columnWidths[column] - 20).clamp(
          1,
          double.infinity,
        );
        if (text.length * 7 > availableWidth) {
          rows.add(row);
          break;
        }
      }
    }
    return rows;
  }
}

class _TableTagLookup {
  _TableTagLookup(List<NoteScopedTagAssignment> assignments) {
    for (final assignment in assignments) {
      final target = assignment.target;
      switch (target.kind) {
        case NoteTagTargetKind.tableCell:
          final row = target.rowIndex;
          final column = target.columnIndex;
          if (row != null && column != null) {
            final tags = _cellTags.putIfAbsent(
              _cellKey(row, column),
              () => <NoteKnowledgeTag>[],
            );
            tags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableRow:
          final row = target.rowIndex;
          if (row != null) {
            final tags = _rowTags.putIfAbsent(row, () => <NoteKnowledgeTag>[]);
            tags.addAll(assignment.tags);
          }
          break;
        case NoteTagTargetKind.tableColumn:
          final column = target.columnIndex;
          if (column != null) {
            final tags = _columnTags.putIfAbsent(
              column,
              () => <NoteKnowledgeTag>[],
            );
            tags.addAll(assignment.tags);
          }
          break;
        default:
          break;
      }
    }
  }

  final Map<String, List<NoteKnowledgeTag>> _cellTags =
      <String, List<NoteKnowledgeTag>>{};
  final Map<int, List<NoteKnowledgeTag>> _rowTags =
      <int, List<NoteKnowledgeTag>>{};
  final Map<int, List<NoteKnowledgeTag>> _columnTags =
      <int, List<NoteKnowledgeTag>>{};

  static String _cellKey(int row, int column) => '$row:$column';

  List<NoteKnowledgeTag> tagsForCell(int row, int column) {
    final tags = <NoteKnowledgeTag>[];
    void addAll(List<NoteKnowledgeTag>? next) {
      if (next == null) {
        return;
      }
      for (final tag in next) {
        if (!tags.any((current) => current.metadataText == tag.metadataText)) {
          tags.add(tag);
        }
      }
    }

    addAll(_cellTags[_cellKey(row, column)]);
    addAll(_rowTags[row]);
    addAll(_columnTags[column]);
    return tags;
  }
}

TextStyle _taggedTableTextStyle(List<NoteKnowledgeTag> tags) {
  if (tags.isEmpty) {
    return const TextStyle();
  }
  return TextStyle(
    backgroundColor: Color(
      tags.first.resolvedColorValue,
    ).withValues(alpha: 0.16),
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

class _TableGrid extends StatefulWidget {
  const _TableGrid({
    required this.columnCount,
    required this.rowCount,
    required this.columnWidths,
    required this.rowHeights,
    required this.intrinsicRows,
    required this.selection,
    required this.cellControllerFor,
    required this.cellFocusNodeFor,
    required this.tagsForCell,
    required this.onCellChanged,
    required this.onCellSubmitted,
    required this.onSelect,
    required this.onMoveRow,
    required this.onMoveColumn,
    required this.onCommitColumnWidth,
    required this.onCommitRowHeight,
    required this.railForSelection,
  });

  static const double _rowHeadWidth = 64;
  static const double _cellHeight = 52;
  static const double _horizontalPadding = 12;

  final int columnCount;
  final int rowCount;
  final List<double> columnWidths;
  final List<double> rowHeights;
  final Set<int> intrinsicRows;
  final _TableSelection? selection;
  final TextEditingController Function(int row, int column) cellControllerFor;
  final FocusNode Function(int row, int column) cellFocusNodeFor;
  final List<NoteKnowledgeTag> Function(int row, int column) tagsForCell;
  final void Function(int row, int column, String value) onCellChanged;
  final void Function(int row, int column) onCellSubmitted;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveRow;
  final void Function(int fromIndex, int toIndex) onMoveColumn;
  final void Function(int column, double width) onCommitColumnWidth;
  final void Function(int row, double height) onCommitRowHeight;
  final Widget Function(
    _TableSelection selection, {
    double? stickyViewportLeft,
    double? stickyViewportWidth,
  })
  railForSelection;

  @override
  State<_TableGrid> createState() => _TableGridState();
}

class _TableGridState extends State<_TableGrid> {
  late final ScrollController _horizontalController;
  late List<double> _previewColumnWidths;
  late List<double> _previewRowHeights;
  double _viewportWidth = 0;
  double? _lastLoggedCanvasOffset;
  int? _resizingColumn;
  int? _resizingRow;
  int? _pendingColumnResizeColumn;
  int? _pendingRowResizeRow;
  double _pendingColumnResizeDelta = 0;
  double _pendingRowResizeDelta = 0;
  int _columnResizeFrameCount = 0;
  int _rowResizeFrameCount = 0;
  bool _columnResizeFrameScheduled = false;
  bool _rowResizeFrameScheduled = false;

  static const double _horizontalPadding = _TableGrid._horizontalPadding;

  @override
  void initState() {
    super.initState();
    _syncLayoutFromWidget();
    _horizontalController = ScrollController();
    _horizontalController.addListener(_logHorizontalScroll);
  }

  @override
  void didUpdateWidget(covariant _TableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_resizingColumn == null && _resizingRow == null) {
      _syncLayoutFromWidget();
    }
  }

  @override
  void dispose() {
    _horizontalController.removeListener(_logHorizontalScroll);
    _horizontalController.dispose();
    super.dispose();
  }

  void _syncLayoutFromWidget() {
    _previewColumnWidths = [...widget.columnWidths];
    _previewRowHeights = [...widget.rowHeights];
    while (_previewColumnWidths.length < widget.columnCount) {
      _previewColumnWidths.add(_NoteTableEditorScreenState._defaultColumnWidth);
    }
    if (_previewColumnWidths.length > widget.columnCount) {
      _previewColumnWidths = _previewColumnWidths
          .take(widget.columnCount)
          .toList();
    }
    while (_previewRowHeights.length < widget.rowCount) {
      _previewRowHeights.add(_NoteTableEditorScreenState._defaultRowHeight);
    }
    if (_previewRowHeights.length > widget.rowCount) {
      _previewRowHeights = _previewRowHeights.take(widget.rowCount).toList();
    }
  }

  void _logHorizontalScroll() {
    if (!_horizontalController.hasClients) {
      return;
    }
    final offset = _horizontalController.offset;
    final lastOffset = _lastLoggedCanvasOffset;
    if (widget.selection == null) {
      return;
    }
    if (lastOffset != null && (offset - lastOffset).abs() < 160) {
      return;
    }
    _lastLoggedCanvasOffset = offset;
    final railLocalLeft = (offset - _horizontalPadding).toDouble();
    DebugConsole.log(
      '[TableRail] canvas scroll offset=${offset.toStringAsFixed(1)} '
      'viewport=${_viewportWidth.toStringAsFixed(1)} '
      'railLocalLeft=${railLocalLeft.toStringAsFixed(1)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportWidth = constraints.maxWidth;
        final tableWidth = _tableWidth;
        return StretchingOverscrollIndicator(
          key: const ValueKey('note-table-horizontal-rubber-band'),
          axisDirection: AxisDirection.right,
          child: SingleChildScrollView(
            controller: _horizontalController,
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              _horizontalPadding,
              12,
              _horizontalPadding,
              24,
            ),
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
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
        );
      },
    );
  }

  void _scrollFromCellDrag(double deltaDx) {
    if (!_horizontalController.hasClients || deltaDx == 0) {
      return;
    }
    final position = _horizontalController.position;
    final nextOffset = (position.pixels - deltaDx)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (nextOffset == position.pixels) {
      return;
    }
    _horizontalController.jumpTo(nextOffset);
  }

  double get _tableWidth {
    return _TableGrid._rowHeadWidth +
        _previewColumnWidths.fold<double>(0, (total, width) => total + width);
  }

  double _columnWidth(int column) {
    if (column < 0 || column >= _previewColumnWidths.length) {
      return _NoteTableEditorScreenState._defaultColumnWidth;
    }
    return _previewColumnWidths[column];
  }

  double _rowHeight(int row) {
    if (row < 0 || row >= _previewRowHeights.length) {
      return _TableGrid._cellHeight;
    }
    return _previewRowHeights[row];
  }

  void _startColumnResize(int column) {
    if (column < 0 || column >= widget.columnCount) {
      return;
    }
    _resizingColumn = column;
    _pendingColumnResizeColumn = null;
    _pendingColumnResizeDelta = 0;
    _columnResizeFrameCount = 0;
    DebugConsole.log(
      '[TableResize] column start column=$column width=${_columnWidth(column).toStringAsFixed(1)}',
    );
  }

  void _updateColumnResize(int column, double delta) {
    if (column < 0 || column >= widget.columnCount || delta == 0) {
      return;
    }
    if (_pendingColumnResizeColumn != null &&
        _pendingColumnResizeColumn != column) {
      _flushPendingColumnResize();
    }
    _pendingColumnResizeColumn = column;
    _pendingColumnResizeDelta += delta;
    if (_columnResizeFrameScheduled) {
      return;
    }
    _columnResizeFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) {
        _flushPendingColumnResize();
      }
    });
  }

  void _flushPendingColumnResize() {
    final column = _pendingColumnResizeColumn;
    final delta = _pendingColumnResizeDelta;
    _pendingColumnResizeColumn = null;
    _pendingColumnResizeDelta = 0;
    _columnResizeFrameScheduled = false;
    if (column == null ||
        column < 0 ||
        column >= widget.columnCount ||
        delta.abs() <= 0.1) {
      return;
    }
    final currentWidth = _columnWidth(column);
    final nextWidth = (currentWidth + delta)
        .clamp(
          _NoteTableEditorScreenState._minimumColumnWidth,
          _NoteTableEditorScreenState._maximumColumnWidth,
        )
        .toDouble();
    if ((nextWidth - currentWidth).abs() <= 0.1) {
      return;
    }
    _columnResizeFrameCount += 1;
    setState(() => _previewColumnWidths[column] = nextWidth);
  }

  void _commitColumnResize(int column) {
    if (column < 0 || column >= widget.columnCount) {
      _resizingColumn = null;
      return;
    }
    _flushPendingColumnResize();
    final width = _columnWidth(column);
    DebugConsole.log(
      '[TableResize] column end column=$column width=${width.toStringAsFixed(1)} '
      'frames=$_columnResizeFrameCount',
    );
    _resizingColumn = null;
    _columnResizeFrameCount = 0;
    widget.onCommitColumnWidth(column, width);
  }

  void _startRowResize(int row) {
    if (row < 0 || row >= widget.rowCount) {
      return;
    }
    if (_resizingRow != null) {
      if (_resizingRow == row) {
        DebugConsole.log('[TableResize] row duplicate start ignored row=$row');
      }
      return;
    }
    _resizingRow = row;
    _pendingRowResizeRow = null;
    _pendingRowResizeDelta = 0;
    _rowResizeFrameCount = 0;
    DebugConsole.log(
      '[TableResize] row start row=$row height=${_rowHeight(row).toStringAsFixed(1)}',
    );
  }

  void _updateRowResize(int row, double delta) {
    if (row < 0 || row >= widget.rowCount || delta == 0) {
      return;
    }
    if (_resizingRow != null && _resizingRow != row) {
      return;
    }
    if (_pendingRowResizeRow != null && _pendingRowResizeRow != row) {
      _flushPendingRowResize();
    }
    _pendingRowResizeRow = row;
    _pendingRowResizeDelta += delta;
    if (_rowResizeFrameScheduled) {
      return;
    }
    _rowResizeFrameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (mounted) {
        _flushPendingRowResize();
      }
    });
  }

  void _flushPendingRowResize() {
    final row = _pendingRowResizeRow;
    final delta = _pendingRowResizeDelta;
    _pendingRowResizeRow = null;
    _pendingRowResizeDelta = 0;
    _rowResizeFrameScheduled = false;
    if (row == null ||
        row < 0 ||
        row >= widget.rowCount ||
        delta.abs() <= 0.1) {
      return;
    }
    final currentHeight = _rowHeight(row);
    final nextHeight = (currentHeight + delta)
        .clamp(
          _NoteTableEditorScreenState._minimumRowHeight,
          _NoteTableEditorScreenState._maximumRowHeight,
        )
        .toDouble();
    if ((nextHeight - currentHeight).abs() <= 0.1) {
      return;
    }
    _rowResizeFrameCount += 1;
    setState(() => _previewRowHeights[row] = nextHeight);
  }

  void _commitRowResize(int row) {
    if (_resizingRow != null && _resizingRow != row) {
      return;
    }
    if (row < 0 || row >= widget.rowCount) {
      _resizingRow = null;
      return;
    }
    _flushPendingRowResize();
    final height = _rowHeight(row);
    DebugConsole.log(
      '[TableResize] row end row=$row height=${height.toStringAsFixed(1)} '
      'frames=$_rowResizeFrameCount',
    );
    _resizingRow = null;
    _rowResizeFrameCount = 0;
    widget.onCommitRowHeight(row, height);
  }

  Widget _stickyRail({
    required Key key,
    required double width,
    required _TableSelection selection,
  }) {
    return AnimatedBuilder(
      animation: _horizontalController,
      builder: (context, _) {
        final viewportWidth = _viewportWidth <= 0 ? width : _viewportWidth;
        final left = _horizontalController.hasClients
            ? _horizontalController.offset.clamp(0, width).toDouble()
            : 0.0;
        final visibleWidth = viewportWidth.clamp(0, width).toDouble();
        return SizedBox(
          key: key,
          width: width,
          child: widget.railForSelection(
            selection,
            stickyViewportLeft: left,
            stickyViewportWidth: visibleWidth,
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
        SizedBox(
          height: _TableGrid._cellHeight,
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
                  onResizeColumnStart: _startColumnResize,
                  onResizeColumnUpdate: _updateColumnResize,
                  onResizeColumnEnd: _commitColumnResize,
                ),
            ],
          ),
        ),
        if (showColumnRail)
          _stickyRail(
            key: ValueKey(
              'note-table-column-head-expansion-${selectedColumn!.columnIndex}',
            ),
            width: tableWidth,
            selection: selectedColumn,
          ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, int row) {
    final selectedRow = widget.selection;
    final showRowRail =
        selectedRow?.kind == _TableSelectionKind.row &&
        selectedRow?.rowIndex == row;
    final showCellRail =
        selectedRow?.kind == _TableSelectionKind.cell &&
        selectedRow?.rowIndex == row;
    final tableWidth = _tableWidth;
    final rowHeight = _rowHeight(row);
    final rowContent = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RowHeadSlot(
          row: row,
          width: _TableGrid._rowHeadWidth,
          height: rowHeight,
          selected: widget.selection?.isRow(row) == true,
          onSelect: widget.onSelect,
          onMoveRow: widget.onMoveRow,
          onResizeRowStart: _startRowResize,
          onResizeRowUpdate: _updateRowResize,
          onResizeRowEnd: _commitRowResize,
        ),
        for (var column = 0; column < widget.columnCount; column += 1)
          _CellSlot(
            row: row,
            column: column,
            width: _columnWidth(column),
            height: rowHeight,
            controller: widget.cellControllerFor(row, column),
            focusNode: widget.cellFocusNodeFor(row, column),
            selected: widget.selection?.isCell(row, column) == true,
            tags: widget.tagsForCell(row, column),
            onTap: () => widget.onSelect(_TableSelection.cell(row, column)),
            onHorizontalDragUpdate: _scrollFromCellDrag,
            onChanged: (value) => widget.onCellChanged(row, column, value),
            onSubmitted: () => widget.onCellSubmitted(row, column),
          ),
      ],
    );
    final rowBody = _usesIntrinsicHeightForRow(row)
        ? IntrinsicHeight(child: rowContent)
        : SizedBox(height: rowHeight, child: rowContent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        rowBody,
        if (showRowRail)
          _stickyRail(
            key: ValueKey('note-table-row-head-expansion-$row'),
            width: tableWidth,
            selection: selectedRow!,
          )
        else if (showCellRail)
          _stickyRail(
            key: ValueKey(
              'note-table-cell-expansion-$row-${selectedRow!.columnIndex}',
            ),
            width: tableWidth,
            selection: selectedRow,
          ),
      ],
    );
  }

  bool _usesIntrinsicHeightForRow(int row) {
    if (_resizingColumn != null || _resizingRow != null) {
      return false;
    }
    return widget.intrinsicRows.contains(row);
  }
}

class _ColumnHeadSlot extends StatelessWidget {
  const _ColumnHeadSlot({
    required this.column,
    required this.width,
    required this.selected,
    required this.onSelect,
    required this.onMoveColumn,
    required this.onResizeColumnStart,
    required this.onResizeColumnUpdate,
    required this.onResizeColumnEnd,
  });

  final int column;
  final double width;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveColumn;
  final ValueChanged<int> onResizeColumnStart;
  final void Function(int column, double delta) onResizeColumnUpdate;
  final ValueChanged<int> onResizeColumnEnd;

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
                onResizeColumnStart: onResizeColumnStart,
                onResizeColumnUpdate: onResizeColumnUpdate,
                onResizeColumnEnd: onResizeColumnEnd,
              ),
            ),
            child: _ColumnHeadContent(
              column: column,
              width: width,
              selected: selected || candidateData.isNotEmpty,
              resizeEnabled: selected,
              onSelect: onSelect,
              onResizeColumnStart: onResizeColumnStart,
              onResizeColumnUpdate: onResizeColumnUpdate,
              onResizeColumnEnd: onResizeColumnEnd,
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
    required this.onResizeColumnStart,
    required this.onResizeColumnUpdate,
    required this.onResizeColumnEnd,
  });

  final int column;
  final double width;
  final bool selected;
  final bool resizeEnabled;
  final ValueChanged<_TableSelection> onSelect;
  final ValueChanged<int> onResizeColumnStart;
  final void Function(int column, double delta) onResizeColumnUpdate;
  final ValueChanged<int> onResizeColumnEnd;

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
            top: 2,
            right: 2,
            bottom: 2,
            width: 36,
            child: GestureDetector(
              key: ValueKey('note-table-column-resize-$column'),
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onHorizontalDragStart: (_) => onResizeColumnStart(column),
              onHorizontalDragUpdate: (details) =>
                  onResizeColumnUpdate(column, details.delta.dx),
              onHorizontalDragEnd: (_) => onResizeColumnEnd(column),
              onHorizontalDragCancel: () => onResizeColumnEnd(column),
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
    required this.onResizeRowStart,
    required this.onResizeRowUpdate,
    required this.onResizeRowEnd,
  });

  final int row;
  final double width;
  final double height;
  final bool selected;
  final ValueChanged<_TableSelection> onSelect;
  final void Function(int fromIndex, int toIndex) onMoveRow;
  final ValueChanged<int> onResizeRowStart;
  final void Function(int row, double delta) onResizeRowUpdate;
  final ValueChanged<int> onResizeRowEnd;

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
                onResizeRowStart: onResizeRowStart,
                onResizeRowUpdate: onResizeRowUpdate,
                onResizeRowEnd: onResizeRowEnd,
              ),
            ),
            child: _RowHeadContent(
              row: row,
              width: width,
              height: height,
              selected: selected || candidateData.isNotEmpty,
              resizeEnabled: selected,
              onSelect: onSelect,
              onResizeRowStart: onResizeRowStart,
              onResizeRowUpdate: onResizeRowUpdate,
              onResizeRowEnd: onResizeRowEnd,
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
    required this.onResizeRowStart,
    required this.onResizeRowUpdate,
    required this.onResizeRowEnd,
  });

  final int row;
  final double width;
  final double height;
  final bool selected;
  final bool resizeEnabled;
  final ValueChanged<_TableSelection> onSelect;
  final ValueChanged<int> onResizeRowStart;
  final void Function(int row, double delta) onResizeRowUpdate;
  final ValueChanged<int> onResizeRowEnd;

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
            bottom: 2,
            left: (width - 36) / 2,
            width: 36,
            height: 28,
            child: GestureDetector(
              key: ValueKey('note-table-row-resize-$row'),
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onVerticalDragStart: (_) => onResizeRowStart(row),
              onVerticalDragUpdate: (details) =>
                  onResizeRowUpdate(row, details.delta.dy),
              onVerticalDragEnd: (_) => onResizeRowEnd(row),
              onVerticalDragCancel: () => onResizeRowEnd(row),
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
    required this.focusNode,
    required this.selected,
    required this.tags,
    required this.onTap,
    required this.onHorizontalDragUpdate,
    required this.onChanged,
    required this.onSubmitted,
  });

  final int row;
  final int column;
  final double width;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool selected;
  final List<NoteKnowledgeTag> tags;
  final VoidCallback onTap;
  final ValueChanged<double> onHorizontalDragUpdate;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

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
        focusNode: focusNode,
        selected: selected,
        tags: tags,
        onTap: onTap,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
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
                  color: selected
                      ? colorScheme.primary
                      : const Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _CellField extends StatefulWidget {
  const _CellField({
    required this.row,
    required this.column,
    required this.width,
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.selected,
    required this.tags,
    required this.onTap,
    required this.onHorizontalDragUpdate,
    required this.onChanged,
    required this.onSubmitted,
  });

  final int row;
  final int column;
  final double width;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool selected;
  final List<NoteKnowledgeTag> tags;
  final VoidCallback onTap;
  final ValueChanged<double> onHorizontalDragUpdate;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  State<_CellField> createState() => _CellFieldState();
}

class _CellFieldState extends State<_CellField> {
  int? _activePointer;
  Offset? _pointerStart;
  bool _dragExceededSlop = false;
  bool _horizontalDrag = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) {
      return;
    }
    _activePointer = event.pointer;
    _pointerStart = event.localPosition;
    _dragExceededSlop = false;
    _horizontalDrag = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    final start = _pointerStart;
    if (start == null) {
      return;
    }
    final totalDelta = event.localPosition - start;
    if (!_dragExceededSlop && totalDelta.distance > kTouchSlop) {
      _dragExceededSlop = true;
    }
    if (!_horizontalDrag &&
        _dragExceededSlop &&
        totalDelta.dx.abs() > totalDelta.dy.abs()) {
      _horizontalDrag = true;
    }
    if (_horizontalDrag) {
      widget.onHorizontalDragUpdate(event.delta.dx);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    if (!_dragExceededSlop) {
      widget.onTap();
    }
    _resetPointer();
  }

  void _handlePointerCancel(PointerEvent event) {
    if (_activePointer != event.pointer) {
      return;
    }
    _resetPointer();
  }

  void _resetPointer() {
    _activePointer = null;
    _pointerStart = null;
    _dragExceededSlop = false;
    _horizontalDrag = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerCancel,
      child: Container(
        key: ValueKey(
          'note-table-cell-container-${widget.row}-${widget.column}',
        ),
        width: widget.width,
        constraints: BoxConstraints(minHeight: widget.height),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Stack(
          children: [
            if (widget.selected)
              Positioned.fill(
                child: DecoratedBox(
                  key: ValueKey(
                    'note-table-selected-cell-${widget.row}-${widget.column}',
                  ),
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
                key: widget.tags.isEmpty
                    ? null
                    : ValueKey(
                        'note-table-cell-highlight-${widget.row}-${widget.column}',
                      ),
                child: TextFormField(
                  key: ValueKey(
                    'note-table-cell-${widget.row}-${widget.column}',
                  ),
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(border: InputBorder.none),
                  style: _taggedTableTextStyle(widget.tags),
                  onChanged: widget.onChanged,
                  onFieldSubmitted: (_) => widget.onSubmitted(),
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
    return _TableSelection._(
      _TableSelectionKind.column,
      columnIndex: columnIndex,
    );
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
