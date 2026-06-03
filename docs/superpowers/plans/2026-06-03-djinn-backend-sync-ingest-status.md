# Djinn Backend Sync And Ingest Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the end-to-end loop that uploads imported Flutter PDFs to the backend, triggers dry ingest/retry, reconciles document status, and keeps chat readiness honest.

**Architecture:** FastAPI owns backend document status and is the only source allowed to mark a document `processed`. Flutter owns local document metadata and adds a `KnowledgeSyncService` that uploads local PDFs, starts ingest, refreshes backend status, and writes reconciled status back to the local repository. UI actions call the sync service, while chat reads refreshed readiness but keeps grounded refusal behavior until retrieval exists.

**Tech Stack:** Flutter/Dart, `http`, `file_picker`, `path_provider`, JSON local storage, Python FastAPI, Pydantic, pytest, GitHub Actions Android native build.

---

## File Structure

- Modify: `backend/app/schemas.py` - add `processing` status and keep serialized backend status names stable.
- Modify: `backend/app/services/document_registry.py` - make `start_ingest()` a testable dry transition to `processed`, track failures, and report aggregate counts.
- Modify: `backend/app/main.py` - keep endpoints returning updated records and keep chat refusal grounded when retrieval is absent.
- Modify: `backend/tests/test_knowledge_api.py` - cover ingest status transitions and aggregate counts.
- Modify: `backend/tests/test_api.py` - cover processed-corpus refusal without retrieval claims.
- Modify: `lib/src/knowledge/models/knowledge_document.dart` - map backend `processing` and normalize backend JSON fields.
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart` - add document replacement and backend id lookup helpers.
- Modify: `lib/src/knowledge/data/knowledge_api_client.dart` - add list/status/ingest methods and parse backend `stored_path` responses.
- Create: `lib/src/knowledge/data/knowledge_sync_service.dart` - orchestrate upload, ingest, refresh, failure handling.
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart` - show sync/retry actions and backend status/error messages.
- Modify: `lib/src/chat/ui/chat_screen.dart` - refresh sync/readiness before displaying and before send.
- Modify: `lib/src/chat/ui/main_screen.dart` - pass sync service to knowledge and chat screens.
- Modify: `lib/main.dart` - create default backend client/sync service from `DJINN_BACKEND_URL` dart define.
- Create/Modify tests: `test/knowledge_sync_service_test.dart`, `test/knowledge_api_client_test.dart`, `test/knowledge_base_screen_test.dart`, `test/widget_test.dart`.

---

### Task 1: Backend Dry Ingest Status Contract

**Files:**
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/services/document_registry.py`
- Modify: `backend/app/main.py`
- Modify: `backend/tests/test_knowledge_api.py`
- Modify: `backend/tests/test_api.py`

- [ ] **Step 1: Add failing backend tests for dry ingest and aggregate readiness**

Append these tests to `backend/tests/test_knowledge_api.py`:

```python
def test_start_ingest_marks_uploaded_pdf_processed(client):
    response = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', b'%PDF-1.4 test', 'application/pdf')},
    )
    assert response.status_code == 200
    document_id = response.json()['id']

    ingest_response = client.post(f'/knowledge/documents/{document_id}/ingest')

    assert ingest_response.status_code == 200
    body = ingest_response.json()
    assert body['id'] == document_id
    assert body['status'] == 'processed'
    assert body['error_message'] is None


