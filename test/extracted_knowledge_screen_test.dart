import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
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
    expect(find.text('Légzés algoritmus'), findsOneWidget);
    expect(find.text('Törzs + ágkártyák'), findsOneWidget);
    expect(find.text('Térkép + olvasólista'), findsOneWidget);
    expect(find.text('Swimlane ágak'), findsOneWidget);
    expect(find.text('Kinyitható döntéskártya'), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-group-flow-1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('flowchart-rename-flow-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('flowchart-title-field')), 'Új légzés flow');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();
    expect(find.text('Új légzés flow'), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-trunk-view-flow-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('flow-color-rail')), findsNothing);
    expect(find.text('IGEN'), findsOneWidget);
    expect(find.text('NEM'), findsOneWidget);
    expect(find.byIcon(Icons.change_history), findsOneWidget);

    await tester.tap(find.text('Térkép + olvasólista'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-map-view-flow-1')), findsOneWidget);

    await tester.tap(find.text('Swimlane ágak'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-swimlane-view-flow-1')), findsOneWidget);

    await tester.ensureVisible(find.text('Kinyitható döntéskártya'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinyitható döntéskártya'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-decision-view-flow-1')), findsOneWidget);
  });
}
