import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
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

  testWidgets(
    'repository-assigned canonical chunk ids are applied back to the editor',
    (tester) async {
      final repository = _CanonicalizingMemoryNoteRepository();
      final note = await repository.createDocumentNote(
        title: 'Régi cím',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'local-block',
              type: NoteBlockType.paragraph,
              text: 'abc',
            ),
          ],
        ),
      );
      final canonicalId = '${note.id}:chunk:local-block';

      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorRoute(repository: repository, initialNote: note),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('note-editor-title-display')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('note-editor-title-field')),
        'Új cím',
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('note-chunk-card-$canonicalId')),
        findsOneWidget,
      );
      expect(
        (await repository.listNotes()).single.document.blocks.single.id,
        canonicalId,
      );
    },
  );

  testWidgets('editor FAB exposes exactly the two canonical chunk actions', (
    tester,
  ) async {
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

    expect(
      find.byKey(const ValueKey('note-editor-add-note-chunk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-editor-add-flowchart')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('note-editor-add-text')), findsNothing);
    expect(find.byKey(const ValueKey('note-editor-add-list')), findsNothing);
    expect(find.byKey(const ValueKey('note-editor-add-table')), findsNothing);
    expect(find.byKey(const ValueKey('note-editor-add-mixed')), findsNothing);
    expect(find.text('Szöveg'), findsNothing);
  });

  testWidgets('editor note chunk FAB creates the unified rich note chunk', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const ValueKey('note-editor-add-note-chunk')));
    await tester.pump();

    final saved = (await repository.listNotes()).single;
    expect(saved.document.blocks.last.type, NoteBlockType.mixed);
    expect(
      saved.document.blocks.last.mixedSections.single.type,
      NoteMixedSectionType.paragraph,
    );
  });

  testWidgets(
    'note menu exports schema v2 with note and flowchart chunks only',
    (tester) async {
      final repository = MemoryNoteRepository();
      final note = await repository.createDocumentNote(
        title: 'Export jegyzet',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'paragraph-1',
              type: NoteBlockType.paragraph,
              text: 'Bekezdés',
            ),
            NoteBlock(
              id: 'table-1',
              type: NoteBlockType.table,
              rows: [
                ['A', 'B'],
              ],
            ),
            NoteBlock(
              id: 'flow-1',
              type: NoteBlockType.flowchart,
              nodes: [NoteFlowchartNode(id: 'start', label: 'Start')],
            ),
          ],
        ),
      );
      ChunkPackage? savedPackage;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorRoute(
            repository: repository,
            initialNote: note,
            chunkExportSaver: (package) async {
              savedPackage = package;
              return '/memory/note-export.json';
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-editor-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chunk export (JSON)'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-note_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-flowchart_chunk')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('chunk-export-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
      await tester.pumpAndSettle();

      expect(savedPackage?.schemaVersion, 2);
      expect(savedPackage?.chunks.map((chunk) => chunk.kind).toList(), [
        ChunkKind.noteChunk,
        ChunkKind.noteChunk,
        ChunkKind.flowchartChunk,
      ]);
      expect(
        savedPackage?.chunks
            .where((chunk) => chunk.kind == ChunkKind.noteChunk)
            .every((chunk) => chunk.content?.type == NoteBlockType.mixed),
        isTrue,
      );
    },
  );

  testWidgets(
    'note chunk export removes page data when source metadata is disabled',
    (tester) async {
      final repository = _SourceBackedMemoryNoteRepository();
      final note = await repository.createDocumentNote(
        title: 'Forrásos jegyzet',
        document: const NoteDocument(
          blocks: [
            NoteBlock(
              id: 'source-block',
              type: NoteBlockType.paragraph,
              text: 'Forrásból érkező tartalom',
            ),
          ],
        ),
      );
      ChunkPackage? savedPackage;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteEditorRoute(
            repository: repository,
            initialNote: note,
            chunkExportSaver: (package) async {
              savedPackage = package;
              return '/memory/source-free-note-export.json';
            },
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('note-editor-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chunk export (JSON)'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('chunk-export-include-source')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('chunk-export-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
      await tester.pumpAndSettle();

      expect(savedPackage?.chunks.single.source.isEmpty, isTrue);
      expect(savedPackage?.chunks.single.pageNumber, 0);
    },
  );

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
    'tapping a legacy text chunk normalizes it into the unified editor',
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
        find.byKey(const ValueKey('note-mixed-text-editor')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-paragraph-a-section-1')),
        'Új szöveg',
      );
      await tester.pump();

      final saved = (await repository.listNotes()).single;
      expect(saved.document.blocks.single.type, NoteBlockType.mixed);
      expect(
        saved.document.blocks.single.mixedSections.single.text,
        'Új szöveg',
      );
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

class _CanonicalizingMemoryNoteRepository extends MemoryNoteRepository {
  @override
  Future<NoteItem> updateNoteDocument(
    String noteId, {
    required String title,
    required NoteDocument document,
    LocalAuditState? auditState,
    String? reason,
  }) {
    final prefix = '$noteId:chunk:';
    return super.updateNoteDocument(
      noteId,
      title: title,
      document: document.copyWith(
        blocks: [
          for (final block in document.blocks)
            block.copyWith(
              id: block.id.startsWith(prefix) ? block.id : '$prefix${block.id}',
            ),
        ],
      ),
      auditState: auditState,
      reason: reason,
    );
  }
}

class _SourceBackedMemoryNoteRepository extends MemoryNoteRepository {
  @override
  Future<ChunkPackage> exportChunkPackageForNote(
    String noteId, {
    bool includeSourceMetadata = true,
  }) async {
    final base = await super.exportChunkPackageForNote(
      noteId,
      includeSourceMetadata: includeSourceMetadata,
    );
    return ChunkPackage(
      schemaVersion: base.schemaVersion,
      documentHash: base.documentHash,
      filename: base.filename,
      provider: base.provider,
      extractionModel: base.extractionModel,
      embeddingModel: base.embeddingModel,
      embeddingDimension: base.embeddingDimension,
      chunks: [
        base.chunks.single.copyWith(
          pageNumber: 7,
          source: includeSourceMetadata
              ? const ChunkSource(
                  sourceType: ChunkSourceType.pdf,
                  sourceId: 'source.pdf',
                  pageStart: 7,
                )
              : const ChunkSource(),
        ),
      ],
    );
  }
}