def test_knowledge_status_counts_processed_pending_and_failed(client):
    first = client.post(
        '/knowledge/documents',
        files={'file': ('pending.pdf', b'%PDF-1.4 pending', 'application/pdf')},
    ).json()
    second = client.post(
        '/knowledge/documents',
        files={'file': ('processed.pdf', b'%PDF-1.4 processed', 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{second['id']}/ingest")

    response = client.get('/knowledge/status')

    assert response.status_code == 200
    body = response.json()
    assert body['ready'] is True
    assert body['document_count'] == 2
    assert body['pending_count'] == 1
    assert body['processed_count'] == 1
    assert body['failed_count'] == 0
    assert first['status'] == 'pending_ingest'
```

Append this test to `backend/tests/test_api.py`:

```python
def test_chat_refuses_when_documents_processed_but_retrieval_is_not_available(client):
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', b'%PDF-1.4 processed', 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post('/chat', json={'message': 'Mi az ellatasi algoritmus?'})

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'insufficient_evidence'
    assert body['refusal_reason'] == 'retrieval_not_available'
    assert body['citations'] == []
```

- [ ] **Step 2: Run backend tests red**

Run:

```bash
cd backend
. .venv/bin/activate
PYTHONPATH=. pytest -q backend/tests/test_knowledge_api.py backend/tests/test_api.py
```

Expected: tests fail because ingest still returns `pending_ingest`, status counts have no processed document, and chat does not return `retrieval_not_available`.

- [ ] **Step 3: Update backend statuses and dry ingest transition**

In `backend/app/schemas.py`, define the backend status enum as:

```python
class KnowledgeDocumentStatus(StrEnum):
    pending_ingest = 'pending_ingest'
    processing = 'processing'
    processed = 'processed'
    failed = 'failed'
```

In `backend/app/services/document_registry.py`, replace `start_ingest()` with:

```python
def start_ingest(self, document_id: str) -> KnowledgeDocumentRecord:
    record = self._documents.get(document_id)
    if record is None:
        raise HTTPException(status_code=404, detail='Document not found')
    stored_path = Path(record.stored_path)
    if not stored_path.exists():
        updated = record.model_copy(
            update={
                'status': KnowledgeDocumentStatus.failed,
                'error_message': 'Stored PDF file is missing.',
            }
        )
        self._documents[document_id] = updated
        return updated
    updated = record.model_copy(
        update={
            'status': KnowledgeDocumentStatus.processed,
            'error_message': None,
        }
    )
    self._documents[document_id] = updated
    return updated
```

In `backend/app/services/safety.py`, extend `answer_without_corpus()` to accept `retrieval_unavailable: bool = False`. Add this branch before the pending-ingest branch:

```python
if retrieval_unavailable:
    return ChatResponse(
        conversation_id=conversation_id,
        answer='A tudasbazis feldolgozott dokumentumot jelez, de a visszakereso RAG reteg meg nincs bekotve. Klinikai valaszt csak feldolgozott es visszakeresheto forras alapjan adhatok.',
        status=GroundingStatus.insufficient_evidence,
        citations=[],
        refusal_reason='retrieval_not_available',
    )
```

In `backend/app/main.py`, calculate status once in `/chat` and pass the new flag:

```python
knowledge = documents.status()
response = answer_without_corpus(
    conversation_id,
    ingest_pending=knowledge.pending_count > 0 and knowledge.processed_count == 0,
    retrieval_unavailable=knowledge.processed_count > 0,
)
```

- [ ] **Step 4: Run backend tests green**

Run:

```bash
cd backend
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all backend tests pass.

- [ ] **Step 5: Commit backend contract**

Run:

```bash
git add backend/app/schemas.py backend/app/services/document_registry.py backend/app/services/safety.py backend/app/main.py backend/tests/test_knowledge_api.py backend/tests/test_api.py
git commit -m "feat: add dry ingest status contract"
```

---

### Task 2: Flutter Backend API Client And Repository Reconciliation

**Files:**
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/knowledge_api_client.dart`
- Modify: `test/knowledge_document_repository_test.dart`
- Modify: `test/knowledge_api_client_test.dart`

- [ ] **Step 1: Add failing API client tests for status/list/ingest parsing**

Extend `test/knowledge_api_client_test.dart` with a local `HttpServer` test:

```dart
test('fetches status lists documents and starts ingest', () async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  final requests = <String>[];
  server.listen((request) async {
    requests.add('${request.method} ${request.uri.path}');
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET' && request.uri.path == '/knowledge/status') {
      request.response.write(jsonEncode({
        'ready': true,
        'document_count': 1,
        'pending_count': 0,
        'processed_count': 1,
        'failed_count': 0,
      }));
    } else if (request.method == 'GET' && request.uri.path == '/knowledge/documents') {
      request.response.write(jsonEncode([
        {
          'id': 'backend-1',
          'filename': 'protocol.pdf',
          'stored_path': 'corpus/omsz/backend-1-protocol.pdf',
          'size_bytes': 11,
          'status': 'processed',
          'imported_at': '2026-01-01T12:00:00Z',
          'backend_document_id': 'backend-1',
          'error_message': null,
        }
      ]));
    } else if (request.method == 'POST' && request.uri.path == '/knowledge/documents/backend-1/ingest') {
      request.response.write(jsonEncode({
        'id': 'backend-1',
        'filename': 'protocol.pdf',
        'stored_path': 'corpus/omsz/backend-1-protocol.pdf',
        'size_bytes': 11,
        'status': 'processed',
        'imported_at': '2026-01-01T12:00:00Z',
        'backend_document_id': 'backend-1',
        'error_message': null,
      }));
    } else {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('{}');
    }
    await request.response.close();
  });

  final client = KnowledgeApiClient(baseUri: Uri.parse('http://${server.address.host}:${server.port}'));

  final status = await client.getStatus();
  final documents = await client.listDocuments();
  final ingested = await client.startIngest('backend-1');

  expect(status.ready, isTrue);
  expect(status.processedCount, 1);
  expect(documents.single.status, KnowledgeDocumentStatus.processed);
  expect(documents.single.backendDocumentId, 'backend-1');
  expect(documents.single.localPath, 'corpus/omsz/backend-1-protocol.pdf');
  expect(ingested.status, KnowledgeDocumentStatus.processed);
  expect(requests, containsAll(['GET /knowledge/status', 'GET /knowledge/documents', 'POST /knowledge/documents/backend-1/ingest']));
});
```

- [ ] **Step 2: Add failing repository reconciliation tests**

Extend `test/knowledge_document_repository_test.dart`:

```dart
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
```

- [ ] **Step 3: Run Flutter tests red**

Run:

```bash
flutter test test/knowledge_api_client_test.dart test/knowledge_document_repository_test.dart
```

Expected: fail because `getStatus`, `listDocuments`, `startIngest`, and `reconcileBackendDocument` do not exist.

- [ ] **Step 4: Implement backend model parsing and repository helpers**

In `lib/src/knowledge/models/knowledge_document.dart`, update status parsing:

```dart
static KnowledgeDocumentStatus fromWireName(String? value) {
  return switch (value) {
    'imported' => KnowledgeDocumentStatus.imported,
    'uploading' || 'processing' => KnowledgeDocumentStatus.uploading,
    'processed' => KnowledgeDocumentStatus.processed,
    'failed' => KnowledgeDocumentStatus.failed,
    _ => KnowledgeDocumentStatus.pendingIngest,
  };
}
```

Create this model in `lib/src/knowledge/data/knowledge_api_client.dart` above `KnowledgeApiClient`:

```dart
class BackendKnowledgeStatus {
  const BackendKnowledgeStatus({
    required this.ready,
    required this.documentCount,
    required this.pendingCount,
    required this.processedCount,
    required this.failedCount,
  });

  final bool ready;
  final int documentCount;
  final int pendingCount;
  final int processedCount;
  final int failedCount;

  factory BackendKnowledgeStatus.fromJson(Map<String, Object?> json) {
    return BackendKnowledgeStatus(
      ready: json['ready'] as bool? ?? false,
      documentCount: json['document_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      processedCount: json['processed_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
    );
  }
}
```

Add these methods to `KnowledgeApiClient`:

```dart
Future<BackendKnowledgeStatus> getStatus() async {
  final response = await _client.get(_baseUri.resolve('/knowledge/status'));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('knowledge status failed: ${response.statusCode}');
  }
  return BackendKnowledgeStatus.fromJson(jsonDecode(response.body) as Map<String, Object?>);
}

Future<List<KnowledgeDocument>> listDocuments() async {
  final response = await _client.get(_baseUri.resolve('/knowledge/documents'));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('knowledge document list failed: ${response.statusCode}');
  }
  final decoded = jsonDecode(response.body) as List<Object?>;
  return decoded.whereType<Map>().map((item) => _documentFromBackendJson(item.cast<String, Object?>())).toList(growable: false);
}

