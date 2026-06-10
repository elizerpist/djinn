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
    await _pumpUntilFound(tester, find.text('omsz.pdf'));

    expect(find.text('omsz.pdf'), findsOneWidget);
    expect(find.text('Nincs sync'), findsOneWidget);
    expect(find.text('OpenAI API kulcs szükséges'), findsNothing);

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.filename, 'omsz.pdf');
    expect(documents.single.localPath, '/memory/omsz.pdf');
    expect(documents.single.status, KnowledgeDocumentStatus.imported);
  });

  testWidgets('manual sync shows missing OpenAI key after import', (
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
    await _pumpUntilFound(tester, find.text('Nincs sync'));

    expect(find.text('OpenAI API kulcs szükséges'), findsNothing);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.imported,
    );

    await tester.tap(find.byTooltip('Szinkronizálás'));
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

  testWidgets('single tap opens in-app PDF viewer callback', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'stroke.pdf',
      localPath: '/memory/stroke.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'hash',
    );
    String? openedId;

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          onOpenDocumentForTest: (doc) => openedId = doc.id,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('stroke.pdf'));

    await tester.tap(find.text('stroke.pdf'));
    await tester.pumpAndSettle();

    expect(openedId, document.id);
  });

  testWidgets(
    'long tap enters selection mode and checkboxes appear on all rows',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      await repository.addDocument(
        filename: 'a.pdf',
        localPath: '/memory/a.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 9),
        sha256: 'a',
      );
      await repository.addDocument(
        filename: 'b.pdf',
        localPath: '/memory/b.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 9),
        sha256: 'b',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeBaseScreen(
            repository: repository,
            importService: _FakePdfImportService(),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('a.pdf'));

      await tester.longPress(find.text('a.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('1 kijelölve'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    },
  );

  testWidgets('three-dot menu is an overlay and does not remove PDF rows', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'a.pdf',
      localPath: '/memory/a.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'a',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('a.pdf'));

    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('Összes kijelölése'), findsOneWidget);
    expect(find.text('Rendezés'), findsOneWidget);
  });

  testWidgets('batch sync skips already ready PDFs', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final ready = await repository.addDocument(
      filename: 'ready.pdf',
      localPath: '/memory/ready.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'ready',
    );
    await repository.updateStatus(ready.id, KnowledgeDocumentStatus.ready);
    final imported = await repository.addDocument(
      filename: 'imported.pdf',
      localPath: '/memory/imported.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'imported',
    );
    final processingService = _RecordingProcessingService(
      repository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: processingService,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('imported.pdf'));

    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Összes kijelölése'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('knowledge-send-selected')));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, [imported.id]);
  });

  testWidgets('document menu sync processes only eligible PDF', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'menu-sync.pdf',
      localPath: '/memory/menu-sync.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'menu-sync',
    );
    final processingService = _RecordingProcessingService(
      repository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: processingService,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('menu-sync.pdf'));

    await tester.tap(find.byKey(Key('document-menu-${document.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szinkronizálás'));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, [document.id]);
  });

  testWidgets('document menu disables sync for ready PDF', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'ready-menu.pdf',
      localPath: '/memory/ready-menu.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'ready-menu',
    );
    await repository.updateStatus(document.id, KnowledgeDocumentStatus.ready);

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: _RecordingProcessingService(
            repository: repository,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('ready-menu.pdf'));

    await tester.tap(find.byKey(Key('document-menu-${document.id}')));
    await tester.pumpAndSettle();

    final menuItem = tester.widget<PopupMenuItem<String>>(
      find.widgetWithText(PopupMenuItem<String>, 'Szinkronizálás'),
    );
    expect(menuItem.enabled, isFalse);
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
      sha256: 'fake-sha256-${bytes.length}',
    );
  }
}

class _RecordingProcessingService extends DocumentProcessingService {
  _RecordingProcessingService({required KnowledgeDocumentRepository repository})
    : _repository = repository,
      super(
        openAiClient: FakeOpenAiClient(),
        loadSettings: (() async => AppSettings.defaults()),
        hasApiKey: (() async => true),
        repository: repository,
      );

  final KnowledgeDocumentRepository _repository;
  final processedIds = <String>[];

  @override
  Future<ProcessingResult> processDocument(String documentPublicId) async {
    processedIds.add(documentPublicId);
    await _repository.updateStatus(
      documentPublicId,
      KnowledgeDocumentStatus.ready,
    );
    return ProcessingResult(state: KnowledgeDocumentStatus.ready.wireName);
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
