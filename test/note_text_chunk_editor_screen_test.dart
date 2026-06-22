import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('renders shared header and one plain TextField surface', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        title: 'Jegyzet szakasz',
        text: 'Alpha Beta\nGamma',
      ),
    );

    expect(
      find.byKey(const ValueKey('note-chunk-title-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-chunk-global-tag')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note-text-header-outdent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-header-indent')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-text-plain-field')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note-text-chunk-body')),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
    );
  });

  testWidgets('header title and text changes autosave without textchunk logs', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        title: 'Original title',
        text: 'Original text',
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-1',
            start: 0,
            end: 8,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Old tag',
            ),
          ),
        ],
        paragraphStyles: [
          NoteTextParagraphStyle(id: 'p-1', start: 0, end: 13, level: 3),
        ],
      ),
      onChanged: (block) => latest = block,
    );

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-plain-field')),
    );
    expect(field.controller?.text, 'Original text');

    await tester.enterText(
      find.byKey(const ValueKey('note-chunk-title-field')),
      'Updated title',
    );
    await tester.pump();
    expect(latest?.title, 'Updated title');

    await tester.enterText(
      find.byKey(const ValueKey('note-text-plain-field')),
      'New plain text',
    );
    await tester.pump();

    expect(latest?.text, 'New plain text');
    expect(DebugConsole.allText, isNot(contains('[TextChunk')));
  });

  testWidgets('keyboard rail appears above keyboard only for selected text', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
      ),
      viewInsets: const EdgeInsets.only(bottom: 240),
    );

    expect(find.byKey(const ValueKey('note-text-keyboard-rail')), findsNothing);

    final controller = _plainFieldController(tester);
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-keyboard-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-selection-action-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-selection-action-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-selection-pill-row')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-text-rail-tag')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note-text-rail-outdent')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-text-rail-indent')), findsOneWidget);
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

    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-rounded')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-rounded')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-transparent')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-grey')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-text-rail-toggle-border')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-selection-action-rail-borderless')),
      findsOneWidget,
    );

    final padding = tester.widget<AnimatedPadding>(
      find.byKey(const ValueKey('note-text-keyboard-rail-padding')),
    );
    expect(padding.padding.resolve(TextDirection.ltr).bottom, 240);

    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-text-keyboard-rail')), findsNothing);
  });

  testWidgets('collapsed cursor inside tagged range also shows keyboard rail', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta Gamma',
        rangeTags: [
          NoteTextRangeTag(
            id: 'range-1',
            start: 6,
            end: 10,
            tag: NoteKnowledgeTag(
              type: NoteKnowledgeTagTypes.topic,
              label: 'Beta',
              colorValue: 0xFF2563EB,
            ),
          ),
        ],
      ),
    );

    _plainFieldController(tester).selection = const TextSelection.collapsed(
      offset: 8,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-text-keyboard-rail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-text-rail-pill-Beta')),
      findsOneWidget,
    );
  });

  testWidgets('rail tag action saves selected text range tags', (tester) async {
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

    _plainFieldController(tester).selection = const TextSelection(
      baseOffset: 6,
      extentOffset: 10,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-text-rail-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'Beta',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest?.text, 'Alpha Beta Gamma');
    expect(latest?.rangeTags, hasLength(1));
    expect(latest?.rangeTags.single.start, 6);
    expect(latest?.rangeTags.single.end, 10);
    expect(latest?.rangeTags.single.resolvedTags.single.label, 'Beta');
    expect(
      find.byKey(const ValueKey('note-text-rail-pill-Beta')),
      findsOneWidget,
    );
  });

  testWidgets('header global tag action saves chunk tags', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('note-chunk-global-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'fontos',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest?.tags.map((tag) => tag.label), ['fontos']);
  });

  testWidgets('step buttons update paragraph metadata without mutating text', (
    tester,
  ) async {
    NoteBlock? latest;
    const text = 'First paragraph\nStill first\n\nSecond paragraph';
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(id: 'text-1', type: NoteBlockType.paragraph, text: text),
      onChanged: (block) => latest = block,
    );

    _plainFieldController(tester).selection = const TextSelection(
      baseOffset: 2,
      extentOffset: 28,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-text-rail-indent')));
    await tester.pumpAndSettle();

    expect(latest?.text, text);
    expect(latest?.paragraphStyles, hasLength(1));
    expect(latest?.paragraphStyles.single.start, 0);
    expect(latest?.paragraphStyles.single.end, 27);
    expect(latest?.paragraphStyles.single.level, 1);

    await tester.tap(find.byKey(const ValueKey('note-text-rail-outdent')));
    await tester.pumpAndSettle();
    expect(latest?.text, text);
    expect(latest?.paragraphStyles, isEmpty);
  });
}

TextEditingController _plainFieldController(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('note-text-plain-field')),
  );
  return field.controller!;
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          viewInsets: viewInsets,
        ),
        child: NoteTextChunkEditorScreen(
          block: block,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
