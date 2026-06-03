# Djinn Backend Connected Retrieval MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect Flutter chat to the FastAPI backend, ingest PDF text into source-aware chunks, answer only from retrieved chunks, and add Qdrant/PostgreSQL adapters behind safe fallbacks.

**Architecture:** Flutter gets a backend chat client and chat service while keeping local conversation persistence. FastAPI gains chunk storage, PDF extraction, deterministic retrieval, and extractive cited answers before vector infrastructure. Qdrant and PostgreSQL are introduced through interfaces so tests can keep using local in-memory stores.

**Tech Stack:** Flutter/Dart, `http`, JSON local storage, Python FastAPI, Pydantic, pytest, PyMuPDF 1.27.x, qdrant-client 1.18.x, psycopg 3.3.x, Docker Compose, GitHub Actions Android native build.

---

## File Structure

Flutter files:

- Create: `lib/src/chat/models/chat_citation.dart` - citation model used by parsed backend responses and persisted assistant messages.
- Modify: `lib/src/chat/models/chat_message.dart` - add `citations` and `refusalReason` fields while preserving existing JSON compatibility.
- Modify: `lib/src/chat/models/chat_conversation.dart` - no new fields, but JSON reload must keep enriched messages.
- Create: `lib/src/chat/data/backend_chat_client.dart` - HTTP client for `POST /chat`, response parsing, and backend-unavailable errors.
- Create: `lib/src/chat/data/chat_service.dart` - coordinates local repository persistence with backend chat calls.
- Modify: `lib/src/chat/data/local_chat_repository.dart` - add focused append helpers so `ChatService` can persist backend-provided assistant responses without using the old local stub response path.
- Modify: `lib/src/chat/ui/chat_bubble.dart` - render citation metadata compactly under assistant messages.
- Modify: `lib/src/chat/ui/chat_screen.dart` - call `ChatService.sendMessage()` instead of `LocalChatRepository.sendMessage()`.
- Modify: `lib/src/chat/ui/main_screen.dart` - pass `ChatService` into new and existing chat routes.
- Modify: `lib/main.dart` - construct `BackendChatClient` and `ChatService` from `DJINN_BACKEND_URL`.
- Create: `test/backend_chat_client_test.dart` - HTTP parsing and error tests.
- Create: `test/chat_service_test.dart` - persistence and backend failure tests.
- Modify: `test/chat_repository_test.dart` - append helper coverage.
- Modify: `test/widget_test.dart` - widget sends through injected service and renders backend answer.

Backend files:

- Modify: `backend/requirements.txt` - add `PyMuPDF>=1.27,<1.28`, `qdrant-client>=1.18,<1.19`, and `psycopg[binary]>=3.3,<3.4`.
- Modify: `backend/app/schemas.py` - add chunk/retrieval schemas and keep chat response shape stable.
- Create: `backend/app/services/chunk_repository.py` - in-memory chunk repository with replace-by-document and search list methods.
- Create: `backend/app/services/pdf_text_extractor.py` - PyMuPDF-backed page text extraction with a testable extractor interface.
- Create: `backend/app/services/chunking.py` - deterministic text chunking by page with stable chunk ids.
- Create: `backend/app/services/retrieval.py` - lexical scoring retrieval and citation conversion.
- Create: `backend/app/services/answer_service.py` - readiness, retrieval, grounded extractive answer, and refusal orchestration.
- Modify: `backend/app/services/document_registry.py` - inject extractor/chunk repository and mark processed only after chunks are stored.
- Modify: `backend/app/main.py` - wire services, update `/chat`, keep knowledge endpoints stable.
- Create: `backend/app/infra/settings.py` - reads Qdrant/PostgreSQL environment settings and toggles adapters.
- Create: `backend/app/infra/vector_index.py` - `VectorIndex` protocol, local deterministic implementation, and Qdrant adapter shell.
- Create: `backend/app/infra/metadata_store.py` - `MetadataStore` protocol, local implementation, and PostgreSQL adapter shell.
- Create: `backend/tests/test_chunking.py` - chunking behavior tests.
- Create: `backend/tests/test_pdf_text_extractor.py` - small PDF extraction tests.
- Create: `backend/tests/test_retrieval.py` - lexical retrieval and citation tests.
- Modify: `backend/tests/test_knowledge_api.py` - ingest creates chunks and fails on unreadable PDFs.
- Modify: `backend/tests/test_api.py` - `/chat` returns grounded cited answers and refusals.
- Create: `backend/tests/test_infra_adapters.py` - settings and local adapter contract tests.

---

## Task 1: Flutter Backend Chat Client Models

**Files:**
- Create: `lib/src/chat/models/chat_citation.dart`
- Modify: `lib/src/chat/models/chat_message.dart`
- Create: `lib/src/chat/data/backend_chat_client.dart`
- Create: `test/backend_chat_client_test.dart`
- Modify: `test/chat_repository_test.dart`

- [ ] **Step 1: Write failing backend chat client tests**

Create `test/backend_chat_client_test.dart` with these tests:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/backend_chat_client.dart';

