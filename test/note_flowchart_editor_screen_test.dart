import 'package:flutter/gestures.dart';
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
                        NoteFlowchartNode(
                          id: 'no',
                          label: 'Megfigyelés',
                          order: 3,
                        ),
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
    expect(
      result!.edges.map((edge) => edge.label),
      containsAll(['Igen', 'Nem']),
    );
    expect(
      result!.plainText,
      contains('Légzési elégtelenség? -> Oxigén [Igen]'),
    );
    expect(
      result!.plainText,
      contains('Légzési elégtelenség? -> Megfigyelés [Nem]'),
    );
  });

  testWidgets(
    'flowchart canvas connects with highlighted connector mode and inline text editing',
    (tester) async {
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
      expect(
        find.byKey(const ValueKey('note-flowchart-connector-decision-in')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-connector-decision-yes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-connector-decision-no')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-connector-oxygen-in')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-connector-oxygen-out')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.link), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('note-flowchart-connector-decision-yes'),
          ),
          matching: find.byIcon(Icons.add),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey('note-flowchart-connector-decision-no'),
          ),
          matching: find.byIcon(Icons.remove),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-connector-decision-yes')),
      );
      await tester.pump(const Duration(milliseconds: 120));
      final sourceScale = tester.widget<AnimatedScale>(
        find.byKey(const ValueKey('note-flowchart-source-scale-decision')),
      );
      expect(sourceScale.scale, greaterThan(1));
      final cardOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('note-flowchart-card-opacity-decision')),
      );
      expect(cardOpacity.opacity, lessThan(1));

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-connector-oxygen-in')),
      );
      await tester.pumpAndSettle();
      expect(latest, isNotNull);
      expect(latest!.edges.single.label, 'Igen');

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-decision')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-flowchart-node-shape-field')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-flowchart-node-inline-field-decision')),
        'Súlyos légzési elégtelenség?',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(latest!.nodes.first.label, 'Súlyos légzési elégtelenség?');
    },
  );

  testWidgets(
    'flowchart inline label rail applies and clears Kitöltés ranges',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-fill',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'node-1',
                  label: 'Súlyos állapot',
                  x: 120,
                  y: 120,
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-node-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-flowchart-fill-rail')),
        findsOneWidget,
      );

      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-flowchart-node-inline-field-node-1')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-fill-0xfffff59d')),
      );
      await tester.pumpAndSettle();

      expect(latest!.nodes.single.labelFills.single.start, 0);
      expect(latest!.nodes.single.labelFills.single.end, 6);
      expect(latest!.nodes.single.labelFills.single.colorValue, 0xFFFFF59D);

      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 6,
      );
      await tester.tap(find.byKey(const ValueKey('note-flowchart-fill-clear')));
      await tester.pumpAndSettle();

      expect(latest!.nodes.single.labelFills, isEmpty);
    },
  );

  testWidgets(
    'clearing part of a node label fill preserves both outer fragments',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-node-partial-fill-clear',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'node-1',
                  label: 'ABCDEFGHIJ',
                  labelFills: [
                    NoteTextFill(
                      id: 'node-fill',
                      start: 0,
                      end: 10,
                      colorValue: 0xFFFFF59D,
                    ),
                  ],
                  x: 120,
                  y: 120,
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-node-1')),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-flowchart-node-inline-field-node-1')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 6,
      );
      await tester.tap(find.byKey(const ValueKey('note-flowchart-fill-clear')));
      await tester.pumpAndSettle();

      expect(
        latest!.nodes.single.labelFills
            .map((fill) => (fill.start, fill.end, fill.colorValue))
            .toList(),
        [(0, 3, 0xFFFFF59D), (6, 10, 0xFFFFF59D)],
      );
    },
  );

  testWidgets(
    'recoloring part of an edge label fill preserves both outer fragments',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-edge-partial-fill-recolor',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(id: 'from', label: 'Forrás', x: 120, y: 120),
                NoteFlowchartNode(id: 'to', label: 'Cél', x: 120, y: 320),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'from',
                  toNodeId: 'to',
                  label: 'ABCDEFGHIJ',
                  labelFills: [
                    NoteTextFill(
                      id: 'edge-fill',
                      start: 0,
                      end: 10,
                      colorValue: 0xFFFFF59D,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-edge-label-edge-1')),
      );
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('note-flowchart-edge-inline-field-edge-1')),
      );
      field.controller!.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 6,
      );
      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-fill-0xffbbdefb')),
      );
      await tester.pumpAndSettle();

      expect(
        latest!.edges.single.labelFills
            .map((fill) => (fill.start, fill.end, fill.colorValue))
            .toList(),
        [(0, 3, 0xFFFFF59D), (3, 6, 0xFFBBDEFB), (6, 10, 0xFFFFF59D)],
      );
    },
  );

  testWidgets(
    'node and edge label fills independently follow their text edit deltas',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-fill-deltas',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'a',
                  label: 'Alpha Beta',
                  labelFills: [
                    NoteTextFill(
                      id: 'node-fill',
                      start: 6,
                      end: 10,
                      colorValue: 0xFFFFF59D,
                    ),
                  ],
                  x: 120,
                  y: 120,
                ),
                NoteFlowchartNode(id: 'b', label: 'Target', x: 120, y: 320),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'a',
                  toNodeId: 'b',
                  label: 'Say Alpha Beta',
                  labelFills: [
                    NoteTextFill(
                      id: 'edge-fill',
                      start: 10,
                      end: 14,
                      colorValue: 0xFFC8E6C9,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-a')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-flowchart-node-inline-field-a')),
        'Say Alpha Beta',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        (
          latest!.nodes.first.labelFills.single.start,
          latest!.nodes.first.labelFills.single.end,
        ),
        (10, 14),
      );
      expect(
        (
          latest!.edges.single.labelFills.single.start,
          latest!.edges.single.labelFills.single.end,
        ),
        (10, 14),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-edge-label-edge-1')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-flowchart-edge-inline-field-edge-1')),
        'Alpha Beta',
      );
      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-edge-commit-edge-1')),
      );
      await tester.pumpAndSettle();

      expect(
        (
          latest!.nodes.first.labelFills.single.start,
          latest!.nodes.first.labelFills.single.end,
        ),
        (10, 14),
      );
      expect(
        (
          latest!.edges.single.labelFills.single.start,
          latest!.edges.single.labelFills.single.end,
        ),
        (6, 10),
      );
    },
  );

  testWidgets(
    'deleting an edited node clears its and incident edge fill scopes',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-fill-delete',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'a',
                  label: 'Alpha',
                  labelFills: [
                    NoteTextFill(
                      id: 'node-fill',
                      start: 0,
                      end: 5,
                      colorValue: 0xFFFFF59D,
                    ),
                  ],
                  x: 120,
                  y: 120,
                ),
                NoteFlowchartNode(id: 'b', label: 'Beta', x: 120, y: 320),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'a',
                  toNodeId: 'b',
                  label: 'next',
                  labelFills: [
                    NoteTextFill(
                      id: 'edge-fill',
                      start: 0,
                      end: 4,
                      colorValue: 0xFFC8E6C9,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-a')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('note-flowchart-fill-rail')),
        findsOneWidget,
      );

      final delete = find.descendant(
        of: find.byKey(const ValueKey('note-flowchart-node-a')),
        matching: find.byTooltip('Törlés'),
      );
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(latest!.nodes.map((node) => node.id), ['b']);
      expect(latest!.edges, isEmpty);
      expect(latest!.nodes.expand((node) => node.labelFills), isEmpty);
      expect(
        find.byKey(const ValueKey('note-flowchart-fill-rail')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'new node fill stays at edited coordinates while existing fill shifts',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-fill-live-edit',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'a',
                  label: 'Alpha Beta',
                  labelFills: [
                    NoteTextFill(
                      id: 'existing-fill',
                      start: 6,
                      end: 10,
                      colorValue: 0xFFFFF59D,
                    ),
                  ],
                  x: 120,
                  y: 120,
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-label-a')),
      );
      await tester.pumpAndSettle();
      final fieldFinder = find.byKey(
        const ValueKey('note-flowchart-node-inline-field-a'),
      );
      await tester.enterText(fieldFinder, 'Say Alpha Beta');
      final field = tester.widget<TextField>(fieldFinder);
      field.controller!.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-fill-0xffc8e6c9')),
      );
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final ranges =
          latest!.nodes.single.labelFills
              .map((fill) => (fill.start, fill.end))
              .toList()
            ..sort((left, right) => left.$1.compareTo(right.$1));
      expect(ranges, [(0, 3), (10, 14)]);
    },
  );

  testWidgets('palette single tap does not add flowchart nodes', (
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

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-fab-universal')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNull);
    expect(
      find.byKey(const ValueKey('note-flowchart-source-scale-node-2')),
      findsNothing,
    );
  });

  testWidgets(
    'palette long press drag shows ghost and drops a node on canvas',
    (tester) async {
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

      final palette = find.byKey(
        const ValueKey('note-flowchart-fab-universal'),
      );
      final canvas = find.byKey(const ValueKey('note-flowchart-grid'));
      final start = tester.getCenter(palette);
      final drop = tester.getTopLeft(canvas) + const Offset(260, 260);

      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));
      await gesture.moveTo(drop);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('note-flowchart-palette-ghost-universal')),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.nodes, hasLength(2));
      expect(latest!.nodes.last.shape, AiFlowchartNodeShape.process);
      expect(
        find.byKey(const ValueKey('note-flowchart-palette-ghost-universal')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'dragging an existing node after palette drop keeps the new node',
    (tester) async {
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

      final palette = find.byKey(
        const ValueKey('note-flowchart-fab-universal'),
      );
      final canvas = find.byKey(const ValueKey('note-flowchart-grid'));
      final start = tester.getCenter(palette);
      final drop = tester.getTopLeft(canvas) + const Offset(260, 300);

      final gesture = await tester.startGesture(start);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));
      await gesture.moveTo(drop);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      expect(latest!.nodes, hasLength(2));

      await tester.drag(
        find.byKey(const ValueKey('note-flowchart-node-node-2')),
        const Offset(20, 24),
      );
      await tester.pumpAndSettle();

      expect(latest!.nodes, hasLength(2));
      expect(
        latest!.nodes.map((node) => node.id),
        containsAll(['node-1', 'node-2']),
      );
    },
  );

  testWidgets('flowchart palette exposes simplified logical elements only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'node-1', label: 'Kezdés', x: 120, y: 120),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-flowchart-fab-universal')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-fab-binary-decision')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-fab-multi-decision')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-palette-subprocess')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-palette-dataStore')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-palette-container')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-zoom-in')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-zoom-out')),
      findsOneWidget,
    );

    final universal = tester.getTopLeft(
      find.byKey(const ValueKey('note-flowchart-fab-universal')),
    );
    final binary = tester.getTopLeft(
      find.byKey(const ValueKey('note-flowchart-fab-binary-decision')),
    );
    final multi = tester.getTopLeft(
      find.byKey(const ValueKey('note-flowchart-fab-multi-decision')),
    );
    expect(binary.dx, universal.dx);
    expect(multi.dx, universal.dx);
    expect(binary.dy, greaterThan(universal.dy));
    expect(multi.dy, greaterThan(binary.dy));
  });

  testWidgets('node body opens popup while label tap keeps inline editing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'node-1', label: 'Kezdés', x: 120, y: 120),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-node-label-node-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('note-flowchart-node-inline-field-node-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-node-popup')),
      findsNothing,
    );

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-node-body-node-1')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('note-flowchart-node-popup')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-node-popup-type-universal')),
      findsOneWidget,
    );
    expect(find.text('Forma'), findsNothing);
    expect(find.text('Rombusz'), findsNothing);
    expect(find.text('Ovális'), findsNothing);
    expect(
      find.byKey(const ValueKey('note-flowchart-node-popup-add-port')),
      findsOneWidget,
    );
  });

  testWidgets('flowchart node tags stay metadata without canvas coloring', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-tags',
            type: NoteBlockType.flowchart,
            title: 'Ellátási ág',
            nodes: [
              NoteFlowchartNode(id: 'node-1', label: 'Súlyos?', x: 120, y: 120),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-node-select-node-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-chunk-menu-tag-selection')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'súlyos',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(
      latest!.scopedTags.single.target.kind,
      NoteTagTargetKind.flowchartNode,
    );
    expect(latest!.scopedTags.single.target.elementId, 'node-1');
    expect(
      find.byKey(const ValueKey('note-flowchart-node-tag-marker-node-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-node-tag-outline-node-1')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('note-selected-tag-tray')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-flowchart-canvas-tag-pill-súlyos')),
      findsNothing,
    );
  });

  testWidgets('flowchart edge tags stay metadata without edge coloring', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-tags',
            type: NoteBlockType.flowchart,
            title: 'Ellátási ág',
            nodes: [
              NoteFlowchartNode(id: 'node-1', label: 'Súlyos?', x: 120, y: 120),
              NoteFlowchartNode(id: 'node-2', label: 'Oxygén', x: 340, y: 120),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-1',
                fromNodeId: 'node-1',
                toNodeId: 'node-2',
                label: 'Igen',
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-edge-select-edge-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-chunk-overflow-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('note-chunk-menu-tag-selection')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('tag-manager-name')),
      'igen ág',
    );
    await tester.tap(find.byKey(const ValueKey('tag-manager-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tag-manager-close')));
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(
      latest!.scopedTags.single.target.kind,
      NoteTagTargetKind.flowchartEdge,
    );
    expect(latest!.scopedTags.single.target.elementId, 'edge-1');
    expect(
      find.byKey(const ValueKey('note-flowchart-edge-tag-marker-edge-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-edge-tag-line-edge-1')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('note-selected-tag-tray')), findsNothing);
    expect(
      find.byKey(const ValueKey('note-flowchart-canvas-tag-pill-igen ág')),
      findsNothing,
    );
  });

  testWidgets('flowchart deleting an edge prunes stale scoped edge tags', (
    tester,
  ) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-tags',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'node-1', label: 'Súlyos?', x: 120, y: 120),
              NoteFlowchartNode(id: 'node-2', label: 'Oxygén', x: 340, y: 120),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-1',
                fromNodeId: 'node-1',
                toNodeId: 'node-2',
                label: 'Igen',
              ),
            ],
            scopedTags: [
              NoteScopedTagAssignment(
                id: 'edge-tag',
                target: NoteTagTarget(
                  kind: NoteTagTargetKind.flowchartEdge,
                  elementId: 'edge-1',
                ),
                tags: [
                  NoteKnowledgeTag(
                    type: NoteKnowledgeTagTypes.branch,
                    label: 'igen ág',
                  ),
                ],
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-edge-delete-edge-1')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.edges, isEmpty);
    expect(latest!.scopedTags, isEmpty);
  });

  testWidgets('ports connect in tapped direction and store endpoint ids', (
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
                id: 'a',
                label: 'Alsó lépés',
                x: 120,
                y: 320,
                ports: [
                  NoteFlowchartPort(
                    id: 'right-1',
                    side: NoteFlowchartPortSide.right,
                    label: 'ki',
                  ),
                ],
              ),
              NoteFlowchartNode(
                id: 'b',
                label: 'Felső lépés',
                x: 120,
                y: 120,
                ports: [
                  NoteFlowchartPort(
                    id: 'left-1',
                    side: NoteFlowchartPortSide.left,
                    label: 'be',
                  ),
                ],
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-connector-a-right-1')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-connector-b-left-1')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.edges.single.fromNodeId, 'a');
    expect(latest!.edges.single.fromPortId, 'right-1');
    expect(latest!.edges.single.toNodeId, 'b');
    expect(latest!.edges.single.toPortId, 'left-1');
  });

  testWidgets('connector dots derive input output and shared port states', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-port-state',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(
                id: 'a',
                label: 'A',
                x: 120,
                y: 120,
                ports: [
                  NoteFlowchartPort(
                    id: 'shared',
                    side: NoteFlowchartPortSide.bottom,
                    label: 'közös',
                  ),
                ],
              ),
              NoteFlowchartNode(
                id: 'b',
                label: 'B',
                x: 120,
                y: 320,
                ports: [
                  NoteFlowchartPort(
                    id: 'in',
                    side: NoteFlowchartPortSide.top,
                    label: 'be',
                  ),
                  NoteFlowchartPort(
                    id: 'out',
                    side: NoteFlowchartPortSide.bottom,
                    label: 'ki',
                  ),
                ],
              ),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-forward',
                fromNodeId: 'a',
                fromPortId: 'shared',
                toNodeId: 'b',
                toPortId: 'in',
                label: '',
              ),
              NoteFlowchartEdge(
                id: 'edge-back',
                fromNodeId: 'b',
                fromPortId: 'out',
                toNodeId: 'a',
                toPortId: 'shared',
                label: '',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey(
          'note-flowchart-connector-state-a-shared-inputAndOutput',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-connector-outer-a-shared')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('note-flowchart-connector-state-b-in-inputOnly'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('note-flowchart-connector-state-b-out-outputOnly'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('loop-closing edges are exposed separately from normal edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-loop',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'a', label: 'A', x: 120, y: 120),
              NoteFlowchartNode(id: 'b', label: 'B', x: 120, y: 320),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-forward',
                fromNodeId: 'a',
                toNodeId: 'b',
                label: '',
              ),
              NoteFlowchartEdge(
                id: 'edge-back',
                fromNodeId: 'b',
                toNodeId: 'a',
                label: '',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-flowchart-edge-edge-forward')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-flowchart-loop-edge-edge-back')),
      findsOneWidget,
    );
  });

  testWidgets('all edge labels can delete non decision edges', (tester) async {
    NoteBlock? latest;
    await tester.pumpWidget(
      MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: const NoteBlock(
            id: 'flow-1',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(id: 'a', label: 'A', x: 120, y: 120),
              NoteFlowchartNode(id: 'b', label: 'B', x: 120, y: 280),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-1',
                fromNodeId: 'a',
                toNodeId: 'b',
                label: 'következő',
              ),
            ],
          ),
          onChanged: (block) => latest = block,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-edge-delete-edge-1')),
    );
    await tester.pumpAndSettle();

    expect(latest, isNotNull);
    expect(latest!.edges, isEmpty);
  });

  test('back edge routes sideways before returning upward', () {
    const from = NoteFlowchartNode(id: 'lower', label: 'Alsó', x: 120, y: 420);
    const to = NoteFlowchartNode(id: 'upper', label: 'Felső', x: 120, y: 120);
    const edge = NoteFlowchartEdge(
      id: 'edge-1',
      fromNodeId: 'lower',
      toNodeId: 'upper',
      label: 'vissza',
    );
    final route = debugFlowchartRouteForTest(edge, from, to, {
      from.id: const Size(220, 90),
      to.id: const Size(220, 90),
    });

    expect(route.kind, 'backEdge');
    expect(route.points.length, greaterThanOrEqualTo(6));
    expect(route.points[1].dx, route.points.first.dx);
    expect(route.points[1].dy, greaterThan(route.points.first.dy));
    expect(route.points[2].dx, isNot(route.points.first.dx));
    expect(route.points[3].dy, lessThan(route.points.first.dy));
  });

  testWidgets(
    'editor expands virtual canvas and lazily skips far offscreen nodes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: NoteBlock(
              id: 'flow-virtual',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'near',
                  label: 'Közeli lépés',
                  x: 120,
                  y: 120,
                ),
                NoteFlowchartNode(
                  id: 'far',
                  label: 'Távoli lépés',
                  x: 5200,
                  y: 4200,
                ),
              ],
            ),
          ),
        ),
      );

      final surface = tester.widget<SizedBox>(
        find.byKey(const ValueKey('note-flowchart-canvas-surface')),
      );
      expect(surface.width, greaterThan(6000));
      expect(surface.height, greaterThan(5000));
      expect(
        find.byKey(const ValueKey('note-flowchart-node-near')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-node-far')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'binary decision yes and no ports cannot be deleted but can move sides',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-ports',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'decision',
                  label: 'Légzési elégtelenség?',
                  kind: NoteFlowchartNodeKind.binaryDecision,
                  shape: AiFlowchartNodeShape.decision,
                  visualShape: NoteFlowchartVisualShape.diamond,
                  x: 120,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'in',
                      side: NoteFlowchartPortSide.top,
                      label: 'Bemenet',
                    ),
                    NoteFlowchartPort(
                      id: 'yes',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Igen',
                      semantic: NoteFlowchartPortSemantic.yes,
                    ),
                    NoteFlowchartPort(
                      id: 'no',
                      side: NoteFlowchartPortSide.bottom,
                      label: 'Nem',
                      semantic: NoteFlowchartPortSemantic.no,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-body-decision')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('note-flowchart-node-popup-port-delete-yes')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('note-flowchart-node-popup-port-delete-no')),
        findsNothing,
      );

      final yesLeft = find.byKey(
        const ValueKey('note-flowchart-node-popup-port-side-yes-left'),
      );
      await tester.ensureVisible(yesLeft);
      await tester.pumpAndSettle();
      await tester.tap(yesLeft);
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      final yes = latest!.nodes.single.ports.singleWhere(
        (port) => port.id == 'yes',
      );
      expect(yes.side, NoteFlowchartPortSide.left);
    },
  );

  testWidgets(
    'multi decision branch ports can be renamed and moved to any side',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-multi',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'sat',
                  label: 'Szaturáció?',
                  kind: NoteFlowchartNodeKind.multiDecision,
                  shape: AiFlowchartNodeShape.decision,
                  visualShape: NoteFlowchartVisualShape.diamond,
                  x: 120,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'branch-1',
                      side: NoteFlowchartPortSide.right,
                      label: 'Ág 1',
                      semantic: NoteFlowchartPortSemantic.custom,
                    ),
                  ],
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-body-sat')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey('note-flowchart-node-popup-port-label-branch-1'),
        ),
        '90-95%',
      );
      final branchLeft = find.byKey(
        const ValueKey('note-flowchart-node-popup-port-side-branch-1-left'),
      );
      await tester.ensureVisible(branchLeft);
      await tester.pumpAndSettle();
      await tester.tap(branchLeft);
      await tester.pumpAndSettle();

      expect(latest, isNotNull);
      final branch = latest!.nodes.single.ports.singleWhere(
        (port) => port.id == 'branch-1',
      );
      expect(branch.label, '90-95%');
      expect(branch.side, NoteFlowchartPortSide.left);
    },
  );

  testWidgets(
    'deleting a referenced source port keeps the edge with auto attachment',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-delete-referenced-port',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'source',
                  label: 'Forrás',
                  x: 120,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'keep',
                      side: NoteFlowchartPortSide.top,
                      label: 'Marad',
                    ),
                    NoteFlowchartPort(
                      id: 'obsolete-out',
                      side: NoteFlowchartPortSide.right,
                      label: 'Törlendő',
                    ),
                  ],
                ),
                NoteFlowchartNode(
                  id: 'target',
                  label: 'Cél',
                  x: 480,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'target-in',
                      side: NoteFlowchartPortSide.left,
                      label: 'Bemenet',
                    ),
                  ],
                ),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'source',
                  fromPortId: 'obsolete-out',
                  toNodeId: 'target',
                  toPortId: 'target-in',
                  label: 'kapcsolat',
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-body-source')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('note-flowchart-node-popup-port-delete-obsolete-out'),
        ),
      );
      await tester.pumpAndSettle();

      expect(latest!.edges, hasLength(1));
      expect(latest!.edges.single.fromPortId, isNull);
      expect(latest!.edges.single.toPortId, 'target-in');
    },
  );

  testWidgets(
    'node kind port replacement clears a missing target port reference',
    (tester) async {
      NoteBlock? latest;
      await tester.pumpWidget(
        MaterialApp(
          home: NoteFlowchartEditorScreen(
            block: const NoteBlock(
              id: 'flow-kind-replaces-ports',
              type: NoteBlockType.flowchart,
              nodes: [
                NoteFlowchartNode(
                  id: 'source',
                  label: 'Forrás',
                  x: 120,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'out',
                      side: NoteFlowchartPortSide.right,
                      label: 'Kimenet',
                    ),
                  ],
                ),
                NoteFlowchartNode(
                  id: 'target',
                  label: 'Többágú cél',
                  kind: NoteFlowchartNodeKind.multiDecision,
                  shape: AiFlowchartNodeShape.decision,
                  x: 480,
                  y: 120,
                  ports: [
                    NoteFlowchartPort(
                      id: 'branch-target',
                      side: NoteFlowchartPortSide.left,
                      label: 'Régi ág',
                      semantic: NoteFlowchartPortSemantic.custom,
                    ),
                  ],
                ),
              ],
              edges: [
                NoteFlowchartEdge(
                  id: 'edge-1',
                  fromNodeId: 'source',
                  fromPortId: 'out',
                  toNodeId: 'target',
                  toPortId: 'branch-target',
                  label: 'kapcsolat',
                ),
              ],
            ),
            onChanged: (block) => latest = block,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-body-target')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('note-flowchart-node-popup-type-universal')),
      );
      await tester.pumpAndSettle();

      expect(latest!.edges, hasLength(1));
      expect(latest!.edges.single.fromPortId, 'out');
      expect(latest!.edges.single.toPortId, isNull);
    },
  );

  testWidgets('popup preview aligns port dots to the preview shape edges', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-preview',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(
                id: 'decision',
                label: 'Döntés?',
                kind: NoteFlowchartNodeKind.binaryDecision,
                shape: AiFlowchartNodeShape.decision,
                visualShape: NoteFlowchartVisualShape.diamond,
                x: 120,
                y: 120,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('note-flowchart-node-body-decision')),
    );
    await tester.pumpAndSettle();

    final shape = tester.getRect(
      find.byKey(const ValueKey('note-flowchart-preview-shape')),
    );
    final yes = tester.getCenter(
      find.byKey(const ValueKey('note-flowchart-preview-port-yes')),
    );
    final no = tester.getCenter(
      find.byKey(const ValueKey('note-flowchart-preview-port-no')),
    );
    expect(yes.dy, closeTo(shape.bottom, 2));
    expect(no.dy, closeTo(shape.bottom, 2));
    expect(yes.dx, greaterThan(shape.left));
    expect(no.dx, lessThan(shape.right));
  });

  test(
    'back edge from a bottom port leaves the source before routing upward',
    () {
      const from = NoteFlowchartNode(
        id: 'lower',
        label: 'Alsó',
        x: 120,
        y: 420,
        ports: [
          NoteFlowchartPort(
            id: 'out',
            side: NoteFlowchartPortSide.bottom,
            label: 'Kimenet',
          ),
        ],
      );
      const to = NoteFlowchartNode(
        id: 'upper',
        label: 'Felső',
        x: 120,
        y: 120,
        ports: [
          NoteFlowchartPort(
            id: 'in',
            side: NoteFlowchartPortSide.top,
            label: 'Bemenet',
          ),
        ],
      );
      const edge = NoteFlowchartEdge(
        id: 'edge-1',
        fromNodeId: 'lower',
        fromPortId: 'out',
        toNodeId: 'upper',
        toPortId: 'in',
        label: 'vissza',
      );
      final route = debugFlowchartRouteForTest(edge, from, to, {
        from.id: const Size(220, 90),
        to.id: const Size(220, 90),
      });

      expect(route.kind, 'backEdge');
      expect(route.points.length, greaterThanOrEqualTo(6));
      expect(route.points[1].dx, route.points.first.dx);
      expect(route.points[1].dy, greaterThan(route.points.first.dy));
      expect(route.points[2].dx, isNot(route.points.first.dx));
    },
  );

  testWidgets('edge chip display name follows renamed source port label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteFlowchartEditorScreen(
          block: NoteBlock(
            id: 'flow-labels',
            type: NoteBlockType.flowchart,
            nodes: [
              NoteFlowchartNode(
                id: 'sat',
                label: 'Szaturáció?',
                kind: NoteFlowchartNodeKind.multiDecision,
                x: 120,
                y: 120,
                ports: [
                  NoteFlowchartPort(
                    id: 'branch-1',
                    side: NoteFlowchartPortSide.right,
                    label: '90-95%',
                    semantic: NoteFlowchartPortSemantic.custom,
                  ),
                ],
              ),
              NoteFlowchartNode(
                id: 'target',
                label: 'Megfigyelés',
                x: 480,
                y: 120,
                ports: [
                  NoteFlowchartPort(
                    id: 'in',
                    side: NoteFlowchartPortSide.left,
                    label: 'Bemenet',
                  ),
                ],
              ),
            ],
            edges: [
              NoteFlowchartEdge(
                id: 'edge-branch',
                fromNodeId: 'sat',
                fromPortId: 'branch-1',
                toNodeId: 'target',
                toPortId: 'in',
                label: 'Ág 1',
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-flowchart-edge-edge-branch')),
      findsOneWidget,
    );
    expect(find.text('90-95%'), findsOneWidget);
    expect(find.text('Ág 1'), findsNothing);
  });
}
