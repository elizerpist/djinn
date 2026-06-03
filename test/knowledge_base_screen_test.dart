import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_api_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/knowledge_sync_service.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/knowledge/ui/knowledge_base_screen.dart';

void main() {
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
    await _pumpUntilFound(tester, find.text('Nincs importalt PDF'));

    await tester.tap(find.byTooltip('PDF hozzaadasa'));
    await _pumpUntilFound(tester, find.text('omsz.pdf'));

    expect(find.text('omsz.pdf'), findsOneWidget);
    expect(find.text('Feldolgozasra var'), findsOneWidget);

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.filename, 'omsz.pdf');
    expect(documents.single.status, KnowledgeDocumentStatus.pendingIngest);
    expect(documents.single.localPath, '/memory/omsz.pdf');
  });

  testWidgets('shows backend unavailable status when refresh fails', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          syncService: _UnavailableKnowledgeSyncService(
            repository: repository,
            client: KnowledgeApiClient(baseUri: Uri.parse('http://localhost')),
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Backend nem erheto el'));

    expect(find.text('Backend nem erheto el'), findsOneWidget);
  });

  testWidgets('sync action processes a pending PDF row', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'protocol.pdf',
      localPath: '/memory/protocol.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final syncService = _FakeKnowledgeSyncService(
      repository: repository,
      client: KnowledgeApiClient(baseUri: Uri.parse('http://localhost')),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          syncService: syncService,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('protocol.pdf'));

    await tester.tap(find.byTooltip('Szinkronizalas'));
    await _pumpUntilFound(tester, find.text('Feldolgozva'));

    expect(syncService.syncCalls, [document.id]);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.processed,
    );
  });
}

class _FakeKnowledgeSyncService extends KnowledgeSyncService {
  _FakeKnowledgeSyncService({required super.repository, required super.client});

  final syncCalls = <String>[];

  @override
  Future<KnowledgeDocument> syncDocument(String localDocumentId) async {
    syncCalls.add(localDocumentId);
    return repository.updateStatus(
      localDocumentId,
      KnowledgeDocumentStatus.processed,
      backendDocumentId: 'backend-1',
    );
  }
}

class _UnavailableKnowledgeSyncService extends KnowledgeSyncService {
  _UnavailableKnowledgeSyncService({
    required super.repository,
    required super.client,
  });

  @override
  Future<KnowledgeRefreshResult> refresh() async {
    return KnowledgeRefreshResult(
      state: await repository.state(),
      backendAvailable: false,
      errorMessage: 'backend unavailable',
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
