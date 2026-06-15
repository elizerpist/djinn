import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/extracted_knowledge_screen.dart';

void main() {
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
    expect(find.byKey(const ValueKey('flowchart-group-flow-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flowchart-rename-flow-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('flowchart-title-field')), 'Új légzés flow');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Új légzés flow'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-view-list-flow-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-color-rail')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-n1-igen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-n1-nem')), findsOneWidget);
    expect(find.text('Igen'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-canvas')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-flowchart-view-canvas-flow-1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-guide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-flowchart-view-guide-flow-1')), findsOneWidget);
  });
  testWidgets('pipeline menu and type chips filter extracted chunks', (
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
    await repository.saveLocalChunks(
      document.id,
      const [
        LocalChunk(
          id: 'local-table',
          documentId: 'document-1',
          text: 'Lokális táblázat chunk',
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
      ],
      replaceExisting: false,
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

    expect(find.text('AI szöveg chunk'), findsOneWidget);
    expect(find.text('Lokális táblázat chunk'), findsNothing);
    expect(find.text('Szöveg'), findsOneWidget);
    expect(find.text('Táblázat'), findsOneWidget);
    expect(find.text('Flowchart'), findsOneWidget);

    await tester.tap(find.byKey(const Key('extracted-pipeline-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lokális chunkok').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('extracted-type-table')));
    await tester.pumpAndSettle();

    expect(find.text('Lokális táblázat chunk'), findsOneWidget);
    expect(find.text('AI szöveg chunk'), findsNothing);

    await tester.tap(find.byKey(const Key('extracted-pipeline-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális chunkok').last);
    await tester.pumpAndSettle();
    expect(find.text('Manuális chunkok'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('extracted-type-all')));
    await tester.pumpAndSettle();

    expect(find.text('Manuális szöveg chunk'), findsOneWidget);
  });

  testWidgets('long pressing extracted chunk opens validation editor and saves changes', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'audit.pdf',
      localPath: '/memory/audit.pdf',
      sizeBytes: 8,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'hash-audit-ui',
    );
    await repository.saveLocalChunks(
      document.id,
      const [
        LocalChunk(
          id: 'local-audit-text',
          documentId: 'document-1',
          text: 'Eredeti lokális chunk',
          pageNumber: 1,
          pipeline: LocalExtractionPipeline.localOcr,
          kind: LocalChunkKind.text,
        ),
      ],
      replaceExisting: false,
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

    await tester.tap(find.byKey(const Key('extracted-pipeline-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lokális chunkok').last);
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const ValueKey('chunk-card-local-audit-text')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chunk-validation-card')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('chunk-validation-text-field')),
      'Javított lokális chunk',
    );
    await tester.tap(find.text('Elfogad'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('chunk-validation-save')));
    await tester.pumpAndSettle();

    final items = await repository.listExtractedKnowledgeItems(document.id);
    final edited = items.singleWhere((item) => item.id == 'local-audit-text');
    expect(edited.text, 'Javított lokális chunk');
    expect(edited.auditState, LocalAuditState.accepted);
  });



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
    expect(find.byKey(const ValueKey('flowchart-editor-canvas')), findsOneWidget);

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
