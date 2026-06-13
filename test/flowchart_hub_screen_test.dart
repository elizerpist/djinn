import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/flowchart/ui/flowchart_hub_screen.dart';

void main() {
  testWidgets('hub switches between validation, extracted, builder, and templates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: FlowchartHubScreen(validationRepository: null)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Flowchart'), findsOneWidget);
    expect(find.text('Validálás'), findsOneWidget);
    expect(find.text('Kinyert'), findsOneWidget);
    expect(find.text('Építő'), findsOneWidget);
    expect(find.text('Sablonok'), findsOneWidget);
    expect(find.textContaining('Flowchart validáció nem elérhető'), findsOneWidget);

    await tester.tap(find.text('Építő'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-builder-canvas')), findsOneWidget);

    await tester.tap(find.text('Sablonok'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-template-list')), findsOneWidget);

    await tester.tap(find.text('Klinikai protokoll'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-builder-canvas')), findsOneWidget);
    expect(find.text('Triázs'), findsOneWidget);
  });
}
