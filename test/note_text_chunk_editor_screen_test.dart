import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  test(
    'text chunk editor screen does not route Android editing through WebView',
    () {
      final source = File(
        'lib/src/notes/ui/note_text_chunk_editor_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('NoteTextChunkWebEditor')));
      expect(source, isNot(contains('note_text_chunk_web_editor.dart')));
      expect(source, isNot(contains('_shouldUseWebEditor')));
      expect(
        File('pubspec.yaml').readAsStringSync(),
        isNot(contains('webview_flutter')),
      );
    },
  );

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

  testWidgets('text editor stays one native editable chunk across paragraphs', (
    tester,
  ) async {
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

    expect(find.byKey(const ValueKey('note-text-chunk-body')), findsOneWidget);
    final body = tester.widget<Container>(
      find.byKey(const ValueKey('note-text-chunk-body')),
    );
    expect(body.color, Colors.white);
    expect(find.byKey(const ValueKey('note-text-chunk-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-text-chunk-field-1')), findsNothing);
    expect(find.byKey(const ValueKey('note-text-web-editor')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-text-visual-selection-layout')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    expect(
      field.controller!.text,
      'Első bekezdés szövege.\n\nMásodik bekezdés szövege.',
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
    expect(
      find.byKey(const ValueKey('note-text-visual-selection-layout')),
      findsNothing,
    );
    final span = field.controller!.buildTextSpan(
      context: tester.element(
        find.byKey(const ValueKey('note-text-chunk-field')),
      ),
      style: const TextStyle(),
      withComposing: false,
    );
    expect(_containsWidgetSpan(span), isFalse);
  });

  testWidgets('tagged text remains visible when the selection rail is closed', (
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

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    expect(field.style!.color, isNot(Colors.transparent));
    expect(
      find.byKey(const ValueKey('note-text-visual-selection-layout')),
      findsNothing,
    );
  });

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
    expect(field.controller!.selection.isCollapsed, isTrue);
  });

  testWidgets('text range secondary tags render one underline per tag', (
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
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.symbol,
                    label: 'oxigén',
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

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-secondary-underline-range-1-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-secondary-underline-range-1-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-secondary-underline-range-1-3')),
      findsNothing,
    );
  });

  testWidgets('text editor keeps default line height', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Első sor\nMásodik sor',
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );

    expect(field.style!.height, isNull);
  });

  testWidgets('manual line breaks stay in one editable paragraph field', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Első sor\nMásodik sor',
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );

    expect(field.controller!.text, 'Első sor\nMásodik sor');
    expect(find.byKey(const ValueKey('note-text-chunk-field-1')), findsNothing);
  });

  testWidgets('empty line keeps paragraph split inside one text field', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Első bekezdés',
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('note-text-chunk-field')),
      'Első bekezdés\n\nMásodik bekezdés',
    );
    await tester.pump();

    expect(latest!.text, 'Első bekezdés\n\nMásodik bekezdés');
    expect(find.byKey(const ValueKey('note-text-chunk-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-text-chunk-field-1')), findsNothing);
  });

  testWidgets('non-empty text chunk does not autofocus on editor open', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Meglévő szöveg',
          ),
          onChanged: _ignoreBlockChange,
        ),
      ),
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );

    expect(field.autofocus, isFalse);
  });

  testWidgets('indent changes every manual row in the active paragraph', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Első sor\nMásodik sor\n\nMásik bekezdés',
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
    field.controller!.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-text-indent')));
    await tester.pump();

    expect(latest!.text, '  Első sor\n  Második sor\n\nMásik bekezdés');
  });

  testWidgets('text range coloring does not add native text decoration', (
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

    expect(_textDecorations(span), isNot(contains(TextDecoration.underline)));
  });

  testWidgets('overlapping text range tags merge into secondary underlines', (
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
                id: 'range-primary',
                start: 0,
                end: 6,
                tag: NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.state,
                  label: 'súlyos',
                  colorValue: 0xFFDC2626,
                ),
              ),
              NoteTextRangeTag(
                id: 'range-secondary-a',
                start: 0,
                end: 6,
                tag: NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.topic,
                  label: 'légzés',
                  colorValue: 0xFF2563EB,
                ),
              ),
              NoteTextRangeTag(
                id: 'range-secondary-b',
                start: 0,
                end: 6,
                tag: NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.symbol,
                  label: 'oxigén',
                  colorValue: 0xFF16A34A,
                ),
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
    field.controller!.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-primary-1'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('note-text-secondary-underline-range-primary-2'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'selection rail is inserted under the selected visual line inside the text field',
    (tester) async {
      const text =
          'Hdhjdjdjdjrj\n'
          'Hdjdjdjdjdj meg a par pixellel nagyobb meret is jo lenne ha nem '
          'lenne meg a par pixellel nagyobb meret is jo lenne ha nem lenne '
          'meg a par pixellel nagyobb';
      final start = text.indexOf('nem');
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        textScale: 1.6,
        surfaceSize: const Size(360, 960),
      );

      await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      field.controller!.selection = TextSelection(
        baseOffset: start,
        extentOffset: start + 3,
      );
      await tester.pumpAndSettle();

      final selectedRect = _editableSelectionRect(
        tester,
        TextSelection(baseOffset: start, extentOffset: start + 3),
      );
      final railRect = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );

      expect(railRect.top, greaterThanOrEqualTo(selectedRect.bottom + 8));
    },
  );

  testWidgets(
    'text chunk field expands on the canvas without inner scrolling',
    (tester) async {
      const text =
          'Hdhjdjdjdjrj\n'
          'Hdjdjdjdjdj meg a par pixellel nagyobb meret is jo lenne ha nem '
          'lenne meg a par pixellel nagyobb meret is jo lenne ha nem lenne '
          'meg a par pixellel nagyobb meret is jo lenne ha nem lenne meg a par '
          'pixellel nagyobb meret is jo lenne ha nem lenne meg a par pixellel '
          'nagyobb';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        textScale: 1.6,
        surfaceSize: const Size(360, 960),
      );

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      final fieldHeight = tester
          .getSize(find.byKey(const ValueKey('note-text-chunk-field')))
          .height;

      expect(field.scrollPhysics, isA<NeverScrollableScrollPhysics>());
      expect(fieldHeight, greaterThan(220));
    },
  );

  testWidgets('rail indent changes every manual row in the active paragraph', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteTextChunkEditorScreen(
          block: const NoteBlock(
            id: 'text-1',
            type: NoteBlockType.paragraph,
            text: 'Első sor\nMásodik sor\n\nMásik bekezdés',
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
      extentOffset: 4,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('note-text-selection-rail-indent')),
    );
    await tester.pump();

    expect(latest!.text, '  Első sor\n  Második sor\n\nMásik bekezdés');
  });

  testWidgets(
    'header indent changes every wrapped visual row in the paragraph',
    (tester) async {
      const text =
          'Elso bekezdes hosszu szovege ami biztosan tobb vizualis sorra torik '
          'a keskeny szerkesztoben es a masodik automatikus sor is ugyanahhoz '
          'a bekezdeshez tartozik.\n\nMasodik bekezdes marad.';
      NoteBlock? latest;
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        onChanged: (block) => latest = block,
        surfaceSize: const Size(320, 900),
      );
      final fieldRect = tester.getRect(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      final visualStarts = _visualLineStarts(
        text: text,
        maxWidth: fieldRect.width,
        paragraph: TextRange(start: 0, end: text.indexOf('\n\n')),
      );
      expect(visualStarts.length, greaterThan(1));

      await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );
      final wrappedLineStart = visualStarts[1];
      field.controller!.selection = TextSelection.collapsed(
        offset: wrappedLineStart,
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('note-text-indent')));
      await tester.pump();

      expect(latest!.text, _insertAtOffsets(text, visualStarts, '  '));
      expect(latest!.text.endsWith('\n\nMasodik bekezdes marad.'), isTrue);
    },
  );

  testWidgets('rail indent changes every wrapped visual row in the paragraph', (
    tester,
  ) async {
    const text =
        'Elso bekezdes hosszu szovege ami biztosan tobb vizualis sorra torik '
        'a keskeny szerkesztoben es a masodik automatikus sor is ugyanahhoz '
        'a bekezdeshez tartozik.\n\nMasodik bekezdes marad.';
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      onChanged: (block) => latest = block,
      surfaceSize: const Size(320, 900),
    );
    final fieldRect = tester.getRect(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    final visualStarts = _visualLineStarts(
      text: text,
      maxWidth: fieldRect.width,
      paragraph: TextRange(start: 0, end: text.indexOf('\n\n')),
    );
    expect(visualStarts.length, greaterThan(1));

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = TextSelection(
      baseOffset: visualStarts[1],
      extentOffset: visualStarts[1] + 4,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-text-selection-rail-indent')),
    );
    await tester.pump();

    expect(latest!.text, _insertAtOffsets(text, visualStarts, '  '));
    expect(latest!.text.endsWith('\n\nMasodik bekezdes marad.'), isTrue);
  });

  testWidgets('secondary underline marker matches the tagged word width', (
    tester,
  ) async {
    const text =
        'Hdhjdjdjdjrj\n'
        'Hdjdjdjdjdj meg a par pixellel nagyobb meret is jo lenne ha nem '
        'lenne meg a par pixellel nagyobb';
    final start = text.indexOf('nem');
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: text,
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-word',
            start: start,
            end: start + 3,
            tag: const NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'primary',
              colorValue: 0xFFDC2626,
            ),
            tags: const [
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'primary',
                colorValue: 0xFFDC2626,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.topic,
                label: 'secondary',
                colorValue: 0xFF2563EB,
              ),
            ],
          ),
        ],
      ),
      textScale: 1.6,
      surfaceSize: const Size(360, 960),
    );
    await tester.pumpAndSettle();

    final targetRect = _editableSelectionRect(
      tester,
      TextSelection(baseOffset: start, extentOffset: start + 3),
    );
    final markerRect = tester.getRect(
      find.byKey(const ValueKey('note-text-secondary-underline-range-word-1')),
    );

    expect(markerRect.left, closeTo(targetRect.left, 5));
    expect(markerRect.width, closeTo(targetRect.width, 5));
  });

  testWidgets('stacked secondary underlines leave room before the next line', (
    tester,
  ) async {
    const text = 'Alpha beta gamma\nNext line starts here';
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: text,
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-many',
            start: 0,
            end: 5,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.state,
              label: 'primary',
              colorValue: 0xFFDC2626,
            ),
            tags: [
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'primary',
                colorValue: 0xFFDC2626,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.topic,
                label: 'secondary-a',
                colorValue: 0xFF2563EB,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.symbol,
                label: 'secondary-b',
                colorValue: 0xFF16A34A,
              ),
              NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.custom,
                label: 'secondary-c',
                colorValue: 0xFF7C3AED,
              ),
            ],
          ),
        ],
      ),
      textScale: 1.6,
      surfaceSize: const Size(360, 960),
    );
    await tester.pumpAndSettle();

    final lastMarkerRect = tester.getRect(
      find.byKey(const ValueKey('note-text-secondary-underline-range-many-3')),
    );
    final nextLineRect = _editableSelectionRect(
      tester,
      const TextSelection(baseOffset: 17, extentOffset: 21),
    );

    expect(nextLineRect.top, greaterThanOrEqualTo(lastMarkerRect.bottom + 6));
  });

  testWidgets(
    'stacked secondary underlines reserve line space without global line height',
    (tester) async {
      final plainHeight = await _pumpTextFieldHeight(
        tester,
        const NoteBlock(
          id: 'plain',
          type: NoteBlockType.paragraph,
          text: 'Alpha beta\nGamma delta',
        ),
      );
      final taggedHeight = await _pumpTextFieldHeight(
        tester,
        const NoteBlock(
          id: 'tagged',
          type: NoteBlockType.paragraph,
          text: 'Alpha beta\nGamma delta',
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-many',
              start: 0,
              end: 5,
              tag: NoteKnowledgeTag(
                type: NoteKnowledgeTagTypes.state,
                label: 'primary',
                colorValue: 0xFFDC2626,
              ),
              tags: [
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.state,
                  label: 'primary',
                  colorValue: 0xFFDC2626,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.topic,
                  label: 'secondary-a',
                  colorValue: 0xFF2563EB,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.symbol,
                  label: 'secondary-b',
                  colorValue: 0xFF16A34A,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.custom,
                  label: 'secondary-c',
                  colorValue: 0xFF7C3AED,
                ),
              ],
            ),
          ],
        ),
      );

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-text-chunk-field')),
      );

      expect(field.style!.height, isNull);
      expect(taggedHeight, greaterThan(plainHeight + 8));
    },
  );
}

