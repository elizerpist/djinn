import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';
import 'package:djinn/src/notes/ui/note_editor_route.dart';

void main() {
  testWidgets('note editor autosaves title edits immediately', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Régi cím',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'block-1', type: NoteBlockType.paragraph, text: 'abc'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(repository: repository, initialNote: note),
      ),
    );

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-title-field')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('note-editor-title-display')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('note-editor-title-field')),
      'Új cím',
    );
    await tester.pump();

    final saved = (await repository.listNotes()).single;
    expect(saved.title, 'Új cím');
  });

  testWidgets('editor FAB expands icon-only chunk actions', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: NoteDocument.empty(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(repository: repository, initialNote: note),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-editor-add-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-add-text')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-add-list')), findsNothing);
    expect(find.byKey(const ValueKey('note-editor-add-table')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-editor-add-flowchart')),
      findsOneWidget,
    );
    expect(find.text('Szöveg'), findsNothing);
  });

  testWidgets('editor text FAB creates a mixed text chunk', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: NoteDocument.empty(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(repository: repository, initialNote: note),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-editor-add-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-editor-add-text')));
    await tester.pump();

    final saved = (await repository.listNotes()).single;
    expect(saved.document.blocks.last.type, NoteBlockType.mixed);
    expect(
      saved.document.blocks.last.mixedSections.single.type,
      NoteMixedSectionType.paragraph,
    );
  });

  testWidgets('delete chunk shows undo and restores original position', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Alpha'),
          NoteBlock(id: 'b', type: NoteBlockType.paragraph, text: 'Beta'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(repository: repository, initialNote: note),
      ),
    );

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('note-chunk-delete-a')));
    await tester.pump();

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsNothing);
    tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-chunk-card-a')), findsOneWidget);
    final saved = (await repository.listNotes()).single;
    expect(saved.document.blocks.map((block) => block.id), ['a', 'b']);
  });

  testWidgets(
    'tapping a text chunk opens full-screen editor and autosaves edits',
    (tester) async {
      final repository = MemoryNoteRepository();
      final note = await repository.createDocumentNote(
        title: 'N',
        document: const NoteDocument(
          blocks: [
            NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Régi'),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorRoute(repository: repository, initialNote: note),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-chunk-card-a')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-text-chunk-editor')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('note-text-plain-field')),
        'Új szöveg',
      );
      await tester.pump();

      final saved = (await repository.listNotes()).single;
      expect(saved.document.blocks.single.text, 'Új szöveg');
    },
  );

  testWidgets('note menu opens the colored tag manager for the current note', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'N',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Alpha'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(repository: repository, initialNote: note),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-editor-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tagek'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-manager-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'légzési elégtelenség',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-manager-save')), findsNothing);
    expect(find.byKey(const ValueKey('tag-manager-type')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    final saved = (await repository.listNotes()).single;
    expect(saved.document.tags.single.label, 'légzési elégtelenség');
    expect(saved.document.tags.single.colorValue, isNotNull);
  });

  testWidgets('note menu exports only the opened note as PDF', (tester) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Aktív jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'a', type: NoteBlockType.paragraph, text: 'Alpha'),
        ],
      ),
    );
    await repository.createDocumentNote(
      title: 'Másik jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'b', type: NoteBlockType.paragraph, text: 'Beta'),
        ],
      ),
    );
    final receivedIds = <String>[];
    NotePdfPreviewFile? openedFile;
    final service = _CapturingPdfExportService(
      receivedIds: receivedIds,
      filename: 'Akt_v_jegyzet.pdf',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorRoute(
          repository: repository,
          initialNote: note,
          pdfExportService: service,
          pdfPreviewOpener: (context, file, service, viewerBuilder) {
            openedFile = file;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-editor-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Export as PDF'), findsOneWidget);
    await tester.tap(find.text('Export as PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(receivedIds, [note.id]);
    expect(openedFile?.filename, 'Akt_v_jegyzet.pdf');
  });
}

class _CapturingPdfExportService extends NotePdfExportService {
  const _CapturingPdfExportService({
    required this.receivedIds,
    required this.filename,
  });

  final List<String> receivedIds;
  final String filename;

  @override
  Future<NotePdfPreviewFile> createPreviewFileForNotes(
    List<NoteItem> notes,
  ) async {
    receivedIds.addAll(notes.map((note) => note.id));
    return NotePdfPreviewFile(
      path: 'memory:$filename',
      filename: filename,
      bytes: Uint8List.fromList('%PDF fake'.codeUnits),
    );
  }
}
