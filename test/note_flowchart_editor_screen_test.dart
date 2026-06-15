import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

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

  testWidgets('flowchart canvas connects with highlighted connector mode and inline text editing', (
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note-flowchart-connector-decision-yes')),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('note-flowchart-connector-decision-no')),
        matching: find.byIcon(Icons.remove),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('note-flowchart-connector-decision-yes')));
    await tester.pump(const Duration(milliseconds: 120));
    final sourceScale = tester.widget<AnimatedScale>(
      find.byKey(const ValueKey('note-flowchart-source-scale-decision')),
    );
    expect(sourceScale.scale, greaterThan(1));
    final cardOpacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('note-flowchart-card-opacity-decision')),
    );
    expect(cardOpacity.opacity, lessThan(1));

    await tester.tap(find.byKey(const ValueKey('note-flowchart-connector-oxygen-in')));
    await tester.pumpAndSettle();
    expect(latest, isNotNull);
    expect(latest!.edges.single.label, 'Igen');

    await tester.tap(find.byKey(const ValueKey('note-flowchart-node-label-decision')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('note-flowchart-node-shape-field')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('note-flowchart-node-inline-field-decision')),
      'Súlyos légzési elégtelenség?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(latest!.nodes.first.label, 'Súlyos légzési elégtelenség?');
  });

  testWidgets('palette single tap does not add flowchart nodes', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(
                id: 'node-1',
                label: 'Kezdés',
                shape: AiFlowchartNodeShape.startEnd,
                order: 1,
                x: 120,
                y: 120,
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-flowchart-palette-process')));
    await tester.pumpAndSettle();

    expect(latest, isNull);
    expect(find.byKey(const ValueKey('note-flowchart-source-scale-node-2')), findsNothing);
  });
}
