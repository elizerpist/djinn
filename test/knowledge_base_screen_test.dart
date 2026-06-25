import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/knowledge/data/document_processing_service.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/local_document_processing_service.dart';
import 'package:djinn/src/knowledge/data/pdf_import_service.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/knowledge/models/local_extraction.dart';
import 'package:djinn/src/knowledge/models/knowledge_pack.dart';
import 'package:djinn/src/knowledge/ui/knowledge_base_screen.dart';
import 'package:djinn/src/knowledge/ui/knowledge_document_row.dart';
import 'package:djinn/src/local_store/entities.dart';
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

    await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
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

  testWidgets('imports pathless picked PDF bytes with detailed debug logs', (
    tester,
  ) async {
    DebugConsole.clear();
    final repository = KnowledgeDocumentRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          pickPdfs: () async => [
            PickedPdfFile(
              filename: 'cloud-source.pdf',
              bytes: [37, 80, 68, 70],
            ),
          ],
          clock: () => DateTime.utc(2026, 6, 24, 10),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
    await _pumpUntilFound(tester, find.text('cloud-source.pdf'));

    final documents = await repository.listDocuments();
    expect(documents, hasLength(1));
    expect(documents.single.localPath, '/memory/cloud-source.pdf');
    expect(DebugConsole.allText, contains('[Knowledge/Import] start'));
    expect(DebugConsole.allText, contains('picker result count=1'));
    expect(
      DebugConsole.allText,
      contains('file copy source=bytes filename=cloud-source.pdf bytes=4'),
    );
    expect(
      DebugConsole.allText,
      contains('repository add filename=cloud-source.pdf'),
    );
    expect(
      DebugConsole.allText,
      contains('[Knowledge/Import] complete added=1'),
    );
  });

  testWidgets(
    'logs skipped picked PDF when Android picker returns no path or bytes',
    (tester) async {
      DebugConsole.clear();
      final repository = KnowledgeDocumentRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgeBaseScreen(
            repository: repository,
            importService: _FakePdfImportService(),
            pickPdfs: () async => const [
              PickedPdfFile(filename: 'provider-only.pdf'),
            ],
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

      await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
      await tester.pumpAndSettle();

      final documents = await repository.listDocuments();
      expect(documents, isEmpty);
      expect(
        DebugConsole.allText,
        contains(
          '[Knowledge/Import] file skipped filename=provider-only.pdf reason=missing_path_and_bytes',
        ),
      );
      expect(
        DebugConsole.allText,
        contains('[Knowledge/Import] complete added=0'),
      );
    },
  );

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
            PickedPdfFile(
              filename: 'rave-flowchart.png',
              bytes: [137, 80, 78, 71],
            ),
          ],
          clock: () => DateTime.utc(2026, 1, 1, 12),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('Nincs importált dokumentum'));

    await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
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

    await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
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
    await tester.tap(find.text('AI chunkolás'));
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
    await tester.tap(find.text('AI újrapróbálás'));
    await _pumpUntilFound(tester, find.text('Kész'));

    expect(
      (await repository.listDocuments()).single.status,
      KnowledgeDocumentStatus.ready,
    );
  });

  testWidgets('left document icon opens in-app PDF viewer callback', (
    tester,
  ) async {
    DebugConsole.clear();
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

    await tester.tap(
      find.byKey(ValueKey('knowledge-document-source-${document.id}')),
    );
    await tester.pumpAndSettle();

    expect(openedId, document.id);
    expect(
      DebugConsole.allText,
      contains(
        '[Knowledge/List] open source document=${document.id} filename=stroke.pdf',
      ),
    );
    expect(
      DebugConsole.allText,
      contains(
        '[Knowledge/Viewer] open document=${document.id} filename=stroke.pdf path=/memory/stroke.pdf',
      ),
    );
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
    await tester.tap(find.byTooltip('PDF/kép hozzáadása'));
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
    expect(find.byTooltip('AI chunkolás'), findsNothing);
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

  testWidgets('selection menu opens extracted table and score inspector', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'race-score.png',
      localPath: '/memory/race-score.png',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 13),
      sha256: 'race-hash',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'table--1-row-1',
        text: 'Arcbénulás: nincs, 0 pont; enyhe, 1 pont; súlyos, 2 pont.',
        pageNumber: 1,
        sectionTitle: 'RACE Score',
        sourceType: AiEvidenceSourceType.table,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'gemini-embedding-001',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'score--1',
        text:
            'RACE score: 0-9 pont, magasabb pontszám nagyér-okklúziót valószínűsít.',
        pageNumber: 1,
        sectionTitle: 'RACE Score',
        sourceType: AiEvidenceSourceType.score,
      ),
      embedding: List<double>.filled(3072, 0.2),
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
    await _pumpUntilFound(tester, find.text('race-score.png'));

    await tester.longPress(find.text('race-score.png'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kinyert chunkok'));
    await tester.pumpAndSettle();

    expect(find.text('AI chunkok'), findsOneWidget);
    expect(find.textContaining('Táblázat'), findsWidgets);
    expect(find.textContaining('Score'), findsWidgets);
    expect(find.textContaining('Arcbénulás'), findsOneWidget);
    expect(find.textContaining('nagyér-okklúziót'), findsOneWidget);
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
      expect(find.text('Chunk+PDF csomag export'), findsNothing);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('a.pdf'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('knowledge-share-selected')), findsOneWidget);
      await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
      await tester.pumpAndSettle();

      expect(find.text('Rendezés'), findsNothing);
      expect(find.text('Megosztás'), findsNothing);
      expect(find.text('Chunk+PDF csomag export'), findsOneWidget);
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
    await tester.tap(find.text('Chunk+PDF csomag export'));
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
    await tester.tap(find.text('AI újrachunkolás'));
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
    await tester.tap(find.text('AI chunkolás'));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, hasLength(1));
  });

  testWidgets('selection menu exposes only AI and manual chunking modes', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'ai-ready-local.pdf',
      localPath: '/memory/ai-ready-local.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'ai-ready-local',
    );
    await repository.updateStatus(document.id, KnowledgeDocumentStatus.ready);
    final localProcessingService = _RecordingLocalProcessingService(
      repository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
          processingService: _RecordingProcessingService(
            repository: repository,
          ),
          localProcessingService: localProcessingService,
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('ai-ready-local.pdf'));

    await tester.longPress(find.text('ai-ready-local.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();

    expect(find.text('AI újrachunkolás'), findsOneWidget);
    expect(find.text('Kézi chunkolás'), findsOneWidget);
    expect(find.text('Lokális chunkolás'), findsNothing);
    expect(find.text('Lokális újrachunkolás'), findsNothing);
    expect(localProcessingService.processedIds, isEmpty);
  });

  testWidgets('manual chunk editor saves a selected PDF chunk', (tester) async {
    DebugConsole.clear();
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'manual-source.pdf',
      localPath: '/memory/manual-source.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 14),
      sha256: 'manual-source',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgeBaseScreen(
          repository: repository,
          importService: _FakePdfImportService(),
        ),
      ),
    );
    await _pumpUntilFound(tester, find.text('manual-source.pdf'));

    await tester.longPress(find.text('manual-source.pdf'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kézi chunkolás'));
    await tester.pumpAndSettle();

    expect(find.text('Kézi chunkolás'), findsOneWidget);
    await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szöveg').last);
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.text('Húzz kijelölő téglalapot a PDF-en vagy képen.'),
    );
    await tester.drag(
      find.byKey(const Key('manual-chunk-selection-layer')),
      const Offset(260, 160),
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('manual-chunk-title-field')),
    );

    await tester.enterText(
      find.byKey(const Key('manual-chunk-title-field')),
      'COPDAE kiváltó okai',
    );
    await tester.enterText(
      find.byKey(const Key('manual-chunk-content-field')),
      'Infekció, pneumothorax, pulmonális embólia.',
    );
    await tester.ensureVisible(find.byKey(const Key('manual-chunk-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-chunk-save')));
    await tester.pumpAndSettle();

    final manualItems = await repository.listExtractedKnowledgeItems(
      document.id,
      pipeline: LocalExtractionPipeline.manual,
    );
    expect(manualItems, hasLength(1));
    expect(manualItems.single.sectionTitle, 'COPDAE kiváltó okai');
    expect(manualItems.single.text, contains('pneumothorax'));
    expect(manualItems.single.auditState, LocalAuditState.edited);
    expect(
      DebugConsole.allText,
      contains(
        '[ManualChunk] open document=${document.id} filename=manual-source.pdf',
      ),
    );
    expect(
      DebugConsole.allText,
      contains(
        '[ManualChunk] selection type selected kind=text source=pdf_text',
      ),
    );
    expect(
      DebugConsole.allText,
      contains('[ManualChunk] selection drag start'),
    );
    expect(
      DebugConsole.allText,
      contains('[ManualChunk] selection complete kind=text'),
    );
    expect(
      DebugConsole.allText,
      contains('[ManualChunk] prefill skipped missing_file'),
    );
    expect(
      DebugConsole.allText,
      contains('[ManualChunk] save complete document=${document.id} kind=text'),
    );
  });

  testWidgets('manual chunk sheet uses clamping scroll physics', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await _openManualChunkEditor(
      tester,
      repository,
      filename: 'manual-sheet-scroll.pdf',
    );

    await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szöveg').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('manual-chunk-selection-layer')),
      const Offset(260, 160),
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('manual-chunk-title-field')),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).last,
    );
    expect(scrollView.physics, isA<ClampingScrollPhysics>());
  });

  testWidgets('manual chunk save sheet omits page field and can drag-dismiss', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await _openManualChunkEditor(
      tester,
      repository,
      filename: 'manual-sheet-dismiss.pdf',
    );

    await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szöveg').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('manual-chunk-selection-layer')),
      const Offset(260, 160),
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('manual-chunk-title-field')),
    );

    expect(find.byKey(const Key('manual-chunk-page-field')), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('inline-bottom-sheet-card')),
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('manual-chunk-title-field')), findsNothing);
    expect(find.byKey(const Key('manual-chunk-new-selection')), findsOneWidget);
  });

  testWidgets('manual chunk save stays in viewer and prints saved source box', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    final document = await _openManualChunkEditor(
      tester,
      repository,
      filename: 'manual-print-box.pdf',
    );

    await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szöveg').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('manual-chunk-selection-layer')),
      const Offset(260, 160),
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('manual-chunk-title-field')),
    );

    await tester.enterText(
      find.byKey(const Key('manual-chunk-title-field')),
      'Kész szakasz',
    );
    await tester.enterText(
      find.byKey(const Key('manual-chunk-content-field')),
      'Mentett tartalom',
    );
    await tester.ensureVisible(find.byKey(const Key('manual-chunk-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manual-chunk-save')));
    await tester.pumpAndSettle();

    final items = await repository.listExtractedKnowledgeItems(
      document.id,
      pipeline: LocalExtractionPipeline.manual,
    );
    expect(items, hasLength(1));
    expect(items.single.sourceRectJson, contains('page_rect_normalized'));
    expect(items.single.sourceRectJson, isNot(contains('viewport_rect')));
    expect(find.text('Kézi chunkolás'), findsOneWidget);
    expect(find.byKey(const Key('manual-chunk-title-field')), findsNothing);
    expect(
      find.byKey(ValueKey('source-chunk-box-${items.single.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('manual-chunk-new-selection')), findsOneWidget);
  });

  testWidgets('manual chunk sheet keeps its header pinned above the form', (
    tester,
  ) async {
    final repository = KnowledgeDocumentRepository();
    await _openManualChunkEditor(
      tester,
      repository,
      filename: 'manual-sheet-header.pdf',
    );

    await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Szöveg').last);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('manual-chunk-selection-layer')),
      const Offset(260, 160),
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('manual-chunk-title-field')),
    );

    final surface = find.byKey(const Key('manual-chunk-card-surface'));
    final header = find.byKey(const Key('manual-chunk-card-header'));
    final formScroll = find.byKey(const Key('manual-chunk-form-scroll'));

    expect(surface, findsOneWidget);
    expect(header, findsOneWidget);
    expect(formScroll, findsOneWidget);
    expect(
      find.descendant(
        of: formScroll,
        matching: find.text('Kijelölt chunk mentése'),
      ),
      findsNothing,
    );

    final headerGap =
        tester.getTopLeft(header).dy - tester.getTopLeft(surface).dy;
    expect(headerGap, inInclusiveRange(0, 24));
  });

  testWidgets(
    'manual table selection exposes box controls and logs operations',
    (tester) async {
      DebugConsole.clear();
      final repository = KnowledgeDocumentRepository();
      await _openManualChunkEditor(
        tester,
        repository,
        filename: 'manual-table.pdf',
      );

      await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
      await tester.pumpAndSettle();
      await _tapManualSelectionKind(tester, 'Táblázat');
      await tester.drag(
        find.byKey(const Key('manual-chunk-selection-layer')),
        const Offset(260, 160),
      );
      await tester.pumpAndSettle();
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('manual-extraction-box-header')),
      );

      expect(find.text('Táblázat box'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('manual-table-toolbar')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-table-toolbar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('manual-table-add-row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-table-add-column')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-table-drop-cell')));
      await tester.pumpAndSettle();

      expect(
        DebugConsole.allText,
        contains('[ManualChunk] selection type selected kind=table'),
      );
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] table action=add_row rows=3 columns=2'),
      );
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] table action=add_column rows=3 columns=3'),
      );
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] table action=drop_cell rows=3 columns=3'),
      );
    },
  );

  testWidgets(
    'manual flowchart selection exposes box controls and opens draft editor',
    (tester) async {
      DebugConsole.clear();
      final repository = KnowledgeDocumentRepository();
      await _openManualChunkEditor(
        tester,
        repository,
        filename: 'manual-flowchart.pdf',
      );

      await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
      await tester.pumpAndSettle();
      await _tapManualSelectionKind(tester, 'Flowchart');
      await tester.drag(
        find.byKey(const Key('manual-chunk-selection-layer')),
        const Offset(260, 160),
      );
      await tester.pumpAndSettle();
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('manual-extraction-box-header')),
      );

      expect(find.text('Flowchart box'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('manual-flowchart-toolbar')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('manual-flowchart-toolbar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('manual-flowchart-draft-nodes')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('manual-flowchart-open-editor')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('manual-flowchart-open-editor')));
      await tester.pumpAndSettle();

      expect(find.text('Kézi flowchart szerkesztő'), findsOneWidget);
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] selection type selected kind=flowchart'),
      );
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] flowchart action=draft_nodes'),
      );
      expect(
        DebugConsole.allText,
        contains('[ManualChunk] flowchart draft open'),
      );
    },
  );

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
    expect(find.text('AI újrachunkolás'), findsOneWidget);
    await tester.tap(find.text('AI újrachunkolás'));
    await tester.pumpAndSettle();

    expect(processingService.processedIds, [document.id]);
    expect(processingService.forceReprocessFlags, [true]);
  });

  testWidgets(
    'document row card opens chunks and left icon opens source viewer',
    (tester) async {
      final document = KnowledgeDocument(
        id: 'doc-1',
        filename: 'source.pdf',
        localPath: '/memory/source.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 24),
        status: KnowledgeDocumentStatus.imported,
      );
      var openedChunks = 0;
      var openedSource = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeDocumentRow(
              document: document,
              selectionMode: false,
              selected: false,
              processing: false,
              onTap: () => openedChunks += 1,
              onOpenSource: () => openedSource += 1,
              onLongPress: () {},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      await tester.tap(find.text('source.pdf'));
      await tester.pumpAndSettle();
      expect(openedChunks, 1);
      expect(openedSource, 0);

      await tester.tap(
        find.byKey(const ValueKey('knowledge-document-source-doc-1')),
      );
      await tester.pumpAndSettle();
      expect(openedChunks, 1);
      expect(openedSource, 1);
    },
  );

  testWidgets(
    'png document row uses image icon and chunk/source split behavior',
    (tester) async {
      final document = KnowledgeDocument(
        id: 'img-1',
        filename: 'scan.png',
        localPath: '/memory/scan.png',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 24),
        status: KnowledgeDocumentStatus.imported,
      );
      var openedChunks = 0;
      var openedSource = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KnowledgeDocumentRow(
              document: document,
              selectionMode: false,
              selected: false,
              processing: false,
              onTap: () => openedChunks += 1,
              onOpenSource: () => openedSource += 1,
              onLongPress: () {},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      await tester.tap(find.text('scan.png'));
      await tester.pumpAndSettle();
      expect(openedChunks, 1);
      await tester.tap(
        find.byKey(const ValueKey('knowledge-document-source-img-1')),
      );
      await tester.pumpAndSettle();
      expect(openedSource, 1);
    },
  );

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
            onOpenSource: () {},
            onLongPress: () {},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Embedding 4/15'), findsOneWidget);
    expect(find.byKey(const Key('document-progress-doc-1')), findsOneWidget);
  });

  testWidgets('document row status badges use semantic colors', (tester) async {
    final failedDocument = KnowledgeDocument(
      id: 'doc-1',
      filename: 'failed.pdf',
      localPath: '/memory/failed.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      status: KnowledgeDocumentStatus.failed,
    );
    final readyDocument = KnowledgeDocument(
      id: 'doc-2',
      filename: 'ready.pdf',
      localPath: '/memory/ready.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      status: KnowledgeDocumentStatus.ready,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              KnowledgeDocumentRow(
                document: failedDocument,
                selectionMode: false,
                selected: false,
                processing: false,
                onTap: () {},
                onOpenSource: () {},
                onLongPress: () {},
                onSelectionChanged: (_) {},
              ),
              KnowledgeDocumentRow(
                document: readyDocument,
                selectionMode: false,
                selected: false,
                processing: false,
                onTap: () {},
                onOpenSource: () {},
                onLongPress: () {},
                onSelectionChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(_badgeDecoration(tester, 'Hiba').color, const Color(0xFFFEE2E2));
    expect(_badgeTextStyle(tester, 'Hiba').color, const Color(0xFF991B1B));
    expect(_badgeDecoration(tester, 'Kész').color, const Color(0xFFDCFCE7));
    expect(_badgeDecoration(tester, 'RAG').color, const Color(0xFFE0F2FE));
  });
}

