import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/knowledge/data/document_processing_service.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/knowledge/models/knowledge_pack.dart';
import 'package:djinn/src/knowledge/ui/knowledge_base_screen.dart';
import 'package:djinn/src/knowledge/ui/knowledge_document_row.dart';
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

    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    expect(find.text('Helyi ObjectBox tudástár'), findsNothing);
    expect(find.text('Nincs importált dokumentum'), findsOneWidget);
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
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byTooltip('PDF/PNG hozzáadása'));
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

  testWidgets('imports picked PNG files into the local knowledge base', (
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
            PickedPdfFile(filename: 'rave-flowchart.png', bytes: [137, 80, 78, 71]),
          ],
          clock: () => DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byTooltip('PDF/PNG hozzáadása'));
    await _pumpUntilFound(tester, find.text('rave-flowchart.png'));

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.filename, 'rave-flowchart.png');
    expect(documents.single.localPath, '/memory/rave-flowchart.png');
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
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byTooltip('PDF/PNG hozzáadása'));
    await _pumpUntilFound(tester, find.text('Nincs sync'));

    expect(find.text('OpenAI API kulcs szükséges'), findsNothing);
    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.imported,
    );

    await tester.longPress(find.text('omsz.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szinkronizálás'));
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

    await tester.longPress(find.text('protocol.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Újrapróbálás'));
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
      expect(find.byKey(const Key('knowledge-share-selected')), findsOneWidget);
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

  testWidgets('general menu creates a new folder and shows it', (tester) async {
    final repository = KnowledgeDocumentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Új mappa'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('folder-name-field')),
      'Eljárásrendek',
    );
    await tester.tap(find.text('Létrehozás'));
    await tester.pumpAndSettle();

    expect(find.text('Eljárásrendek'), findsOneWidget);
    expect((await repository.listFolders()).single.name, 'Eljárásrendek');
  });

  testWidgets('folder pills filter PDFs by the active folder', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final procedures = await repository.createFolder('Eljárásrendek');
    final guidelines = await repository.createFolder('Külső guidelineok');
    await repository.addDocument(
      filename: 'root.pdf',
      localPath: '/memory/root.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'root',
    );
    await repository.addDocument(
      filename: 'procedure.pdf',
      localPath: '/memory/procedure.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'procedure',
      folderId: procedures.id,
    );
    await repository.addDocument(
      filename: 'guideline.pdf',
      localPath: '/memory/guideline.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'guideline',
      folderId: guidelines.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('procedure.pdf'));

    expect(find.byKey(const Key('folder-pill-scroll')), findsOneWidget);
    expect(find.byKey(const Key('folder-pill-all')), findsOneWidget);
    expect(find.byKey(Key('folder-pill-${procedures.id}')), findsOneWidget);
    expect(find.byKey(Key('folder-pill-${guidelines.id}')), findsOneWidget);
    expect(find.text('root.pdf'), findsOneWidget);
    expect(find.text('procedure.pdf'), findsOneWidget);
    expect(find.text('guideline.pdf'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('folder-pill-all'))).dx,
      lessThan(48),
    );

    await tester.tap(find.byKey(Key('folder-pill-${procedures.id}')));
    await tester.pumpAndSettle();

    expect(find.text('procedure.pdf'), findsOneWidget);
    expect(find.text('root.pdf'), findsNothing);
    expect(find.text('guideline.pdf'), findsNothing);

    await tester.tap(find.byKey(const Key('folder-pill-all')));
    await tester.pumpAndSettle();

    expect(find.text('root.pdf'), findsOneWidget);
    expect(find.text('procedure.pdf'), findsOneWidget);
    expect(find.text('guideline.pdf'), findsOneWidget);
  });

  testWidgets('imports PDFs into the active folder', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final folder = await repository.createFolder('Eljárásrendek');

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          pickPdfs: () async => [
            PickedPdfFile(filename: 'folder.pdf', bytes: [37, 80, 68, 70]),
          ],
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(Key('folder-pill-${folder.id}')));

    await tester.tap(find.byKey(Key('folder-pill-${folder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('PDF/PNG hozzáadása'));
    await _pumpUntilFound(tester, find.text('folder.pdf'));

    expect((await repository.listDocuments()).single.folderId, folder.id);
  });

  testWidgets('PDF rows do not show per-row overflow menus', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'a.pdf',
      localPath: '/memory/a.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
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

    expect(find.byKey(const Key('knowledge-general-menu')), findsOneWidget);
    expect(find.byKey(Key('document-menu-${document.id}')), findsNothing);
    expect(find.byTooltip('Szinkronizálás'), findsNothing);
  });

  testWidgets('menus do not show disabled placeholder items', (tester) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'a.pdf',
      localPath: '/memory/a.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
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

    expect(find.text('Chunk csomag import'), findsOneWidget);
    expect(find.text('Tudástár export'), findsOneWidget);
    expect(_disabledPopupLabels(tester), isEmpty);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('a.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Chunk csomag import'), findsNothing);
    expect(find.text('Embedding frissítés'), findsNothing);
    expect(find.text('Flowchart validálásra'), findsNothing);
    expect(find.text('Offline index frissítés'), findsNothing);
    expect(_disabledPopupLabels(tester), isEmpty);
  });

  testWidgets(
    'header menu changes from general to PDF actions after selection',
    (tester) async {
      final repository = KnowledgeDocumentRepository();
      await repository.addDocument(
        filename: 'a.pdf',
        localPath: '/memory/a.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 10),
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

      expect(find.text('Rendezés'), findsOneWidget);
      expect(find.text('Chunk csomag export'), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('a.pdf'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('knowledge-share-selected')), findsOneWidget);
      await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Rendezés'), findsNothing);
      expect(find.text('Megosztás'), findsNothing);
      expect(find.text('Chunk csomag export'), findsOneWidget);
    },
  );

  testWidgets('selection menu exports a djinnpack for selected PDFs', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('djinn-pack-test-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final pdf = File('${tempDir.path}/chunks.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'chunks.pdf',
      localPath: pdf.path,
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'hash-chunks',
    );
    await repository.updateStatus(
      document.id,
      KnowledgeDocumentStatus.ready,
      activeProvider: 'openai',
      activeModel: 'gpt-5.5',
    );
    await repository.saveExtractedChunk(
      documentPublicId: document.id,
      chunk: const OpenAiExtractedChunk(
        id: 'p1-main',
        text: 'Régi chunk',
        pageNumber: 1,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'text-embedding-3-large',
    );
    String? exportedDocumentId;

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          readDocumentBytesForTest: (_) async => [37, 80, 68, 70],
          exportKnowledgePackForTest: (pack) async {
            exportedDocumentId =
                pack.documents.single.chunkPackage.documentHash;
            expect(pack.documents.single.filename, 'chunks.pdf');
            expect(pack.documents.single.pdfBytes, [37, 80, 68, 70]);
            expect(
              pack.documents.single.chunkPackage.chunks.single.text,
              'Régi chunk',
            );
            return '/memory/chunks.djinnpack';
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('chunks.pdf'));

    await tester.longPress(find.text('chunks.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chunk csomag export'));
    await _pumpUntil(tester, () => exportedDocumentId != null);

    expect(exportedDocumentId, document.sha256, reason: DebugConsole.allText);
  });

  testWidgets('selection header shares a djinnpack for selected PDFs', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('djinn-pack-share-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final pdf = File('${tempDir.path}/share.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'share.pdf',
      localPath: pdf.path,
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'hash-share',
    );
    await repository.saveExtractedChunk(
      documentPublicId: document.id,
      chunk: const OpenAiExtractedChunk(
        id: 'p1-main',
        text: 'Megosztott chunk',
        pageNumber: 1,
      ),
      embedding: [0.1, 0.2],
      embeddingModel: 'gemini-embedding-001',
    );
    KnowledgePack? sharedPack;

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          readDocumentBytesForTest: (_) async => [37, 80, 68, 70],
          shareKnowledgePackForTest: (pack) async {
            sharedPack = pack;
            return '/memory/share.djinnpack';
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('share.pdf'));

    await tester.longPress(find.text('share.pdf'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('knowledge-share-selected')), findsOneWidget);

    await tester.tap(find.byKey(const Key('knowledge-share-selected')));
    await _pumpUntil(tester, () => sharedPack != null);

    expect(sharedPack, isNotNull, reason: DebugConsole.allText);
    expect(sharedPack!.documents.single.filename, 'share.pdf');
    expect(
      sharedPack!.documents.single.chunkPackage.chunks.single.text,
      'Megosztott chunk',
    );
  });

  testWidgets('global menu exports visible PDFs as one djinnpack', (
    tester,
  ) async {
    final tempDir = Directory.systemTemp.createTempSync('djinn-pack-export-');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final pdf = File('${tempDir.path}/export.pdf')
      ..writeAsBytesSync([37, 80, 68, 70, 45]);
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'export.pdf',
      localPath: pdf.path,
      sizeBytes: 5,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'hash-export',
    );
    await repository.saveExtractedChunk(
      documentPublicId: document.id,
      chunk: const OpenAiExtractedChunk(
        id: 'p1-main',
        text: 'Exportált chunk',
        pageNumber: 1,
      ),
      embedding: [0.1, 0.2],
      embeddingModel: 'gemini-embedding-001',
    );
    KnowledgePack? exportedPack;

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          readDocumentBytesForTest: (_) async => [37, 80, 68, 70, 45],
          exportKnowledgePackForTest: (pack) async {
            exportedPack = pack;
            return '/memory/export.djinnpack';
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('export.pdf'));

    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tudástár export'));
    await _pumpUntil(tester, () => exportedPack != null);

    expect(exportedPack, isNotNull, reason: DebugConsole.allText);
    expect(exportedPack!.documents.single.filename, 'export.pdf');
    expect(exportedPack!.documents.single.pdfBytes, [37, 80, 68, 70, 45]);
    expect(
      exportedPack!.documents.single.chunkPackage.chunks.single.text,
      'Exportált chunk',
    );
  });

  testWidgets('global menu imports djinnpack into the active folder', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final folder = await repository.createFolder('Eljárásrendek');

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          importKnowledgePackForTest: () async => _knowledgePack(
            filename: 'imported-pack.pdf',
            documentHash: 'fake-sha256-4',
            pdfBytes: [1, 2, 3, 4],
            chunkText: 'Importált chunk',
          ),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(Key('folder-pill-${folder.id}')));

    await tester.tap(find.byKey(Key('folder-pill-${folder.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chunk csomag import'));
    await tester.pumpAndSettle();

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.filename, 'imported-pack.pdf');
    expect(documents.single.folderId, folder.id);
    expect(documents.single.localPath, '/memory/imported-pack.pdf');
    expect(documents.single.status, KnowledgeDocumentStatus.ready);
    final exportedChunks = await repository.exportChunkPackage(
      documents.single.id,
    );
    expect(exportedChunks.chunks.single.text, 'Importált chunk');
  });

  testWidgets('duplicate djinnpack import asks and can create duplicate', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'existing.pdf',
      localPath: '/memory/existing.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'fake-sha256-4',
    );
    var duplicatePromptShown = false;

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          importKnowledgePackForTest: () async => _knowledgePack(
            filename: 'duplicate.pdf',
            documentHash: 'fake-sha256-4',
            pdfBytes: [1, 2, 3, 4],
            chunkText: 'Duplikált chunk',
          ),
          chooseDuplicatePackImportForTest: (existing, incoming) async {
            duplicatePromptShown = true;
            expect(existing.filename, 'existing.pdf');
            expect(incoming.filename, 'duplicate.pdf');
            return KnowledgePackDuplicateChoice.createDuplicate;
          },
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('existing.pdf'));

    await tester.tap(find.byKey(const Key('knowledge-general-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chunk csomag import'));
    await tester.pumpAndSettle();

    final documents = await repository.listDocuments();
    expect(duplicatePromptShown, isTrue);
    expect(documents, hasLength(2));
    expect(
      documents.map((document) => document.filename),
      contains('existing.pdf'),
    );
    expect(
      documents.map((document) => document.filename),
      contains('duplicate.pdf'),
    );
  });

  testWidgets('sort opens a bottom sheet and reorders PDFs', (tester) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'b.pdf',
      localPath: '/memory/b.pdf',
      sizeBytes: 20,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'b',
    );
    await repository.addDocument(
      filename: 'a.pdf',
      localPath: '/memory/a.pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 6, 10),
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
    await tester.tap(find.text('Rendezés'));
    await tester.pumpAndSettle();

    expect(find.text('Legújabb legelöl'), findsOneWidget);
    expect(find.text('Név (A→Z)'), findsOneWidget);

    await tester.tap(find.text('Név (A→Z)'));
    await tester.pumpAndSettle();

    final aTop = tester.getTopLeft(find.text('a.pdf')).dy;
    final bTop = tester.getTopLeft(find.text('b.pdf')).dy;
    expect(aTop, lessThan(bTop));
  });

  testWidgets('selection menu moves selected PDFs into a folder', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final folder = await repository.createFolder('Eljárásrendek');
    final document = await repository.addDocument(
      filename: 'move-me.pdf',
      localPath: '/memory/move-me.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'move-me',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('move-me.pdf'));

    await tester.longPress(find.text('move-me.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mozgatás mappába'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('move-folder-${folder.id}')));
    await tester.pumpAndSettle();

    final documents = await repository.listDocuments();
    expect(
      documents.singleWhere((item) => item.id == document.id).folderId,
      folder.id,
    );
  });

  testWidgets('selection header deletes selected PDFs', (tester) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
      filename: 'keep.pdf',
      localPath: '/memory/keep.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'keep',
    );
    final remove = await repository.addDocument(
      filename: 'remove.pdf',
      localPath: '/memory/remove.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'remove',
    );
    await repository.saveExtractedChunk(
      documentPublicId: remove.id,
      chunk: const OpenAiExtractedChunk(
        id: 'p1-main',
        text: 'Törlendő chunk',
        pageNumber: 1,
      ),
      embedding: [0.1, 0.2],
      embeddingModel: 'gemini-embedding-001',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('remove.pdf'));

    await tester.longPress(find.text('remove.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-delete-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Törlés'));
    await tester.pumpAndSettle();

    final documents = await repository.listDocuments();
    expect(find.text('remove.pdf'), findsNothing);
    expect(find.text('keep.pdf'), findsOneWidget);
    expect(documents.map((document) => document.filename), ['keep.pdf']);
    expect(
      repository.exportChunkPackage(remove.id),
      throwsA(isA<StateError>()),
    );
  });

  testWidgets('batch sync includes ready PDFs as re-sync', (tester) async {
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

    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Újraszinkronizálás'));
    await tester.pumpAndSettle();

    final forceByDocument = <String, bool>{
      for (
        var index = 0;
        index < processingService.processedIds.length;
        index += 1
      )
        processingService.processedIds[index]:
            processingService.forceReprocessFlags[index],
    };
    expect(forceByDocument[ready.id], isTrue);
    expect(forceByDocument[imported.id], isFalse);
  });

  testWidgets('selection menu sync processes only eligible PDFs', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await repository.addDocument(
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

    await tester.longPress(find.text('menu-sync.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szinkronizálás'));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, hasLength(1));
  });

  testWidgets('selection menu re-syncs ready PDF', (tester) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'ready-menu.pdf',
      localPath: '/memory/ready-menu.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'ready-menu',
    );
    await repository.updateStatus(document.id, KnowledgeDocumentStatus.ready);
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
    await _pumpUntilFound(tester, find.text('ready-menu.pdf'));

    await tester.longPress(find.text('ready-menu.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Újraszinkronizálás'), findsOneWidget);
    await tester.tap(find.text('Újraszinkronizálás'));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, [document.id]);
    expect(processingService.forceReprocessFlags, [true]);
  });

  testWidgets('processing row shows compact progress strip', (tester) async {
    final document = KnowledgeDocument(
      id: 'doc-1',
      filename: 'syncing.pdf',
      localPath: '/memory/syncing.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      status: KnowledgeDocumentStatus.processing,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KnowledgeDocumentRow(
            document: document,
            selectionMode: false,
            selected: false,
            processing: true,
            progressLabel: 'Embedding 4/15',
            progressValue: 4 / 15,
            onTap: () {},
            onLongPress: () {},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Embedding 4/15'), findsOneWidget);
    expect(find.byKey(const Key('document-progress-doc-1')), findsOneWidget);
  });
}

