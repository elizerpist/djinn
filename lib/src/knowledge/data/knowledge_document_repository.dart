import '../../core/storage/json_file_store.dart';
import '../models/knowledge_document.dart';

class KnowledgeDocumentRepository {
  KnowledgeDocumentRepository({JsonFileStore? store}) : _store = store;

  final JsonFileStore? _store;
  final List<KnowledgeDocument> _documents = [];
  int _nextDocumentId = 1;

  Future<void> load() async {
    final store = _store;
    if (store == null) {
      return;
    }
    final items = await store.readList();
    _documents
      ..clear()
      ..addAll(items.map(KnowledgeDocument.fromJson));
    _nextDocumentId =
        _nextNumericSuffix(
          _documents.map((document) => document.id),
          'document-',
        ) +
        1;
  }

  Future<List<KnowledgeDocument>> listDocuments() async {
    return List.unmodifiable(_documents);
  }

  Future<KnowledgeBaseState> state() async {
    return KnowledgeBaseState.fromDocuments(_documents);
  }

  Future<KnowledgeDocument> addDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
    required DateTime importedAt,
  }) async {
    final document = KnowledgeDocument(
      id: 'document-${_nextDocumentId++}',
      filename: filename,
      localPath: localPath,
      sizeBytes: sizeBytes,
      importedAt: importedAt,
      status: KnowledgeDocumentStatus.pendingIngest,
    );
    _documents.insert(0, document);
    await _persist();
    return document;
  }

  Future<KnowledgeDocument> updateStatus(
    String documentId,
    KnowledgeDocumentStatus status, {
    String? backendDocumentId,
    String? errorMessage,
  }) async {
    final index = _documents.indexWhere(
      (document) => document.id == documentId,
    );
    if (index == -1) {
      throw StateError('knowledge document not found: $documentId');
    }
    final updated = _documents[index].copyWith(
      status: status,
      backendDocumentId: backendDocumentId,
      errorMessage: errorMessage,
    );
    _documents[index] = updated;
    await _persist();
    return updated;
  }

  Future<void> _persist() async {
    final store = _store;
    if (store == null) {
      return;
    }
    await store.writeList(
      _documents.map((document) => document.toJson()).toList(),
    );
  }

  int _nextNumericSuffix(Iterable<String> ids, String prefix) {
    var max = 0;
    for (final id in ids) {
      if (!id.startsWith(prefix)) {
        continue;
      }
      final value = int.tryParse(id.substring(prefix.length));
      if (value != null && value > max) {
        max = value;
      }
    }
    return max;
  }
}