Future<KnowledgeDocument> startIngest(String backendDocumentId) async {
  final response = await _client.post(_baseUri.resolve('/knowledge/documents/$backendDocumentId/ingest'));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('knowledge ingest failed: ${response.statusCode}');
  }
  return _documentFromBackendJson(jsonDecode(response.body) as Map<String, Object?>);
}

KnowledgeDocument _documentFromBackendJson(Map<String, Object?> decoded) {
  final id = decoded['id'] as String? ?? '';
  return KnowledgeDocument(
    id: id,
    filename: decoded['filename'] as String? ?? '',
    localPath: decoded['stored_path'] as String? ?? decoded['source_path'] as String? ?? '',
    sizeBytes: decoded['size_bytes'] as int? ?? 0,
    importedAt: DateTime.tryParse(decoded['imported_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    status: KnowledgeDocumentStatus.fromWireName(decoded['status'] as String?),
    backendDocumentId: decoded['backend_document_id'] as String? ?? id,
    errorMessage: decoded['error_message'] as String?,
  );
}
```

Update `uploadDocument()` to return `_documentFromBackendJson(decoded)` and preserve the local path only if backend has no `stored_path`.

Add this method to `KnowledgeDocumentRepository`:

```dart
Future<KnowledgeDocument> reconcileBackendDocument({
  required String localDocumentId,
  required KnowledgeDocument backendDocument,
}) async {
  final index = _documents.indexWhere((document) => document.id == localDocumentId);
  if (index == -1) {
    throw StateError('knowledge document not found: $localDocumentId');
  }
  final current = _documents[index];
  final updated = current.copyWith(
    filename: backendDocument.filename.isEmpty ? current.filename : backendDocument.filename,
    sizeBytes: backendDocument.sizeBytes == 0 ? current.sizeBytes : backendDocument.sizeBytes,
    status: backendDocument.status,
    backendDocumentId: backendDocument.backendDocumentId ?? backendDocument.id,
    errorMessage: backendDocument.errorMessage,
  );
  _documents[index] = updated;
  await _persist();
  return updated;
}

KnowledgeDocument? findByBackendDocumentId(String backendDocumentId) {
  for (final document in _documents) {
    if (document.backendDocumentId == backendDocumentId) {
      return document;
    }
  }
  return null;
}
```

- [ ] **Step 5: Run Flutter API/repository tests green**

Run:

```bash
flutter test test/knowledge_api_client_test.dart test/knowledge_document_repository_test.dart
```

Expected: all selected tests pass.

- [ ] **Step 6: Commit Flutter client/repository contract**

Run:

```bash
git add lib/src/knowledge/models/knowledge_document.dart lib/src/knowledge/data/knowledge_api_client.dart lib/src/knowledge/data/knowledge_document_repository.dart test/knowledge_api_client_test.dart test/knowledge_document_repository_test.dart
git commit -m "feat: add knowledge backend client status APIs"
```

---

### Task 3: Flutter Knowledge Sync Service

**Files:**
- Create: `lib/src/knowledge/data/knowledge_sync_service.dart`
- Create: `test/knowledge_sync_service_test.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`

- [ ] **Step 1: Add failing sync service tests**

Create `test/knowledge_sync_service_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/knowledge/data/knowledge_api_client.dart';
import 'package:djinn/src/knowledge/data/knowledge_document_repository.dart';
import 'package:djinn/src/knowledge/data/knowledge_sync_service.dart';
import 'package:djinn/src/knowledge/models/knowledge_document.dart';

class _FakeKnowledgeApiClient extends KnowledgeApiClient {
  _FakeKnowledgeApiClient({this.failUpload = false, this.failList = false}) : super(baseUri: Uri.parse('http://localhost'));

  final bool failUpload;
  final bool failList;
  final uploadedPaths = <String>[];

  @override
  Future<KnowledgeDocument> uploadDocument({required String localPath, required String filename}) async {
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
  test('uploads a local pending document and stores processed backend status', () async {
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
    final service = KnowledgeSyncService(repository: repository, client: client);

    final result = await service.syncDocument(document.id);

    expect(result.status, KnowledgeDocumentStatus.processed);
    expect(result.backendDocumentId, 'backend-1');
    expect(client.uploadedPaths, [file.path]);
    expect((await repository.state()).readiness, KnowledgeBaseReadiness.ready);
  });

  test('refresh reports backend unavailable without changing local readiness', () async {
    final repository = KnowledgeDocumentRepository();
    final service = KnowledgeSyncService(
      repository: repository,
      client: _FakeKnowledgeApiClient(failList: true),
    );

    final result = await service.refresh();

    expect(result.backendAvailable, isFalse);
    expect(result.errorMessage, contains('backend unavailable'));
    expect(result.state.readiness, KnowledgeBaseReadiness.empty);
  });

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
    final service = KnowledgeSyncService(repository: repository, client: _FakeKnowledgeApiClient(failUpload: true));

    final result = await service.syncDocument(document.id);

    expect(result.status, KnowledgeDocumentStatus.failed);
    expect(result.errorMessage, contains('backend unavailable'));
    expect((await repository.listDocuments()).single.localPath, file.path);
  });
}
```

- [ ] **Step 2: Run sync tests red**

Run:

```bash
flutter test test/knowledge_sync_service_test.dart
```

Expected: fail because `KnowledgeSyncService` does not exist.

- [ ] **Step 3: Implement sync service**

Create `lib/src/knowledge/data/knowledge_sync_service.dart`:

```dart
import 'dart:io';

import 'knowledge_api_client.dart';
import 'knowledge_document_repository.dart';
import '../models/knowledge_document.dart';

class KnowledgeRefreshResult {
  const KnowledgeRefreshResult({
    required this.state,
    required this.backendAvailable,
    this.errorMessage,
  });

  final KnowledgeBaseState state;
  final bool backendAvailable;
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
      orElse: () => throw StateError('knowledge document not found: $localDocumentId'),
    );
    await repository.updateStatus(document.id, KnowledgeDocumentStatus.uploading, errorMessage: null);
    try {
      if (!await File(document.localPath).exists()) {
        return repository.updateStatus(
          document.id,
          KnowledgeDocumentStatus.failed,
          errorMessage: 'Local PDF file is missing.',
        );
      }
      final backendDocument = document.backendDocumentId == null
          ? await client.uploadDocument(localPath: document.localPath, filename: document.filename)
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
      return repository.reconcileBackendDocument(localDocumentId: document.id, backendDocument: ingested);
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
        final backendId = backendDocument.backendDocumentId ?? backendDocument.id;
        final local = repository.findByBackendDocumentId(backendId);
        if (local != null) {
          await repository.reconcileBackendDocument(
            localDocumentId: local.id,
            backendDocument: backendDocument,
          );
        }
      }
      return KnowledgeRefreshResult(state: await repository.state(), backendAvailable: true);
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
```

- [ ] **Step 4: Run sync tests green**

Run:

```bash
flutter test test/knowledge_sync_service_test.dart
```

Expected: all sync service tests pass.

- [ ] **Step 5: Commit sync service**

Run:

```bash
git add lib/src/knowledge/data/knowledge_sync_service.dart test/knowledge_sync_service_test.dart lib/src/knowledge/data/knowledge_document_repository.dart
git commit -m "feat: add knowledge document sync service"
```

---

### Task 4: Knowledge Base UI Sync And Retry Actions

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/knowledge_base_screen_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add failing UI tests for sync/retry action and backend status**

Extend `test/knowledge_base_screen_test.dart` with:

```dart
class _FakeKnowledgeSyncService extends KnowledgeSyncService {
  _FakeKnowledgeSyncService({required super.repository, required super.client});

  var syncCalls = <String>[];

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
  _UnavailableKnowledgeSyncService({required super.repository, required super.client});

  @override
  Future<KnowledgeRefreshResult> refresh() async {
    return KnowledgeRefreshResult(
      state: await repository.state(),
      backendAvailable: false,
      errorMessage: 'backend unavailable',
    );
  }
}

testWidgets('shows backend unavailable status when refresh fails', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      syncService: _UnavailableKnowledgeSyncService(
        repository: repository,
        client: KnowledgeApiClient(baseUri: Uri.parse('http://localhost')),
      ),
    ),
  ));
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

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      syncService: syncService,
    ),
  ));
  await _pumpUntilFound(tester, find.text('protocol.pdf'));

  await tester.tap(find.byTooltip('Szinkronizalas'));
  await _pumpUntilFound(tester, find.text('Feldolgozva'));

  expect(syncService.syncCalls, [document.id]);
  expect((await repository.listDocuments()).single.status, KnowledgeDocumentStatus.processed);
});
```

- [ ] **Step 2: Run UI tests red**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart test/widget_test.dart
```

