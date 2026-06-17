import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_document_editor_screen.dart';

void main() {
  testWidgets('full-screen note editor saves free text and list blocks', (
    tester,
  ) async {
    NoteDocumentEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteDocumentEditorResult>(
                MaterialPageRoute(
                  builder: (_) => NoteDocumentEditorScreen(
                    title: 'Mentési jegyzet',
                    document: NoteDocument.empty(),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-document-block-block-1')),
      'Szabad szöveg.',
    );
    await tester.tap(find.byKey(const ValueKey('note-document-add-list')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('note-document-block-block-2')),
      160,
      scrollable: find.byType(ListView),
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-document-block-block-2')),
      'Első vázlatpont',
    );
    await tester.tap(find.byKey(const ValueKey('note-document-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.document.blocks.map((block) => block.type), [
      NoteBlockType.paragraph,
      NoteBlockType.listItem,
    ]);
    expect(result!.document.plainText, contains('Szabad szöveg.'));
    expect(result!.document.plainText, contains('Első vázlatpont'));
  });

  testWidgets('list indentation is saved in the document editor', (tester) async {
    NoteDocumentEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteDocumentEditorResult>(
                MaterialPageRoute(
                  builder: (_) => NoteDocumentEditorScreen(
                    title: 'Lista',
                    document: const NoteDocument(blocks: [
                      NoteBlock(
                        id: 'list-1',
                        type: NoteBlockType.listItem,
                        text: 'Alpont',
                      ),
                    ]),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Behúzás'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-document-save')));
    await tester.pumpAndSettle();

    expect(result!.document.blocks.single.level, 1);
  });

  testWidgets('block search metadata is saved in the document editor', (
    tester,
  ) async {
    NoteDocumentEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteDocumentEditorResult>(
                MaterialPageRoute(
                  builder: (_) => NoteDocumentEditorScreen(
                    title: 'Meta',
                    document: NoteDocument.empty(),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-document-block-block-1')),
      'DO2 = oxygénkínálat',
    );
    await tester.enterText(
      find.byKey(const ValueKey('note-block-search-context-block-1')),
      'légzési elégtelenség',
    );
    await tester.tap(find.byKey(const ValueKey('note-block-search-role-block-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Definíció').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-block-search-aliases-block-1')),
      'DO2, VO2',
    );
    await tester.tap(find.byKey(const ValueKey('note-document-save')));
    await tester.pumpAndSettle();

    final block = result!.document.blocks.single;
    expect(block.searchContext, 'légzési elégtelenség');
    expect(block.searchRole, NoteSearchRoles.definition);
    expect(block.searchAliases, ['DO2', 'VO2']);
  });

  testWidgets('block search metadata tags are visible in the editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              Navigator.of(context).push<NoteDocumentEditorResult>(
                MaterialPageRoute(
                  builder: (_) => const NoteDocumentEditorScreen(
                    title: 'Meta',
                    document: NoteDocument(
                      blocks: [
                        NoteBlock(
                          id: 'block-1',
                          type: NoteBlockType.paragraph,
                          text: 'DO2 = oxygénkínálat',
                          searchContext: 'légzési elégtelenség',
                          searchRole: NoteSearchRoles.definition,
                          searchAliases: ['DO2', 'VO2'],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Keresési metadata / tagek'), findsOneWidget);
    expect(find.text('Kontextus: légzési elégtelenség'), findsOneWidget);
    expect(find.text('Tudástípus: Definíció'), findsOneWidget);
    expect(find.text('Tag: DO2'), findsOneWidget);
    expect(find.text('Tag: VO2'), findsOneWidget);
  });

}
