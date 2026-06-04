import 'dart:io';

import '../models/knowledge_document.dart';
import 'knowledge_api_client.dart';
import 'knowledge_document_repository.dart';

class KnowledgeRefreshResult {
  const KnowledgeRefreshResult({
    required this.state,
    required this.backendAvailable,
    this.systemReadiness,
    this.errorMessage,
  });

  final KnowledgeBaseState state;
  final bool backendAvailable;
  final BackendSystemReadiness? systemReadiness;
  final String? errorMessage;
}

class KnowledgeSyncService {
  KnowledgeSyncService({required this.repository, required this.client});

  final KnowledgeDocumentRepository repository;
  final KnowledgeApiClient client;

  Future<KnowledgeDocument> syncDocument(String localDocumentId) async {
    final documents = await repository.listDocuments();
    final document = documents.firstWhere(
      (item) => item.id == localDocumentId,
      orElse: () =>
          throw StateError('knowledge document not found: $localDocumentId'),
    );
    await repository.updateStatus(
      document.id,
      KnowledgeDocumentStatus.uploading,
      errorMessage: null,
    );
    try {
      if (!await File(document.localPath).exists()) {
        return repository.updateStatus(
          document.id,
          KnowledgeDocumentStatus.failed,
          errorMessage: 'Local PDF file is missing.',
        );
      }
      final backendDocument = document.backendDocumentId == null
          ? await client.uploadDocument(
              localPath: document.localPath,
              filename: document.filename,
            )
          : document;
      final reconciled = await repository.reconcileBackendDocument(
        localDocumentId: document.id,
        backendDocument: backendDocument,
      );
      final backendId = reconciled.backendDocumentId;
      if (backendId == null || backendId.isEmpty) {
        return repository.updateStatus(
          document.id,
          KnowledgeDocumentStatus.failed,
          errorMessage: 'Backend document id is missing.',
        );
      }
      final ingested = await client.startIngest(backendId);
      return repository.reconcileBackendDocument(
        localDocumentId: document.id,
        backendDocument: ingested,
      );
    } catch (error) {
      return repository.updateStatus(
        document.id,
        KnowledgeDocumentStatus.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Future<KnowledgeRefreshResult> refresh() async {
    try {
      final backendDocuments = await client.listDocuments();
      for (final backendDocument in backendDocuments) {
        final backendId =
            backendDocument.backendDocumentId ?? backendDocument.id;
        final local = repository.findByBackendDocumentId(backendId);
        if (local != null) {
          await repository.reconcileBackendDocument(
            localDocumentId: local.id,
            backendDocument: backendDocument,
          );
        }
      }
      final systemReadiness = await client.getSystemReadiness();
      return KnowledgeRefreshResult(
        state: await repository.state(),
        backendAvailable: true,
        systemReadiness: systemReadiness,
      );
    } catch (error) {
      return KnowledgeRefreshResult(
        state: await repository.state(),
        backendAvailable: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<KnowledgeBaseState> refreshReadiness() async {
    return (await refresh()).state;
  }
}