Expected: fail because `KnowledgeBaseScreen` has no `syncService` parameter and no row sync action.

- [ ] **Step 3: Add sync service injection and row actions**

In `KnowledgeBaseScreen`, add constructor field:

```dart
final KnowledgeSyncService? syncService;
```

Add state fields:

```dart
String? _syncingDocumentId;
String _backendStatusText = 'Backend nincs ellenorizve';
```

Add methods:

```dart
Future<void> _refreshBackendStatus() async {
  final syncService = widget.syncService;
  if (syncService == null) {
    setState(() => _backendStatusText = 'Backend nincs beallitva');
    return;
  }
  final result = await syncService.refresh();
  if (!mounted) {
    return;
  }
  setState(() {
    _backendStatusText = result.backendAvailable ? _statusText(result.state.readiness) : 'Backend nem erheto el';
  });
  await _loadDocuments();
}

String _statusText(KnowledgeBaseReadiness readiness) {
  return switch (readiness) {
    KnowledgeBaseReadiness.empty => 'Nincs betoltott tudastar',
    KnowledgeBaseReadiness.pendingIngest => 'Feldolgozas folyamatban',
    KnowledgeBaseReadiness.ready => 'Tudastar kesz',
    KnowledgeBaseReadiness.failed => 'Tudastar hiba',
  };
}

Future<void> _syncDocument(KnowledgeDocument document) async {
  final syncService = widget.syncService;
  if (syncService == null) {
    return;
  }
  setState(() => _syncingDocumentId = document.id);
  try {
    await syncService.syncDocument(document.id);
    await _loadDocuments();
  } finally {
    if (mounted) {
      setState(() => _syncingDocumentId = null);
    }
  }
}
```

