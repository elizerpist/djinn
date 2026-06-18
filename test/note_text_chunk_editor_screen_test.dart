import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  testWidgets('selected text can be tagged as a highlighted range', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Súlyos esetben high flow oxygen.',
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('note-text-selection-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-rail-tag')),
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
    expect(latest!.rangeTags, hasLength(1));
    expect(latest!.rangeTags.single.start, 0);
    expect(latest!.rangeTags.single.end, 6);
    expect(latest!.rangeTags.single.tag.label, 'súlyos');
    expect(
      find.byKey(const ValueKey('note-local-tag-pill-súlyos')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-range-highlight')),
      findsWidgets,
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-text-chunk-field')),
      'Nagyon Súlyos esetben high flow oxygen.',
    );
    await tester.pump();

    expect(latest!.rangeTags.single.start, 7);
    expect(latest!.rangeTags.single.end, 13);
  });

  testWidgets('text editor shows global tag capsules and local range pills', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            title: 'Régi cím',
            text: 'Súlyos esetben high flow oxygen.',
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-chunk-title-field')),
      'Új szöveg cím',
    );
    await tester.pump();
    expect(latest!.title, 'Új szöveg cím');

    await tester.tap(find.byKey(const ValueKey('note-chunk-global-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'légzés',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest!.tags.single.label, 'légzés');
    expect(
      find.byKey(const ValueKey('note-global-tag-pill-légzés')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 6,
    );
    await tester.pump();
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

    expect(
      latest!.rangeTags.single.tags.map((tag) => tag.label),
      contains('súlyos'),
    );
    expect(
      find.byKey(const ValueKey('note-local-tag-pill-súlyos')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('note-text-tip-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-text-tag-selection')), findsNothing);
  });

  testWidgets(
    'selected tag deletion menu updates when text selection overlaps a range tag',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoteTextChunkEditorScreen(
            block: NoteBlock(
              id: 'text-1',
              type: NoteBlockType.paragraph,
              text: 'Súlyos esetben high flow oxygen.',
              rangeTags: [
                NoteTextRangeTag(
                  id: 'range-1',
                  start: 0,
                  end: 6,
                  tag: NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.state,
                    label: 'súlyos',
                    colorValue: 0xFFDC2626,
                  ),
                ),
              ],
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
      await tester.pumpAndSettle();

      final deleteItem = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('note-chunk-menu-delete-selected-tag')),
      );
      expect(deleteItem.enabled, isTrue);
    },
  );

  testWidgets('caret inside a tagged text range opens the selection rail', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Súlyos esetben high flow oxygen.',
            rangeTags: [
              NoteTextRangeTag(
                id: 'range-1',
                start: 0,
                end: 6,
                tag: NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.state,
                  label: 'súlyos',
                  colorValue: 0xFFDC2626,
                ),
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('note-text-selection-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-rail-pill-súlyos')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-text-selection-rail-clear-tags')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.rangeTags, isEmpty);
  });
}

void _ignoreBlockChange(NoteBlock block) {}