void main() {
  test('posts a chat request and parses cited backend response', () async {
    final requests = <Map<String, Object?>>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      requests.add({
        'method': request.method,
        'path': request.uri.path,
        'body': jsonDecode(await utf8.decoder.bind(request).join()),
      });
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'conversation_id': 'backend-conversation-1',
          'answer': 'Az ellatas lepesei a protokoll szerint...',
          'status': 'grounded',
          'citations': [
            {
              'document_id': 'backend-doc-1',
              'title': 'omsz.pdf',
              'page': 2,
              'section': null,
              'excerpt': 'Az ellatas lepesei a protokoll szerint...'
            }
          ],
          'refusal_reason': null,
        }));
      await request.response.close();
    });

    final client = BackendChatClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    final response = await client.sendMessage(
      message: 'Mi a teendo?',
      conversationId: 'conversation-1',
    );

    expect(response.conversationId, 'backend-conversation-1');
    expect(response.answer, contains('protokoll'));
    expect(response.status, 'grounded');
    expect(response.citations.single.documentId, 'backend-doc-1');
    expect(response.citations.single.page, 2);
    expect(response.refusalReason, isNull);
    expect(requests.single['method'], 'POST');
    expect(requests.single['path'], '/chat');
    expect((requests.single['body'] as Map)['message'], 'Mi a teendo?');
    expect((requests.single['body'] as Map)['conversation_id'], 'conversation-1');
  });

  test('throws BackendChatException on non-success response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = 503;
      await request.response.close();
    });

    final client = BackendChatClient(
      baseUri: Uri.parse('http://${server.address.host}:${server.port}'),
    );

    expect(
      () => client.sendMessage(message: 'Kerdes'),
      throwsA(isA<BackendChatException>()),
    );
  });
}
```

Extend `test/chat_repository_test.dart` with a compatibility assertion:

```dart
test('reloads messages with citations and refusal reason', () async {
  final message = ChatMessage(
    id: 'message-1',
    conversationId: 'conversation-1',
    sender: ChatSender.assistant,
    text: 'Valasz forrassal',
    createdAt: DateTime.utc(2026, 1, 1, 12),
    status: 'grounded',
    refusalReason: null,
    citations: const [
      ChatCitation(
        documentId: 'backend-doc-1',
        title: 'omsz.pdf',
        page: 2,
        section: null,
        excerpt: 'Valasz forrassal',
      ),
    ],
  );

  final reloaded = ChatMessage.fromJson(message.toJson());

  expect(reloaded.citations.single.documentId, 'backend-doc-1');
  expect(reloaded.citations.single.page, 2);
  expect(reloaded.refusalReason, isNull);
});
```

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter test test/backend_chat_client_test.dart test/chat_repository_test.dart
```

Expected: FAIL because `BackendChatClient`, `ChatCitation`, `refusalReason`, and `citations` do not exist.

- [ ] **Step 3: Implement chat citation model**

Create `lib/src/chat/models/chat_citation.dart`:

```dart
class ChatCitation {
  const ChatCitation({
    required this.documentId,
    required this.title,
    required this.excerpt,
    this.page,
    this.section,
  });

  final String documentId;
  final String title;
  final int? page;
  final String? section;
  final String excerpt;

  Map<String, Object?> toJson() {
    return {
      'documentId': documentId,
      'title': title,
      'page': page,
      'section': section,
      'excerpt': excerpt,
    };
  }

  factory ChatCitation.fromJson(Map<String, Object?> json) {
    return ChatCitation(
      documentId: json['documentId'] as String? ?? json['document_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      page: json['page'] as int?,
      section: json['section'] as String?,
      excerpt: json['excerpt'] as String? ?? '',
    );
  }
}
```

- [ ] **Step 4: Extend ChatMessage JSON**

Modify `lib/src/chat/models/chat_message.dart`:

```dart
import 'chat_citation.dart';

enum ChatSender { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.text,
    required this.createdAt,
    this.status,
    this.refusalReason,
    this.citations = const [],
  });

  final String id;
  final String conversationId;
  final ChatSender sender;
  final String text;
  final DateTime createdAt;
  final String? status;
  final String? refusalReason;
  final List<ChatCitation> citations;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'conversationId': conversationId,
      'sender': sender.name,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'status': status,
      'refusalReason': refusalReason,
      'citations': citations.map((citation) => citation.toJson()).toList(),
    };
  }

  factory ChatMessage.fromJson(Map<String, Object?> json) {
    final citationItems = (json['citations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ChatCitation.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    return ChatMessage(
      id: json['id']! as String,
      conversationId: json['conversationId']! as String,
      sender: ChatSender.values.byName(json['sender']! as String),
      text: json['text']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      status: json['status'] as String?,
      refusalReason: json['refusalReason'] as String?,
      citations: citationItems,
    );
  }
}
```

- [ ] **Step 5: Implement BackendChatClient**

