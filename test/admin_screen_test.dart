import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/admin/ui/admin_screen.dart';

void main() {
  testWidgets('admin screen shows summary and confirms destructive clear', (
    tester,
  ) async {
    var clearCalls = 0;
    var exportCalls = 0;
    var importCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          loadSummary: () async => const AdminSummary(
            documentCount: 2,
            chunkCount: 30,
            flowchartCount: 1,
          ),
          clearKnowledgeBase: () async {
            clearCalls += 1;
          },
          exportTrainingPack: () async {
            exportCalls += 1;
            return 'export.djinnpack';
          },
          importTrainingPack: () async {
            importCalls += 1;
            return 'import.djinnpack';
          },
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('2 PDF'), findsOneWidget);
    expect(find.text('30 chunk'), findsOneWidget);
    expect(find.text('1 flowchart'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(exportCalls, 1);
    expect(find.textContaining('export.djinnpack'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(importCalls, 1);
    expect(find.textContaining('import.djinnpack'), findsOneWidget);

    await tester.tap(find.text('Tudástár törlése'));
    await tester.pumpAndSettle();
    expect(clearCalls, 0);

    await tester.tap(find.text('Törlés megerősítése'));
    await tester.pumpAndSettle();
    expect(clearCalls, 1);
  });
}
