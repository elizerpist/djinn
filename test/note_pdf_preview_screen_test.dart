import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_models.dart';
import 'package:djinn/src/notes/pdf/note_pdf_export_service.dart';
import 'package:djinn/src/notes/ui/note_pdf_preview_screen.dart';

void main() {
  testWidgets('preview save cancellation keeps the PDF preview open', (
    tester,
  ) async {
    DebugConsole.clear();
    var saveCalled = false;
    final service = NotePdfExportService(
      saveFile:
          ({required bytes, required dialogTitle, required fileName}) async {
            saveCalled = true;
            expect(dialogTitle, 'PDF mentése');
            expect(fileName, 'teszt.pdf');
            expect(String.fromCharCodes(bytes.take(4)), '%PDF');
            return null;
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotePdfPreviewScreen(
          file: NotePdfPreviewFile(
            path: 'unused.pdf',
            filename: 'teszt.pdf',
            bytes: Uint8List.fromList('%PDF preview'.codeUnits),
          ),
          exportService: service,
          viewerBuilder: (_) =>
              const SizedBox(key: ValueKey('note-pdf-preview-viewer-test')),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('note-pdf-preview-save')));
    await tester.pump();

    expect(saveCalled, isTrue);
    expect(
      find.byKey(const ValueKey('note-pdf-preview-screen')),
      findsOneWidget,
    );
    expect(
      DebugConsole.allText,
      contains('[NotePdfExport] save cancelled filename=teszt.pdf'),
    );
  });
}
