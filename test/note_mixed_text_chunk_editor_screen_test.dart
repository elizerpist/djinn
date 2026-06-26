import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_mixed_text_chunk_editor_screen.dart';

void main() {
  testWidgets(
    'mixed editor renders paragraph list and table sections in order',
    (tester) async {
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'p1',
              type: NoteMixedSectionType.paragraph,
              text: 'Intro paragraph',
            ),
            NoteMixedSection(
              id: 'list-1',
              type: NoteMixedSectionType.list,
              listItems: [
                NoteListItem(id: 'l1', text: 'First item'),
                NoteListItem(id: 'l2', text: 'Second item'),
              ],
            ),
            NoteMixedSection(
              id: 'table-1',
              type: NoteMixedSectionType.table,
              rows: [
                ['Name', 'Value'],
              ],
            ),
          ],
        ),
      );

      expect(
        find.byKey(const ValueKey('note-mixed-text-editor')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-add-paragraph')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('note-mixed-add-list')), findsNothing);
      expect(
        find.byKey(const ValueKey('note-mixed-add-table')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-section-p1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-section-list-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-section-table-1')),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
      expect(
        find.byKey(const ValueKey('note-mixed-section-menu-p1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-section-menu-list-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-mixed-section-menu-table-1')),
        findsNothing,
      );
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      expect(find.text('Bekezdes'), findsNothing);
      expect(find.text('Lista'), findsNothing);
      expect(find.text('Tablazat'), findsNothing);

      final paragraphTop = tester.getTopLeft(
        find.byKey(const ValueKey('note-mixed-section-p1')),
      );
      final listTop = tester.getTopLeft(
        find.byKey(const ValueKey('note-mixed-section-list-1')),
      );
      final tableTop = tester.getTopLeft(
        find.byKey(const ValueKey('note-mixed-section-table-1')),
      );
      expect(paragraphTop.dy, lessThan(listTop.dy));
      expect(listTop.dy, lessThan(tableTop.dy));
    },
  );

  testWidgets('mixed list section indents items from the universal rail', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpMixedEditor(
      tester,
      const NoteBlock(
        id: 'mixed-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'list-1',
            type: NoteMixedSectionType.list,
            listLayoutMode: NoteListLayoutMode.hierarchy,
            listItems: [
              NoteListItem(id: 'l1', text: 'Mother'),
              NoteListItem(id: 'l2', text: 'Child'),
            ],
          ),
        ],
      ),
      onChanged: (block) => latest = block,
    );

    await tester.tap(find.byKey(const ValueKey('note-mixed-list-item-l1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-mixed-rail-indent')));
    await tester.pumpAndSettle();

    final item = latest!.mixedSections.single.listItems.singleWhere(
      (candidate) => candidate.id == 'l1',
    );
    expect(item.level, 1);
    expect(
      find.byKey(const ValueKey('note-mixed-list-move-up-l1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-mixed-list-move-down-l1')),
      findsNothing,
    );
  });

  testWidgets(
    'mixed hierarchy list markers number mothers and style nested levels',
    (tester) async {
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'list-1',
              type: NoteMixedSectionType.list,
              listLayoutMode: NoteListLayoutMode.hierarchy,
              listItems: [
                NoteListItem(id: 'm1', text: 'Mother one'),
                NoteListItem(id: 'c1', text: 'Child square', level: 1),
                NoteListItem(id: 'c2', text: 'Child dot', level: 2),
                NoteListItem(id: 'c3', text: 'Child hollow dot', level: 3),
                NoteListItem(id: 'm2', text: 'Mother two'),
              ],
            ),
          ],
        ),
      );

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('note-mixed-list-marker-m1')),
            )
            .data,
        '1.',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('note-mixed-list-marker-c1')),
            )
            .data,
        '▪',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('note-mixed-list-marker-c2')),
            )
            .data,
        '•',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('note-mixed-list-marker-c3')),
            )
            .data,
        '◦',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('note-mixed-list-marker-m2')),
            )
            .data,
        '2.',
      );
    },
  );

  testWidgets(
    'header table button inserts a 2x2 table after the active paragraph',
    (tester) async {
      NoteBlock? latest;
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'p1',
              type: NoteMixedSectionType.paragraph,
              text: 'Before',
            ),
            NoteMixedSection(
              id: 'p2',
              type: NoteMixedSectionType.paragraph,
              text: 'After',
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      await tester.tap(find.byKey(const ValueKey('note-mixed-paragraph-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-mixed-add-table')));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      final sections = latest!.mixedSections;
      expect(sections.map((section) => section.type), [
        NoteMixedSectionType.paragraph,
        NoteMixedSectionType.table,
        NoteMixedSectionType.paragraph,
      ]);
      expect(sections[1].rows, [
        ['', ''],
        ['', ''],
      ]);
    },
  );

  testWidgets('mixed table section edits cells and adds rows and columns', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpMixedEditor(
      tester,
      const NoteBlock(
        id: 'mixed-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'table-1',
            type: NoteMixedSectionType.table,
            rows: [
              ['Metric', 'Value'],
            ],
          ),
        ],
      ),
      onChanged: (block) => latest = block,
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-mixed-table-cell-table-1-0-1')),
      '88-92%',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('note-mixed-table-cell-table-1-0-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-mixed-rail-add-row')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('note-selection-action-row')),
      const Offset(-520, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-mixed-rail-add-column')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    final rows = latest!.mixedSections.single.rows;
    expect(rows, hasLength(2));
    expect(rows, everyElement(hasLength(3)));
    expect(rows.first[1], '88-92%');
    expect(
      find.byKey(const ValueKey('note-mixed-table-cell-table-1-1-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-mixed-rail-delete-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-mixed-rail-toggle-rounded')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-mixed-rail-toggle-transparent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-mixed-rail-toggle-border')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mixed rail converts paragraph to heading list table and paragraph indent',
    (tester) async {
      NoteBlock? latest;
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'p1',
              type: NoteMixedSectionType.paragraph,
              text: 'Célok:',
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      await tester.tap(find.byKey(const ValueKey('note-mixed-paragraph-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-mixed-rail-heading')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-mixed-rail-heading-level-2')),
      );
      await tester.pumpAndSettle();

      expect(
        latest!.mixedSections.single.paragraphRole,
        NoteMixedParagraphRole.heading,
      );
      expect(latest!.mixedSections.single.headingLevel, 2);

      await tester.tap(find.byKey(const ValueKey('note-mixed-rail-bold')));
      await tester.pumpAndSettle();
      expect(latest!.mixedSections.single.text, '**Célok:**');

      await tester.tap(find.byKey(const ValueKey('note-mixed-rail-indent')));
      await tester.pumpAndSettle();
      expect(latest!.mixedSections.single.paragraphIndentLevel, 1);

      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-paragraph-p1')),
        'az ellátás során\na felszerelés táskákban',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-mixed-rail-list-dynamic')),
      );
      await tester.pumpAndSettle();

      expect(latest!.mixedSections.single.type, NoteMixedSectionType.list);
      expect(latest!.mixedSections.single.listItems.map((item) => item.text), [
        'az ellátás során',
        'a felszerelés táskákban',
      ]);
    },
  );

  testWidgets('mixed rail color palette expands upward and closes on choice', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpMixedEditor(
      tester,
      const NoteBlock(
        id: 'mixed-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'p1',
            type: NoteMixedSectionType.paragraph,
            text: 'Célok',
          ),
        ],
      ),
      onChanged: (block) => latest = block,
    );

    await tester.tap(find.byKey(const ValueKey('note-mixed-paragraph-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-mixed-rail-text-color')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-mixed-rail-color-popover')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-mixed-rail-color-0xff2563eb')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-mixed-rail-color-popover')),
      findsNothing,
    );
    expect(latest!.mixedSections.single.textColorValue, 0xFF2563EB);
  });

  testWidgets(
    'mixed selection rail appears above keyboard for selected list item',
    (tester) async {
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'list-1',
              type: NoteMixedSectionType.list,
              listItems: [NoteListItem(id: 'l1', text: 'Oxygen')],
            ),
          ],
        ),
        mediaQueryData: const MediaQueryData(
          viewInsets: EdgeInsets.only(bottom: 240),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-mixed-list-item-l1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-mixed-keyboard-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-selection-action-rail')),
        findsOneWidget,
      );
      final editorBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('note-mixed-text-editor')),
      );
      final railBottom = tester.getBottomLeft(
        find.byKey(const ValueKey('note-mixed-keyboard-rail')),
      );
      expect(railBottom.dy, lessThanOrEqualTo(editorBottom.dy - 200));
    },
  );
}

Future<void> _pumpMixedEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  MediaQueryData? mediaQueryData,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: mediaQueryData ?? const MediaQueryData(),
        child: NoteMixedTextChunkEditorScreen(
          block: block,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
}
