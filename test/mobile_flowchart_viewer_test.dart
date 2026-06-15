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

    expect(find.textContaining('Célzott O2-terápia'), findsOneWidget);
    expect(find.text('Shock jelek?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-branch-root-igen')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Célzott O2-terápia'), findsNothing);
    expect(find.text('Shock jelek?'), findsNothing);
    expect(find.byKey(const ValueKey('mobile-flowchart-branch-root-nem')), findsOneWidget);
    expect(find.text('További vizsgálat és monitorozás'), findsOneWidget);
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
    expect(find.byKey(const ValueKey('mobile-flowchart-guide-next')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mobile-flowchart-guide-back')));
    await tester.pumpAndSettle();
    expect(find.text('Légzési elégtelenség?'), findsOneWidget);
  });
}
