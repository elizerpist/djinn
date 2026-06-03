import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_api_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/knowledge_sync_service.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';

class _FakeKnowledgeApiClient extends KnowledgeApiClient {
  _FakeKnowledgeApiClient({this.failUpload = false, this.failList = false})
    : super(baseUri: Uri.parse('http://localhost'));

  final bool failUpload;
  final bool failList;
  final uploadedPaths = <String>[];

  @override
  Future<KnowledgeDocument> uploadDocument({
    required String localPath,
    required String filename,
  }) async {
    if (failUpload) {
      throw StateError('backend unavailable');
    }
    uploadedPaths.add(localPath);
    return KnowledgeDocument(
      id: 'backend-1',
      filename: filename,
      localPath: 'corpus/omsz/backend-1-$filename',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
      status: KnowledgeDocumentStatus.pendingIngest,
      backendDocumentId: 'backend-1',
    );
  }

  @override
  Future<List<KnowledgeDocument>> listDocuments() async {
    if (failList) {
      throw StateError('backend unavailable');
    }
    return const [];
  }

  @override
  Future<KnowledgeDocument> startIngest(String backendDocumentId) async {
    return KnowledgeDocument(
      id: backendDocumentId,
      filename: 'protocol.pdf',
      localPath: 'corpus/omsz/backend-1-protocol.pdf',
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
      status: KnowledgeDocumentStatus.processed,
      backendDocumentId: backendDocumentId,
    );
  }
}

void main() {
  test(
    'uploads a local pending document and stores processed backend status',
    () async {
      final directory = await Directory.systemTemp.createTemp('djinn-sync-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/protocol.pdf');
      await file.writeAsBytes([37, 80, 68, 70]);
      final repository = KnowledgeDocumentRepository();
      final document = await repository.addDocument(
        filename: 'protocol.pdf',
        localPath: file.path,
        sizeBytes: 4,
        importedAt: DateTime.utc(2026, 1, 1, 12),
      );
      final client = _FakeKnowledgeApiClient();
      final service = KnowledgeSyncService(
        repository: repository,
        client: client,
      );

      final result = await service.syncDocument(document.id);

      expect(result.status, KnowledgeDocumentStatus.processed);
      expect(result.backendDocumentId, 'backend-1');
      expect(client.uploadedPaths, [file.path]);
      expect(
        (await repository.state()).readiness,
        KnowledgeBaseReadiness.ready,
      );
    },
  );

  test(
    'refresh reports backend unavailable without changing local readiness',
    () async {
      final repository = KnowledgeDocumentRepository();
      final service = KnowledgeSyncService(
        repository: repository,
        client: _FakeKnowledgeApiClient(failList: true),
      );

      final result = await service.refresh();

      expect(result.backendAvailable, isFalse);
      expect(result.errorMessage, contains('backend unavailable'));
      expect(result.state.readiness, KnowledgeBaseReadiness.empty);
    },
  );

  test('records upload failure without deleting local metadata', () async {
    final directory = await Directory.systemTemp.createTemp('djinn-sync-fail-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/protocol.pdf');
    await file.writeAsBytes([37, 80, 68, 70]);
    final repository = KnowledgeDocumentRepository();
    final document = await repository.addDocument(
      filename: 'protocol.pdf',
      localPath: file.path,
      sizeBytes: 4,
      importedAt: DateTime.utc(2026, 1, 1, 12),
    );
    final service = KnowledgeSyncService(
      repository: repository,
      client: _FakeKnowledgeApiClient(failUpload: true),
    );

    final result = await service.syncDocument(document.id);

    expect(result.status, KnowledgeDocumentStatus.failed);
    expect(result.errorMessage, contains('backend unavailable'));
    expect((await repository.listDocuments()).single.localPath, file.path);
  });
}
