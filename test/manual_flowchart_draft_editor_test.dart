import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/flowchart/ui/manual_flowchart_draft_editor_screen.dart';

void main() {
  testWidgets('manual flowchart draft editor returns edited graph text', (
    tester,
  ) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => const ManualFlowchartDraftEditorScreen(
                      initialText: 'Start\nOxigén',
                      documentId: 'doc-1',
                      pageNumber: 1,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flowchart-editor-canvas')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('manual-flowchart-add-node')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('manual-flowchart-node-label-field')),
      'Szállítás',
    );
    await tester.tap(find.text('Mentés').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('manual-flowchart-save')));
    await tester.pumpAndSettle();

    expect(result, contains('node draft-node-3'));
    expect(result, contains('Szállítás'));
    expect(result, contains('edge Start -> Oxigén'));
  });
}