Create `lib/src/chat/data/backend_chat_client.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_citation.dart';

class BackendChatException implements Exception {
  BackendChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendChatResponse {
  const BackendChatResponse({
    required this.conversationId,
    required this.answer,
    required this.status,
    required this.citations,
    this.refusalReason,
  });

  final String conversationId;
  final String answer;
  final String status;
  final List<ChatCitation> citations;
  final String? refusalReason;

  factory BackendChatResponse.fromJson(Map<String, Object?> json) {
    final citations = (json['citations'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ChatCitation.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    return BackendChatResponse(
      conversationId: json['conversation_id'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      status: json['status'] as String? ?? 'insufficient_evidence',
      citations: citations,
      refusalReason: json['refusal_reason'] as String?,
    );
  }
}

class BackendChatClient {
  BackendChatClient({required Uri baseUri, http.Client? client})
    : _baseUri = baseUri,
      _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;

  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/chat'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'conversation_id': conversationId,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BackendChatException('backend chat failed: ${response.statusCode}');
    }
    return BackendChatResponse.fromJson(
      jsonDecode(response.body) as Map<String, Object?>,
    );
  }
}
```

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
dart format lib/src/chat/models/chat_citation.dart lib/src/chat/models/chat_message.dart lib/src/chat/data/backend_chat_client.dart test/backend_chat_client_test.dart test/chat_repository_test.dart
flutter test test/backend_chat_client_test.dart test/chat_repository_test.dart
```

Expected: targeted Flutter tests pass.

Commit:

```bash
git add lib/src/chat/models/chat_citation.dart lib/src/chat/models/chat_message.dart lib/src/chat/data/backend_chat_client.dart test/backend_chat_client_test.dart test/chat_repository_test.dart
git commit -m "feat: add backend chat client"
```

---

## Task 2: Flutter Chat Service And UI Routing

**Files:**
- Modify: `lib/src/chat/data/local_chat_repository.dart`
- Create: `lib/src/chat/data/chat_service.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/main.dart`
- Create: `test/chat_service_test.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write failing repository and service tests**

Create `test/chat_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:djinn/src/chat/data/backend_chat_client.dart';
import 'package:djinn/src/chat/data/chat_service.dart';
import 'package:djinn/src/chat/data/local_chat_repository.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';

void main() {
  test('persists user message and backend assistant response', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      backend: _FakeBackendChatClient(
        response: const BackendChatResponse(
          conversationId: 'backend-conversation-1',
          answer: 'Forrasbol valaszolok.',
          status: 'grounded',
          citations: [
            ChatCitation(
              documentId: 'backend-doc-1',
              title: 'omsz.pdf',
              page: 1,
              section: null,
              excerpt: 'Forrasbol valaszolok.',
            ),
          ],
        ),
      ),
    );

    await service.sendMessage(conversation.id, 'Mi a teendo?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.first.sender, ChatSender.user);
    expect(messages.first.text, 'Mi a teendo?');
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.text, 'Forrasbol valaszolok.');
    expect(messages.last.status, 'grounded');
    expect(messages.last.citations.single.documentId, 'backend-doc-1');
  });

  test('records backend unavailable assistant message', () async {
    final repository = LocalChatRepository(
      clock: () => DateTime.utc(2026, 1, 1, 12),
    );
    final conversation = await repository.createConversation();
    final service = ChatService(
      repository: repository,
      backend: _FailingBackendChatClient(),
    );

    await service.sendMessage(conversation.id, 'Mi a teendo?');
    final messages = await repository.getMessages(conversation.id);

    expect(messages, hasLength(2));
    expect(messages.last.sender, ChatSender.assistant);
    expect(messages.last.status, 'backend_unavailable');
    expect(messages.last.refusalReason, 'backend_unavailable');
    expect(messages.last.text, contains('Backend'));
  });
}

class _FakeBackendChatClient extends BackendChatClient {
  _FakeBackendChatClient({required this.response})
    : super(baseUri: Uri.parse('http://localhost'));

  final BackendChatResponse response;

  @override
  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    return response;
  }
}

class _FailingBackendChatClient extends BackendChatClient {
  _FailingBackendChatClient() : super(baseUri: Uri.parse('http://localhost'));

  @override
  Future<BackendChatResponse> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    throw BackendChatException('backend chat failed: 503');
  }
}
```

Add a widget test case to `test/widget_test.dart` that injects a fake `ChatService` response and expects `Forrasbol valaszolok.` after tapping send.

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter test test/chat_service_test.dart test/widget_test.dart
```

Expected: FAIL because `ChatService`, repository append helpers, and app injection do not exist.

- [ ] **Step 3: Add repository append helpers**

Modify `lib/src/chat/data/local_chat_repository.dart` with focused helpers:

```dart
Future<ChatMessage> appendUserMessage(String conversationId, String text) async {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('message text must not be blank');
  }
  final message = ChatMessage(
    id: 'message-${_nextMessageId++}',
    conversationId: conversationId,
    sender: ChatSender.user,
    text: trimmed,
    createdAt: _clock(),
  );
  await _appendMessage(conversationId, message, titleSeed: trimmed);
  return message;
}

Future<ChatMessage> appendAssistantMessage(
  String conversationId, {
  required String text,
  required String status,
  String? refusalReason,
  List<ChatCitation> citations = const [],
}) async {
  final message = ChatMessage(
    id: 'message-${_nextMessageId++}',
    conversationId: conversationId,
    sender: ChatSender.assistant,
    text: text,
    createdAt: _clock(),
    status: status,
    refusalReason: refusalReason,
    citations: citations,
  );
  await _appendMessage(conversationId, message);
  return message;
}

Future<void> _appendMessage(
  String conversationId,
  ChatMessage message, {
  String? titleSeed,
}) async {
  final conversation = _findConversation(conversationId);
  final messages = [...conversation.messages, message];
  final updated = conversation.copyWith(
    title: titleSeed != null && conversation.title == 'Uj chat'
        ? _titleFrom(titleSeed)
        : conversation.title,
    updatedAt: message.createdAt,
    messages: messages,
  );
  final index = _conversations.indexWhere((item) => item.id == conversationId);
  _conversations[index] = updated;
  await _persist();
}
```

Keep `sendMessage()` as a compatibility wrapper that calls the new helpers and the existing refusal text.

- [ ] **Step 4: Implement ChatService**

Create `lib/src/chat/data/chat_service.dart`:

```dart
import 'backend_chat_client.dart';
import 'local_chat_repository.dart';