void _ignoreBlockChange(NoteBlock block) {}

Future<double> _pumpTextFieldHeight(
  WidgetTester tester,
  NoteBlock block,
) async {
  await _pumpTextChunkEditor(tester, block);
  await tester.pumpAndSettle();
  return tester
      .getSize(find.byKey(const ValueKey('note-text-chunk-field')))
      .height;
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock> onChanged = _ignoreBlockChange,
  double textScale = 1,
  Size surfaceSize = const Size(800, 600),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: surfaceSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: NoteTextChunkEditorScreen(block: block, onChanged: onChanged),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Rect _editableSelectionRect(WidgetTester tester, TextSelection selection) {
  final editableState = tester.state<EditableTextState>(
    find.descendant(
      of: find.byKey(const ValueKey('note-text-chunk-field')),
      matching: find.byType(EditableText),
    ),
  );
  final renderEditable = editableState.renderEditable;
  final boxes = renderEditable.getBoxesForSelection(selection);
  expect(boxes, isNotEmpty);
  final box = boxes.first;
  final localRect = Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
  return renderEditable.localToGlobal(localRect.topLeft) & localRect.size;
}

List<int> _visualLineStarts({
  required String text,
  required double maxWidth,
  required TextRange paragraph,
  double textScale = 1,
}) {
  final painter = TextPainter(
    text: const TextSpan(
      text: '',
      style: TextStyle(color: Color(0xFF111827), fontSize: 16),
    ),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(textScale),
  );
  painter.text = TextSpan(
    text: text,
    style: const TextStyle(color: Color(0xFF111827), fontSize: 16),
  );
  painter.layout(maxWidth: maxWidth);
  final starts = <int>{};
  for (final line in painter.computeLineMetrics()) {
    final centerY = line.baseline + ((line.descent - line.ascent) / 2);
    final position = painter.getPositionForOffset(Offset(0, centerY));
    final boundary = painter.getLineBoundary(position);
    final start = boundary.start.clamp(paragraph.start, paragraph.end).toInt();
    final end = boundary.end.clamp(paragraph.start, paragraph.end).toInt();
    if (start < end) {
      starts.add(start);
    }
  }
  return starts.toList()..sort();
}

String _insertAtOffsets(String text, List<int> offsets, String insertion) {
  final buffer = StringBuffer();
  var cursor = 0;
  for (final offset in offsets) {
    buffer
      ..write(text.substring(cursor, offset))
      ..write(insertion);
    cursor = offset;
  }
  buffer.write(text.substring(cursor));
  return buffer.toString();
}

bool _containsWidgetSpan(InlineSpan span) {
  if (span is WidgetSpan) {
    return true;
  }
  if (span is TextSpan) {
    return span.children?.any(_containsWidgetSpan) ?? false;
  }
  return false;
}

List<TextDecoration?> _textDecorations(InlineSpan span) {
  final decorations = <TextDecoration?>[];
  if (span is TextSpan) {
    decorations.add(span.style?.decoration);
    for (final child in span.children ?? const <InlineSpan>[]) {
      decorations.addAll(_textDecorations(child));
    }
  }
  return decorations;
}
