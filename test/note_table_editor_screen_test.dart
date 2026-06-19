import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_table_editor_screen.dart';

void main() {
  testWidgets('table editor edits cells and adds rows and columns', (
    tester,
  ) async {
    NoteBlock? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteBlock>(
                MaterialPageRoute(
                  builder: (_) => const NoteTableEditorScreen(
                    block: NoteBlock(
                      id: 'table-1',
                      type: NoteBlockType.table,
                      rows: [
                        ['Elem', 'Érték'],
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-table-cell-0-1')),
      '88-92%',
    );
    expect(find.byKey(const ValueKey('note-table-add-column')), findsNothing);
    expect(find.byKey(const ValueKey('note-table-add-row')), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('note-table-appbar-add-column')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-table-cell-0-2')),
      'Cél',
    );
    await tester.tap(find.byKey(const ValueKey('note-table-appbar-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-table-cell-1-0')),
      'SpO2',
    );
    await tester.tap(find.byKey(const ValueKey('note-table-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rows, hasLength(2));
    expect(result!.rows.first, ['Elem', '88-92%', 'Cél']);
    expect(result!.rows.last.first, 'SpO2');
  });

  testWidgets(
    'table editor normalizes ragged rows and supports inserting columns',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B', 'C'],
                ['D', 'E'],
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('note-table-cell-1-2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('note-table-column-head-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('note-table-rail-insert-column-right-column-0'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('note-table-cell-0-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-table-cell-1-3')), findsOneWidget);
      expect(latest, isNotNull);
      expect(latest!.rows, everyElement(hasLength(4)));
    },
  );

  testWidgets(
    'table editor selects cells and stores scoped tags in an expanding rail',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              title: 'Oxigén táblázat',
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos', 'High flow'],
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('note-table-corner-head')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-column-head-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-row-head-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-select-cell-1-1')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-table-selected-cell-1-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-expansion-1-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-row-expansion-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-selection-action-rail')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-chunk-menu-tag-selection')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-manager-name')),
        'súlyos',
      );
      await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(
        latest!.scopedTags.single.target.kind,
        NoteTagTargetKind.tableCell,
      );
      expect(latest!.scopedTags.single.target.rowIndex, 1);
      expect(latest!.scopedTags.single.target.columnIndex, 1);
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-tag-marker-1-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-selected-tag-tray')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-selection-rail-tag-pill-súlyos')),
        findsOneWidget,
      );
    },
  );

  testWidgets('table editor expands a column head with the shared rail', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-column-head-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-table-column-head-expansion-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-column-expansion-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-selection-action-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-rail-tag-column-1')),
      findsOneWidget,
    );
  });

  testWidgets('table column tagging writes tags onto the affected cells', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-column-head-1')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-table-rail-tag-column-1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'oxigén',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.scopedTags, hasLength(2));
    expect(
      latest!.scopedTags.map((assignment) => assignment.target.kind),
      everyElement(NoteTagTargetKind.tableCell),
    );
    expect(
      latest!.scopedTags.map((assignment) => assignment.target.columnIndex),
      everyElement(1),
    );
    expect(
      find.byKey(const ValueKey('note-table-cell-highlight-0-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'table row and column tags highlight affected cell text instead of markers',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos', 'High flow'],
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'row-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.state,
                      label: 'súlyos',
                      colorValue: 0xFFDC2626,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-1-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-tag-marker-1-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-selected-tag-tray')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'table cell tag color wins over row and column highlight colors',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos', 'High flow'],
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'row-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.state,
                      label: 'sor',
                      colorValue: 0xFFDC2626,
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'column-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableColumn,
                    columnIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'oszlop',
                      colorValue: 0xFF2563EB,
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'cell-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 1,
                    columnIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.custom,
                      label: 'cella',
                      colorValue: 0xFF16A34A,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      final highlightedField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
          matching: find.byType(TextField),
        ),
      );

      expect(
        highlightedField.style!.backgroundColor,
        const Color(0xFF16A34A).withValues(alpha: 0.16),
      );
    },
  );

  testWidgets(
    'table editor remaps scoped cell tags when inserting columns before them',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos', 'High flow'],
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'cell-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 1,
                    columnIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.state,
                      label: 'súlyos',
                      colorValue: 0xFFDC2626,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-table-column-head-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('note-table-rail-insert-column-right-column-0'),
        ),
      );
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.scopedTags.single.target.rowIndex, 1);
      expect(latest!.scopedTags.single.target.columnIndex, 2);
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-1-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'table editor remaps and drops scoped row tags when deleting rows',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Enyhe', 'Célzott'],
                ['Súlyos', 'High flow'],
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'row-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 2,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.state,
                      label: 'súlyos',
                      colorValue: 0xFFDC2626,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-table-row-head-expansion-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-row-expansion-1')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-delete-row-1')),
      );
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.scopedTags.single.target.rowIndex, 1);

      await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-delete-row-1')),
      );
      await tester.pumpAndSettle();

      expect(latest!.scopedTags, isEmpty);
    },
  );

  testWidgets(
    'table editor inserts rows from the rail and remaps cell tags below insertion',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Enyhe', 'Célzott'],
                ['Súlyos', 'High flow'],
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'cell-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 2,
                    columnIndex: 0,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.state,
                      label: 'súlyos',
                      colorValue: 0xFFDC2626,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-table-row-head-0')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-insert-row-below-0')),
      );
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.rows, hasLength(4));
      expect(latest!.scopedTags.single.target.rowIndex, 3);
      expect(latest!.scopedTags.single.target.columnIndex, 0);
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-3-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-table-cell-highlight-2-0')),
        findsNothing,
      );
    },
  );

  testWidgets('table row heads stretch to match wrapped cell height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot'],
              [
                'Nagyon hosszú cellaszöveg, ami több sorba törik a fix táblázatcellában, '
                    'ezért a sor fejének ugyanakkora magasnak kell lennie.',
              ],
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    final rowHeadHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
        .height;
    final cellHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-cell-container-1-0')))
        .height;

    expect(rowHeadHeight, cellHeight);
    expect(cellHeight, greaterThan(52));
  });

  testWidgets('table row head long-press drag reorders rows and remaps tags', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Enyhe', 'Célzott'],
              ['Súlyos', 'High flow'],
            ],
            tableRowHeights: [52, 62, 72],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'cell-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 2,
                  columnIndex: 1,
                ),
                tags: [
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.state,
                    label: 'súlyos',
                    colorValue: 0xFFDC2626,
                  ),
                ],
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await _longPressDrag(
      tester,
      from: find.byKey(const ValueKey('note-table-row-head-2')),
      to: find.byKey(const ValueKey('note-table-row-head-0')),
    );

    expect(latest, isNotNull);
    expect(latest!.rows.first, ['Súlyos', 'High flow']);
    expect(latest!.rows[1], ['Állapot', 'Teendő']);
    expect(latest!.tableRowHeights, [72, 52, 62]);
    expect(latest!.scopedTags.single.target.rowIndex, 0);
    expect(latest!.scopedTags.single.target.columnIndex, 1);
  });

  testWidgets(
    'table column head long-press drag reorders columns and remaps tags',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő', 'Megjegyzés'],
                ['Súlyos', 'High flow', 'ABCDE'],
              ],
              tableColumnWidths: [140, 160, 190],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'cell-tag',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 1,
                    columnIndex: 2,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'abcde',
                      colorValue: 0xFF2563EB,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await _longPressDrag(
        tester,
        from: find.byKey(const ValueKey('note-table-column-head-2')),
        to: find.byKey(const ValueKey('note-table-column-head-0')),
      );

      expect(latest, isNotNull);
      expect(latest!.rows.first, ['Megjegyzés', 'Állapot', 'Teendő']);
      expect(latest!.rows[1], ['ABCDE', 'Súlyos', 'High flow']);
      expect(latest!.tableColumnWidths, [190, 140, 160]);
      expect(latest!.scopedTags.single.target.rowIndex, 1);
      expect(latest!.scopedTags.single.target.columnIndex, 0);
    },
  );

  testWidgets('table resize handles are available only on selected headers', (
    tester,
  ) async {
    NoteBlock? latest;
    var changeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: (block) {
            latest = block;
            changeCount += 1;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-table-column-resize-0')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('note-table-row-resize-1')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-table-cell-column-resize-1-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-table-cell-row-resize-1-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('note-table-column-head-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-table-column-resize-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-column-resize-icon-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-column-resize-1')),
      findsNothing,
    );
    final initialColumnWidth = tester
        .getSize(find.byKey(const ValueKey('note-table-column-head-0')))
        .width;
    await tester.drag(
      find.byKey(const ValueKey('note-table-column-resize-0')),
      const Offset(42, 0),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.tableColumnWidths.first, greaterThan(initialColumnWidth));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('note-table-column-head-0')))
          .width,
      greaterThan(initialColumnWidth),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-table-cell-column-resize-1-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-table-cell-row-resize-1-1')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-table-row-resize-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-table-row-resize-icon-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-table-row-resize-0')), findsNothing);
    final initialRowHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
        .height;
    await tester.drag(
      find.byKey(const ValueKey('note-table-row-resize-1')),
      const Offset(0, 36),
    );
    await tester.pumpAndSettle();

    expect(latest!.tableRowHeights[1], greaterThan(initialRowHeight));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
          .height,
      greaterThan(initialRowHeight),
    );
    expect(changeCount, 2);
  });

  testWidgets('table resize commits only once per continuous drag', (
    tester,
  ) async {
    DebugConsole.clear();
    NoteBlock? latest;
    var changeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: (block) {
            latest = block;
            changeCount += 1;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-column-head-0')));
    await tester.pumpAndSettle();
    final initialColumnWidth = tester
        .getSize(find.byKey(const ValueKey('note-table-column-head-0')))
        .width;

    await tester.timedDrag(
      find.byKey(const ValueKey('note-table-column-resize-0')),
      const Offset(72, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(changeCount, 1);
    expect(latest!.tableColumnWidths.first, greaterThan(initialColumnWidth));
    expect(
      DebugConsole.allText,
      contains('[TableResize] column start column=0'),
    );
    expect(
      DebugConsole.allText,
      contains('[TableResize] column commit column=0'),
    );
    final columnEndLog = DebugConsole.entries.firstWhere(
      (entry) => entry.contains('[TableResize] column end column=0'),
    );
    final columnFrames = int.parse(
      RegExp(r'frames=(\d+)').firstMatch(columnEndLog)!.group(1)!,
    );
    expect(columnFrames, greaterThan(1));

    await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
    await tester.pumpAndSettle();
    final initialRowHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
        .height;

    await tester.timedDrag(
      find.byKey(const ValueKey('note-table-row-resize-1')),
      const Offset(0, 68),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(changeCount, 2);
    expect(latest!.tableRowHeights[1], greaterThan(initialRowHeight));
    expect(DebugConsole.allText, contains('[TableResize] row start row=1'));
    expect(DebugConsole.allText, contains('[TableResize] row commit row=1'));
    expect(
      DebugConsole.entries
          .where((entry) => entry.contains('[TableResize]'))
          .length,
      lessThanOrEqualTo(8),
    );
  });

  testWidgets('table row resize only starts from the selected row drag icon', (
    tester,
  ) async {
    DebugConsole.clear();
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
              ['Enyhe', 'Célzott oxygen'],
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
    await tester.pumpAndSettle();
    final initialRowHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
        .height;
    final rowHeadBottomLeft = tester.getBottomLeft(
      find.byKey(const ValueKey('note-table-row-head-1')),
    );

    await tester.dragFrom(
      rowHeadBottomLeft + const Offset(8, -8),
      const Offset(0, 64),
    );
    await tester.pumpAndSettle();

    expect(latest, isNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
          .height,
      initialRowHeight,
    );
    expect(
      DebugConsole.entries.where(
        (entry) => entry.contains('[TableResize] row start row=1'),
      ),
      isEmpty,
    );
  });

  testWidgets('table row grows immediately while editing multiline cell', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    final initialRowHeight = tester
        .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
        .height;

    await tester.enterText(
      find.byKey(const ValueKey('note-table-cell-1-0')),
      'Első sor\nMásodik sor\nHarmadik sor\nNegyedik sor',
    );
    await tester.pump();

    expect(latest!.rows[1][0], contains('\n'));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('note-table-row-head-1')))
          .height,
      greaterThan(initialRowHeight),
    );
  });

  testWidgets('table cell tap selects but horizontal drag scrolls the table', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['A', 'B', 'C', 'D', 'E', 'F'],
              ['1', '2', '3', '4', '5', '6'],
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-table-selected-cell-1-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('note-table-column-head-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-table-selected-cell-1-1')),
      findsNothing,
    );

    final headerLeftBefore = tester
        .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
        .dx;
    await tester.drag(
      find.byKey(const ValueKey('note-table-cell-container-1-1')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
          .dx,
      lessThan(headerLeftBefore),
    );
    expect(
      find.byKey(const ValueKey('note-table-selected-cell-1-1')),
      findsNothing,
    );
  });

  testWidgets('table vertical drag over a cell does not select the cell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['A', 'B', 'C'],
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['10', '11', '12'],
              ['13', '14', '15'],
              ['16', '17', '18'],
              ['19', '20', '21'],
              ['22', '23', '24'],
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('note-table-cell-container-1-1')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-table-selected-cell-1-1')),
      findsNothing,
    );
  });

  testWidgets(
    'table vertical drag over the editable field does not select the cell',
    (tester) async {
      tester.view.physicalSize = const Size(360, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B', 'C'],
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
                ['10', '11', '12'],
                ['13', '14', '15'],
                ['16', '17', '18'],
                ['19', '20', '21'],
                ['22', '23', '24'],
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey('note-table-cell-1-1')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-table-selected-cell-1-1')),
        findsNothing,
      );
    },
  );

  testWidgets('table secondary cell tags render as underline styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteTableEditorScreen(
          block: NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'cell-tag-1',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 1,
                  columnIndex: 0,
                ),
                tags: [
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.state,
                    label: 'súlyos',
                    colorValue: 0xFFDC2626,
                  ),
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.topic,
                    label: 'légzés',
                    colorValue: 0xFF2563EB,
                  ),
                ],
              ),
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('note-table-cell-highlight-1-0')),
        matching: find.byType(EditableText),
      ),
    );

    expect(
      field.style.backgroundColor,
      const Color(0xFFDC2626).withValues(alpha: 0.16),
    );
    expect(field.style.decoration, TextDecoration.underline);
    expect(field.style.decorationColor, const Color(0xFF2563EB));
  });

  testWidgets('table does not expose pinch zoom wrappers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTableEditorScreen(
          block: const NoteBlock(
            id: 'table-1',
            type: NoteBlockType.table,
            rows: [
              ['Állapot', 'Teendő'],
              ['Súlyos', 'High flow'],
            ],
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-table-zoomable-content')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-table-zoom-gesture')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-table-zoom-transform')),
      findsNothing,
    );
  });

  testWidgets(
    'table rail exposes rounded, transparent, and border style toggles',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['Állapot', 'Teendő'],
                ['Súlyos', 'High flow'],
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-selection-action-rail-separator')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-selection-action-rail-border')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('note-table-rail-toggle-rounded')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-toggle-rounded')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-selection-action-rail-rounded')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('note-table-rail-toggle-transparent')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-toggle-transparent')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-selection-action-rail-transparent')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('note-table-rail-toggle-border')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-table-rail-toggle-border')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-selection-action-rail-borderless')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'table rail is screen-sticky and scrolls independently from canvas',
    (tester) async {
      DebugConsole.clear();
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B', 'C', 'D', 'E', 'F'],
                ['1', '2', '3', '4', '5', '6'],
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-table-cell-1-0')));
      await tester.pumpAndSettle();

      final tableWidth = tester
          .getSize(find.byKey(const ValueKey('note-table-zoomable-content')))
          .width;
      final railFinder = find.byKey(
        const ValueKey('note-selection-action-rail'),
      );
      expect(
        tester.getSize(railFinder).width,
        moreOrLessEquals(tableWidth, epsilon: 0.1),
      );
      var railVisualWidth =
          tester.getBottomRight(railFinder).dx -
          tester.getTopLeft(railFinder).dx;
      var tableVisualWidth =
          tester
              .getBottomRight(
                find.byKey(const ValueKey('note-table-zoomable-content')),
              )
              .dx -
          tester
              .getTopLeft(
                find.byKey(const ValueKey('note-table-zoomable-content')),
              )
              .dx;
      expect(railVisualWidth, moreOrLessEquals(tableVisualWidth, epsilon: 0.1));

      final headerLeftBefore = tester
          .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
          .dx;
      final railViewportStart = tester.getTopLeft(
        find.byKey(const ValueKey('note-selection-action-row')),
      );
      await tester.dragFrom(
        railViewportStart + const Offset(80, 24),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
            .dx,
        headerLeftBefore,
      );
      expect(
        DebugConsole.allText,
        contains('[TableRail] row scroll row=actions'),
      );

      await tester.dragFrom(
        railViewportStart + const Offset(80, 74),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
            .dx,
        headerLeftBefore,
      );
      final railToggleLeftBeforeCanvasScroll = tester
          .getTopLeft(
            find.byKey(const ValueKey('note-selection-rail-toggle-tags')),
          )
          .dx;

      await tester.dragFrom(
        tester.getTopLeft(
              find.byKey(const ValueKey('note-table-column-head-1')),
            ) +
            const Offset(80, 20),
        const Offset(-220, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('note-table-column-head-0')))
            .dx,
        lessThan(headerLeftBefore),
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(const ValueKey('note-selection-rail-toggle-tags')),
            )
            .dx,
        moreOrLessEquals(railToggleLeftBeforeCanvasScroll, epsilon: 0.1),
      );
      expect(
        tester.getSize(railFinder).width,
        moreOrLessEquals(tableWidth, epsilon: 0.1),
      );
      final railVisualWidthAfterScroll =
          tester.getBottomRight(railFinder).dx -
          tester.getTopLeft(railFinder).dx;
      expect(
        railVisualWidthAfterScroll,
        moreOrLessEquals(railVisualWidth, epsilon: 0.1),
      );
      expect(
        DebugConsole.allText,
        contains('[TableRail] canvas scroll offset='),
      );
    },
  );

  testWidgets(
    'table horizontal overscroll uses the same stretch rubber band wrapper',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteTableEditorScreen(
            block: const NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B', 'C', 'D'],
                ['1', '2', '3', '4'],
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('note-table-horizontal-rubber-band')),
        findsOneWidget,
      );
    },
  );
}

Future<void> _longPressDrag(
  WidgetTester tester, {
  required Finder from,
  required Finder to,
}) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void _ignoreBlockChange(NoteBlock block) {}
