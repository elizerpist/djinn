import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/notes/models/note_document.dart';
import 'package:djinn/src/notes/ui/note_flowchart_editor_screen.dart';

void main() {
  testWidgets('flowchart editor preserves yes and no decision branches', (
    tester,
  ) async {
    NoteBlock? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.of(context).push<NoteBlock>(
                MaterialPageRoute(
                  builder: (_) => const NoteFlowchartEditorScreen(
                    block: NoteBlock(
                      id: 'flow-1',
                      type: NoteBlockType.flowchart,
                      title: 'Légzési döntés',
                      nodes: [
                        NoteFlowchartNode(
                          id: 'decision',
                          label: 'Légzési elégtelenség?',
                          shape: AiFlowchartNodeShape.decision,
                          order: 1,
                        ),
                        NoteFlowchartNode(id: 'yes', label: 'Oxigén', order: 2),
                        NoteFlowchartNode(id: 'no', label: 'Megfigyelés', order: 3),
                      ],
                      edges: [
                        NoteFlowchartEdge(
                          id: 'edge-yes',
                          fromNodeId: 'decision',
                          toNodeId: 'yes',
                          label: 'Igen',
                          order: 1,
                        ),
                        NoteFlowchartEdge(
                          id: 'edge-no',
                          fromNodeId: 'decision',
                          toNodeId: 'no',
                          label: 'Nem',
                          order: 2,
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
    expect(find.text('Igen'), findsOneWidget);
    expect(find.text('Nem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('note-flowchart-save')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.edges.map((edge) => edge.label), containsAll(['Igen', 'Nem']));
    expect(result!.plainText, contains('Légzési elégtelenség? -> Oxigén [Igen]'));
    expect(result!.plainText, contains('Légzési elégtelenség? -> Megfigyelés [Nem]'));
  });

  testWidgets('flowchart canvas shows grid, per-node connectors, and tap edits node text', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(
                id: 'decision',
                label: 'Légzési elégtelenség?',
                shape: AiFlowchartNodeShape.decision,
                order: 1,
                x: 120,
                y: 120,
              ),
              NoteFlowchartNode(
                id: 'oxygen',
                label: 'Oxigén',
                shape: AiFlowchartNodeShape.process,
                order: 2,
                x: 120,
                y: 280,
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('note-flowchart-grid')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-decision-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-decision-yes')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-decision-no')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-oxygen-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-oxygen-out')), findsOneWidget);
    expect(find.byIcon(Icons.link), findsNothing);

    await tester.tap(find.text('Légzési elégtelenség?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('note-flowchart-node-label-field')),
      'Súlyos légzési elégtelenség?',
    );
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.nodes.first.label, 'Súlyos légzési elégtelenség?');
  });
}
