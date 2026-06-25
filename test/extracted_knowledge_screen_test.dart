import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/extracted_knowledge_screen.dart';
import 'package:djinn/src/knowledge/ui/pdf_chunk_note_block_adapter.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/shared/chunks/chunk_card.dart';

void main() {
  test('chunk cards expose only the four shared chunk kinds', () {
    expect(ChunkCardKind.values.map((kind) => kind.name), [
      'text',
      'list',
      'table',
      'flowchart',
    ]);
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

  testWidgets('manual pdf chunk cards render saved tag pills', (tester) async {
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

    await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
    await tester.pumpAndSettle();

    expect(find.text('súlyos'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
    await tester.pumpAndSettle();

    final scrollable = tester.widget<Scrollable>(
      find.byType(Scrollable).first,
    );
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
      await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuális chunkok').last);
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
        editorKey: const ValueKey('note-text-chunk-editor'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-list'),
        editorKey: const ValueKey('note-list-chunk-editor'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-table'),
        editorKey: const ValueKey('note-table-zoomable-content'),
      );
      await _expectPdfChunkEditor(
        tester,
        cardKey: const ValueKey('chunk-card-pdf-flow'),
        editorKey: const ValueKey('note-flowchart-canvas-editor'),
      );
    },
  );

  testWidgets('mixed flowchart rows open the interactive flowchart editor', (
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
      find.byKey(const ValueKey('chunk-card-flow-mixed:n1')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('chunk-card-flow-mixed:n1')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('flowchart-editor-canvas')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-canvas-editor')),
      findsNothing,
    );
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
    await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
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

    await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
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

  testWidgets('flowchart tab provides named views without color rail clutter', (
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
    expect(find.text('Légzés algoritmus'), findsWidgets);
    expect(find.text('Lista'), findsOneWidget);
    expect(find.text('Canvas'), findsOneWidget);
    expect(find.text('Guide'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flowchart-group-flow-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('flowchart-rename-flow-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('flowchart-title-field')),
      'Új légzés flow',
    );
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Új légzés flow'), findsWidgets);
    expect(
      find.byKey(const ValueKey('mobile-flowchart-view-list-flow-1')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('flow-color-rail')), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-flowchart-branch-n1-igen')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-flowchart-branch-n1-nem')),
      findsOneWidget,
    );
    expect(find.text('Igen'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('mobile-flowchart-selector-canvas')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-flowchart-view-canvas-flow-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('mobile-flowchart-selector-guide')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('mobile-flowchart-view-guide-flow-1')),
      findsOneWidget,
    );
  });
  testWidgets('pdf chunk menu exposes only AI and manual OCR-assisted modes', (
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

    expect(find.text('AI chunkok'), findsOneWidget);
    expect(find.text('AI szöveg chunk'), findsOneWidget);
    expect(find.text('Régi lokális OCR chunk'), findsNothing);
    expect(find.text('Lokális chunkok'), findsNothing);
    expect(find.text('Összehasonlítás'), findsNothing);
    expect(find.text('Score'), findsNothing);
    expect(find.text('Kép'), findsNothing);
    expect(find.text('Vizuális tény'), findsNothing);
    expect(find.byKey(const ValueKey('extracted-type-all')), findsNothing);

    await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
    await tester.pumpAndSettle();

    expect(find.text('Manuális chunkok'), findsOneWidget);
    expect(find.text('Manuális szöveg chunk'), findsOneWidget);
    expect(find.text('Régi lokális OCR chunk'), findsOneWidget);
    expect(find.text('AI szöveg chunk'), findsNothing);
  });

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

      await tester.tap(find.byKey(const Key('pdf-chunk-mode-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manuális chunkok').last);
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey('chunk-card-pdf-first')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chunk-validation-card')),
        findsNothing,
      );

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

  testWidgets('flowchart card opens interactive editor and saves added nodes', (
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

    await tester.tap(find.byKey(const ValueKey('flowchart-edit-flow-edit-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('flowchart-editor-canvas')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('flowchart-editor-add-node')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('flowchart-editor-node-label-field')),
      'Újraértékelés',
    );
    await tester.tap(find.text('Mentés').last);
    await tester.pumpAndSettle();
    expect(find.text('Újraértékelés'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flowchart-editor-save')));
    await tester.pumpAndSettle();

    final saved = await repository.loadEditableFlowchart(
      documentId: document.id,
      flowchartId: 'flow-edit-1',
    );
    expect(saved?.nodes.map((node) => node.label), contains('Újraértékelés'));
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
