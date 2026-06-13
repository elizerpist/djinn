import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/ui/extracted_knowledge_screen.dart';

void main() {
  testWidgets('flowchart tab renders a logical hierarchy with shape labels', (
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
        ],
        edges: [
          AiFlowchartEdge(
            id: 'e1',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            label: 'igen',
            order: 2,
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
    await tester.tap(find.text('Flowchart'));
    await tester.pumpAndSettle();

    expect(find.text('Légzés algoritmus'), findsOneWidget);
    expect(find.text('Döntés'), findsOneWidget);
    expect(find.text('Folyamatlépés'), findsOneWidget);
    expect(find.text('Folyamvonal: igen'), findsNothing);
    expect(find.text('IGEN'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('flow-connector-flow-1:e1')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
    expect(find.byIcon(Icons.change_history), findsOneWidget);
  });
}