KnowledgePack _knowledgePack({
  required String filename,
  required String documentHash,
  required List<int> pdfBytes,
  required String chunkText,
}) {
  return KnowledgePack(
    schemaVersion: 1,
    documents: [
      KnowledgePackDocument(
        filename: filename,
        documentHash: documentHash,
        pdfBytes: pdfBytes,
        chunkPackage: ChunkPackage(
          schemaVersion: 1,
          documentHash: documentHash,
          filename: filename,
          provider: 'gemini',
          extractionModel: 'gemini-2.5-flash-lite',
          embeddingModel: 'gemini-embedding-001',
          embeddingDimension: 2,
          chunks: [
            ChunkPackageItem(
              id: 'p1-main',
              text: chunkText,
              pageNumber: 1,
              sectionTitle: 'Teszt',
              embedding: [0.1, 0.2],
            ),
          ],
        ),
      ),
    ],
  );
}

class _ExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
    required String chunkingMode,
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
  Future<PdfImportResult> copyDocumentBytes({
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
  final forceReprocessFlags = <bool>[];

  @override
  Future<ProcessingResult> processDocument(
    String documentPublicId, {
    bool forceReprocess = false,
    void Function(ProcessingProgress progress)? onProgress,
  }) async {
    processedIds.add(documentPublicId);
    forceReprocessFlags.add(forceReprocess);
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

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20; i += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) {
      return;
    }
  }
}

List<String> _disabledPopupLabels(WidgetTester tester) {
  return tester
      .widgetList<PopupMenuItem<String>>(find.byType(PopupMenuItem<String>))
      .where((item) => !item.enabled)
      .map((item) {
        final child = item.child;
        if (child is Text) {
          return child.data ?? '';
        }
        return child?.toStringShort() ?? '';
      })
      .toList(growable: false);
}