class ChatService {
  ChatService({required this.repository, required this.backend});

  final LocalChatRepository repository;
  final BackendChatClient backend;

  Future<void> sendMessage(String conversationId, String text) async {
    final userMessage = await repository.appendUserMessage(conversationId, text);
    try {
      final response = await backend.sendMessage(
        message: userMessage.text,
        conversationId: conversationId,
      );
      await repository.appendAssistantMessage(
        conversationId,
        text: response.answer,
        status: response.status,
        refusalReason: response.refusalReason,
        citations: response.citations,
      );
    } on BackendChatException {
      await repository.appendAssistantMessage(
        conversationId,
        text: 'Backend nem erheto el. A kerdes megmaradt a chatben, probald ujra kesobb.',
        status: 'backend_unavailable',
        refusalReason: 'backend_unavailable',
      );
    }
  }
}
```

- [ ] **Step 5: Wire UI and render citations**

Modify `ChatBubble` to render citations for assistant messages:

```dart
if (!isUser && message.citations.isNotEmpty) ...[
  const SizedBox(height: 8),
  for (final citation in message.citations)
    Text(
      '${citation.title}${citation.page == null ? '' : ' p.${citation.page}'}',
      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
    ),
]
```

Modify `ChatScreen` constructor to accept `ChatService chatService` and change `_send()`:

```dart
await _loadKnowledgeState();
await widget.chatService.sendMessage(widget.conversation.id, text);
await _loadMessages();
```

Modify `MainScreen` and `DjinnApp` to construct and pass `ChatService`:

```dart
final chatService = widget.chatService ?? ChatService(
  repository: chatRepository,
  backend: BackendChatClient(baseUri: _backendUri()),
);
```

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
dart format lib/main.dart lib/src/chat/data/local_chat_repository.dart lib/src/chat/data/chat_service.dart lib/src/chat/ui/chat_bubble.dart lib/src/chat/ui/chat_screen.dart lib/src/chat/ui/main_screen.dart test/chat_service_test.dart test/widget_test.dart
flutter test test/chat_service_test.dart test/widget_test.dart test/chat_repository_test.dart
```

Expected: targeted Flutter tests pass.

Commit:

```bash
git add lib/main.dart lib/src/chat/data/local_chat_repository.dart lib/src/chat/data/chat_service.dart lib/src/chat/ui/chat_bubble.dart lib/src/chat/ui/chat_screen.dart lib/src/chat/ui/main_screen.dart test/chat_service_test.dart test/widget_test.dart test/chat_repository_test.dart
git commit -m "feat: route chat through backend service"
```

---

## Task 3: Backend Chunk Model And Local Retrieval Contract

**Files:**
- Modify: `backend/app/schemas.py`
- Create: `backend/app/services/chunk_repository.py`
- Create: `backend/app/services/chunking.py`
- Create: `backend/app/services/retrieval.py`
- Create: `backend/tests/test_chunking.py`
- Create: `backend/tests/test_retrieval.py`

- [ ] **Step 1: Write failing chunking and retrieval tests**

Create `backend/tests/test_chunking.py`:

```python
from app.services.chunking import chunk_pages


def test_chunk_pages_preserves_document_page_and_excerpt():
    chunks = chunk_pages(
        document_id='backend-doc-1',
        filename='omsz.pdf',
        source_path='corpus/omsz/backend-doc-1-omsz.pdf',
        pages=[(1, 'Mellkasi fajdalom es ellatasi algoritmus. ABCDE vizsgalat.')],
    )

    assert len(chunks) == 1
    assert chunks[0].id == 'backend-doc-1-1-0'
    assert chunks[0].document_id == 'backend-doc-1'
    assert chunks[0].title == 'omsz.pdf'
    assert chunks[0].page == 1
    assert 'ABCDE' in chunks[0].text
    assert chunks[0].metadata['extraction_method'] == 'pymupdf'
```

Create `backend/tests/test_retrieval.py`:

```python
from app.schemas import SourceChunk
from app.services.chunk_repository import ChunkRepository
from app.services.retrieval import RetrievalService


def test_retrieval_returns_matching_chunk_as_citation():
    repository = ChunkRepository()
    repository.replace_document_chunks(
        'backend-doc-1',
        [
            SourceChunk(
                id='chunk-1',
                document_id='backend-doc-1',
                title='omsz.pdf',
                page=3,
                text='Mellkasi fajdalom eseten ABCDE vizsgalat szukseges.',
                metadata={'source_path': 'corpus/omsz/omsz.pdf'},
            )
        ],
    )
    service = RetrievalService(repository=repository, minimum_score=1)

    result = service.retrieve('Mi a teendo mellkasi fajdalom eseten?')

    assert len(result.chunks) == 1
    assert result.citations[0].document_id == 'backend-doc-1'
    assert result.citations[0].page == 3
    assert 'ABCDE' in result.citations[0].excerpt


def test_retrieval_returns_empty_when_score_below_threshold():
    repository = ChunkRepository()
    repository.replace_document_chunks(
        'backend-doc-1',
        [
            SourceChunk(
                id='chunk-1',
                document_id='backend-doc-1',
                title='omsz.pdf',
                page=1,
                text='Lazcsillapitas gyermekeknel.',
                metadata={},
            )
        ],
    )
    service = RetrievalService(repository=repository, minimum_score=2)

    result = service.retrieve('trauma immobilizalas')

    assert result.chunks == []
    assert result.citations == []
```

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_chunking.py tests/test_retrieval.py
```

Expected: FAIL because chunk and retrieval modules do not exist.

- [ ] **Step 3: Add SourceChunk schema**

Modify `backend/app/schemas.py`:

```python
class SourceChunk(BaseModel):
    id: str
    document_id: str
    title: str
    page: int | None = None
    text: str
    metadata: dict[str, str] = Field(default_factory=dict)


