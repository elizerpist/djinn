import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_list_chunk_editor_screen.dart';

void main() {
  testWidgets('list editor autosaves item edits and new rows', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [NoteListItem(id: 'item-1', text: 'Régi')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-list-item-item-1')),
      'Első pont',
    );
    await tester.pump();
    expect(latest!.listItems.first.text, 'Első pont');

    await tester.tap(find.byKey(const ValueKey('note-list-header-add-item')));
    await tester.pumpAndSettle();
    expect(latest!.listItems, hasLength(2));
    expect(find.byKey(const ValueKey('note-list-add-item')), findsNothing);
  });

  testWidgets('list editor autosaves editable list title', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            title: 'Régi lista',
            listItems: [NoteListItem(id: 'item-1', text: 'Első')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('note-list-title-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('note-chunk-title-field')),
      'Felszerelés lista',
    );
    await tester.pump();

    expect(latest, isNotNull);
    expect(latest!.title, 'Felszerelés lista');
    expect(latest!.plainText, startsWith('Felszerelés lista'));
  });

  testWidgets('list editor tags the selected item through the shared menu', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [NoteListItem(id: 'item-1', text: 'High flow oxygen')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-list-row-item-1')));
    await tester.pumpAndSettle();
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
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'légzési elégtelenség',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.listItems.first.tags.map((tag) => tag.label), [
      'súlyos',
      'légzési elégtelenség',
    ]);
    expect(
      find.byKey(const ValueKey('note-list-item-tag-highlight-item-1')),
      findsOneWidget,
    );
    final highlightWrapper = tester.widget<Container>(
      find.byKey(const ValueKey('note-list-item-tag-highlight-item-1')),
    );
    final highlightDecoration = highlightWrapper.decoration as BoxDecoration?;
    expect(highlightDecoration?.color, isNull);
    final highlightedField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('note-list-item-tag-highlight-item-1')),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      highlightedField.style.backgroundColor,
      const Color(0xFF2563EB).withValues(alpha: 0.22),
    );
    expect(
      find.byKey(const ValueKey('note-list-item-tag-pill-item-1-súlyos')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-list-item-tags-item-1')),
      findsNothing,
    );
  });

  testWidgets(
    'list item tap selects the card and opens the inline action rail',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: NoteListChunkEditorScreen(
            block: const NoteBlock(
              id: 'list-1',
              type: NoteBlockType.listItem,
              listItems: [NoteListItem(id: 'item-1', text: 'High flow oxygen')],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-list-row-item-1')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-list-item-select-item-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-selection-action-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('note-selection-action-rail-bottom-borderless'),
        ),
        findsOneWidget,
      );
      final card = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('note-list-item-card-item-1')),
      );
      final decoration = card.decoration as BoxDecoration;
      final border = decoration.border! as Border;
      expect(border.top.color, const Color(0xFFE5E7EB));
      expect(border.top.width, 1);
      final rail = tester.widget<Material>(
        find.byKey(const ValueKey('note-selection-action-rail')),
      );
      expect(rail.color, Colors.white);
      expect(rail.elevation, 0);
      expect(
        find.byKey(const ValueKey('note-selection-action-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-selection-pill-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-selection-empty-tags')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-tag-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-clear-tags-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-prev-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-next-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-outdent-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-indent-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-delete-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-toggle-rounded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-toggle-transparent')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-rail-toggle-border')),
        findsOneWidget,
      );
    },
  );

  testWidgets('list item secondary tags render as underline styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteListChunkEditorScreen(
          block: NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [
              NoteListItem(
                id: 'item-1',
                text: 'High flow oxygen',
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
        of: find.byKey(const ValueKey('note-list-item-tag-highlight-item-1')),
        matching: find.byType(EditableText),
      ),
    );

    expect(
      field.style.backgroundColor,
      const Color(0xFFDC2626).withValues(alpha: 0.22),
    );
    expect(field.style.decoration, TextDecoration.none);
    expect(
      find.byKey(
        const ValueKey('note-list-item-item-1-secondary-underline-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('note-list-item-item-1-secondary-underline-2'),
      ),
      findsNothing,
    );
  });

  testWidgets('list item submit creates and focuses a new row below', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteListChunkEditorScreen(
          block: const NoteBlock(
            id: 'list-1',
            type: NoteBlockType.listItem,
            listItems: [NoteListItem(id: 'item-1', text: 'High flow oxygen')],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-list-item-item-1')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.listItems, hasLength(2));
    expect(latest!.listItems.last.text, isEmpty);
    expect(
      find.byKey(ValueKey('note-list-item-${latest!.listItems.last.id}')),
      findsOneWidget,
    );
    final newItemEditor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey('note-list-item-${latest!.listItems.last.id}')),
        matching: find.byType(EditableText),
      ),
    );
    expect(newItemEditor.focusNode.hasFocus, isTrue);
  });

  testWidgets(
    'list menu switches between checkbox and dynamic hierarchy layout',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteListChunkEditorScreen(
            block: const NoteBlock(
              id: 'list-1',
              type: NoteBlockType.listItem,
              listItems: [
                NoteListItem(id: 'i1', text: 'Mother one'),
                NoteListItem(id: 'i2', text: 'Child', level: 1),
                NoteListItem(id: 'i3', text: 'Mother two'),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-list-menu-layout-checkbox')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-list-menu-layout-hierarchy')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('note-list-menu-layout-hierarchy')),
      );
      await tester.pumpAndSettle();

      expect(latest!.listLayoutMode, NoteListLayoutMode.hierarchy);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i1')))
            .data,
        '1.',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i2')))
            .data,
        '-',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i3')))
            .data,
        '2.',
      );

      await tester.tap(find.byKey(const ValueKey('note-list-row-i2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('note-list-rail-outdent-i2')));
      await tester.pumpAndSettle();

      expect(latest!.listItems[1].level, 0);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i1')))
            .data,
        '1.',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i2')))
            .data,
        '2.',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('note-list-marker-i3')))
            .data,
        '3.',
      );
    },
  );
}

void _ignoreBlockChange(NoteBlock block) {}
