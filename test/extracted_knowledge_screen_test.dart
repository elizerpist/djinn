import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/extracted_knowledge_screen.dart';
import 'package:djinn/src/knowledge/ui/pdf_chunk_editor_route.dart';
import 'package:djinn/src/knowledge/ui/pdf_chunk_note_block_adapter.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/data/note_repository.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/shared/chunks/chunk_card.dart';

void main() {
  test('chunk cards expose only the two canonical shared chunk kinds', () {
    expect(ChunkCardKind.values.map((kind) => kind.name), [
      'noteChunk',
      'flowchartChunk',
    ]);
  });

  testWidgets(
    'expanded cards never expose legacy extraction types as user metadata',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'canonical-labels.pdf',
        localPath: '/memory/canonical-labels.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'canonical-labels',
      );
      await repository.saveExtractedEvidence(
        documentPublicId: document.id,
        evidence: const AiExtractedEvidence(
          id: 'legacy-table',
          text: 'Táblázatos adat',
          pageNumber: 1,
          sourceType: AiEvidenceSourceType.table,
        ),
        embedding: const [],
        embeddingModel: '',
      );
      await repository.saveExtractedEvidence(
        documentPublicId: document.id,
        evidence: const AiExtractedEvidence(
          id: 'legacy-score',
          text: 'Pontozási adat',
          pageNumber: 1,
          sourceType: AiEvidenceSourceType.score,
        ),
        embedding: const [],
        embeddingModel: '',
      );
      await repository.saveFlowchartCandidate(
        documentPublicId: document.id,
        flowchart: const AiFlowchartCandidate(
          id: 'legacy-flowchart',
          pageNumber: 1,
          title: 'Döntési folyamat',
          nodes: [AiFlowchartNode(id: 'start', label: 'Kezdés')],
          edges: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: repository,
            document: document,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final id in ['legacy-table', 'legacy-score', 'legacy-flowchart']) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey('pdf-chunk-expand-$id')),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(ValueKey('pdf-chunk-expand-$id')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Jegyzetchunk'), findsNWidgets(2));
      expect(find.text('Flowchart'), findsOneWidget);
      expect(find.textContaining('table_chunk'), findsNothing);
      expect(find.textContaining('score_chunk'), findsNothing);
      expect(find.textContaining('flowchart_node'), findsNothing);
    },
  );

  testWidgets('imported chunks keep their Importált provenance label', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'imported.pdf',
      localPath: '/memory/imported.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 7, 25),
      sha256: 'imported-hash',
    );
    await repository.importChunkPackage(
      document.id,
      const ChunkPackage(
        schemaVersion: 2,
        documentHash: 'imported-hash',
        filename: 'imported.pdf',
        provider: '',
        extractionModel: '',
        embeddingModel: '',
        embeddingDimension: 0,
        chunks: [
          ChunkPackageItem(
            id: 'imported-chunk',
            text: 'Importált tudáselem',
            pageNumber: 1,
            sectionTitle: 'Importált rész',
            embedding: [],
            creationMethod: ChunkCreationMethod.imported,
            content: NoteBlock(
              id: 'imported-chunk',
              type: NoteBlockType.mixed,
              mixedSections: [
                NoteMixedSection(
                  id: 'paragraph-1',
                  type: NoteMixedSectionType.paragraph,
                  text: 'Importált tudáselem',
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Importált'), findsOneWidget);
    expect(find.text('AI-javaslat'), findsNothing);
  });

  test('pdf chunk adapter preserves list levels and checkbox states', () {
    final text = pdfChunkTextFromNoteBlock(
      const NoteBlock(
        id: 'list-1',
        type: NoteBlockType.listItem,
        listItems: [
          NoteListItem(id: 'a', text: 'Parent', checked: true),
          NoteListItem(id: 'b', text: 'Child', level: 2),
        ],
      ),
    );

    expect(text, '[x] Parent\n    [ ] Child');

    final block = noteBlockFromPdfChunk(
      const ExtractedKnowledgeItem(
        id: 'list-1',
        documentId: 'document-1',
        sourceType: EvidenceSourceType.textChunk,
        text: '[x] Parent\n    [ ] Child',
        chunkKind: LocalChunkKind.list,
      ),
    );

    expect(block.listItems.first.checked, isTrue);
    expect(block.listItems.first.level, 0);
    expect(block.listItems.last.checked, isFalse);
    expect(block.listItems.last.level, 2);
  });

  test('pdf chunk adapter regenerates flowchart text from edited nodes', () {
    final text = pdfChunkTextFromNoteBlock(
      const NoteBlock(
        id: 'flow-1',
        type: NoteBlockType.flowchart,
        text: 'Régi, stale szöveg',
        nodes: [
          NoteFlowchartNode(id: 'start', label: 'Start'),
          NoteFlowchartNode(id: 'end', label: 'Vége'),
        ],
        edges: [
          NoteFlowchartEdge(
            id: 'edge-1',
            fromNodeId: 'start',
            toNodeId: 'end',
            label: 'igen',
          ),
        ],
      ),
    );

    expect(text, 'Start\nVége\nStart -> Vége: igen');
  });

  test('pdf chunk adapter preserves empty table cells', () {
    final block = noteBlockFromPdfChunk(
      const ExtractedKnowledgeItem(
        id: 'table-1',
        documentId: 'document-1',
        sourceType: EvidenceSourceType.tableChunk,
        text: 'A |  | C\n1 | 2 |',
        chunkKind: LocalChunkKind.table,
      ),
    );

    expect(block.rows, [
      ['A', '', 'C'],
      ['1', '2', ''],
    ]);

    final text = pdfChunkTextFromNoteBlock(
      const NoteBlock(
        id: 'table-1',
        type: NoteBlockType.table,
        rows: [
          ['A', '', 'C'],
          ['1', '2', ''],
        ],
      ),
    );

    expect(text, 'A |  | C\n1 | 2 |');
  });

  test('pdf chunk adapter loads structured mixed content when present', () {
    final block = noteBlockFromPdfChunk(
      const ExtractedKnowledgeItem(
        id: 'mixed-1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Fallback',
        structuredContentJson:
            '{"id":"mixed-1","type":"mixed","mixedSections":[{"id":"p1","type":"paragraph","text":"Structured"}]}',
      ),
    );

    expect(block.type, NoteBlockType.mixed);
    expect(block.plainText, 'Structured');
  });

  test(
    'pdf chunk adapter keeps aggregate item tags out of structured top-level tags',
    () {
      const scopedTag = NoteKnowledgeTag(
        id: 'tag-cell',
        type: NoteKnowledgeTagTypes.topic,
        label: 'Cell scope',
      );
      const content = NoteBlock(
        id: 'mixed-scoped-1',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'table-1',
            type: NoteMixedSectionType.table,
            rows: [
              ['Scoped value'],
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'scope-cell',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 0,
                  columnIndex: 0,
                ),
                tags: [scopedTag],
              ),
            ],
          ),
        ],
      );

      final block = noteBlockFromPdfChunk(
        ExtractedKnowledgeItem(
          id: 'mixed-scoped-1',
          documentId: 'doc-1',
          sourceType: EvidenceSourceType.tableChunk,
          text: content.plainText,
          tags: const [scopedTag],
          structuredContentJson: jsonEncode(content.toJson()),
        ),
      );

      expect(block.tags, isEmpty);
      expect(
        block.mixedSections.single.scopedTags.single.tags.map(
          (tag) => tag.metadataText,
        ),
        [scopedTag.metadataText],
      );
      expect(block.knownTags.map((tag) => tag.metadataText), [
        scopedTag.metadataText,
      ]);
    },
  );

  testWidgets(
    'editing structured pdf content does not persist aggregate tags at top level',
    (tester) async {
      const scopedTag = NoteKnowledgeTag(
        id: 'tag-cell',
        type: NoteKnowledgeTagTypes.topic,
        label: 'Cell scope',
      );
      const content = NoteBlock(
        id: 'mixed-scoped-edit',
        type: NoteBlockType.mixed,
        mixedSections: [
          NoteMixedSection(
            id: 'table-1',
            type: NoteMixedSectionType.table,
            rows: [
              ['Before'],
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'scope-cell',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.tableCell,
                  rowIndex: 0,
                  columnIndex: 0,
                ),
                tags: [scopedTag],
              ),
            ],
          ),
        ],
      );
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'scoped-tags.pdf',
        localPath: '/memory/scoped-tags.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'scoped-tags-hash',
      );
      await repository.saveLocalChunks(document.id, [
        LocalChunk(
          id: content.id,
          documentId: document.id,
          text: content.plainText,
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.text,
          tags: const [scopedTag],
          structuredContentJson: jsonEncode(content.toJson()),
        ),
      ], replaceExisting: false);
      final item = (await repository.listExtractedKnowledgeItems(
        document.id,
      )).single;

      await tester.pumpWidget(
        MaterialApp(
          home: PdfChunkEditorRoute(
            repository: repository,
            documentId: document.id,
            item: item,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-mixed-table-cell-table-1-0-0')),
        'After',
      );
      await tester.pumpAndSettle();

      final saved = (await repository.listExtractedKnowledgeItems(
        document.id,
      )).single;
      final savedBlock = NoteBlock.fromJson(
        Map<String, Object?>.from(
          jsonDecode(saved.structuredContentJson!) as Map,
        ),
      );
      expect(savedBlock.tags, isEmpty);
      expect(
        savedBlock.mixedSections.single.scopedTags.single.tags.map(
          (tag) => tag.metadataText,
        ),
        [scopedTag.metadataText],
      );
      expect(savedBlock.knownTags.map((tag) => tag.metadataText), [
        scopedTag.metadataText,
      ]);
    },
  );

  test('manual pdf chunk tags round trip through repository', () async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'tags.pdf',
      localPath: '/memory/tags.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 24),
      sha256: 'hash-tags',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-tagged',
        documentId: 'document-1',
        text: 'Tagelhető chunk',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await repository
        .updateExtractedKnowledgeTags(document.id, 'manual-tagged', const [
          NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.custom,
            label: 'súlyos',
            colorSlotId: 1,
          ),
        ]);

    final items = await repository.listExtractedKnowledgeItems(document.id);
    expect(items.single.tags.single.label, 'súlyos');
  });

  testWidgets('pdf chunk cards render one saved tag-count badge', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'tag-card.pdf',
      localPath: '/memory/tag-card.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 24),
      sha256: 'hash-tag-card',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-tag-card',
        documentId: 'document-1',
        text: 'Tagelt kártya tartalom',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
        tags: [
          NoteKnowledgeTag(
            type: NoteKnowledgeTagTypes.custom,
            label: 'súlyos',
            colorSlotId: 1,
          ),
        ],
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chunk-card-tag-count-manual-tag-card')),
      findsOneWidget,
    );
    expect(find.text('súlyos'), findsNothing);
  });

  testWidgets('PDF and Note scopes use the same rich mixed chunk body', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'rich-card.pdf',
      localPath: '/memory/rich-card.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 7, 25),
      sha256: 'hash-rich-card',
    );
    const content = NoteBlock(
      id: 'rich-1',
      type: NoteBlockType.mixed,
      mixedSections: [
        NoteMixedSection(
          id: 'paragraph-1',
          type: NoteMixedSectionType.paragraph,
          text: 'PDF bekezdés',
        ),
        NoteMixedSection(
          id: 'list-1',
          type: NoteMixedSectionType.list,
          listItems: [NoteListItem(id: 'item-1', text: 'PDF listaelem')],
        ),
        NoteMixedSection(
          id: 'table-1',
          type: NoteMixedSectionType.table,
          rows: [
            ['PDF kulcs', 'PDF érték'],
          ],
        ),
      ],
    );
    await repository.saveLocalChunks(document.id, [
      LocalChunk(
        id: 'rich-1',
        documentId: document.id,
        text: content.plainText,
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        structuredContentJson: jsonEncode(content.toJson()),
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pdf-chunk-expand-rich-1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('unified-mixed-paragraph-paragraph-1')),
      findsOneWidget,
    );
    expect(find.text('PDF listaelem'), findsOneWidget);
    expect(find.text('PDF kulcs'), findsOneWidget);
    expect(find.text('PDF érték'), findsOneWidget);
  });

  testWidgets('pdf chunk list relies on ambient scroll physics', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'scroll.pdf',
      localPath: '/memory/scroll.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 25),
      sha256: 'hash-scroll',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-scroll',
        documentId: 'document-1',
        text: 'Scroll tartalom',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(scrollable.physics, isNot(isA<BouncingScrollPhysics>()));
  });

  testWidgets(
    'manual pdf chunk cards expand scroll and open fullscreen note-style editors',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'manual-card-contract.pdf',
        localPath: '/memory/manual-card-contract.pdf',
        sizeBytes: 8,
        importedAt: DateTime.utc(2026, 6, 25),
        sha256: 'hash-manual-card-contract',
      );
      await repository.saveLocalChunks(document.id, [
        const LocalChunk(
          id: 'pdf-text',
          documentId: 'document-1',
          text: 'Szöveg chunk tartalom',
          pageNumber: 1,
          sectionTitle: 'Szöveg',
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.text,
        ),
        const LocalChunk(
          id: 'pdf-list',
          documentId: 'document-1',
          text: 'Első pont\nMásodik pont',
          pageNumber: 1,
          sectionTitle: 'Lista',
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.list,
        ),
        const LocalChunk(
          id: 'pdf-table',
          documentId: 'document-1',
          text: 'A | B\n1 | 2',
          pageNumber: 1,
          sectionTitle: 'Táblázat',
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.table,
        ),
        const LocalChunk(
          id: 'pdf-flow',
          documentId: 'document-1',
          text: 'Kezdés -> Vége',
          pageNumber: 1,
          sectionTitle: 'Flow',
          pipeline: LocalExtractionPipeline.manual,
          kind: LocalChunkKind.flowchart,
        ),
        for (var index = 0; index < 8; index += 1)
          LocalChunk(
            id: 'pdf-extra-$index',
            documentId: 'document-1',
            text: 'Extra chunk $index',
            pageNumber: 1,
            pipeline: LocalExtractionPipeline.manual,
            kind: LocalChunkKind.text,
          ),
      ], replaceExisting: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: repository,
            document: document,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('pdf-chunk-expand-pdf-extra-0')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('pdf-chunk-expanded-body-pdf-extra-0')),
        findsOneWidget,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(find.text('Extra chunk 7'), findsWidgets);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 420));
      await tester.pumpAndSettle();

      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-text'),
        editorKey: const ValueKey('note-mixed-text-editor'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-list'),
        editorKey: const ValueKey('note-mixed-text-editor'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-table'),
        editorKey: const ValueKey('note-mixed-text-editor'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-flow'),
        editorKey: const ValueKey('note-flowchart-canvas-editor'),
      );
    },
  );

  testWidgets('flowchart chunk opens the same unified flowchart editor', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'mixed-flowchart.pdf',
      localPath: '/memory/mixed-flowchart.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 25),
      sha256: 'hash-mixed-flowchart',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'ai-text',
        text: 'AI szöveg chunk',
        pageNumber: 1,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'gemini-embedding-001',
    );
    await repository.saveFlowchartCandidate(
      documentPublicId: document.id,
      flowchart: const AiFlowchartCandidate(
        id: 'flow-mixed',
        pageNumber: 1,
        title: 'Vegyes flowchart',
        nodes: [
          AiFlowchartNode(
            id: 'n1',
            label: 'Döntés',
            shape: AiFlowchartNodeShape.decision,
          ),
        ],
        edges: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('chunk-card-flow-mixed')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('chunk-card-flow-mixed')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-flowchart-canvas-editor')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('flowchart-editor-canvas')), findsNothing);
  });

  testWidgets('pdf chunk fullscreen editor hides note delete action', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'delete-menu.pdf',
      localPath: '/memory/delete-menu.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 25),
      sha256: 'hash-delete-menu',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-delete-menu',
        documentId: 'document-1',
        text: 'Nem törölhető PDF route-ból',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('chunk-card-manual-delete-menu')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-chunk-menu-delete-chunk')),
      findsNothing,
    );
    expect(find.text('Chunk törlése'), findsNothing);
  });

  testWidgets('manual pdf chunk tag button opens sheet and persists tags', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'tag-sheet.pdf',
      localPath: '/memory/tag-sheet.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 24),
      sha256: 'hash-tag-sheet',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'manual-tag-sheet',
        documentId: 'document-1',
        text: 'Tag sheet tartalom',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('pdf-chunk-tags-manual-tag-sheet')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'akut',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    final items = await repository.listExtractedKnowledgeItems(document.id);
    expect(items.single.tags.single.label, 'akut');
  });

  testWidgets('structured pdf tag sheet saves only explicit top-level tags', (
    tester,
  ) async {
    const scopedTag = NoteKnowledgeTag(
      id: 'tag-cell',
      type: NoteKnowledgeTagTypes.topic,
      label: 'Cell scope',
    );
    const content = NoteBlock(
      id: 'structured-tag-sheet',
      type: NoteBlockType.mixed,
      mixedSections: [
        NoteMixedSection(
          id: 'table-1',
          type: NoteMixedSectionType.table,
          rows: [
            ['Scoped value'],
          ],
          scopedTags: [
            NoteScopedTagAssignment(
              id: 'scope-cell',
              target: NoteTagTarget(
                kind: NoteTagTargetKind.tableCell,
                rowIndex: 0,
                columnIndex: 0,
              ),
              tags: [scopedTag],
            ),
          ],
        ),
      ],
    );
    final repository = _CapturingKnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'structured-tag-sheet.pdf',
      localPath: '/memory/structured-tag-sheet.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 7, 25),
      sha256: 'structured-tag-sheet-hash',
    );
    await repository.saveLocalChunks(document.id, [
      LocalChunk(
        id: content.id,
        documentId: document.id,
        text: content.plainText,
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
        tags: const [scopedTag],
        structuredContentJson: jsonEncode(content.toJson()),
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('pdf-chunk-tags-structured-tag-sheet')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    expect(repository.lastUpdatedTags, isEmpty);
  });

  testWidgets('flowchart is one canonical card in the common PDF list', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'stroke.pdf',
      localPath: '/memory/stroke.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 13),
      sha256: 'hash-flow-ui',
    );
    await repository.saveFlowchartCandidate(
      documentPublicId: document.id,
      flowchart: const AiFlowchartCandidate(
        id: 'flow-1',
        pageNumber: 1,
        title: 'Légzés algoritmus',
        nodes: [
          AiFlowchartNode(
            id: 'n1',
            label: 'Légzési elégtelenség?',
            shape: AiFlowchartNodeShape.decision,
            order: 1,
          ),
          AiFlowchartNode(
            id: 'n2',
            label: 'Oxigén',
            shape: AiFlowchartNodeShape.process,
            order: 3,
          ),
          AiFlowchartNode(
            id: 'n3',
            label: 'Monitorozás',
            shape: AiFlowchartNodeShape.process,
            order: 5,
          ),
        ],
        edges: [
          AiFlowchartEdge(
            id: 'e1',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            label: 'igen',
            order: 2,
          ),
          AiFlowchartEdge(
            id: 'e2',
            fromNodeId: 'n1',
            toNodeId: 'n3',
            label: 'nem',
            order: 4,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chunk-card-flow-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-group-flow-1')), findsNothing);
    expect(find.text('PDF chunkok'), findsOneWidget);
  });
  testWidgets('PDF list mixes AI manual and OCR chunks without mode tabs', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'mixed.pdf',
      localPath: '/memory/mixed.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'hash-mixed-ui',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'ai-text',
        text: 'AI szöveg chunk',
        pageNumber: 1,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'gemini-embedding-001',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'local-table',
        documentId: 'document-1',
        text: 'Régi lokális OCR chunk',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.localOcr,
        kind: LocalChunkKind.table,
      ),
      LocalChunk(
        id: 'manual-text',
        documentId: 'document-1',
        text: 'Manuális szöveg chunk',
        pageNumber: 3,
        pipeline: LocalExtractionPipeline.manual,
        kind: LocalChunkKind.text,
      ),
    ], replaceExisting: false);

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF chunkok'), findsOneWidget);
    expect(find.text('AI szöveg chunk'), findsOneWidget);
    expect(find.text('Régi lokális OCR chunk'), findsOneWidget);
    expect(find.text('Manuális szöveg chunk'), findsOneWidget);
    expect(find.byKey(const Key('pdf-chunk-mode-menu')), findsNothing);
    expect(find.text('AI chunkok'), findsNothing);
    expect(find.text('Manuális chunkok'), findsNothing);
    expect(find.text('Lokális chunkok'), findsNothing);
    expect(find.text('Összehasonlítás'), findsNothing);
    expect(find.text('Score'), findsNothing);
    expect(find.text('Kép'), findsNothing);
    expect(find.text('Vizuális tény'), findsNothing);
    expect(find.byKey(const ValueKey('extracted-type-all')), findsNothing);
  });

  testWidgets(
    'PDF chunk export sheet saves schema v2 with only the two canonical kinds',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'export.pdf',
        localPath: '/memory/export.pdf',
        sizeBytes: 8,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'hash-export-ui',
      );
      await repository.saveLocalChunks(document.id, const [
        LocalChunk(
          id: 'note-1',
          documentId: 'ignored',
          text: 'Jegyzettartalom',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
        ),
      ], replaceExisting: false);
      await repository.saveFlowchartCandidate(
        documentPublicId: document.id,
        flowchart: const AiFlowchartCandidate(
          id: 'flow-1',
          pageNumber: 2,
          nodes: [AiFlowchartNode(id: 'start', label: 'Start')],
          edges: [],
        ),
      );
      ChunkPackage? savedPackage;

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: repository,
            document: document,
            chunkExportSaver: (package) async {
              savedPackage = package;
              return '/memory/export.djinn.json';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pdf-chunk-export-action')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chunk-export-scope-current_pdf')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-note_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-flowchart_chunk')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('chunk-export-include-source')),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('chunk-export-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
      await tester.pumpAndSettle();

      expect(savedPackage?.schemaVersion, 2);
      expect(savedPackage?.chunks.map((chunk) => chunk.kind).toSet(), {
        ChunkKind.noteChunk,
        ChunkKind.flowchartChunk,
      });
      expect(
        savedPackage?.chunks.every((chunk) => chunk.source.isEmpty),
        isTrue,
      );
      expect(
        savedPackage?.chunks.every((chunk) => chunk.pageNumber == 0),
        isTrue,
      );
      expect(
        savedPackage?.toJson()['chunks'],
        everyElement(isNot(contains('source'))),
      );
    },
  );

  testWidgets('single selected PDF chunk exports with current chunk scope', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'single-selection.pdf',
      localPath: '/memory/single-selection.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 7, 25),
      sha256: 'hash-single-selection',
    );
    await repository.saveLocalChunks(document.id, const [
      LocalChunk(
        id: 'scope-1',
        documentId: 'ignored',
        text: 'Első exportálható chunk',
        pageNumber: 1,
        pipeline: LocalExtractionPipeline.manual,
      ),
      LocalChunk(
        id: 'scope-2',
        documentId: 'ignored',
        text: 'Második exportálható chunk',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.manual,
      ),
    ], replaceExisting: false);
    ChunkPackage? savedPackage;

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
          chunkExportSaver: (package) async {
            savedPackage = package;
            return '/memory/single-selection.json';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('chunk-card-scope-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pdf-chunk-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chunk export'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('chunk-export-scope-current_chunk')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chunk-export-scope-selected_chunks')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('chunk-export-confirm')),
    );
    await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
    await tester.pumpAndSettle();

    expect(
      savedPackage?.chunks.map((chunk) => chunk.id),
      orderedEquals(const ['scope-2']),
    );
  });

  testWidgets(
    'multiple selected PDF chunks export only the selected chunk subset',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'multiple-selection.pdf',
        localPath: '/memory/multiple-selection.pdf',
        sizeBytes: 8,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'hash-multiple-selection',
      );
      await repository.saveLocalChunks(document.id, const [
        LocalChunk(
          id: 'multi-1',
          documentId: 'ignored',
          text: 'Első kijelölt chunk',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
        ),
        LocalChunk(
          id: 'multi-2',
          documentId: 'ignored',
          text: 'Második kijelölt chunk',
          pageNumber: 2,
          pipeline: LocalExtractionPipeline.manual,
        ),
        LocalChunk(
          id: 'multi-3',
          documentId: 'ignored',
          text: 'Nem kijelölt chunk',
          pageNumber: 3,
          pipeline: LocalExtractionPipeline.manual,
        ),
      ], replaceExisting: false);
      ChunkPackage? savedPackage;

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: repository,
            document: document,
            chunkExportSaver: (package) async {
              savedPackage = package;
              return '/memory/multiple-selection.json';
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('chunk-card-multi-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chunk-card-multi-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pdf-chunk-selection-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chunk export'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chunk-export-scope-selected_chunks')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('chunk-export-confirm')),
      );
      await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
      await tester.pumpAndSettle();

      expect(savedPackage?.chunks.map((chunk) => chunk.id).toSet(), const {
        'multi-1',
        'multi-2',
      });
    },
  );

  testWidgets(
    'long press sends selected PDF chunks to a note as idempotent links',
    (tester) async {
      final knowledgeRepository = KnowledgeDocumentRepository();
      final noteRepository = MemoryNoteRepository();
      final note = await noteRepository.createDocumentNote(
        title: 'Kutatás',
        document: NoteDocument.empty(),
      );
      final document = await knowledgeRepository.addDocument(
        filename: 'send.pdf',
        localPath: '/memory/send.pdf',
        sizeBytes: 8,
        importedAt: DateTime.utc(2026, 7, 25),
        sha256: 'hash-send',
      );
      await knowledgeRepository.saveLocalChunks(document.id, const [
        LocalChunk(
          id: 'send-1',
          documentId: 'ignored',
          text: 'Beküldendő tudáselem',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.manual,
        ),
      ], replaceExisting: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: knowledgeRepository,
            document: document,
            noteRepository: noteRepository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const ValueKey('chunk-card-send-1')));
      await tester.pumpAndSettle();
      expect(find.text('1 kijelölve'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pdf-chunk-selection-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jegyzetbe küldés'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('send-chunks-to-note-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(ValueKey('send-chunks-to-note-${note.id}')));
      await tester.pumpAndSettle();

      expect(await noteRepository.listLinkedChunkIds(note.id), {
        '${document.id}:send-1',
      });
      expect(find.text('PDF chunkok'), findsOneWidget);
    },
  );

  testWidgets(
    'pdf chunk list reorders with the shared drag handle and does not open validation',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'reorder.pdf',
        localPath: '/memory/reorder.pdf',
        sizeBytes: 8,
        importedAt: DateTime.utc(2026, 6, 14),
        sha256: 'hash-reorder-ui',
      );
      await repository.saveLocalChunks(document.id, const [
        LocalChunk(
          id: 'pdf-first',
          documentId: 'document-1',
          text: 'Első PDF chunk',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
          kind: LocalChunkKind.text,
        ),
        LocalChunk(
          id: 'pdf-second',
          documentId: 'document-1',
          text: 'Második PDF chunk',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
          kind: LocalChunkKind.text,
        ),
        LocalChunk(
          id: 'pdf-third',
          documentId: 'document-1',
          text: 'Harmadik PDF chunk',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
          kind: LocalChunkKind.text,
        ),
      ], replaceExisting: false);

      await tester.pumpWidget(
        MaterialApp(
          home: ExtractedKnowledgeScreen(
            repository: repository,
            document: document,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('chunk-validation-card')), findsNothing);

      expect(
        find.byKey(const ValueKey('shared-chunk-drag-pdf-first')),
        findsOneWidget,
      );
      await tester.drag(
        find.byKey(const ValueKey('shared-chunk-drag-pdf-first')),
        const Offset(0, 190),
      );
      await tester.pumpAndSettle();

      final items = await repository.listExtractedKnowledgeItems(document.id);
      expect(items.map((item) => item.id), [
        'pdf-second',
        'pdf-first',
        'pdf-third',
      ]);
    },
  );

  testWidgets('flowchart card uses unified editor and persists label edits', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'flow-editor.pdf',
      localPath: '/memory/flow-editor.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'hash-flow-editor-ui',
    );
    await repository.saveFlowchartCandidate(
      documentPublicId: document.id,
      flowchart: const AiFlowchartCandidate(
        id: 'flow-edit-1',
        pageNumber: 1,
        title: 'Szerkeszthető flow',
        nodes: [
          AiFlowchartNode(
            id: 'n1',
            label: 'Start',
            shape: AiFlowchartNodeShape.startEnd,
            order: 1,
          ),
        ],
        edges: [],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ExtractedKnowledgeScreen(
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chunk-card-flow-edit-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-flowchart-canvas-editor')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-node-label-n1')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-flowchart-node-inline-field-n1')),
      'Újraértékelés',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final saved = (await repository.listExtractedKnowledgeItems(
      document.id,
    )).single;
    final block = NoteBlock.fromJson(
      Map<String, Object?>.from(
        (jsonDecode(saved.structuredContentJson!) as Map),
      ),
    );
    expect(block.nodes.map((node) => node.label), contains('Újraértékelés'));
  });
}

Future<void> _expectPdfChunkEditor(
  WidgetTester tester, {
  required ValueKey<String> cardKey,
  required ValueKey<String> editorKey,
}) async {
  await tester.scrollUntilVisible(
    find.byKey(cardKey),
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(cardKey));
  await tester.pumpAndSettle();

  expect(find.byKey(editorKey), findsOneWidget);

  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

class _CapturingKnowledgeDocumentRepository
    extends KnowledgeDocumentRepository {
  List<NoteKnowledgeTag>? lastUpdatedTags;

  @override
  Future<void> updateExtractedKnowledgeTags(
    String documentPublicId,
    String itemId,
    List<NoteKnowledgeTag> tags,
  ) async {
    lastUpdatedTags = List.unmodifiable(tags);
    await super.updateExtractedKnowledgeTags(documentPublicId, itemId, tags);
  }
}