class RetrievalResult(BaseModel):
    chunks: list[SourceChunk] = Field(default_factory=list)
    citations: list[Citation] = Field(default_factory=list)
```

- [ ] **Step 4: Implement chunk repository and chunker**

Create `backend/app/services/chunk_repository.py`:

```python
from app.schemas import SourceChunk


class ChunkRepository:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        self._chunks_by_document[document_id] = list(chunks)

    def list_chunks(self) -> list[SourceChunk]:
        chunks: list[SourceChunk] = []
        for document_chunks in self._chunks_by_document.values():
            chunks.extend(document_chunks)
        return chunks

    def count_document_chunks(self, document_id: str) -> int:
        return len(self._chunks_by_document.get(document_id, []))

    def clear(self) -> None:
        self._chunks_by_document.clear()
```

Create `backend/app/services/chunking.py`:

```python
import re

from app.schemas import SourceChunk

_MAX_CHARS = 900


def chunk_pages(
    *,
    document_id: str,
    filename: str,
    source_path: str,
    pages: list[tuple[int, str]],
    extraction_method: str = 'pymupdf',
) -> list[SourceChunk]:
    chunks: list[SourceChunk] = []
    for page, text in pages:
        normalized = re.sub(r'\s+', ' ', text).strip()
        if not normalized:
            continue
        parts = _split_text(normalized)
        for index, part in enumerate(parts):
            chunks.append(
                SourceChunk(
                    id=f'{document_id}-{page}-{index}',
                    document_id=document_id,
                    title=filename,
                    page=page,
                    text=part,
                    metadata={
                        'source_path': source_path,
                        'chunk_index': str(index),
                        'extraction_method': extraction_method,
                    },
                )
            )
    return chunks


def _split_text(text: str) -> list[str]:
    if len(text) <= _MAX_CHARS:
        return [text]
    parts: list[str] = []
    cursor = 0
    while cursor < len(text):
        parts.append(text[cursor:cursor + _MAX_CHARS].strip())
        cursor += _MAX_CHARS
    return [part for part in parts if part]
```

- [ ] **Step 5: Implement retrieval service**

Create `backend/app/services/retrieval.py`:

```python
import re

from app.schemas import Citation, RetrievalResult, SourceChunk
from app.services.chunk_repository import ChunkRepository


class RetrievalService:
    def __init__(self, *, repository: ChunkRepository, minimum_score: int = 1) -> None:
        self._repository = repository
        self._minimum_score = minimum_score

    def retrieve(self, query: str, *, limit: int = 3) -> RetrievalResult:
        query_terms = _terms(query)
        scored: list[tuple[int, SourceChunk]] = []
        for chunk in self._repository.list_chunks():
            score = len(query_terms.intersection(_terms(chunk.text)))
            if score >= self._minimum_score:
                scored.append((score, chunk))
        scored.sort(key=lambda item: item[0], reverse=True)
        chunks = [chunk for _, chunk in scored[:limit]]
        citations = [
            Citation(
                document_id=chunk.document_id,
                title=chunk.title,
                page=chunk.page,
                section=None,
                excerpt=chunk.text[:500],
            )
            for chunk in chunks
        ]
        return RetrievalResult(chunks=chunks, citations=citations)


def _terms(value: str) -> set[str]:
    return {term for term in re.findall(r'[0-9A-Za-zÁÉÍÓÖŐÚÜŰáéíóöőúüű]+', value.lower()) if len(term) >= 3}
```

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_chunking.py tests/test_retrieval.py
```

Expected: chunking and retrieval tests pass.

Commit:

```bash
git add backend/app/schemas.py backend/app/services/chunk_repository.py backend/app/services/chunking.py backend/app/services/retrieval.py backend/tests/test_chunking.py backend/tests/test_retrieval.py
git commit -m "feat: add local chunk retrieval contract"
```

---

## Task 4: Backend PDF Extraction And Ingest Chunk Storage

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/app/services/pdf_text_extractor.py`
- Modify: `backend/app/services/document_registry.py`
- Modify: `backend/app/main.py`
- Modify: `backend/tests/conftest.py`
- Create: `backend/tests/test_pdf_text_extractor.py`
- Modify: `backend/tests/test_knowledge_api.py`

- [ ] **Step 1: Write failing PDF extraction and ingest tests**

Create `backend/tests/test_pdf_text_extractor.py`:

```python
from pathlib import Path

import fitz

from app.services.pdf_text_extractor import PdfTextExtractor


def test_extracts_text_by_page(tmp_path: Path):
    pdf_path = tmp_path / 'sample.pdf'
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), 'Mellkasi fajdalom ABCDE vizsgalat')
    document.save(pdf_path)
    document.close()

    pages = PdfTextExtractor().extract_pages(pdf_path)

    assert pages == [(1, 'Mellkasi fajdalom ABCDE vizsgalat')]
