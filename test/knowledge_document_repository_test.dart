import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/core/storage/json_file_store.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';

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
    final directory = await Directory.systemTemp.createTemp('djinn-docs-state-');
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
    expect((await repository.state()).readiness, KnowledgeBaseReadiness.pendingIngest);

    await repository.updateStatus(pending.id, KnowledgeDocumentStatus.processed);
    expect((await repository.state()).readiness, KnowledgeBaseReadiness.ready);
  });
}
