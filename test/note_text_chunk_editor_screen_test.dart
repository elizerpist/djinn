import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_text_chunk_editor_screen.dart';

void main() {
  testWidgets('selected text can be tagged as a highlighted range', (tester) async {
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
    field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();

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
    expect(latest!.rangeTags, hasLength(1));
    expect(latest!.rangeTags.single.start, 0);
    expect(latest!.rangeTags.single.end, 6);
    expect(latest!.rangeTags.single.tag.label, 'súlyos');

    await tester.enterText(
      find.byKey(const ValueKey('note-text-chunk-field')),
      'Nagyon Súlyos esetben high flow oxygen.',
    );
    await tester.pump();

    expect(latest!.rangeTags.single.start, 7);
    expect(latest!.rangeTags.single.end, 13);
  });

  testWidgets('text editor shows global tag capsules and local range pills', (tester) async {
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

    await tester.enterText(find.byKey(const ValueKey('note-chunk-title-field')), 'Új szöveg cím');
    await tester.pump();
    expect(latest!.title, 'Új szöveg cím');

    await tester.tap(find.byKey(const ValueKey('note-chunk-global-tag')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag-manager-name')), 'légzés');
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest!.tags.single.label, 'légzés');
    expect(find.byKey(const ValueKey('note-global-tag-pill-légzés')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-text-chunk-field')));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('note-text-chunk-field')),
    );
    field.controller!.selection = const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-menu-tag-selection')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('tag-manager-name')), 'súlyos');
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-save')));
    await tester.pumpAndSettle();

    expect(latest!.rangeTags.single.tags.map((tag) => tag.label), contains('súlyos'));
    expect(find.byKey(const ValueKey('note-local-tag-pill-súlyos')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-text-tip-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-text-tag-selection')), findsNothing);
  });
}