```

Replace the dry ingest expectations in `backend/tests/test_knowledge_api.py` with:

```python
def test_ingest_extracts_pdf_text_and_marks_processed():
    pdf_bytes = _pdf_bytes('Mellkasi fajdalom ABCDE vizsgalat')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', pdf_bytes, 'application/pdf')},
    ).json()

    response = client.post(f"/knowledge/documents/{upload['id']}/ingest")

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'processed'
    assert body['error_message'] is None


def test_ingest_marks_unreadable_pdf_failed():
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('broken.pdf', b'%PDF-1.4 broken', 'application/pdf')},
    ).json()

    response = client.post(f"/knowledge/documents/{upload['id']}/ingest")

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'failed'
    assert body['error_message']


def _pdf_bytes(text: str) -> bytes:
    document = fitz.open()
    page = document.new_page()
    page.insert_text((72, 72), text)
    data = document.tobytes()
    document.close()
    return data
```

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_pdf_text_extractor.py tests/test_knowledge_api.py
```

Expected: FAIL because PyMuPDF dependency and extractor do not exist, and ingest is still dry.

- [ ] **Step 3: Add dependency and install locally**

Modify `backend/requirements.txt` by appending:

```text
PyMuPDF>=1.27,<1.28
```

Install:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
pip install -r requirements.txt
```

Expected: PyMuPDF installs and `python -c "import fitz"` exits 0.

- [ ] **Step 4: Implement PdfTextExtractor**

Create `backend/app/services/pdf_text_extractor.py`:

```python
from pathlib import Path

import fitz


class PdfExtractionError(Exception):
    pass


class PdfTextExtractor:
    def extract_pages(self, pdf_path: Path) -> list[tuple[int, str]]:
        try:
            document = fitz.open(pdf_path)
        except Exception as error:
            raise PdfExtractionError(str(error)) from error
        try:
            pages: list[tuple[int, str]] = []
            for index, page in enumerate(document, start=1):
                text = ' '.join(page.get_text('text').split())
                if text:
                    pages.append((index, text))
            return pages
        finally:
            document.close()
```

- [ ] **Step 5: Replace dry ingest with extraction and chunks**

Modify `DocumentRegistry.__init__` to accept `chunk_repository` and `extractor`. In `start_ingest()`:

```python
pages = self._extractor.extract_pages(record.stored_path)
chunks = chunk_pages(
    document_id=record.id,
    filename=record.filename,
    source_path=str(record.stored_path),
    pages=pages,
)
if not chunks:
    updated = record.model_copy(update={
        'status': KnowledgeDocumentStatus.failed,
        'error_message': 'No extractable text was found in the PDF.',
    })
    self._documents[document_id] = updated
    self._chunk_repository.replace_document_chunks(document_id, [])
    return updated
self._chunk_repository.replace_document_chunks(document_id, chunks)
updated = record.model_copy(update={
    'status': KnowledgeDocumentStatus.processed,
    'error_message': None,
})
self._documents[document_id] = updated
return updated
```

Catch `PdfExtractionError` and missing file errors by storing `failed` with `error_message`.

Modify `backend/app/main.py` to instantiate:

```python
chunks = ChunkRepository()
documents = DocumentRegistry(chunk_repository=chunks, extractor=PdfTextExtractor())
```

Modify `backend/tests/conftest.py` to clear `main.chunks` between tests.

- [ ] **Step 6: Run backend tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_pdf_text_extractor.py tests/test_knowledge_api.py tests/test_chunking.py tests/test_retrieval.py
```

Expected: targeted backend tests pass.

Commit:

```bash
git add backend/requirements.txt backend/app/services/pdf_text_extractor.py backend/app/services/document_registry.py backend/app/main.py backend/tests/conftest.py backend/tests/test_pdf_text_extractor.py backend/tests/test_knowledge_api.py
git commit -m "feat: extract PDF text during ingest"
```

---

## Task 5: Backend Retrieval-Aware Chat Answers

**Files:**
- Create: `backend/app/services/answer_service.py`
- Modify: `backend/app/main.py`
- Modify: `backend/app/services/safety.py`
- Modify: `backend/tests/test_api.py`

- [ ] **Step 1: Write failing chat retrieval tests**

Modify `backend/tests/test_api.py`:

```python
def test_chat_returns_grounded_answer_with_citation_after_ingest():
    pdf_bytes = _pdf_bytes('Mellkasi fajdalom eseten ABCDE vizsgalat szukseges.')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('protocol.pdf', pdf_bytes, 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post('/chat', json={'message': 'Mi a teendo mellkasi fajdalom eseten?'})

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'grounded'
    assert 'ABCDE' in body['answer']
    assert body['citations'][0]['document_id'] == upload['id']
    assert body['citations'][0]['page'] == 1
    assert body['refusal_reason'] is None


def test_chat_refuses_when_processed_chunks_do_not_match_question():
    pdf_bytes = _pdf_bytes('Lazcsillapitas gyermekkorban.')
    upload = client.post(
        '/knowledge/documents',
        files={'file': ('fever.pdf', pdf_bytes, 'application/pdf')},
    ).json()
    client.post(f"/knowledge/documents/{upload['id']}/ingest")

    response = client.post('/chat', json={'message': 'Trauma immobilizalas?'})

    assert response.status_code == 200
    body = response.json()
    assert body['status'] == 'insufficient_evidence'
    assert body['citations'] == []
    assert body['refusal_reason'] == 'insufficient_retrieval_evidence'
```