Call `_refreshBackendStatus()` from `initState()` after `_loadDocuments()`.

Render the status line above the document list:

```dart
Padding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
  child: Text(_backendStatusText),
)
```

Replace list row `trailing: Text(_statusLabel(document.status))` with:

```dart
trailing: _DocumentAction(
  document: document,
  syncing: _syncingDocumentId == document.id,
  onSync: widget.syncService == null ? null : () => _syncDocument(document),
),
```

Add widget below `KnowledgeBaseScreen`:

```dart
class _DocumentAction extends StatelessWidget {
  const _DocumentAction({required this.document, required this.syncing, required this.onSync});

  final KnowledgeDocument document;
  final bool syncing;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    if (syncing) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (document.status == KnowledgeDocumentStatus.processed) {
      return const Text('Feldolgozva');
    }
    return IconButton(
      tooltip: document.status == KnowledgeDocumentStatus.failed ? 'Ujraprobalas' : 'Szinkronizalas',
      onPressed: onSync,
      icon: const Icon(Icons.sync),
    );
  }
}
```

- [ ] **Step 4: Wire default sync service in app initialization**

In `lib/main.dart`, import `knowledge_api_client.dart` and `knowledge_sync_service.dart`. Add optional `KnowledgeSyncService? knowledgeSyncService` to `DjinnApp`. In `_loadDependencies()`, build:

