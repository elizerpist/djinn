import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  setUp(DebugConsole.clear);

  testWidgets('renders one plain TextField baseline and no textchunk runtime', (
    tester,
  ) async {
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
        text: 'Alpha Beta\nGamma',
      ),
    );

    expect(find.byKey(const ValueKey('note-text-plain-field')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('plain TextField starts with block text and emits text changes', (
    tester,
  ) async {
    NoteBlock? latest;
    await _pumpTextChunkEditor(
      tester,
      const NoteBlock(
        id: 'text-1',
        type: NoteBlockType.paragraph,
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
      find.byKey(const ValueKey('note-text-plain-field')),
      'New plain text',
    );
    await tester.pump();

    expect(latest?.text, 'New plain text');
    expect(latest?.rangeTags, isEmpty);
    expect(latest?.paragraphStyles, isEmpty);
    expect(DebugConsole.allText, isNot(contains('[TextChunk')));
  });
}

Future<void> _pumpTextChunkEditor(
  WidgetTester tester,
  NoteBlock block, {
  ValueChanged<NoteBlock>? onChanged,
}) async {
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
