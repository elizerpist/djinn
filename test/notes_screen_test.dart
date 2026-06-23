import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/models/note_item.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';
import 'package:djinn/src/notes/ui/notes_screen.dart';

void main() {
  testWidgets('notes screen shows PDF-like folder subheader by default', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    await repository.createFolder('Stroke');
    await repository.createDocumentNote(
      title: 'Stroke note',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'p1',
            type: NoteBlockType.paragraph,
            text: 'Stroke tartalom',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jegyzetek'), findsOneWidget);
    expect(find.byKey(const ValueKey('notes-folder-bar')), findsOneWidget);
    expect(find.text('Összes'), findsOneWidget);
    expect(find.text('Stroke'), findsOneWidget);
  });

  testWidgets('notes folder bar omits all pill when library has no notes', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    await repository.createFolder('Üres mappa');
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes-folder-bar')), findsOneWidget);
    expect(find.text('Összes'), findsNothing);
    expect(find.text('Üres mappa'), findsOneWidget);
  });

  testWidgets('notes FAB opens full-screen note editor route', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final fab = tester.widget<FloatingActionButton>(
      find.byKey(const ValueKey('notes-create-fab')),
    );
    expect(fab.isExtended, isFalse);

    await tester.tap(find.byKey(const ValueKey('notes-create-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-create-preview-box')), findsNothing);
    expect((await repository.listNotes()).single.type, NoteItemType.document);
  });

  testWidgets('tapping a note opens full-screen note editor route', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Oxigén cél',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'block-1',
            type: NoteBlockType.paragraph,
            text: 'SpO2 cél 88-92%',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('note-box-${note.id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('note-editor-route')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('note-editor-title-display')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-editor-title-field')), findsNothing);
  });

  testWidgets(
    'long pressing a note enters note selection mode with note actions',
    (tester) async {
      final repository = MemoryNoteRepository();
      final note = await repository.createDocumentNote(
        title: 'COPD kiváltó okok',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'p1',
              type: NoteBlockType.paragraph,
              text: 'Fertőzés és környezeti irritánsok.',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: NotesScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(ValueKey('note-box-${note.id}')));
      await tester.pumpAndSettle();

      expect(find.text('1 kijelölve'), findsOneWidget);
      expect(find.byKey(ValueKey('note-checkbox-${note.id}')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('notes-share-selected')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('notes-delete-selected')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('notes-selection-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Szerkesztés'), findsOneWidget);
      expect(find.text('Chunkok megtekintése'), findsOneWidget);
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(find.text('Kinyert tartalom audit'), findsOneWidget);
      expect(find.text('Másolat'), findsNothing);

      await tester.tapAt(const Offset(20, 580));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kijelölés megszüntetése'));
      await tester.pumpAndSettle();
      expect(find.text('Jegyzetek'), findsOneWidget);
    },
  );

  testWidgets('multi-selected notes export together as one PDF preview', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final first = await repository.createDocumentNote(
      title: 'Első jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Első'),
        ],
      ),
    );
    final second = await repository.createDocumentNote(
      title: 'Második jegyzet',
      document: const NoteDocument(
        blocks: [
          NoteBlock(id: 'p1', type: NoteBlockType.paragraph, text: 'Második'),
        ],
      ),
    );
    final receivedIds = <String>[];
    NotePdfPreviewFile? openedFile;
    final service = _CapturingPdfExportService(
      receivedIds: receivedIds,
      filename: 'jegyzetek_2.pdf',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NotesScreen(
          repository: repository,
          pdfExportService: service,
          pdfPreviewOpener: (context, file, service, viewerBuilder) {
            openedFile = file;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.longPress(find.byKey(ValueKey('note-box-${first.id}')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(ValueKey('note-checkbox-${second.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('notes-selection-menu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2 kijelölve'), findsOneWidget);
    expect(find.text('Export as PDF'), findsOneWidget);
    await tester.tap(find.text('Export as PDF'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(receivedIds, hasLength(2));
    expect(receivedIds, containsAll([first.id, second.id]));
    expect(openedFile?.filename, 'jegyzetek_2.pdf');
  });

  testWidgets('header menu opens the tag usage guide', (tester) async {
    final repository = MemoryNoteRepository();
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-header-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Tagek'), findsOneWidget);
    await tester.tap(find.text('Tagek'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('notes-tag-dialog')), findsOneWidget);
    expect(find.text('Direct tag'), findsOneWidget);
    expect(find.text('Örökölt tag'), findsOneWidget);
  });

  testWidgets('selected-note menu opens note tag assignment dialog', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final note = await repository.createDocumentNote(
      title: 'Légzési elégtelenség',
      document: const NoteDocument(
        blocks: [
          NoteBlock(
            id: 'p1',
            type: NoteBlockType.paragraph,
            text: 'Oxigénterápia',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: NotesScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(ValueKey('note-box-${note.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('notes-selection-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Tagek'), findsOneWidget);
    await tester.tap(find.text('Tagek'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tag-manager-sheet')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'légzési elégtelenség',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tag-manager-type')), findsNothing);
    expect(find.byKey(const ValueKey('tag-manager-save')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'terápia',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    final updated = (await repository.listNotes()).single;
    final document = NoteDocument.fromPayload(updated.payloadJson);
    expect(document.tags.map((tag) => '${tag.type}:${tag.label}'), [
      'custom:légzési elégtelenség',
      'custom:terápia',
    ]);
  });

  testWidgets('header menu imports exported notes into the current library', (
    tester,
  ) async {
    final repository = MemoryNoteRepository();
    final importedAt = DateTime(2026, 6, 16, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: NotesScreen(
          repository: repository,
          importNotesForTest: () async => [
            NoteItem(
              id: 'foreign-note',
              type: NoteItemType.document,
              title: 'Importált jegyzet',
              plainText: 'Importált tartalom',
              payloadJson: const NoteDocument(
                blocks: [
                  NoteBlock(
                    id: 'p1',
                    type: NoteBlockType.paragraph,
                    text: 'Importált tartalom',
                  ),
                ],
              ).toPayloadJson(),
              auditState: LocalAuditState.edited,
              createdAt: importedAt,
              updatedAt: importedAt,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('notes-header-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    final notes = await repository.listNotes();
    expect(notes, hasLength(1));
    expect(notes.single.id, isNot('foreign-note'));
    expect(notes.single.title, 'Importált jegyzet');
    expect(find.text('Importált jegyzet'), findsOneWidget);
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