```dart
final backendUri = Uri.parse(
  const String.fromEnvironment('DJINN_BACKEND_URL', defaultValue: 'http://10.0.2.2:8000'),
);
final syncService = widget.knowledgeSyncService ?? KnowledgeSyncService(
  repository: knowledgeRepository,
  client: KnowledgeApiClient(baseUri: backendUri),
);
```

Add `knowledgeSyncService` to `_AppDependencies` and pass it into `MainScreen`.

In `lib/src/chat/ui/main_screen.dart`, add a required `KnowledgeSyncService knowledgeSyncService` field and pass it to `KnowledgeBaseScreen`.

- [ ] **Step 5: Run UI tests green**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart test/widget_test.dart
```

Expected: all selected widget tests pass.

- [ ] **Step 6: Commit UI sync actions**

Run:

```bash
git add lib/main.dart lib/src/chat/ui/main_screen.dart lib/src/knowledge/ui/knowledge_base_screen.dart test/knowledge_base_screen_test.dart test/widget_test.dart
git commit -m "feat: add knowledge sync actions"
```

---

### Task 5: Chat Readiness Refresh Through Sync Service

**Files:**
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Add failing widget test for refreshed processed readiness**

Add this test to `test/widget_test.dart` using an injected repository with a processed document:

```dart
testWidgets('chat shows ready knowledge base when a document is processed', (tester) async {
  final chatRepository = LocalChatRepository();
  final knowledgeRepository = KnowledgeDocumentRepository();
  await knowledgeRepository.addDocument(
    filename: 'protocol.pdf',
    localPath: '/memory/protocol.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 1, 1, 12),
  );
  final document = (await knowledgeRepository.listDocuments()).single;
  await knowledgeRepository.updateStatus(
    document.id,
    KnowledgeDocumentStatus.processed,
    backendDocumentId: 'backend-1',
  );

  await tester.pumpWidget(DjinnApp(
    chatRepository: chatRepository,
    knowledgeRepository: knowledgeRepository,
    pdfImportService: PdfImportService(importDirectory: Directory('/memory')),
    knowledgeSyncService: KnowledgeSyncService(
      repository: knowledgeRepository,
      client: KnowledgeApiClient(baseUri: Uri.parse('http://localhost')),
    ),
  ));
  await _pumpUntilFound(tester, find.text('Djinn'));

  await tester.tap(find.byTooltip('Uj chat'));
  await _pumpUntilFound(tester, find.textContaining('Tudastar kesz'));

  expect(find.textContaining('Tudastar kesz'), findsOneWidget);
});
```

- [ ] **Step 2: Run widget test red**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: fail because `DjinnApp` or `ChatScreen` does not accept/pass `knowledgeSyncService`, or chat does not refresh readiness through it.

- [ ] **Step 3: Pass sync service into chat and refresh readiness**

In `ChatScreen`, add:

```dart
final KnowledgeSyncService? knowledgeSyncService;
```

Update `_loadKnowledgeState()`:

```dart
Future<void> _loadKnowledgeState() async {
  final state = await (widget.knowledgeSyncService?.refreshReadiness() ?? widget.knowledgeRepository.state());
  if (!mounted) {
    return;
  }
  setState(() => _knowledgeState = state);
}
```

At the top of `_send()`, before setting `_sending`, call:

```dart
await _loadKnowledgeState();
```

In `MainScreen`, pass `knowledgeSyncService` into each `ChatScreen` route.

- [ ] **Step 4: Run widget tests green**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: all widget tests pass.

- [ ] **Step 5: Commit chat readiness refresh**

Run:

```bash
git add lib/src/chat/ui/chat_screen.dart lib/src/chat/ui/main_screen.dart test/widget_test.dart
git commit -m "feat: refresh chat knowledge readiness"
```

---

### Task 6: Final Verification, Push, And GitHub Native Build

**Files:**
- Verify all changed files.

- [ ] **Step 1: Format Dart code**

Run:

```bash
dart format lib test
```

Expected: command exits 0.

- [ ] **Step 2: Run Flutter analyzer and tests**

Run:

```bash
flutter analyze
flutter test
```

Expected: analyzer reports no issues and Flutter tests pass.

- [ ] **Step 3: Run backend tests**

Run:

```bash
cd backend
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all backend tests pass.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short
```

Expected: only intended source/test files are modified before final commit, and no runtime PDFs under `backend/corpus/omsz` are staged.

- [ ] **Step 5: Commit any final formatting-only changes**

If formatter changed files after previous commits, run:

```bash
git add lib test backend
git commit -m "chore: format sync ingest changes"
```

Expected: commit succeeds only if there are remaining formatting changes. If no changes remain, skip this step.

- [ ] **Step 6: Push to GitHub**

Run:

```bash
git push origin main
```

Expected: local `main` pushes to `origin/main`.

- [ ] **Step 7: Watch GitHub Actions Android build**

Run:

```bash
gh run list --repo elizerpist/djinn --limit 1
gh run watch <run-id> --repo elizerpist/djinn --exit-status
```

Expected: `Android native build` succeeds and uploads `djinn-release-apk`.

---

## Self-Review

- Spec coverage: Task 1 covers backend ingest/status and no hallucinated retrieval; Task 2 covers backend status/list/ingest client parsing and local reconciliation; Task 3 covers upload, retry, failure preservation, backend availability reporting, and refresh; Task 4 covers knowledge-base UI actions plus backend status display; Task 5 covers chat readiness refresh; Task 6 covers verification and GitHub native build.
- Red-flag scan: no banned empty-plan tokens, no open-ended error handling instructions, and no unspecified test commands remain.
- Type consistency: backend uses serialized `pending_ingest`, `processing`, `processed`, `failed`; Flutter maps `processing` to `KnowledgeDocumentStatus.uploading`; local processed state only comes from backend records or explicit test setup.
- Scope check: this plan does not add OCR, Qdrant, MinerU, graph extraction, or final clinical RAG answers.
