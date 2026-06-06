import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/document_processing_service.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/knowledge/ui/knowledge_base_screen.dart';
import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  testWidgets('shows local ObjectBox empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: KnowledgeDocumentRepository(),
          importService: _FakePdfImportService(),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Helyi ObjectBox tudástár'));

    expect(find.text('Helyi ObjectBox tudástár'), findsOneWidget);
    expect(find.text('Nincs importált PDF'), findsOneWidget);
  });

  testWidgets('imports picked PDFs into the local knowledge base', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final importService = _FakePdfImportService();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: importService,
          pickPdfs: () async => [
            PickedPdfFile(filename: 'omsz.pdf', bytes: [37, 80, 68, 70]),
          ],
          clock: () => DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált PDF'));

    await tester.tap(find.byTooltip('PDF hozzáadása'));
    await _pumpUntilFound(tester, find.text('omsz.pdf'));

    expect(find.text('omsz.pdf'), findsOneWidget);
    expect(find.text('Feldolgozásra vár'), findsOneWidget);

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.filename, 'omsz.pdf');
    expect(documents.single.localPath, '/memory/omsz.pdf');
  });

  testWidgets('shows missing OpenAI key after local processing starts', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: FakeOpenAiClient(),
            loadSettings: () async => AppSettings.defaults(),
            hasApiKey: () async => false,
            repository: repository,
          ),
          pickPdfs: () async => [
            PickedPdfFile(filename: 'omsz.pdf', bytes: [37, 80, 68, 70]),
          ],
          clock: () => DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált PDF'));

    await tester.tap(find.byTooltip('PDF hozzáadása'));
    await _pumpUntilFound(tester, find.text('OpenAI API kulcs szükséges'));

    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.blockedMissingApiKey,
    );
  });

  testWidgets('retry action processes a blocked PDF row', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'protocol.pdf',
      localPath: '/memory/protocol.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    await repository.updateStatus(
      document.id,
      KnowledgeDocumentStatus.blockedMissingApiKey,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: _ExtractingOpenAiClient(),
            loadSettings: () async => AppSettings.defaults(),
            hasApiKey: () async => true,
            repository: repository,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('protocol.pdf'));

    await tester.tap(find.byTooltip('Újrapróbálás'));
    await _pumpUntilFound(tester, find.text('Kész'));

    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.ready,
    );
  });
}

class _ExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }
}

class _FakePdfImportService extends PdfImportService {
  _FakePdfImportService() : super(importDirectory: Directory('/memory'));

  @override
  Future<PdfImportResult> copyPdfBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    return PdfImportResult(
      filename: filename,
      localPath: '/memory/$filename',
      sizeBytes: bytes.length,
    );
  }
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      return;
    }
  }
  expect(finder, findsOneWidget);
}
