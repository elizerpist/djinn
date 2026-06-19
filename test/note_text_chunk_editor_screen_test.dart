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
    expect(find.byKey(const ValueKey('note-text-tip-bar')), findsNothing);
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

  testWidgets(
    'text editor keeps one white text surface and exposes style toggles',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoteTextChunkEditorScreen(
            block: NoteBlock(
              id: 'text-1',
              type: NoteBlockType.paragraph,
              text: 'Első bekezdés szövege.\n\nMásodik bekezdés szövege.',
            ),
            onChanged: _ignoreBlockChange,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('note-text-chunk-body')),
        findsOneWidget,
      );
      final body = tester.widget<Container>(
        find.byKey(const ValueKey('note-text-chunk-body')),
      );
      expect(body.color, Colors.white);
      expect(
        find.byKey(const ValueKey('note-text-paragraph-box-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-paragraph-box-1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-text-chunk-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-text-chunk-field-1')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 4,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-text-selection-rail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-text-rail-toggle-transparent')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-text-rail-toggle-border')),
        findsOneWidget,
      );
      final span = field.controller!.buildTextSpan(
        context: tester.element(
          find.byKey(const ValueKey('note-text-chunk-field')),
        ),
        style: const TextStyle(),
        withComposing: false,
      );
      expect(_containsWidgetSpan(span), isTrue);
      final inlineChildren = span.children!;
      final railIndex = inlineChildren.indexWhere(
        (child) => child is WidgetSpan,
      );
      expect(railIndex, greaterThan(0));
      expect((inlineChildren[railIndex - 1] as TextSpan).text, endsWith('\n'));
    },
  );

  testWidgets('tap inside an existing tagged range opens the selection rail', (
    tester,
  ) async {
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

    await tester.tapAt(
      tester.getTopLeft(find.byKey(const ValueKey('note-text-chunk-field'))) +
          const Offset(24, 24),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-selection-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-rail-pill-súlyos')),
      findsOneWidget,
    );
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    expect(field.controller!.selection.baseOffset, 0);
    expect(field.controller!.selection.extentOffset, 6);
  });

  testWidgets('text range secondary tags render as underline styling', (
    tester,
  ) async {
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

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    final span = field.controller!.buildTextSpan(
      context: tester.element(
        find.byKey(const ValueKey('note-text-chunk-field')),
      ),
      style: const TextStyle(),
      withComposing: false,
    );
    final taggedSpan =
        span.children!.firstWhere((child) => child.toPlainText() == 'Súlyos')
            as TextSpan;

    expect(taggedSpan.style!.backgroundColor, isNotNull);
    expect(taggedSpan.style!.decoration, TextDecoration.underline);
    expect(taggedSpan.style!.decorationColor, const Color(0xFF2563EB));
  });
}

void _ignoreBlockChange(NoteBlock block) {}

bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) {
    return true;
  }
  if (span is TextSpan) {
    return span.children?.any(_containsWidgetSpan) ?? false;
  }
  return false;
}