Keep `_pdf_bytes()` in the same file as the helper from Task 4.

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_api.py
```

Expected: FAIL because `/chat` still returns `retrieval_not_available` when processed documents exist.

- [ ] **Step 3: Implement AnswerService**

Create `backend/app/services/answer_service.py`:

```python
from app.schemas import ChatResponse, GroundingStatus, KnowledgeStatusResponse
from app.services.retrieval import RetrievalService
from app.services.safety import answer_without_corpus


class AnswerService:
    def __init__(self, *, retrieval: RetrievalService) -> None:
        self._retrieval = retrieval

    def answer(self, *, conversation_id: str, message: str, knowledge: KnowledgeStatusResponse) -> ChatResponse:
        if knowledge.pending_count > 0 and knowledge.processed_count == 0:
            return answer_without_corpus(conversation_id, ingest_pending=True)
        if knowledge.processed_count == 0:
            return answer_without_corpus(conversation_id)
        result = self._retrieval.retrieve(message)
        if not result.chunks:
            return ChatResponse(
                conversation_id=conversation_id,
                answer='A feldolgozott tudasbazisban nincs elegendo idezett forras ehhez a valaszhoz.',
                status=GroundingStatus.insufficient_evidence,
                citations=[],
                refusal_reason='insufficient_retrieval_evidence',
            )
        top_chunk = result.chunks[0]
        return ChatResponse(
            conversation_id=conversation_id,
            answer=top_chunk.text,
            status=GroundingStatus.grounded,
            citations=result.citations,
            refusal_reason=None,
        )
```

- [ ] **Step 4: Wire AnswerService into `/chat`**

Modify `backend/app/main.py` service construction:

```python
chunks = ChunkRepository()
retrieval = RetrievalService(repository=chunks, minimum_score=1)
answers = AnswerService(retrieval=retrieval)
documents = DocumentRegistry(chunk_repository=chunks, extractor=PdfTextExtractor())
```

Modify `/chat`:

```python
knowledge = documents.status()
response = answers.answer(
    conversation_id=conversation_id,
    message=request.message,
    knowledge=knowledge,
)
```

Keep `ConversationStore.append_message()` unchanged except it now stores grounded status when returned.

- [ ] **Step 5: Run backend tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_api.py tests/test_retrieval.py tests/test_knowledge_api.py
```

Expected: targeted backend tests pass.

Commit:

```bash
git add backend/app/services/answer_service.py backend/app/main.py backend/app/services/safety.py backend/tests/test_api.py
git commit -m "feat: answer from retrieved chunks"
```

---

## Task 6: Qdrant And PostgreSQL Adapter Interfaces

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/app/infra/__init__.py`
- Create: `backend/app/infra/settings.py`
- Create: `backend/app/infra/vector_index.py`
- Create: `backend/app/infra/metadata_store.py`
- Create: `backend/tests/test_infra_adapters.py`

- [ ] **Step 1: Write failing infra adapter tests**

Create `backend/tests/test_infra_adapters.py`:

```python
from app.infra.metadata_store import LocalMetadataStore
from app.infra.settings import BackendSettings
from app.infra.vector_index import LocalVectorIndex
from app.schemas import SourceChunk


def test_settings_default_to_local_retrieval():
    settings = BackendSettings.from_env({})

    assert settings.use_qdrant is False
    assert settings.use_postgres is False
    assert settings.qdrant_url == 'http://localhost:6333'
    assert settings.postgres_dsn == 'postgresql://djinn:djinn_dev_password@localhost:5432/djinn'


def test_local_vector_index_returns_upserted_chunk_ids():
    index = LocalVectorIndex()
    chunk = SourceChunk(
        id='chunk-1',
        document_id='backend-doc-1',
        title='omsz.pdf',
        page=1,
        text='Mellkasi fajdalom ABCDE',
        metadata={},
    )

    index.upsert_chunks([chunk])
    results = index.search('mellkasi fajdalom')

    assert results == ['chunk-1']


def test_local_metadata_store_records_chunks_by_document():
    store = LocalMetadataStore()
    chunk = SourceChunk(
        id='chunk-1',
        document_id='backend-doc-1',
        title='omsz.pdf',
        page=1,
        text='ABCDE',
        metadata={},
    )

    store.replace_document_chunks('backend-doc-1', [chunk])

    assert store.list_document_chunks('backend-doc-1') == [chunk]
```

- [ ] **Step 2: Run tests red**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_infra_adapters.py
```

Expected: FAIL because infra modules do not exist.

- [ ] **Step 3: Add dependencies**

Modify `backend/requirements.txt`:

```text
qdrant-client>=1.18,<1.19
psycopg[binary]>=3.3,<3.4
```

Install:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
pip install -r requirements.txt
```

Expected: `python -c "import qdrant_client, psycopg"` exits 0.

- [ ] **Step 4: Implement settings**

Create `backend/app/infra/settings.py`:

```python
from dataclasses import dataclass
from os import environ
from typing import Mapping


@dataclass(frozen=True)
class BackendSettings:
    use_qdrant: bool
    use_postgres: bool
    qdrant_url: str
    qdrant_collection: str
    postgres_dsn: str

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> 'BackendSettings':
        values = environ if env is None else env
        return cls(
            use_qdrant=values.get('DJINN_USE_QDRANT', 'false').lower() == 'true',
            use_postgres=values.get('DJINN_USE_POSTGRES', 'false').lower() == 'true',
            qdrant_url=values.get('DJINN_QDRANT_URL', 'http://localhost:6333'),
            qdrant_collection=values.get('DJINN_QDRANT_COLLECTION', 'djinn_chunks'),
            postgres_dsn=values.get(
                'DJINN_POSTGRES_DSN',
                'postgresql://djinn:djinn_dev_password@localhost:5432/djinn',
            ),
        )