BoxDecoration _badgeDecoration(WidgetTester tester, String label) {
  final decoration = tester.widget<DecoratedBox>(
    find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)),
  );
  return decoration.decoration as BoxDecoration;
}

TextStyle _badgeTextStyle(WidgetTester tester, String label) {
  return tester.widget<Text>(find.text(label)).style!;
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

class _RecordingLocalProcessingService extends LocalDocumentProcessingService {
  _RecordingLocalProcessingService({required super.repository})
    : super(pageExtractor: _NoopLocalPageExtractor());

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
    await repository.updateStatus(
      documentPublicId,
      KnowledgeDocumentStatus.needsReview,
    );
    return ProcessingResult(
      state: KnowledgeDocumentStatus.needsReview.wireName,
    );
  }
}

class _NoopLocalPageExtractor implements LocalPageExtractor {
  @override
  Future<List<LocalDocumentPage>> extractPages({
    required String documentId,
    required String path,
  }) async {
    return const [];
  }
}

class _RecordingProcessingService extends DocumentProcessingService {
  _RecordingProcessingService({required super.repository})
    : super(
        openAiClient: FakeOpenAiClient(),
        loadSettings: (() async => AppSettings.defaults()),
        hasApiKey: (() async => true),
      );

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
    await repository.markState(documentPublicId, ProcessingState.ready);
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

Future<KnowledgeDocument> _openManualChunkEditor(
  WidgetTester tester,
  KnowledgeDocumentRepository repository, {
  required String filename,
}) async {
  final document = await repository.addDocument(
    filename: filename,
    localPath: '/memory/$filename',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 14),
    sha256: filename,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: KnowledgeBaseScreen(
        repository: repository,
        importService: _FakePdfImportService(),
      ),
    ),
  );
  await _pumpUntilFound(tester, find.text(filename));

  await tester.longPress(find.text(filename));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Kézi chunkolás'));
  await tester.pumpAndSettle();
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('manual-chunk-new-selection')),
  );

  return document;
}

Future<void> _tapManualSelectionKind(WidgetTester tester, String label) async {
  final option = find.text(label);
  for (var attempt = 0; attempt < 8; attempt += 1) {
    if (option.evaluate().isNotEmpty) {
      await tester.tap(option.last);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(ListView).last, const Offset(0, -160));
    await tester.pumpAndSettle();
  }
  expect(option, findsOneWidget);
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
