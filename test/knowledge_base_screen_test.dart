import 'dart:async';
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

  testWidgets('import does not auto-process and per-document sync starts it', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final openAiClient = _CountingOpenAiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: openAiClient,
            loadSettings: () async => AppSettings.defaults().copyWith(
              allowPaidAi: true,
              confirmBeforeAiProcessing: false,
            ),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => AppSettings.defaults().copyWith(
            allowPaidAi: true,
            confirmBeforeAiProcessing: false,
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

    expect(openAiClient.extractCalls, 0);
    expect(find.byTooltip('Chunkolás indítása'), findsOneWidget);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.pendingIngest,
    );

    await tester.tap(find.byTooltip('Chunkolás indítása'));
    await _pumpUntilFound(tester, find.text('Kész'));

    expect(openAiClient.extractCalls, 1);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.ready,
    );
  });

  testWidgets('duplicate PDF hash is skipped', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final importService = _FakePdfImportService(contentHash: 'same-hash');

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: importService,
          pickPdfs: () async => const [
            PickedPdfFile(filename: 'first.pdf', bytes: [37, 80, 68, 70]),
            PickedPdfFile(filename: 'second.pdf', bytes: [37, 80, 68, 70]),
          ],
          clock: () => DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált PDF'));

    await tester.tap(find.byTooltip('PDF hozzáadása'));
    await _pumpUntilFound(tester, find.text('first.pdf'));

    expect(await repository.listDocuments(), hasLength(1));
    expect(importService.deleteCalls, 1);
    expect(find.text('second.pdf'), findsNothing);
    expect(find.textContaining('duplikált'), findsOneWidget);
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
            loadSettings: () async => AppSettings.defaults().copyWith(
              allowPaidAi: true,
              confirmBeforeAiProcessing: false,
            ),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => AppSettings.defaults().copyWith(
            allowPaidAi: true,
            confirmBeforeAiProcessing: false,
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

  testWidgets('does not start sync when paid AI is disabled', (tester) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'costly.pdf',
      localPath: '/memory/costly.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final openAiClient = _CountingOpenAiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: openAiClient,
            loadSettings: () async => AppSettings.defaults(),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => AppSettings.defaults(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('costly.pdf'));

    await tester.tap(find.byTooltip('Chunkolás indítása'));
    await _pumpUntilFound(tester, find.textContaining('AI feldolgozás tiltva'));

    expect(openAiClient.extractCalls, 0);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.pendingIngest,
    );
  });

  testWidgets('asks for confirmation before paid sync', (tester) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'confirm.pdf',
      localPath: '/memory/confirm.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final openAiClient = _CountingOpenAiClient();
    final paidSettings = AppSettings.defaults().copyWith(
      allowPaidAi: true,
      confirmBeforeAiProcessing: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: openAiClient,
            loadSettings: () async =>
                paidSettings.copyWith(confirmBeforeAiProcessing: false),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => paidSettings,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('confirm.pdf'));

    await tester.tap(find.byTooltip('Chunkolás indítása'));
    await tester.pumpAndSettle();
    expect(find.text('AI feldolgozás indítása?'), findsOneWidget);
    expect(openAiClient.extractCalls, 0);

    await tester.tap(find.text('Mégse'));
    await tester.pumpAndSettle();
    expect(openAiClient.extractCalls, 0);

    await tester.tap(find.byTooltip('Chunkolás indítása'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indítás'));
    await _pumpUntilFound(tester, find.text('Kész'));

    expect(openAiClient.extractCalls, 1);
  });

  testWidgets('ready document does not expose reprocessing sync action', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'ready.pdf',
      localPath: '/memory/ready.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    await repository.updateStatus(document.id, KnowledgeDocumentStatus.ready);

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: _CountingOpenAiClient(),
            loadSettings: () async => AppSettings.defaults().copyWith(
              allowPaidAi: true,
              confirmBeforeAiProcessing: false,
            ),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => AppSettings.defaults().copyWith(
            allowPaidAi: true,
            confirmBeforeAiProcessing: false,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('ready.pdf'));

    expect(find.byTooltip('Chunkolás indítása'), findsNothing);
    expect(find.byTooltip('Újrapróbálás'), findsNothing);
  });

  testWidgets('document collection can be edited from the row', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'collection.pdf',
      localPath: '/memory/collection.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('collection.pdf'));

    await tester.tap(find.byTooltip('Gyűjtemény módosítása: collection.pdf'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('collection-field')),
      'Stroke',
    );
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();

    final updated = (await repository.listDocuments()).firstWhere(
      (item) => item.id == document.id,
    );
    expect(updated.collectionName, 'Stroke');
    expect(find.text('Stroke'), findsOneWidget);
  });

  testWidgets('selected PDF queue can be cancelled before the next item', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final first = await repository.addDocument(
      filename: 'first.pdf',
      localPath: '/memory/first.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final second = await repository.addDocument(
      filename: 'second.pdf',
      localPath: '/memory/second.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final third = await repository.addDocument(
      filename: 'third.pdf',
      localPath: '/memory/third.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final openAiClient = _DelayedOpenAiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: DocumentProcessingService(
            openAiClient: openAiClient,
            loadSettings: () async => AppSettings.defaults().copyWith(
              allowPaidAi: true,
              confirmBeforeAiProcessing: false,
            ),
            hasApiKey: () async => true,
            repository: repository,
            pdfExists: (_) async => true,
          ),
          loadSettings: () async => AppSettings.defaults().copyWith(
            allowPaidAi: true,
            confirmBeforeAiProcessing: false,
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('first.pdf'));

    await tester.tap(find.byTooltip('PDF kiválasztása: first.pdf'));
    await tester.tap(find.byTooltip('PDF kiválasztása: second.pdf'));
    await tester.tap(find.byTooltip('PDF kiválasztása: third.pdf'));
    await tester.pump();
    await tester.tap(find.byTooltip('Kijelöltek chunkolása'));
    await tester.pump();
    await _pumpUntilFound(tester, find.byTooltip('Queue leállítása'));

    await tester.tap(find.byTooltip('Queue leállítása'));
    openAiClient.completeNext();
    await tester.pumpAndSettle();

    expect(openAiClient.startedPaths, ['/memory/first.pdf']);
    final documents = await repository.listDocuments();
    expect(
      documents.firstWhere((document) => document.id == first.id).status,
      KnowledgeDocumentStatus.ready,
    );
    expect(
      documents.firstWhere((document) => document.id == second.id).status,
      KnowledgeDocumentStatus.pendingIngest,
    );
    expect(
      documents.firstWhere((document) => document.id == third.id).status,
      KnowledgeDocumentStatus.pendingIngest,
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

class _CountingOpenAiClient extends FakeOpenAiClient {
  int extractCalls = 0;

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    extractCalls += 1;
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }
}

class _DelayedOpenAiClient extends FakeOpenAiClient {
  final startedPaths = <String>[];
  final _pending = <Completer<void>>[];

  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    startedPaths.add(pdfPath);
    final completer = Completer<void>();
    _pending.add(completer);
    await completer.future;
    return const OpenAiExtractionResult(
      chunks: [
        OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1),
      ],
    );
  }

  void completeNext() {
    _pending.removeAt(0).complete();
  }
}

class _FakePdfImportService extends PdfImportService {
  _FakePdfImportService({this.contentHash})
    : super(importDirectory: Directory('/memory'));

  final String? contentHash;
  int deleteCalls = 0;

  @override
  Future<PdfImportResult> copyPdfBytes({
    required String filename,
    required List<int> bytes,
  }) async {
    return PdfImportResult(
      filename: filename,
      localPath: '/memory/$filename',
      sizeBytes: bytes.length,
      contentHash: contentHash ?? filename,
      ocrStatus: 'text_available',
    );
  }

  @override
  Future<void> deleteImportedFile(PdfImportResult result) async {
    deleteCalls += 1;
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
