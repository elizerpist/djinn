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

  testWidgets(
    'paragraph to list conversion preserves fills tags and indentation',
    (tester) async {
      NoteBlock? latest;
      const alphaTag = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'alpha',
      );
      const betaTag = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'beta',
      );
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'p1',
              type: NoteMixedSectionType.paragraph,
              text: 'Alpha\n- Beta',
              rangeTags: [
                NoteTextRangeTag(
                  id: 'alpha-range',
                  start: 0,
                  end: 5,
                  tag: alphaTag,
                ),
                NoteTextRangeTag(
                  id: 'beta-range',
                  start: 8,
                  end: 12,
                  tag: betaTag,
                ),
              ],
              textFills: [
                NoteTextFill(
                  id: 'alpha-fill',
                  start: 0,
                  end: 5,
                  colorValue: 0xFFFFF59D,
                  targetKey: 'paragraph',
                ),
                NoteTextFill(
                  id: 'beta-fill',
                  start: 8,
                  end: 12,
                  colorValue: 0xFFBBDEFB,
                  targetKey: 'paragraph',
                ),
              ],
              paragraphStyles: [
                NoteTextParagraphStyle(
                  id: 'alpha-style',
                  start: 0,
                  end: 5,
                  level: 1,
                ),
                NoteTextParagraphStyle(
                  id: 'beta-style',
                  start: 8,
                  end: 12,
                  level: 2,
                ),
              ],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      await tester.tap(find.byKey(const ValueKey('note-mixed-paragraph-p1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-mixed-rail-list-dynamic')),
      );
      await tester.pumpAndSettle();

      final section = latest!.mixedSections.single;
      expect(section.type, NoteMixedSectionType.list);
      expect(section.listItems.map((item) => item.text), ['Alpha', 'Beta']);
      expect(section.listItems.map((item) => item.level), [1, 2]);
      expect(
        section.listItems
            .map((item) => item.tags.single.label)
            .toList(growable: false),
        ['alpha', 'beta'],
      );
      expect(section.rangeTags, isEmpty);
      expect(section.paragraphStyles, isEmpty);
      expect(section.textFills.map((fill) => (fill.start, fill.end)).toList(), [
        (0, 5),
        (0, 4),
      ]);
      expect(section.textFills.map((fill) => fill.targetKey), [
        'list:${section.listItems[0].id}',
        'list:${section.listItems[1].id}',
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
    'Kitöltés applies changes and removes a selected text background range',
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
              text: 'Alpha Beta Gamma',
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      final fieldFinder = find.byKey(const ValueKey('note-mixed-paragraph-p1'));
      await tester.tap(fieldFinder);
      final field = tester.widget<TextField>(fieldFinder);
      field.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 10,
      );
      await tester.pump();

      final fillButton = find.byKey(const ValueKey('note-mixed-rail-fill'));
      await tester.ensureVisible(fillButton);
      await tester.tap(fillButton);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Kitöltés'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('note-mixed-rail-color-0xfffff7ed')),
      );
      await tester.pumpAndSettle();

      final fill = latest!.mixedSections.single.textFills.single;
      expect(fill.start, 6);
      expect(fill.end, 10);
      expect(fill.colorValue, 0xFFFFF7ED);
      expect(fill.targetKey, 'paragraph');

      field.controller!.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 10,
      );
      await tester.ensureVisible(fillButton);
      await tester.tap(fillButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-mixed-fill-clear')));
      await tester.pumpAndSettle();

      expect(latest!.mixedSections.single.textFills, isEmpty);
    },
  );

  testWidgets(
    'partial retag remaps text range scoped tags to preserved fragments',
    (tester) async {
      NoteBlock? latest;
      const rangeTag = NoteKnowledgeTag(
        id: 'range-tag',
        type: NoteKnowledgeTagTypes.topic,
        label: 'Range',
      );
      const scopedTag = NoteKnowledgeTag(
        id: 'scoped-tag',
        type: NoteKnowledgeTagTypes.custom,
        label: 'Scoped',
      );
      await _pumpMixedEditor(
        tester,
        const NoteBlock(
          id: 'mixed-1',
          type: NoteBlockType.mixed,
          mixedSections: [
            NoteMixedSection(
              id: 'p1',
              type: NoteMixedSectionType.paragraph,
              text: '0123456789',
              rangeTags: [
                NoteTextRangeTag(
                  id: 'original-range',
                  start: 0,
                  end: 10,
                  tag: rangeTag,
                ),
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'original-scope',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.textRange,
                    rangeId: 'original-range',
                  ),
                  tags: [scopedTag],
                ),
              ],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      final fieldFinder = find.byKey(const ValueKey('note-mixed-paragraph-p1'));
      await tester.tap(fieldFinder);
      final field = tester.widget<TextField>(fieldFinder);
      field.controller!.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 6,
      );
      await tester.pump();
      await _tapMixedRailButton(tester, 'note-mixed-rail-clear-tags');

      final section = latest!.mixedSections.single;
      expect(
        section.rangeTags
            .map((range) => (range.start, range.end))
            .toList(growable: false),
        [(0, 3), (6, 10)],
      );
      final rangeIds = section.rangeTags.map((range) => range.id).toSet();
      expect(rangeIds, hasLength(section.rangeTags.length));
      final scopedRangeIds = section.scopedTags
          .where(
            (assignment) =>
                assignment.target.kind == NoteTagTargetKind.textRange,
          )
          .map((assignment) => assignment.target.rangeId)
          .toList(growable: false);
      expect(
        section.scopedTags.map((assignment) => assignment.id).toSet(),
        hasLength(section.scopedTags.length),
      );
      expect(scopedRangeIds, hasLength(2));
      expect(scopedRangeIds.toSet(), rangeIds);
      expect(
        section.scopedTags
            .expand((assignment) => assignment.tags)
            .map((tag) => tag.metadataText),
        everyElement(scopedTag.metadataText),
      );
      expect(
        scopedRangeIds.every(
          (rangeId) => rangeId != null && rangeIds.contains(rangeId),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'mixed paragraph list and table fills follow their own text edit deltas',
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
              text: 'Alpha Beta',
              textFills: [
                NoteTextFill(
                  id: 'paragraph-fill',
                  start: 6,
                  end: 10,
                  colorValue: 0xFFFFF59D,
                  targetKey: 'paragraph',
                ),
              ],
            ),
            NoteMixedSection(
              id: 'list-1',
              type: NoteMixedSectionType.list,
              listItems: [NoteListItem(id: 'l1', text: 'Say Alpha Beta')],
              textFills: [
                NoteTextFill(
                  id: 'list-fill',
                  start: 10,
                  end: 14,
                  colorValue: 0xFFC8E6C9,
                  targetKey: 'list:l1',
                ),
              ],
            ),
            NoteMixedSection(
              id: 'table-1',
              type: NoteMixedSectionType.table,
              rows: [
                ['Alpha Beta'],
              ],
              textFills: [
                NoteTextFill(
                  id: 'table-fill',
                  start: 6,
                  end: 10,
                  colorValue: 0xFFBBDEFB,
                  targetKey: 'table:0:0',
                ),
              ],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-paragraph-p1')),
        'Say Alpha Beta',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-list-item-l1')),
        'Alpha Beta',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-table-cell-table-1-0-0')),
        'Alpha BETA!',
      );
      await tester.pump();

      NoteTextFill fill(String sectionId) => latest!.mixedSections
          .singleWhere((section) => section.id == sectionId)
          .textFills
          .single;
      expect((fill('p1').start, fill('p1').end), (10, 14));
      expect((fill('list-1').start, fill('list-1').end), (6, 10));
      expect((fill('table-1').start, fill('table-1').end), (6, 11));
    },
  );

  testWidgets('deleting a mixed list item drops only its scoped fills', (
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
            listItems: [
              NoteListItem(id: 'l1', text: 'First'),
              NoteListItem(id: 'l2', text: 'Second'),
            ],
            textFills: [
              NoteTextFill(
                id: 'first-fill',
                start: 0,
                end: 5,
                colorValue: 0xFFFFF59D,
                targetKey: 'list:l1',
              ),
              NoteTextFill(
                id: 'second-fill',
                start: 0,
                end: 6,
                colorValue: 0xFFC8E6C9,
                targetKey: 'list:l2',
              ),
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'first-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.listItem,
                  listItemId: 'l1',
                ),
                tags: [
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.topic,
                    label: 'first',
                  ),
                ],
              ),
              NoteScopedTagAssignment(
                id: 'second-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.listItem,
                  listItemId: 'l2',
                ),
                tags: [
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.topic,
                    label: 'second',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      onChanged: (block) => latest = block,
    );

    await tester.tap(find.byKey(const ValueKey('note-mixed-list-item-l1')));
    await tester.pumpAndSettle();
    final delete = find.byKey(
      const ValueKey('note-mixed-rail-delete-list-item'),
    );
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();

    final section = latest!.mixedSections.single;
    expect(section.listItems.map((item) => item.id), ['l2']);
    expect(section.textFills.map((fill) => fill.id), ['second-fill']);
    expect(section.textFills.single.targetKey, 'list:l2');
    expect(section.scopedTags.map((assignment) => assignment.id), [
      'second-tag',
    ]);
  });

  testWidgets(
    'table row and column mutations remap fills with their logical cells',
    (tester) async {
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
                ['A', 'A1', 'A2'],
                ['B', 'B1', 'B2'],
                ['C', 'C1', 'C2'],
              ],
              textFills: [
                NoteTextFill(
                  id: 'row-a',
                  start: 0,
                  end: 1,
                  colorValue: 0xFFFFF59D,
                  targetKey: 'table:0:0',
                ),
                NoteTextFill(
                  id: 'row-b',
                  start: 0,
                  end: 1,
                  colorValue: 0xFFFFF59D,
                  targetKey: 'table:1:0',
                ),
                NoteTextFill(
                  id: 'row-c',
                  start: 0,
                  end: 1,
                  colorValue: 0xFFFFF59D,
                  targetKey: 'table:2:0',
                ),
                NoteTextFill(
                  id: 'column-one',
                  start: 0,
                  end: 2,
                  colorValue: 0xFFC8E6C9,
                  targetKey: 'table:0:1',
                ),
                NoteTextFill(
                  id: 'column-two',
                  start: 0,
                  end: 2,
                  colorValue: 0xFFBBDEFB,
                  targetKey: 'table:0:2',
                ),
              ],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'tag-a',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 0,
                    columnIndex: 0,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'A',
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'tag-b',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 1,
                    columnIndex: 0,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'B',
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'tag-c',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 2,
                    columnIndex: 0,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'C',
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'tag-column-one',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 0,
                    columnIndex: 1,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'column one',
                    ),
                  ],
                ),
                NoteScopedTagAssignment(
                  id: 'tag-column-two',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableCell,
                    rowIndex: 0,
                    columnIndex: 2,
                  ),
                  tags: [
                    NoteKnowledgeTag(
                      type: NoteKnowledgeTagTypes.topic,
                      label: 'column two',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      Map<String, String?> fillTargets() => {
        for (final fill in latest!.mixedSections.single.textFills)
          fill.id: fill.targetKey,
      };
      Map<String, (int?, int?)> tagTargets() => {
        for (final assignment in latest!.mixedSections.single.scopedTags)
          assignment.id: (
            assignment.target.rowIndex,
            assignment.target.columnIndex,
          ),
      };

      await _selectMixedTableCell(tester, 'table-1', 1, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-delete-row');
      expect(fillTargets(), {
        'row-a': 'table:0:0',
        'row-c': 'table:1:0',
        'column-one': 'table:0:1',
        'column-two': 'table:0:2',
      });
      expect(tagTargets(), {
        'tag-a': (0, 0),
        'tag-c': (1, 0),
        'tag-column-one': (0, 1),
        'tag-column-two': (0, 2),
      });

      await _selectMixedTableCell(tester, 'table-1', 1, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-row-up');
      expect(fillTargets(), {
        'row-c': 'table:0:0',
        'row-a': 'table:1:0',
        'column-one': 'table:1:1',
        'column-two': 'table:1:2',
      });
      expect(tagTargets(), {
        'tag-c': (0, 0),
        'tag-a': (1, 0),
        'tag-column-one': (1, 1),
        'tag-column-two': (1, 2),
      });

      await _selectMixedTableCell(tester, 'table-1', 1, 2);
      await _tapMixedRailButton(tester, 'note-mixed-rail-column-left');
      expect(fillTargets(), {
        'row-c': 'table:0:0',
        'row-a': 'table:1:0',
        'column-one': 'table:1:2',
        'column-two': 'table:1:1',
      });
      expect(tagTargets(), {
        'tag-c': (0, 0),
        'tag-a': (1, 0),
        'tag-column-one': (1, 2),
        'tag-column-two': (1, 1),
      });

      await _selectMixedTableCell(tester, 'table-1', 1, 2);
      await _tapMixedRailButton(tester, 'note-mixed-rail-delete-column');
      expect(fillTargets(), {
        'row-c': 'table:0:0',
        'row-a': 'table:1:0',
        'column-two': 'table:1:1',
      });
      expect(tagTargets(), {
        'tag-c': (0, 0),
        'tag-a': (1, 0),
        'tag-column-two': (1, 1),
      });

      await _selectMixedTableCell(tester, 'table-1', 0, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-add-row');
      await _selectMixedTableCell(tester, 'table-1', 0, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-add-column');
      expect(fillTargets(), {
        'row-c': 'table:0:0',
        'row-a': 'table:1:0',
        'column-two': 'table:1:1',
      });
      expect(tagTargets(), {
        'tag-c': (0, 0),
        'tag-a': (1, 0),
        'tag-column-two': (1, 1),
      });
    },
  );

  testWidgets(
    'table mutations keep row and column tags and dimensions aligned',
    (tester) async {
      NoteBlock? latest;
      const tag = NoteKnowledgeTag(
        type: NoteKnowledgeTagTypes.topic,
        label: 'meta',
      );
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
                ['A0', 'A1', 'A2'],
                ['B0', 'B1', 'B2'],
                ['C0', 'C1', 'C2'],
              ],
              tableRowHeights: [10, 20, 30],
              tableColumnWidths: [100, 200, 300],
              scopedTags: [
                NoteScopedTagAssignment(
                  id: 'row-0',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 0,
                  ),
                  tags: [tag],
                ),
                NoteScopedTagAssignment(
                  id: 'row-1',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 1,
                  ),
                  tags: [tag],
                ),
                NoteScopedTagAssignment(
                  id: 'row-2',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableRow,
                    rowIndex: 2,
                  ),
                  tags: [tag],
                ),
                NoteScopedTagAssignment(
                  id: 'column-0',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableColumn,
                    columnIndex: 0,
                  ),
                  tags: [tag],
                ),
                NoteScopedTagAssignment(
                  id: 'column-1',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableColumn,
                    columnIndex: 1,
                  ),
                  tags: [tag],
                ),
                NoteScopedTagAssignment(
                  id: 'column-2',
                  target: NoteTagTarget(
                    kind: NoteTagTargetKind.tableColumn,
                    columnIndex: 2,
                  ),
                  tags: [tag],
                ),
              ],
            ),
          ],
        ),
        onChanged: (block) => latest = block,
      );

      Map<String, (int?, int?)> targets() => {
        for (final assignment in latest!.mixedSections.single.scopedTags)
          assignment.id: (
            assignment.target.rowIndex,
            assignment.target.columnIndex,
          ),
      };

      await _selectMixedTableCell(tester, 'table-1', 1, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-delete-row');
      expect(latest!.mixedSections.single.tableRowHeights, [10, 30]);
      expect(targets()['row-0'], (0, null));
      expect(targets()['row-1'], isNull);
      expect(targets()['row-2'], (1, null));

      await _selectMixedTableCell(tester, 'table-1', 1, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-row-up');
      expect(latest!.mixedSections.single.tableRowHeights, [30, 10]);
      expect(targets()['row-2'], (0, null));
      expect(targets()['row-0'], (1, null));

      await _selectMixedTableCell(tester, 'table-1', 1, 2);
      await _tapMixedRailButton(tester, 'note-mixed-rail-column-left');
      expect(latest!.mixedSections.single.tableColumnWidths, [100, 300, 200]);
      expect(targets()['column-0'], (null, 0));
      expect(targets()['column-2'], (null, 1));
      expect(targets()['column-1'], (null, 2));

      await _selectMixedTableCell(tester, 'table-1', 1, 2);
      await _tapMixedRailButton(tester, 'note-mixed-rail-delete-column');
      expect(latest!.mixedSections.single.tableColumnWidths, [100, 300]);
      expect(targets()['column-1'], isNull);
      expect(targets()['column-2'], (null, 1));

      await _selectMixedTableCell(tester, 'table-1', 0, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-add-row');
      await _selectMixedTableCell(tester, 'table-1', 0, 0);
      await _tapMixedRailButton(tester, 'note-mixed-rail-add-column');
      expect(latest!.mixedSections.single.tableRowHeights, [30, 10, 52]);
      expect(latest!.mixedSections.single.tableColumnWidths, [100, 300, 150]);
    },
  );

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

Future<void> _selectMixedTableCell(
  WidgetTester tester,
  String sectionId,
  int row,
  int column,
) async {
  final cell = find.byKey(
    ValueKey('note-mixed-table-cell-$sectionId-$row-$column'),
  );
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

Future<void> _tapMixedRailButton(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
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
