import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_table_editor_screen.dart';

void main() {
  testWidgets('table editor edits cells and adds rows and columns', (tester) async {
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
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-0-1')), '88-92%');
    expect(find.byKey(const ValueKey('note-table-add-column')), findsNothing);
    expect(find.byKey(const ValueKey('note-table-add-row')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note-table-appbar-add-column')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-0-2')), 'Cél');
    await tester.tap(find.byKey(const ValueKey('note-table-appbar-add-row')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('note-table-cell-1-0')), 'SpO2');
    await tester.tap(find.byKey(const ValueKey('note-table-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.rows, hasLength(2));
    expect(result!.rows.first, ['Elem', '88-92%', 'Cél']);
    expect(result!.rows.last.first, 'SpO2');
  });

  testWidgets('table editor normalizes ragged rows and supports inserting columns', (tester) async {
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
      find.byKey(const ValueKey('note-table-rail-insert-column-right-column-0')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('note-table-cell-0-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-cell-1-3')), findsOneWidget);
    expect(latest, isNotNull);
    expect(latest!.rows, everyElement(hasLength(4)));
  });

  testWidgets('table editor selects cells and stores scoped tags in an expanding rail', (tester) async {
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

    expect(find.byKey(const ValueKey('note-table-corner-head')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-column-head-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-row-head-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-select-cell-1-1')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('note-table-cell-1-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-table-selected-cell-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-row-expansion-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-selection-action-rail')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-menu-tag-selection')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag-manager-name')), 'súlyos');
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
    expect(find.byKey(const ValueKey('note-table-cell-highlight-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-cell-tag-marker-1-1')), findsNothing);
    expect(find.byKey(const ValueKey('note-selected-tag-tray')), findsNothing);
    expect(find.byKey(const ValueKey('note-selection-rail-tag-pill-súlyos')), findsOneWidget);
  });

  testWidgets('table editor expands a column head with the shared rail', (tester) async {
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

    expect(find.byKey(const ValueKey('note-table-column-expansion-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-selection-action-rail')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-rail-tag-column-1')), findsOneWidget);
  });

  testWidgets('table row and column tags highlight affected cell text instead of markers', (tester) async {
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
                target: NoteTagTarget(kind: NoteTagTargetKind.tableRow, rowIndex: 1),
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

    expect(find.byKey(const ValueKey('note-table-cell-highlight-1-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-cell-highlight-1-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-cell-tag-marker-1-1')), findsNothing);
    expect(find.byKey(const ValueKey('note-selected-tag-tray')), findsNothing);
  });

  testWidgets('table cell tag color wins over row and column highlight colors', (tester) async {
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
                target: NoteTagTarget(kind: NoteTagTargetKind.tableRow, rowIndex: 1),
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
                target: NoteTagTarget(kind: NoteTagTargetKind.tableColumn, columnIndex: 1),
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
                    type: NoteKnowledgeTagTypes.definition,
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

    final highlightedField = tester.widget<TextFormField>(
      find.descendant(
        of: find.byKey(const ValueKey('note-table-cell-highlight-1-1')),
        matching: find.byKey(const ValueKey('note-table-cell-1-1')),
      ),
    );

    expect(
      highlightedField.style!.backgroundColor,
      const Color(0xFF16A34A).withValues(alpha: 0.16),
    );
  });

  testWidgets('table editor remaps scoped cell tags when inserting columns before them', (tester) async {
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
      find.byKey(const ValueKey('note-table-rail-insert-column-right-column-0')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.scopedTags.single.target.rowIndex, 1);
    expect(latest!.scopedTags.single.target.columnIndex, 2);
    expect(find.byKey(const ValueKey('note-table-cell-highlight-1-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-table-cell-highlight-1-1')), findsNothing);
  });

  testWidgets('table editor remaps and drops scoped row tags when deleting rows', (tester) async {
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
                target: NoteTagTarget(kind: NoteTagTargetKind.tableRow, rowIndex: 2),
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
    await tester.tap(find.byKey(const ValueKey('note-table-rail-delete-row-1')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.scopedTags.single.target.rowIndex, 1);

    await tester.tap(find.byKey(const ValueKey('note-table-row-head-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-table-rail-delete-row-1')));
    await tester.pumpAndSettle();

    expect(latest!.scopedTags, isEmpty);
  });
}

void _ignoreBlockChange(NoteBlock block) {}
