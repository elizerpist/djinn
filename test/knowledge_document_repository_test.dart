import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/core/storage/json_file_store.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/openai/openai_client.dart';

void main() {
  test('adds updates and persists knowledge documents', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-docs-test-');
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonFileStore(File('${directory.path}/documents.json'));

    final firstRepository = KnowledgeDocumentRepository(store: store);
    await firstRepository.load();
    final document = await firstRepository.addDocument(
      filename: 'omsz.pdf',
      localPath: '${directory.path}/omsz.pdf',
      sizeBytes: 42,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    await firstRepository.updateStatus(
      document.id,
      KnowledgeDocumentStatus.processed,
      backendDocumentId: 'backend-1',
    );

    final secondRepository = KnowledgeDocumentRepository(store: store);
    await secondRepository.load();
    final documents = await secondRepository.listDocuments();

    expect(documents, hasLength(1));
    expect(documents.single.filename, 'omsz.pdf');
    expect(documents.single.status, KnowledgeDocumentStatus.processed);
    expect(documents.single.backendDocumentId, 'backend-1');
  });

  test('derives knowledge readiness from document statuses', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-docs-state-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = KnowledgeDocumentRepository(
      store: JsonFileStore(File('${directory.path}/documents.json')),
    );
    await repository.load();

    expect((await repository.state()).readiness, KnowledgeBaseReadiness.empty);

    final pending = await repository.addDocument(
      filename: 'pending.pdf',
      localPath: '${directory.path}/pending.pdf',
      sizeBytes: 12,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    expect(
      (await repository.state()).readiness,
      KnowledgeBaseReadiness.pendingIngest,
    );

    await repository.updateStatus(
      pending.id,
      KnowledgeDocumentStatus.processed,
    );
    expect((await repository.state()).readiness, KnowledgeBaseReadiness.ready);
  });

  test('reconciles a local document with a backend record', () async {
    final repository = KnowledgeDocumentRepository();
    final local = await repository.addDocument(
      filename: 'protocol.pdf',
      localPath: '/local/protocol.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );

    await repository.reconcileBackendDocument(
      localDocumentId: local.id,
      backendDocument: KnowledgeDocument(
        id: 'backend-1',
        filename: 'protocol.pdf',
        localPath: 'corpus/omsz/backend-1-protocol.pdf',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 1, 1, 12),
        status: KnowledgeDocumentStatus.processed,
        backendDocumentId: 'backend-1',
      ),
    );

    final documents = await repository.listDocuments();
    expect(documents.single.id, local.id);
    expect(documents.single.backendDocumentId, 'backend-1');
    expect(documents.single.status, KnowledgeDocumentStatus.processed);
  });

  test('creates folders and moves documents between folders', () async {
    final repository = KnowledgeDocumentRepository();
    final folder = await repository.createFolder('Eljárásrendek');
    final document = await repository.addDocument(
      filename: 'stroke.pdf',
      localPath: '/memory/stroke.pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'hash-stroke',
    );

    await repository.moveDocumentsToFolder([document.id], folder.id);

    final documents = await repository.listDocuments(folderId: folder.id);
    expect(documents.single.folderId, folder.id);
    expect(documents.single.sha256, 'hash-stroke');
  });

  test('moving a document keeps existing sync error details', () async {
    final repository = KnowledgeDocumentRepository();
    final folder = await repository.createFolder('Guideline-ok');
    final document = await repository.addDocument(
      filename: 'failed.pdf',
      localPath: '/memory/failed.pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 6, 9),
      sha256: 'hash-failed',
    );
    await repository.updateStatus(
      document.id,
      KnowledgeDocumentStatus.failed,
      errorMessage: 'Gemini hibás JSON-t adott.',
    );

    await repository.moveDocumentsToFolder([document.id], folder.id);

    final moved = (await repository.listDocuments(folderId: folder.id)).single;
    expect(moved.errorMessage, 'Gemini hibás JSON-t adott.');
  });

  test('persists folders and document folder links across reloads', () async {
    final directory = await Directory.systemTemp.createTemp(
      'djinn-folders-persist-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final store = JsonFileStore(File('${directory.path}/documents.json'));

    final firstRepository = KnowledgeDocumentRepository(store: store);
    await firstRepository.load();
    final folder = await firstRepository.createFolder('Eljárásrendek');
    await firstRepository.addDocument(
      filename: 'procedure.pdf',
      localPath: '${directory.path}/procedure.pdf',
      sizeBytes: 10,
      importedAt: DateTime.utc(2026, 6, 9),
      folderId: folder.id,
    );

    final secondRepository = KnowledgeDocumentRepository(store: store);
    await secondRepository.load();

    expect((await secondRepository.listFolders()).single.name, 'Eljárásrendek');
    expect(
      (await secondRepository.listDocuments(
        folderId: folder.id,
      )).single.filename,
      'procedure.pdf',
    );
  });

  test(
    'renames and deletes folders while clearing document folder ids',
    () async {
      final repository = KnowledgeDocumentRepository();
      final folder = await repository.createFolder(' Eljárásrendek ');
      final document = await repository.addDocument(
        filename: 'procedure.pdf',
        localPath: '/memory/procedure.pdf',
        sizeBytes: 10,
        importedAt: DateTime.utc(2026, 6, 9),
        folderId: folder.id,
      );

      final renamed = await repository.renameFolder(
        folder.id,
        'Igazgatói utasítások',
      );
      await repository.deleteFolder(folder.id);

      expect(folder.name, 'Eljárásrendek');
      expect(renamed.name, 'Igazgatói utasítások');
      expect(await repository.listFolders(), isEmpty);
      expect((await repository.listDocuments()).single.id, document.id);
      expect((await repository.listDocuments()).single.folderId, isNull);
      expect(await repository.listDocuments(folderId: folder.id), isEmpty);
    },
  );

  test(
    'imported documents start unsynced and retryable only after explicit sync',
    () async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'guideline.pdf',
        localPath: '/memory/guideline.pdf',
        sizeBytes: 10,
        importedAt: DateTime.utc(2026, 6, 9),
        sha256: 'hash-guideline',
      );

      expect(document.status, KnowledgeDocumentStatus.imported);
      expect(document.syncStatusLabel, 'Nincs sync');
    },
  );

  test(
    'exports and imports chunk packages through the UI repository contract',
    () async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'stroke.pdf',
        localPath: '/memory/stroke.pdf',
        sizeBytes: 10,
        importedAt: DateTime.utc(2026, 6, 10),
        sha256: 'hash-stroke',
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
          text: 'ABCDE protokoll',
          pageNumber: 1,
          sectionTitle: 'Ellátás',
        ),
        embedding: List<double>.filled(3072, 0.1),
        embeddingModel: 'text-embedding-3-large',
      );

      final exported = await repository.exportChunkPackage(document.id);

      expect(exported.documentHash, 'hash-stroke');
      expect(exported.provider, 'openai');
      expect(exported.extractionModel, 'gpt-5.5');
      expect(exported.embeddingModel, 'text-embedding-3-large');
      expect(exported.embeddingDimension, 3072);
      expect(exported.chunks.single.id, 'p1-main');

      await repository.updateStatus(
        document.id,
        KnowledgeDocumentStatus.failed,
      );
      await repository.importChunkPackage(document.id, exported);

      final updated = (await repository.listDocuments()).single;
      expect(updated.status, KnowledgeDocumentStatus.ready);
      expect(
        (await repository.exportChunkPackage(document.id)).chunks.single.text,
        'ABCDE protokoll',
      );
    },
  );
}
