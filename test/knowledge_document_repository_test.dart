import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/core/storage/json_file_store.dart';
import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';
import 'package:djinn/src/local_store/entities.dart';
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

  test('clearGeneratedKnowledge removes chunks before re-sync', () async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'stroke.pdf',
      localPath: '/memory/stroke.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 10),
      sha256: 'hash',
    );
    await repository.saveExtractedEvidence(
      documentPublicId: document.id,
      evidence: const AiExtractedEvidence(
        id: 'rave-row-1',
        text: 'RAVE score: arcpanasz 1 pont',
        pageNumber: 2,
        sectionTitle: 'RAVE',
        sourceType: AiEvidenceSourceType.score,
      ),
      embedding: List<double>.filled(3072, 0.1),
      embeddingModel: 'gemini-embedding-001',
    );

    expect(
      (await repository.exportChunkPackage(document.id)).chunks,
      hasLength(1),
    );

    await repository.clearGeneratedKnowledge(document.id);

    expect((await repository.exportChunkPackage(document.id)).chunks, isEmpty);
  });

  test(
    'lists extracted table and score items with their evidence types',
    () async {
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'race-score.png',
        localPath: '/memory/race-score.png',
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 6, 13),
        sha256: 'hash-race',
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
              'RACE score értelmezés: 0-9 pont, magasabb pontszám nagyér-okklúziót valószínűsít.',
          pageNumber: 1,
          sectionTitle: 'RACE Score',
          sourceType: AiEvidenceSourceType.score,
        ),
        embedding: List<double>.filled(3072, 0.2),
        embeddingModel: 'gemini-embedding-001',
      );

      final items = await repository.listExtractedKnowledgeItems(document.id);

      expect(items.map((item) => item.sourceType), [
        EvidenceSourceType.tableChunk,
        EvidenceSourceType.scoreChunk,
      ]);
      expect(items.first.typeLabel, 'Táblázat');
      expect(items.last.typeLabel, 'Score');
      expect(items.first.text, contains('Arcbénulás'));
      expect(items.last.embeddingModel, 'gemini-embedding-001');
    },
  );

  test('lists flowchart nodes and edges as separate extracted items', () async {
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'stroke.pdf',
      localPath: '/memory/stroke.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 6, 13),
      sha256: 'hash-flow',
    );

    await repository.saveFlowchartCandidate(
      documentPublicId: document.id,
      flowchart: const AiFlowchartCandidate(
        id: 'flow-1',
        pageNumber: 3,
        title: 'Stroke döntési fa',
        nodes: [
          AiFlowchartNode(
            id: 'n1',
            label: 'ABCDE vizsgálat',
            shape: AiFlowchartNodeShape.startEnd,
            order: 1,
            sourceRect: {'x': 1, 'y': 2, 'width': 3, 'height': 4},
          ),
          AiFlowchartNode(
            id: 'n2',
            label: 'Légzési elégtelenség?',
            shape: AiFlowchartNodeShape.decision,
            order: 2,
          ),
        ],
        edges: [
          AiFlowchartEdge(
            id: 'e1',
            fromNodeId: 'n1',
            toNodeId: 'n2',
            label: 'romlik',
            order: 3,
          ),
        ],
      ),
    );

    final items = await repository.listExtractedKnowledgeItems(document.id);

    expect(items.map((item) => item.sourceType), [
      EvidenceSourceType.flowchartNode,
      EvidenceSourceType.flowchartNode,
      EvidenceSourceType.flowchartEdge,
    ]);
    expect(
      items.last.text,
      'ABCDE vizsgálat -> Légzési elégtelenség? [romlik]',
    );
    expect(items.first.flowchartShape, AiFlowchartNodeShape.startEnd.wireName);
    expect(items.first.flowchartOrder, 1);
    expect(items.first.sourceRectJson, contains('"width":3'));
    expect(items.last.flowchartFromId, 'n1');
    expect(items.last.flowchartToId, 'n2');
    expect(items.last.flowchartOrder, 3);
    expect(items.last.sectionTitle, 'Stroke döntési fa kapcsolat');
  });
}