```

- [ ] **Step 5: Implement local adapters and adapter shells**

Create `backend/app/infra/vector_index.py`:

```python
from typing import Protocol

from app.schemas import SourceChunk


class VectorIndex(Protocol):
    def upsert_chunks(self, chunks: list[SourceChunk]) -> None: ...
    def search(self, query: str, *, limit: int = 3) -> list[str]: ...


class LocalVectorIndex:
    def __init__(self) -> None:
        self._chunks: list[SourceChunk] = []

    def upsert_chunks(self, chunks: list[SourceChunk]) -> None:
        self._chunks.extend(chunks)

    def search(self, query: str, *, limit: int = 3) -> list[str]:
        terms = {term for term in query.lower().split() if len(term) >= 3}
        scored = []
        for chunk in self._chunks:
            score = sum(1 for term in terms if term in chunk.text.lower())
            if score:
                scored.append((score, chunk.id))
        scored.sort(reverse=True)
        return [chunk_id for _, chunk_id in scored[:limit]]


class QdrantVectorIndex:
    def __init__(self, *, url: str, collection: str) -> None:
        from qdrant_client import QdrantClient

        self._client = QdrantClient(url=url)
        self._collection = collection

    def upsert_chunks(self, chunks: list[SourceChunk]) -> None:
        # Real embedding vectors are introduced after model-provider selection.
        return None

    def search(self, query: str, *, limit: int = 3) -> list[str]:
        return []
```

Create `backend/app/infra/metadata_store.py`:

```python
from typing import Protocol

from app.schemas import SourceChunk


class MetadataStore(Protocol):
    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None: ...
    def list_document_chunks(self, document_id: str) -> list[SourceChunk]: ...


class LocalMetadataStore:
    def __init__(self) -> None:
        self._chunks_by_document: dict[str, list[SourceChunk]] = {}

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        self._chunks_by_document[document_id] = list(chunks)

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return list(self._chunks_by_document.get(document_id, []))


class PostgresMetadataStore:
    def __init__(self, *, dsn: str) -> None:
        import psycopg

        self._dsn = dsn
        self._psycopg = psycopg

    def replace_document_chunks(self, document_id: str, chunks: list[SourceChunk]) -> None:
        return None

    def list_document_chunks(self, document_id: str) -> list[SourceChunk]:
        return []
```

The Qdrant/PostgreSQL classes intentionally provide adapter shells without generating fake embeddings or creating clinical retrieval claims.

- [ ] **Step 6: Run tests green and commit**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q tests/test_infra_adapters.py
```

Expected: infra adapter contract tests pass.

Commit:

```bash
git add backend/requirements.txt backend/app/infra backend/tests/test_infra_adapters.py
git commit -m "feat: add retrieval infrastructure adapters"
```

---

## Task 7: Full Verification, Push, And GitHub Build

**Files:**
- Verify all changed files.

- [ ] **Step 1: Run backend full test suite**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn/backend
. .venv/bin/activate
PYTHONPATH=. pytest -q
```

Expected: all backend tests pass.

- [ ] **Step 2: Run Flutter analyzer**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run Flutter full test suite**

Run:

```bash
cd /home/flutteruser/flutterapps/djinn
export PATH=/home/flutteruser/flutter/bin:$PATH
flutter test
```

Expected: all Flutter tests pass.

- [ ] **Step 4: Check git status**

Run:

```bash
git status --short --branch
```

Expected: branch is ahead of `origin/main` only by the new implementation commits and has no unstaged files.

- [ ] **Step 5: Push to GitHub**

Run:

```bash
git push origin main
```

Expected: `main -> main` push succeeds.

- [ ] **Step 6: Watch GitHub Android build**

Run:

```bash
gh -R elizerpist/djinn run list --limit 1 --json databaseId,headSha,status,conclusion,url,workflowName
gh -R elizerpist/djinn run watch <databaseId> --exit-status
```

Expected: `Android native build` completes with Analyze, Test Flutter app, Build release APK, and Upload APK artifact all passing.

---

## Self-Review

- Spec coverage: Task 1 and Task 2 cover Flutter backend chat integration. Task 3 covers chunk model, chunk repository, and deterministic retrieval. Task 4 replaces dry ingest with PDF text extraction and chunk storage. Task 5 makes `/chat` retrieval-aware with grounded answers and refusal behavior. Task 6 adds Qdrant/PostgreSQL adapter interfaces and development wiring. Task 7 covers local and GitHub verification.
- Red-flag scan: every task includes exact file paths, commands, expected outcomes, and concrete code snippets; no unresolved work markers remain.
- Type consistency: Flutter uses `ChatCitation`, `BackendChatResponse`, `BackendChatClient`, and `ChatService` consistently. Backend uses `SourceChunk`, `RetrievalResult`, `ChunkRepository`, `RetrievalService`, `PdfTextExtractor`, and `AnswerService` consistently.
- Scope check: this is one milestone with staged commits. Flowchart interpretation, LLM generation, and clinical validation remain explicit non-goals from the approved spec.
