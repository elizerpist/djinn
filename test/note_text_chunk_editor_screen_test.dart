import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('single-line selection inserts the rail below that visual line', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    final line0 = tester.getRect(
      find.byKey(const ValueKey('note-text-line-0')),
    );
    final line1 = tester.getRect(
      find.byKey(const ValueKey('note-text-line-1')),
    );
    final rail = tester.getRect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
    );

    expect(rail.top, greaterThanOrEqualTo(line0.bottom));
    expect(line1.top, greaterThanOrEqualTo(rail.bottom));
  });

  testWidgets(
    'rail gap pushes the actual native editable text below the rail',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 4),
      );
      await tester.pumpAndSettle();

      final alpha = _nativeEditableSubstringRect(tester, 'Alpha');
      final beta = _nativeEditableSubstringRect(tester, 'Beta');
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );

      expect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
        findsOneWidget,
      );
      final spacer = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-spacer')),
      );
      expect(spacer.height, greaterThanOrEqualTo(160));

      expect(rail.top, greaterThanOrEqualTo(alpha.bottom));
      expect(beta.top, greaterThanOrEqualTo(rail.bottom));
    },
  );

  testWidgets('textchunk layout writes detailed debug geometry logs', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    expect(DebugConsole.allText, contains('[TextChunkLayout] textLen='));
    expect(DebugConsole.allText, contains('selection=1-4'));
    expect(DebugConsole.allText, contains('railLine=0'));
    expect(DebugConsole.allText, contains('placeholderCount=7'));
    expect(DebugConsole.allText, contains('[TextChunkLayout] nativeGeometry'));
    expect(DebugConsole.allText, contains('placeholderDelta=7'));
  });

  testWidgets(
    'multi-line selection inserts the rail below the lowest selected visual line',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 1, extentOffset: 8),
      );
      await tester.pumpAndSettle();

      final line1 = tester.getRect(
        find.byKey(const ValueKey('note-text-line-1')),
      );
      final line2 = tester.getRect(
        find.byKey(const ValueKey('note-text-line-2')),
      );
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );

      expect(rail.top, greaterThanOrEqualTo(line1.bottom));
      expect(line2.top, greaterThanOrEqualTo(rail.bottom));
    },
  );

  testWidgets(
    'continuous selection spans paragraphs and anchors rail at the last line',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\nBeta\n\nGamma',
        ),
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 0, extentOffset: 17),
      );
      await tester.pumpAndSettle();

      final editable = tester.widget<EditableText>(
        find.byKey(const ValueKey('note-text-input-bridge')),
      );
      expect(editable.controller.selection.start, lessThan(5));
      expect(editable.controller.selection.end, greaterThan(12));
      final rail = tester.getRect(
        find.byKey(const ValueKey('note-text-inline-selection-rail')),
      );
      final selectedLine = tester.getRect(
        find.byKey(const ValueKey('note-text-line-3')),
      );
      expect(rail.top, greaterThanOrEqualTo(selectedLine.bottom));
    },
  );

  testWidgets(
    'collapsed selection is owned by the visible native EditableText',
    (tester) async {
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha\n\n',
        ),
      );

      _setEditorSelection(tester, const TextSelection.collapsed(offset: 7));
      await tester.pumpAndSettle();

      final editableRect = tester.getRect(
        find.byKey(const ValueKey('note-text-input-bridge')),
      );
      final editable = tester.widget<EditableText>(
        find.byKey(const ValueKey('note-text-input-bridge')),
      );

      expect(editableRect.height, greaterThan(20));
      expect(editable.focusNode.hasFocus, isTrue);
      expect(editable.controller.selection.isCollapsed, isTrue);
      expect(editable.selectionControls, isNotNull);
      expect(editable.contextMenuBuilder, isNotNull);
      expect(find.byKey(const ValueKey('note-text-line-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-line-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-line-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('note-text-caret-2')), findsNothing);
    },
  );

  testWidgets('selected range uses the native editable selection path', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    final editableRect = tester.getRect(
      find.byKey(const ValueKey('note-text-input-bridge')),
    );
    final editable = tester.widget<EditableText>(
      find.byKey(const ValueKey('note-text-input-bridge')),
    );

    expect(editableRect.height, greaterThan(20));
    expect(editable.showSelectionHandles, isTrue);
    expect(editable.selectionControls, isNotNull);
    expect(editable.selectionControls, isA<TextSelectionHandleControls>());
    expect(editable.contextMenuBuilder, isNotNull);
    final editableState = tester.state<EditableTextState>(
      find.byKey(const ValueKey('note-text-input-bridge')),
    );
    expect(
      editableState.contextMenuButtonItems.map((item) => item.type),
      contains(ContextMenuButtonType.copy),
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-handle-start')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-text-selection-handle-end')),
      findsNothing,
    );
    expect(editable.controller.selection.start, 6);
    expect(editable.controller.selection.end, 10);
  });

  testWidgets('long text scrolls without clipping the final line', (
    tester,
  ) async {
    final text = List.generate(40, (index) => 'Line $index').join('\n');
    await _pumpTextChunkEditor(
      tester,
      NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      surfaceSize: const Size(360, 480),
    );

    expect(find.byKey(const ValueKey('note-text-line-39')), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('note-text-scroll')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const ValueKey('note-text-line-39'))).bottom,
      lessThanOrEqualTo(480),
    );
  });

  testWidgets(
    'rail tag button saves primary and secondary tags to the selected range',
    (tester) async {
      NoteBlock? latest;
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: 'Alpha Beta Gamma',
        ),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 6, extentOffset: 10),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-text-selection-rail-tag')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tag-manager-name')),
        'primary',
      );
      await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('tag-manager-name')),
        'secondary',
      );
      await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.rangeTags, hasLength(1));
      expect(latest!.rangeTags.single.start, 6);
      expect(latest!.rangeTags.single.end, 10);
      expect(latest!.rangeTags.single.resolvedTags.map((tag) => tag.label), [
        'primary',
        'secondary',
      ]);
    },
  );

  testWidgets('tapping text after tagging focuses input and shows caret', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      onChanged: (block) => latest = block,
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-text-selection-rail-tag')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'primary',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest!.rangeTags, hasLength(1));
    await tester.tapAt(_nativeEditableSubstringRect(tester, 'Alpha').center);
    await tester.pumpAndSettle();

    final editable = tester.widget<EditableText>(
      find.byKey(const ValueKey('note-text-input-bridge')),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(editable.controller.selection.isCollapsed, isTrue);
    expect(find.byKey(const ValueKey('note-text-caret-0')), findsNothing);
  });

  testWidgets('rail is hosted by the native editable text layout', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha\nBeta\nGamma',
      ),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 1, extentOffset: 4),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-native-editable-layout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-inline-selection-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-custom-visible-layout')),
      findsNothing,
    );
  });

  testWidgets(
    'primary highlight and secondary underlines are scoped to tagged text',
    (tester) async {
      const text = 'Alpha Beta Gamma';
      final betaStart = text.indexOf('Beta');
      await _pumpTextChunkEditor(
        tester,
        NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
          rangeTags: [
            NoteTextRangeTag(
              id: 'range-beta',
              start: betaStart,
              end: betaStart + 4,
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
                  label: 'secondary-a',
                  colorValue: 0xFF2563EB,
                ),
                NoteKnowledgeTag(
                  type: NoteKnowledgeTagTypes.custom,
                  label: 'secondary-b',
                  colorValue: 0xFF059669,
                ),
              ],
            ),
          ],
        ),
      );

      final highlight = tester.getRect(
        find.byKey(
          const ValueKey('note-text-primary-highlight-range-beta-0-1'),
        ),
      );
      final firstUnderline = tester.getRect(
        find.byKey(
          const ValueKey('note-text-secondary-underline-range-beta-1-0-1'),
        ),
      );
      final secondUnderline = tester.getRect(
        find.byKey(
          const ValueKey('note-text-secondary-underline-range-beta-2-0-1'),
        ),
      );

      expect(firstUnderline.left, closeTo(highlight.left, 1));
      expect(firstUnderline.width, closeTo(highlight.width, 1));
      expect(secondUnderline.top, greaterThan(firstUnderline.top));
    },
  );

  testWidgets(
    'rail paragraph step indents every visual line in the active paragraph',
    (tester) async {
      NoteBlock? latest;
      const text =
          'Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda\n'
          'manual continuation\n\n'
          'Next paragraph';
      await _pumpTextChunkEditor(
        tester,
        const NoteBlock(
          id: 'text-1',
          type: NoteBlockType.paragraph,
          text: text,
        ),
        surfaceSize: const Size(320, 700),
        onChanged: (block) => latest = block,
      );

      _setEditorSelection(
        tester,
        const TextSelection(baseOffset: 2, extentOffset: 6),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-text-selection-rail-indent')),
      );
      await tester.pumpAndSettle();

      expect(latest!.text.startsWith('  Alpha'), isTrue);
      expect(latest!.text.endsWith('\n\nNext paragraph'), isTrue);
      final firstParagraphLines = tester
          .widgetList<Padding>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Padding &&
                  widget.key.toString().contains('note-text-line-indent-') &&
                  widget.padding.resolve(TextDirection.ltr).left > 0,
            ),
          )
          .length;
      expect(firstParagraphLines, greaterThan(1));
    },
  );

  testWidgets('text rail exposes table-like design toggles and scroll row', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      surfaceSize: const Size(260, 700),
    );

    _setEditorSelection(
      tester,
      const TextSelection(baseOffset: 6, extentOffset: 10),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-selection-action-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-white')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
    );
    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-rounded')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-grey')),
    );
    await tester.tap(find.byKey(const ValueKey('note-text-rail-toggle-grey')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-grey')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('note-text-rail-toggle-border')),
    );
    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-border')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-borderless')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  Size surfaceSize = const Size(420, 900),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surfaceSize;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: NoteTextChunkEditorScreen(
        block: block,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _setEditorSelection(WidgetTester tester, TextSelection selection) {
  final editable = tester.widget<EditableText>(
    find.byKey(const ValueKey('note-text-input-bridge')),
  );
  editable.controller.selection = selection;
  editable.focusNode.requestFocus();
}

Rect _nativeEditableSelectionRect(
  WidgetTester tester,
  TextSelection selection,
) {
  final state = tester.state<EditableTextState>(
    find.byKey(const ValueKey('note-text-input-bridge')),
  );
  final renderEditable = state.renderEditable;
  final boxes = renderEditable.getBoxesForSelection(selection);
  expect(boxes, isNotEmpty);
  final localRect = boxes
      .map((box) => box.toRect())
      .reduce((value, element) => value.expandToInclude(element));
  final topLeft = renderEditable.localToGlobal(Offset.zero);
  return localRect.shift(topLeft);
}

Rect _nativeEditableSubstringRect(WidgetTester tester, String text) {
  final state = tester.state<EditableTextState>(
    find.byKey(const ValueKey('note-text-input-bridge')),
  );
  final plainText = state.renderEditable.text!.toPlainText();
  final start = plainText.indexOf(text);
  expect(start, isNonNegative);
  return _nativeEditableSelectionRect(
    tester,
    TextSelection(baseOffset: start, extentOffset: start + text.length),
  );
}
