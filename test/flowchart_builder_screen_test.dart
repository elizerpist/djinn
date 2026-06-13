import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/flowchart/ui/flowchart_builder_screen.dart';

void main() {
  testWidgets('builder exposes canvas, toolbar, palette, and property sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FlowchartBuilderScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowchart-builder-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-builder-canvas')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-builder-properties')), findsOneWidget);
    expect(find.byKey(const ValueKey('flowchart-builder-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flowchart-builder-add')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowchart-builder-palette')), findsOneWidget);
    expect(find.text('Döntés'), findsOneWidget);
    await tester.tap(find.text('Döntés'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowchart-builder-node-node-1')), findsOneWidget);
    expect(find.text('IGEN'), findsOneWidget);
    expect(find.text('NEM'), findsOneWidget);
  });


  testWidgets('builder keeps generated node ids unique after delete and add', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FlowchartBuilderScreen())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('flowchart-builder-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Folyamat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Törlés'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('flowchart-builder-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Döntés'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowchart-builder-node-node-1')), findsNothing);
    expect(find.byKey(const ValueKey('flowchart-builder-node-node-2')), findsOneWidget);
  });

}
