import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/flowchart/ui/mobile_flowchart_viewer.dart';

void main() {
  const data = MobileFlowchartData(
    id: 'flow-mobile',
    title: 'Légzés algoritmus',
    nodes: [
      MobileFlowchartNode(id: 'root', label: 'Légzési elégtelenség?', shape: 'decision'),
      MobileFlowchartNode(id: 'oxygen', label: 'Célzott O2-terápia megfontolása\nCél: SpO2 88-92%.', shape: 'process'),
      MobileFlowchartNode(id: 'shock', label: 'Shock jelek?', shape: 'decision'),
      MobileFlowchartNode(id: 'transport', label: 'Kórházba szállítás', shape: 'process'),
      MobileFlowchartNode(id: 'monitor', label: 'További vizsgálat és monitorozás', shape: 'process'),
    ],
    edges: [
      MobileFlowchartEdge(id: 'e1', fromNodeId: 'root', toNodeId: 'oxygen', label: 'Igen'),
      MobileFlowchartEdge(id: 'e2', fromNodeId: 'root', toNodeId: 'monitor', label: 'Nem'),
      MobileFlowchartEdge(id: 'e3', fromNodeId: 'oxygen', toNodeId: 'shock', label: ''),
      MobileFlowchartEdge(id: 'e4', fromNodeId: 'shock', toNodeId: 'transport', label: 'Igen'),
    ],
  );


  const portAwareData = MobileFlowchartData(
    id: 'flow-port-aware',
    title: 'Editor chart',
    nodes: [
      MobileFlowchartNode(
        id: 'start',
        label: 'Kezdés',
        shape: 'process',
        kind: 'universal',
        role: 'start',
        visualShape: 'rectangle',
        x: 120,
        y: 120,
        ports: [MobileFlowchartPort(id: 'out', side: 'bottom', label: 'Kimenet')],
      ),
      MobileFlowchartNode(
        id: 'sat',
        label: 'Szaturáció?',
        shape: 'decision',
        kind: 'multi_decision',
        visualShape: 'diamond',
        x: 120,
        y: 300,
        ports: [
          MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet'),
          MobileFlowchartPort(id: 'branch-1', side: 'right', label: '90-95%', semantic: 'custom'),
          MobileFlowchartPort(id: 'branch-2', side: 'bottom', label: '80 alatt', semantic: 'custom'),
        ],
      ),
      MobileFlowchartNode(
        id: 'decision',
        label: 'Javul?',
        shape: 'decision',
        kind: 'binary_decision',
        visualShape: 'diamond',
        x: 520,
        y: 520,
        ports: [
          MobileFlowchartPort(id: 'in', side: 'top', label: 'Bemenet'),
          MobileFlowchartPort(id: 'yes', side: 'right', label: 'Igen', semantic: 'yes'),
          MobileFlowchartPort(id: 'no', side: 'left', label: 'Nem', semantic: 'no'),
        ],
      ),
      MobileFlowchartNode(id: 'transport', label: 'Szállítás', x: 760, y: 700),
    ],
    edges: [
      MobileFlowchartEdge(id: 'edge-start-sat', fromNodeId: 'start', toNodeId: 'sat', label: '', fromPortId: 'out', toPortId: 'in'),
      MobileFlowchartEdge(id: 'edge-sat-decision', fromNodeId: 'sat', toNodeId: 'decision', label: 'Ág 1', fromPortId: 'branch-1', toPortId: 'in'),
      MobileFlowchartEdge(id: 'edge-decision-transport', fromNodeId: 'decision', toNodeId: 'transport', label: '', fromPortId: 'yes', toPortId: 'in'),
    ],
  );

  const loopPortData = MobileFlowchartData(
    id: 'flow-loop-ports',
    title: 'Loop és portok',
    nodes: [
      MobileFlowchartNode(
        id: 'a',
        label: 'A',
        x: 120,
        y: 120,
        ports: [
          MobileFlowchartPort(id: 'shared', side: 'bottom', label: 'közös'),
        ],
      ),
      MobileFlowchartNode(
        id: 'b',
        label: 'B',
        x: 120,
        y: 320,
        ports: [
          MobileFlowchartPort(id: 'in', side: 'top', label: 'be'),
          MobileFlowchartPort(id: 'out', side: 'bottom', label: 'ki'),
        ],
      ),
    ],
    edges: [
      MobileFlowchartEdge(
        id: 'edge-forward',
        fromNodeId: 'a',
        fromPortId: 'shared',
        toNodeId: 'b',
        toPortId: 'in',
        label: '',
      ),
      MobileFlowchartEdge(
        id: 'edge-back',
        fromNodeId: 'b',
        fromPortId: 'out',
        toNodeId: 'a',
        toPortId: 'shared',
        label: '',
      ),
    ],
  );

  testWidgets('port-aware list view renders clean path steps without duplicate decisions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: portAwareData))));

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Szaturáció? 90-95%'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-sat')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-decision')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-sat-90-95')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-decision-igen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-transport')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-leaf-sat-80-alatt')), findsOneWidget);
    expect(find.text('Ág 1'), findsNothing);
  });

  testWidgets('port-aware canvas preview mirrors editor nodes ports and branch labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: portAwareData))));

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-canvas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-node-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-node-sat')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-node-decision')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-port-sat-branch-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-port-sat-branch-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-edge-edge-sat-decision')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-label-edge-sat-decision')), findsOneWidget);
    expect(find.text('90-95%'), findsOneWidget);
    expect(find.text('Többágú döntés'), findsNothing);
    expect(find.text('Folyamat'), findsNothing);
  });

  testWidgets('canvas preview has no grid and marks loop and reused ports', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MobileFlowchartViewer(data: loopPortData)),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-canvas')));
    await tester.pumpAndSettle();

    final gridPainters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((widget) => widget.painter.runtimeType.toString() == '_GridPainter');
    expect(gridPainters, isEmpty);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-grid')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-loop-edge-edge-back')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mobile-flowchart-canvas-port-state-a-shared-inputAndOutput')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-flowchart-canvas-port-outer-a-shared')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-flowchart-canvas-port-state-b-in-inputOnly')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-flowchart-canvas-port-state-b-out-outputOnly')),
      findsOneWidget,
    );
  });

  testWidgets('switching between list and canvas does not reuse keyed list widgets', (tester) async {
    const loopData = MobileFlowchartData(
      id: 'flow-loop',
      title: 'Loop chart',
      nodes: [
        MobileFlowchartNode(id: 'root', label: 'Légzési elégtelen?', shape: 'decision'),
        MobileFlowchartNode(id: 'oxygen', label: 'Oxigén', shape: 'process'),
        MobileFlowchartNode(id: 'monitor', label: 'Megfigyelés', shape: 'process'),
        MobileFlowchartNode(id: 'improved', label: 'Javult?', shape: 'decision'),
      ],
      edges: [
        MobileFlowchartEdge(id: 'e1', fromNodeId: 'root', toNodeId: 'oxygen', label: 'Igen'),
        MobileFlowchartEdge(id: 'e2', fromNodeId: 'root', toNodeId: 'monitor', label: 'Nem'),
        MobileFlowchartEdge(id: 'e3', fromNodeId: 'monitor', toNodeId: 'improved', label: ''),
        MobileFlowchartEdge(id: 'e4', fromNodeId: 'improved', toNodeId: 'monitor', label: 'Igen'),
        MobileFlowchartEdge(id: 'e5', fromNodeId: 'improved', toNodeId: 'oxygen', label: 'Nem'),
      ],
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: loopData))));

    expect(find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-oxygen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-canvas')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-node-oxygen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-oxygen')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-list')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-oxygen')), findsOneWidget);
  });

  testWidgets('guide view renders stacked branch cards and disabled dangling branches', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: portAwareData))));

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-guide')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-guide-answer-kimenet')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-guide-next')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-answer-90-95')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-disabled-80-alatt')), findsOneWidget);
  });


  testWidgets('list view renders question and selected answer in the same branch card', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: data))));

    expect(find.byKey(const ValueKey('mobile-flowchart-view-list-flow-mobile')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')),
        matching: find.text('Légzési elégtelenség?'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')),
        matching: find.text('Igen'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('mobile-flowchart-sibling-divider-root')), findsOneWidget);
  });

  testWidgets('closing root yes branch hides its descendants but keeps no branch visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: data))));

    expect(find.byKey(const ValueKey('mobile-flowchart-process-oxygen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-shock')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-process-oxygen')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-shock')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-root-nem')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-monitor')), findsOneWidget);
  });


  testWidgets('list toolbar opens all branches and closes deep branches by path', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: data))));

    expect(find.byKey(const ValueKey('mobile-flowchart-process-transport')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-close-deep')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-branch-shock-igen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-process-transport')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-root-nem')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-open-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-process-transport')), findsOneWidget);
  });

  testWidgets('canvas view is selectable read-only and exposes zoom controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: data))));

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-canvas')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mobile-flowchart-view-canvas-flow-mobile')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-zoom-in')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-canvas-zoom-out')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-flowchart-connector-root-out')), findsNothing);
  });

  testWidgets('guide view steps through an answer and returns with back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MobileFlowchartViewer(data: data))));

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-selector-guide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mobile-flowchart-view-guide-flow-mobile')), findsOneWidget);
    expect(find.text('Légzési elégtelenség?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-guide-answer-igen')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Célzott O2-terápia'), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-next')), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-answer-igen')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-answer-nem')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-guide-back')));
    await tester.pumpAndSettle();
    expect(find.text('Légzési elégtelenség?'), findsOneWidget);
  });
}
