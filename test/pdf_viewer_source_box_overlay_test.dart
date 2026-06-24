import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/extracted_knowledge_item.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/ui/pdf_viewer_screen.dart';
import 'package:djinn/src/knowledge/ui/source_chunk_box_overlay.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('source box parser filters by mode and page', () {
    const items = [
      ExtractedKnowledgeItem(
        id: 'manual-1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Manual',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.manual,
        sourceRectJson:
            '{"page":2,"viewport_rect":{"left":10,"top":20,"right":110,"bottom":70}}',
      ),
      ExtractedKnowledgeItem(
        id: 'ai-1',
        documentId: 'doc-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'AI',
        pageNumber: 2,
        pipeline: LocalExtractionPipeline.ai,
        sourceRectJson:
            '{"page":2,"viewport_rect":{"left":20,"top":40,"right":140,"bottom":90}}',
      ),
    ];

    final manual = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.manual,
      pageNumber: 2,
    );
    final ai = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.ai,
      pageNumber: 2,
    );
    final hidden = sourceChunkBoxesFromItems(
      items,
      mode: SourceChunkBoxMode.hidden,
      pageNumber: 2,
    );

    expect(manual.map((box) => box.chunkId), ['manual-1']);
    expect(ai.map((box) => box.chunkId), ['ai-1']);
    expect(hidden, isEmpty);
    expect(manual.single.rect.left, 10);
  });

  testWidgets('pdf viewer exposes source box mode menu and logs changes', (
    tester,
  ) async {
    DebugConsole.clear();
    final repository = KnowledgeDocumentRepository();
    final imageFile = _writeTransparentPng();
    addTearDown(() {
      if (imageFile.existsSync()) {
        imageFile.deleteSync();
      }
    });
    final document = KnowledgeDocument(
      id: 'doc-1',
      filename: 'scan.png',
      localPath: '/memory/scan.png',
      sizeBytes: 68,
      importedAt: DateTime.utc(2026, 6, 24),
      status: KnowledgeDocumentStatus.needsReview,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerScreen(
          title: document.filename,
          path: imageFile.path,
          repository: repository,
          document: document,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('source-box-mode-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manuális dobozok').last);
    await tester.pumpAndSettle();

    expect(
      DebugConsole.allText,
      contains('[Knowledge/Viewer] box mode document=doc-1 mode=manual'),
    );
  });
}

File _writeTransparentPng() {
  final directory = Directory.systemTemp.createTempSync('djinn-png-test-');
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  final file = File('${directory.path}/scan.png');
  file.writeAsBytesSync(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0A,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);
  return file;
}
