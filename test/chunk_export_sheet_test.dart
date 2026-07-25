import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chunks/models/chunk.dart';
import 'package:djinn/src/shared/chunks/chunk_export_sheet.dart';

void main() {
  testWidgets(
    'chunk export sheet exposes only note and flowchart kinds with preview',
    (tester) async {
      ChunkExportSelection? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showChunkExportSheet(
                    context,
                    chunks: const [
                      ChunkKind.noteChunk,
                      ChunkKind.noteChunk,
                      ChunkKind.flowchartChunk,
                    ],
                    scopes: const [
                      ChunkExportScope.selectedChunks,
                      ChunkExportScope.currentPdf,
                    ],
                    initialScope: ChunkExportScope.selectedChunks,
                  );
                },
                child: const Text('Nyitás'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Nyitás'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-note_chunk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chunk-export-kind-count-flowchart_chunk')),
        findsOneWidget,
      );
      expect(find.text('Jegyzetchunk'), findsOneWidget);
      expect(find.text('Flowchart chunk'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Szöveg chunk'), findsNothing);
      expect(find.text('Lista chunk'), findsNothing);
      expect(find.text('Táblázat chunk'), findsNothing);
      expect(find.textContaining('AI chunk'), findsNothing);
      expect(find.textContaining('User chunk'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('chunk-export-preview-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chunk-export-preview')),
        findsOneWidget,
      );
      expect(find.textContaining('"note_chunk": 2'), findsOneWidget);
      expect(find.textContaining('"flowchart_chunk": 1'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('chunk-export-include-source')),
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('chunk-export-confirm')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('chunk-export-confirm')));
      await tester.pumpAndSettle();

      expect(result?.scope, ChunkExportScope.selectedChunks);
      expect(result?.includeSourceMetadata, isFalse);
    },
  );
}
