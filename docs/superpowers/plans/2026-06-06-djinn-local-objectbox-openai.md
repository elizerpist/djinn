# Djinn Local ObjectBox OpenAI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build B mode: a Flutter APK runtime where chat, PDF knowledge base, ObjectBox vector retrieval, OpenAI API-key settings, citations, and flowchart validation run without a Termux/FastAPI backend.

**Architecture:** The app keeps UI in Flutter, persists all local domain state in ObjectBox, stores the OpenAI API key in secure storage, and calls OpenAI only through provider adapters. Chat generation is source-bounded: local retrieval and citation verification happen before and after OpenAI answer generation.

**Tech Stack:** Flutter, Dart, ObjectBox Flutter with HNSW vector search, flutter_secure_storage, file_picker, http, path_provider, OpenAI Responses API and Embeddings API, flutter_test.

---

## References Checked

- Design spec: `docs/superpowers/specs/2026-06-06-djinn-local-objectbox-openai-design.md`
- ObjectBox vector search docs: https://docs.objectbox.io/on-device-vector-search
- OpenAI models docs: https://developers.openai.com/api/docs/models
- OpenAI embeddings docs: https://developers.openai.com/api/docs/guides/embeddings

ObjectBox Dart/Flutter vector fields use `@HnswIndex(...)` plus `@Property(type: PropertyType.floatVector)` on `List<double>?` fields. OpenAI embedding default is `text-embedding-3-large`, which produces 3072-dimensional vectors by default.

## Scope Check

This plan covers the full B mode vertical slice from settings to chat answer and validation UI. It is large, so implementation must commit after every task. If a task exposes build-time package incompatibility, stop and fix that task before continuing; do not skip to downstream UI work.

## File Structure

Create or modify these files:

- Modify `pubspec.yaml`: add ObjectBox, secure storage, UUID, and build tooling dependencies.
- Create `lib/src/local_store/entities.dart`: ObjectBox `@Entity` classes and persisted enums.
- Create `lib/src/local_store/objectbox_store.dart`: Store initialization helper.
- Generate `lib/objectbox.g.dart` and `objectbox-model.json` with `build_runner`.
- Create `lib/src/settings/models/app_settings.dart`: non-secret settings model.
- Create `lib/src/settings/data/api_key_store.dart`: secure OpenAI key read/write/delete/test state boundary.
- Create `lib/src/settings/data/app_settings_repository.dart`: ObjectBox-backed non-secret settings.
- Create `lib/src/settings/ui/settings_screen.dart`: settings UI.
- Create `lib/src/openai/openai_client.dart`: provider interface, DTOs, and exceptions.
- Create `lib/src/openai/openai_http_client.dart`: HTTP implementation for Responses and Embeddings APIs.
- Create `lib/src/rag/models/source_evidence.dart`: evidence and citation models used by retrieval and answer generation.
- Create `lib/src/rag/retrieval/local_retriever.dart`: ObjectBox vector search and source filtering.
- Create `lib/src/rag/verification/citation_verifier.dart`: deterministic citation checks and warning derivation.
- Create `lib/src/chat/data/objectbox_chat_repository.dart`: ObjectBox chat persistence.
- Modify `lib/src/chat/data/chat_service.dart`: depend on local B mode orchestration rather than `BackendChatClient`.
- Create `lib/src/chat/data/local_answer_service.dart`: question embedding, retrieval, OpenAI answer, verification.
- Modify `lib/src/chat/models/chat_citation.dart`: add source IDs and source labels needed by local citations.
- Modify `lib/src/chat/models/chat_message.dart`: add warning metadata for unvalidated flowchart evidence.
- Modify `lib/src/chat/ui/chat_bubble.dart`: render warning banner and citation labels.
- Modify `lib/src/chat/ui/main_screen.dart`: add hamburger drawer and actionable empty state.
- Create `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: ObjectBox document, chunk, flowchart, and job persistence.
- Modify `lib/src/knowledge/data/pdf_import_service.dart`: keep local copy behavior, return stable import metadata.
- Create `lib/src/knowledge/data/document_processing_service.dart`: local processing job orchestration using OpenAI.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: remove backend readiness wording and show local processing state.
- Create `lib/src/flowchart/models/flowchart_view_model.dart`: UI models for simple and graphical validation.
- Create `lib/src/flowchart/data/flowchart_validation_repository.dart`: validation state updates.
- Create `lib/src/flowchart/ui/flowchart_validation_screen.dart`: document/flowchart review list.
- Create `lib/src/flowchart/ui/simple_flowchart_editor.dart`: list editor.
- Create `lib/src/flowchart/ui/graph_flowchart_editor.dart`: canvas editor.
- Modify `lib/main.dart`: initialize ObjectBox, secure settings, OpenAI client, and local B mode services.
- Modify `README.md`: explain B mode, API key, local ObjectBox, and no Termux backend requirement.
- Add or update tests under `test/` matching each task below.

## Shared Domain Names

Use these exact enum wire values across entities, DTOs, and tests:

```dart
enum ProcessingState {
  imported,
  blockedMissingApiKey,
  blockedOffline,
  uploading,
  processing,
  embedded,
  ready,
  needsReview,
  failed,
}

enum ValidationState {
  unreviewed,
  partiallyValidated,
  validated,
  rejected,
}

enum EvidenceSourceType {
  textChunk,
  flowchartNode,
  flowchartEdge,
}
```

Use these source labels in UI rendering:

```dart
const sourceLabelByTypeAndValidation = {
  'text': 'Szöveges PDF-részlet',
  'flowchart_validated': 'Validált flowchart',
  'flowchart_partially_validated': 'Részben validált flowchart',
  'flowchart_unreviewed': 'Nem validált flowchart',
};
```

---

### Task 1: Add Local Runtime Dependencies

**Files:**
- Modify: `pubspec.yaml`
- Generated after command: `pubspec.lock`

- [ ] **Step 1: Add dependencies with Flutter tooling**

Run:

```bash
flutter pub add objectbox objectbox_flutter_libs flutter_secure_storage uuid
flutter pub add --dev build_runner objectbox_generator
```

Expected: `pubspec.yaml` gains runtime dependencies and dev dependencies, and `pubspec.lock` is updated.

- [ ] **Step 2: Fetch packages**

Run:

```bash
flutter pub get
```

Expected: command exits 0 and prints dependency resolution output without version solving failure.

- [ ] **Step 3: Commit dependency changes**

Run:

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add local ObjectBox dependencies"
```

Expected: one commit containing only dependency files.

---

### Task 2: Define ObjectBox Entities And Store Initialization

**Files:**
- Create: `lib/src/local_store/entities.dart`
- Create: `lib/src/local_store/objectbox_store.dart`
- Generated: `lib/objectbox.g.dart`
- Generated or modify: `objectbox-model.json`
- Test: `test/local_store_entities_test.dart`

- [ ] **Step 1: Write failing entity metadata test**

Create `test/local_store_entities_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('embedding entity keeps 3072 dimensional vectors', () {
    final entity = ChunkEmbeddingEntity(
      sourceId: 'chunk-1',
      sourceType: EvidenceSourceType.textChunk.wireName,
      vector: List<double>.filled(3072, 0.25),
      model: 'text-embedding-3-large',
      createdAtMillis: 1760000000000,
    );

    expect(entity.vector, hasLength(3072));
    expect(entity.sourceType, 'text_chunk');
    expect(entity.model, 'text-embedding-3-large');
  });

  test('validation state wire names are stable', () {
    expect(ValidationState.unreviewed.wireName, 'unreviewed');
    expect(ValidationState.partiallyValidated.wireName, 'partially_validated');
    expect(ValidationState.validated.wireName, 'validated');
    expect(ValidationState.rejected.wireName, 'rejected');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/local_store_entities_test.dart
```

Expected: FAIL because `entities.dart` does not exist.

- [ ] **Step 3: Create ObjectBox entity definitions**

Create `lib/src/local_store/entities.dart` with this structure:

```dart
import 'package:objectbox/objectbox.dart';

enum ProcessingState {
  imported('imported'),
  blockedMissingApiKey('blocked_missing_api_key'),
  blockedOffline('blocked_offline'),
  uploading('uploading'),
  processing('processing'),
  embedded('embedded'),
  ready('ready'),
  needsReview('needs_review'),
  failed('failed');

  const ProcessingState(this.wireName);
  final String wireName;
}

enum ValidationState {
  unreviewed('unreviewed'),
  partiallyValidated('partially_validated'),
  validated('validated'),
  rejected('rejected');

  const ValidationState(this.wireName);
  final String wireName;
}

enum EvidenceSourceType {
  textChunk('text_chunk'),
  flowchartNode('flowchart_node'),
  flowchartEdge('flowchart_edge');

  const EvidenceSourceType(this.wireName);
  final String wireName;
}

@Entity()
class ChatThreadEntity {
  ChatThreadEntity({
    this.id = 0,
    required this.publicId,
    required this.title,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  String title;
  int createdAtMillis;
  int updatedAtMillis;
}

@Entity()
class ChatMessageEntity {
  ChatMessageEntity({
    this.id = 0,
    required this.publicId,
    required this.threadPublicId,
    required this.sender,
    required this.text,
    required this.createdAtMillis,
    this.status,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  String threadPublicId;
  String sender;
  String text;
  int createdAtMillis;
  String? status;
  String? refusalReason;
  bool hasValidationWarning;
  String? warningText;
}

@Entity()
class KnowledgeDocumentEntity {
  KnowledgeDocumentEntity({
    this.id = 0,
    required this.publicId,
    required this.filename,
    required this.localPath,
    required this.sizeBytes,
    required this.importedAtMillis,
    required this.processingState,
    this.errorMessage,
    this.openAiFileId,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  String filename;
  String localPath;
  int sizeBytes;
  int importedAtMillis;
  String processingState;
  String? errorMessage;
  String? openAiFileId;
}

@Entity()
class DocumentChunkEntity {
  DocumentChunkEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.text,
    required this.pageNumber,
    this.sectionTitle,
    this.sourceRectJson,
  });

  @Id()
  int id;
  @Unique()
  String publicId;
  String documentPublicId;
  String text;
  int pageNumber;
  String? sectionTitle;
  String? sourceRectJson;
}

@Entity()
class ChunkEmbeddingEntity {
  ChunkEmbeddingEntity({
    this.id = 0,
    required this.sourceId,
    required this.sourceType,
    required this.vector,
    required this.model,
    required this.createdAtMillis,
  });

  @Id()
  int id;
  @Index()
  String sourceId;
  String sourceType;
  @HnswIndex(dimensions: 3072, distanceType: VectorDistanceType.cosine)
  @Property(type: PropertyType.floatVector)
  List<double>? vector;
  String model;
  int createdAtMillis;
}
```

Continue the same file with `FlowchartEntity`, `FlowchartNodeEntity`, `FlowchartEdgeEntity`, `CitationEntity`, `ProcessingJobEntity`, and `AppSettingsEntity`. Use scalar public IDs instead of ObjectBox relations for the first pass so tests and migrations stay simple.

Required fields:

```dart
@Entity()
class FlowchartEntity {
  FlowchartEntity({
    this.id = 0,
    required this.publicId,
    required this.documentPublicId,
    required this.pageNumber,
    required this.validationState,
    this.sourceRectJson,
    this.extractionConfidence,
  });
  @Id() int id;
  @Unique() String publicId;
  String documentPublicId;
  int pageNumber;
  String validationState;
  String? sourceRectJson;
  double? extractionConfidence;
}

@Entity()
class FlowchartNodeEntity {
  FlowchartNodeEntity({
    this.id = 0,
    required this.publicId,
    required this.flowchartPublicId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
    this.positionX = 0,
    this.positionY = 0,
  });
  @Id() int id;
  @Unique() String publicId;
  String flowchartPublicId;
  String label;
  String validationState;
  String? rejectionReason;
  double positionX;
  double positionY;
}

@Entity()
class FlowchartEdgeEntity {
  FlowchartEdgeEntity({
    this.id = 0,
    required this.publicId,
    required this.flowchartPublicId,
    required this.fromNodePublicId,
    required this.toNodePublicId,
    required this.label,
    required this.validationState,
    this.rejectionReason,
  });
  @Id() int id;
  @Unique() String publicId;
  String flowchartPublicId;
  String fromNodePublicId;
  String toNodePublicId;
  String label;
  String validationState;
  String? rejectionReason;
}
```

- [ ] **Step 4: Create store opener**

Create `lib/src/local_store/objectbox_store.dart`:

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../objectbox.g.dart';

class ObjectBoxStore {
  ObjectBoxStore._(this.store);

  final Store store;

  static Future<ObjectBoxStore> open({required Directory directory}) async {
    final path = p.join(directory.path, 'objectbox');
    final store = await openStore(directory: path);
    return ObjectBoxStore._(store);
  }

  void close() => store.close();
}
```

- [ ] **Step 5: Generate ObjectBox code**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/objectbox.g.dart` and `objectbox-model.json` are created or updated.

- [ ] **Step 6: Run entity test**

Run:

```bash
flutter test test/local_store_entities_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit local store foundation**

Run:

```bash
git add lib/src/local_store/entities.dart lib/src/local_store/objectbox_store.dart lib/objectbox.g.dart objectbox-model.json test/local_store_entities_test.dart
git commit -m "feat: add ObjectBox local store entities"
```

Expected: commit succeeds.

---

### Task 3: Add Secure API Key And App Settings Repositories

**Files:**
- Create: `lib/src/settings/models/app_settings.dart`
- Create: `lib/src/settings/data/api_key_store.dart`
- Create: `lib/src/settings/data/app_settings_repository.dart`
- Test: `test/settings_repository_test.dart`

- [ ] **Step 1: Write failing settings tests**

Create `test/settings_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';

void main() {
  test('default settings use local ObjectBox mode and OpenAI defaults', () {
    final settings = AppSettings.defaults();

    expect(settings.runtimeMode, 'local_objectbox');
    expect(settings.answerModel, 'gpt-5.5');
    expect(settings.extractionModel, 'gpt-5.5');
    expect(settings.groundednessModel, 'gpt-5.5');
    expect(settings.embeddingModel, 'text-embedding-3-large');
    expect(settings.deleteOpenAiFilesAfterProcessing, isTrue);
    expect(settings.groundednessCheckEnabled, isFalse);
  });

  test('memory API key store can save, read, and delete key', () async {
    final store = MemoryApiKeyStore();

    expect(await store.hasKey(), isFalse);
    await store.saveKey('sk-test');
    expect(await store.hasKey(), isTrue);
    expect(await store.readKey(), 'sk-test');
    await store.deleteKey();
    expect(await store.hasKey(), isFalse);
    expect(await store.readKey(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/settings_repository_test.dart
```

Expected: FAIL because settings classes do not exist.

- [ ] **Step 3: Create settings model**

Create `lib/src/settings/models/app_settings.dart`:

```dart
class AppSettings {
  const AppSettings({
    required this.runtimeMode,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      runtimeMode: 'local_objectbox',
      answerModel: 'gpt-5.5',
      extractionModel: 'gpt-5.5',
      groundednessModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      deleteOpenAiFilesAfterProcessing: true,
      groundednessCheckEnabled: false,
      retrievalLimit: 8,
      minimumSimilarity: 0.72,
    );
  }

  final String runtimeMode;
  final String answerModel;
  final String extractionModel;
  final String groundednessModel;
  final String embeddingModel;
  final bool deleteOpenAiFilesAfterProcessing;
  final bool groundednessCheckEnabled;
  final int retrievalLimit;
  final double minimumSimilarity;
}
```

- [ ] **Step 4: Create API key store boundary**

Create `lib/src/settings/data/api_key_store.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ApiKeyStore {
  Future<bool> hasKey();
  Future<String?> readKey();
  Future<void> saveKey(String value);
  Future<void> deleteKey();
}

class SecureApiKeyStore implements ApiKeyStore {
  SecureApiKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'openai_api_key';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasKey() async {
    final value = await readKey();
    return value != null && value.trim().isNotEmpty;
  }

  @override
  Future<String?> readKey() => _storage.read(key: _key);

  @override
  Future<void> saveKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('OpenAI API key must not be blank');
    }
    await _storage.write(key: _key, value: trimmed);
  }

  @override
  Future<void> deleteKey() => _storage.delete(key: _key);
}

class MemoryApiKeyStore implements ApiKeyStore {
  String? _value;

  @override
  Future<bool> hasKey() async => _value != null && _value!.isNotEmpty;

  @override
  Future<String?> readKey() async => _value;

  @override
  Future<void> saveKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('OpenAI API key must not be blank');
    }
    _value = trimmed;
  }

  @override
  Future<void> deleteKey() async => _value = null;
}
```

- [ ] **Step 5: Create AppSettingsRepository**

Create `lib/src/settings/data/app_settings_repository.dart` with `load()` returning defaults when no `AppSettingsEntity` exists and `save(AppSettings)` updating the single row. Map the model fields to `AppSettingsEntity` scalar fields. Add missing scalar fields to `AppSettingsEntity` in `entities.dart` if they were not added in Task 2.

Required `AppSettingsEntity` fields:

```dart
@Entity()
class AppSettingsEntity {
  AppSettingsEntity({
    this.id = 0,
    required this.runtimeMode,
    required this.answerModel,
    required this.extractionModel,
    required this.groundednessModel,
    required this.embeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
  });

  @Id()
  int id;
  String runtimeMode;
  String answerModel;
  String extractionModel;
  String groundednessModel;
  String embeddingModel;
  bool deleteOpenAiFilesAfterProcessing;
  bool groundednessCheckEnabled;
  int retrievalLimit;
  double minimumSimilarity;
}
```

- [ ] **Step 6: Regenerate ObjectBox if entity changed**

Run:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Expected: generated files update cleanly.

- [ ] **Step 7: Run settings tests**

Run:

```bash
flutter test test/settings_repository_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit settings foundation**

Run:

```bash
git add lib/src/settings lib/src/local_store/entities.dart lib/objectbox.g.dart objectbox-model.json test/settings_repository_test.dart
git commit -m "feat: add secure OpenAI settings storage"
```

Expected: commit succeeds.

---

### Task 4: Add OpenAI Provider Interface And Mockable HTTP Client

**Files:**
- Create: `lib/src/openai/openai_client.dart`
- Create: `lib/src/openai/openai_http_client.dart`
- Test: `test/openai_client_test.dart`

- [ ] **Step 1: Write provider contract tests**

Create `test/openai_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/openai/openai_client.dart';

void main() {
  test('fake OpenAI client returns deterministic embedding', () async {
    final client = FakeOpenAiClient(
      embedding: List<double>.filled(3072, 0.1),
    );

    final vector = await client.createEmbedding(
      input: 'mellkasi fajdalom',
      model: 'text-embedding-3-large',
    );

    expect(vector, hasLength(3072));
    expect(vector.first, 0.1);
  });

  test('fake answer cites supplied evidence ids', () async {
    final client = FakeOpenAiClient(answerText: 'ABCDE szerint jarj el.');

    final answer = await client.generateAnswer(
      model: 'gpt-5.5',
      question: 'Mi a teendo?',
      evidence: [
        OpenAiEvidence(id: 'chunk-1', label: 'Szöveges PDF-részlet', text: 'ABCDE'),
      ],
    );

    expect(answer.answer, 'ABCDE szerint jarj el.');
    expect(answer.citedSourceIds, ['chunk-1']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/openai_client_test.dart
```

Expected: FAIL because `openai_client.dart` does not exist.

- [ ] **Step 3: Create OpenAI provider contract and fake**

Create `lib/src/openai/openai_client.dart`:

```dart
class OpenAiEvidence {
  const OpenAiEvidence({required this.id, required this.label, required this.text});
  final String id;
  final String label;
  final String text;
}

class OpenAiAnswer {
  const OpenAiAnswer({
    required this.answer,
    required this.citedSourceIds,
    this.abstain = false,
    this.refusalReason,
  });

  final String answer;
  final List<String> citedSourceIds;
  final bool abstain;
  final String? refusalReason;
}

class OpenAiExtractedChunk {
  const OpenAiExtractedChunk({
    required this.id,
    required this.text,
    required this.pageNumber,
    this.sectionTitle,
  });

  final String id;
  final String text;
  final int pageNumber;
  final String? sectionTitle;
}

class OpenAiExtractionResult {
  const OpenAiExtractionResult({required this.chunks});
  final List<OpenAiExtractedChunk> chunks;
}

class OpenAiException implements Exception {
  const OpenAiException(this.message);
  final String message;
  @override
  String toString() => 'OpenAiException: $message';
}

abstract class OpenAiClient {
  Future<void> testApiKey({required String apiKey});
  Future<List<double>> createEmbedding({required String input, required String model});
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  });
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  });
  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  });
}

class FakeOpenAiClient implements OpenAiClient {
  FakeOpenAiClient({List<double>? embedding, this.answerText = 'Valasz.'})
    : embedding = embedding ?? List<double>.filled(3072, 0.0);

  final List<double> embedding;
  final String answerText;

  @override
  Future<void> testApiKey({required String apiKey}) async {
    if (apiKey.trim().isEmpty) throw const OpenAiException('missing api key');
  }

  @override
  Future<List<double>> createEmbedding({required String input, required String model}) async => embedding;

  @override
  Future<OpenAiExtractionResult> extractDocument({required String pdfPath, required String model}) async {
    return const OpenAiExtractionResult(chunks: []);
  }

  @override
  Future<OpenAiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<OpenAiEvidence> evidence,
  }) async {
    return OpenAiAnswer(
      answer: answerText,
      citedSourceIds: evidence.map((item) => item.id).take(1).toList(),
    );
  }

  @override
  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<OpenAiEvidence> evidence,
  }) async => true;
}
```

- [ ] **Step 4: Create HTTP client skeleton with no external tools enabled**

Create `lib/src/openai/openai_http_client.dart`. The methods must use `http.Client`, send `Authorization: Bearer <apiKey>`, and call only official OpenAI endpoints. For answer generation, post to `/v1/responses` with explicit instructions that web search, file search, code execution, MCP, and external tools are unavailable.

Minimum class shape:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../settings/data/api_key_store.dart';
import 'openai_client.dart';

class OpenAiHttpClient implements OpenAiClient {
  OpenAiHttpClient({required ApiKeyStore apiKeyStore, http.Client? httpClient, Uri? baseUri})
    : _apiKeyStore = apiKeyStore,
      _httpClient = httpClient ?? http.Client(),
      _baseUri = baseUri ?? Uri.parse('https://api.openai.com');

  final ApiKeyStore _apiKeyStore;
  final http.Client _httpClient;
  final Uri _baseUri;

  Future<Map<String, String>> _headers() async {
    final key = await _apiKeyStore.readKey();
    if (key == null || key.trim().isEmpty) {
      throw const OpenAiException('OpenAI API key is missing');
    }
    return {'Authorization': 'Bearer $key', 'Content-Type': 'application/json'};
  }

  @override
  Future<List<double>> createEmbedding({required String input, required String model}) async {
    final response = await _httpClient.post(
      _baseUri.resolve('/v1/embeddings'),
      headers: await _headers(),
      body: jsonEncode({'model': model, 'input': input}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenAiException('embedding failed: ${response.statusCode}');
    }
    final json = jsonDecode(response.body) as Map<String, Object?>;
    final data = json['data'] as List;
    final embedding = (data.first as Map)['embedding'] as List;
    return embedding.map((value) => (value as num).toDouble()).toList(growable: false);
  }
}
```

Implement the remaining methods in this class during this task, using the DTOs from `openai_client.dart`. Keep parsing defensive: non-2xx responses throw `OpenAiException`; malformed JSON throws `OpenAiException('invalid OpenAI response')`.

- [ ] **Step 5: Run OpenAI contract tests**

Run:

```bash
flutter test test/openai_client_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit OpenAI provider boundary**

Run:

```bash
git add lib/src/openai test/openai_client_test.dart
git commit -m "feat: add OpenAI provider boundary"
```

Expected: commit succeeds.

---

### Task 5: Implement Citation Verification And Warning Rules

**Files:**
- Create: `lib/src/rag/models/source_evidence.dart`
- Create: `lib/src/rag/verification/citation_verifier.dart`
- Test: `test/citation_verifier_test.dart`

- [ ] **Step 1: Write failing verifier tests**

Create `test/citation_verifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/verification/citation_verifier.dart';

void main() {
  test('blocks citations that were not retrieved', () {
    final verifier = CitationVerifier();
    final result = verifier.verify(
      citedSourceIds: ['missing'],
      retrieved: [
        SourceEvidence(
          id: 'chunk-1',
          sourceType: EvidenceSourceType.textChunk,
          text: 'ABCDE',
          label: 'Szöveges PDF-részlet',
          validationState: ValidationState.validated,
        ),
      ],
    );

    expect(result.accepted, isFalse);
    expect(result.refusalReason, 'citation_verification_failed');
  });

  test('warns when unreviewed flowchart evidence is cited', () {
    final verifier = CitationVerifier();
    final result = verifier.verify(
      citedSourceIds: ['node-1'],
      retrieved: [
        SourceEvidence(
          id: 'node-1',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Döntési pont',
          label: 'Nem validált flowchart',
          validationState: ValidationState.unreviewed,
        ),
      ],
    );

    expect(result.accepted, isTrue);
    expect(result.hasValidationWarning, isTrue);
    expect(result.warningText, contains('nem validált'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/citation_verifier_test.dart
```

Expected: FAIL because RAG files do not exist.

- [ ] **Step 3: Create evidence model**

Create `lib/src/rag/models/source_evidence.dart`:

```dart
import '../../local_store/entities.dart';

class SourceEvidence {
  const SourceEvidence({
    required this.id,
    required this.sourceType,
    required this.text,
    required this.label,
    required this.validationState,
    this.documentId,
    this.pageNumber,
    this.score,
  });

  final String id;
  final EvidenceSourceType sourceType;
  final String text;
  final String label;
  final ValidationState validationState;
  final String? documentId;
  final int? pageNumber;
  final double? score;
}

class CitationVerificationResult {
  const CitationVerificationResult({
    required this.accepted,
    required this.citations,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  final bool accepted;
  final List<SourceEvidence> citations;
  final String? refusalReason;
  final bool hasValidationWarning;
  final String? warningText;
}
```

- [ ] **Step 4: Create verifier**

Create `lib/src/rag/verification/citation_verifier.dart`:

```dart
import '../../local_store/entities.dart';
import '../models/source_evidence.dart';

class CitationVerifier {
  CitationVerificationResult verify({
    required List<String> citedSourceIds,
    required List<SourceEvidence> retrieved,
  }) {
    if (citedSourceIds.isEmpty) {
      return const CitationVerificationResult(
        accepted: false,
        citations: [],
        refusalReason: 'citation_verification_failed',
      );
    }
    final byId = {for (final item in retrieved) item.id: item};
    final citations = <SourceEvidence>[];
    for (final id in citedSourceIds) {
      final evidence = byId[id];
      if (evidence == null) {
        return const CitationVerificationResult(
          accepted: false,
          citations: [],
          refusalReason: 'citation_verification_failed',
        );
      }
      citations.add(evidence);
    }
    final warning = citations.any(
      (item) =>
          item.sourceType != EvidenceSourceType.textChunk &&
          item.validationState != ValidationState.validated,
    );
    return CitationVerificationResult(
      accepted: true,
      citations: List.unmodifiable(citations),
      hasValidationWarning: warning,
      warningText: warning
          ? 'A válasz nem vagy csak részben validált flowchart elemet használ.'
          : null,
    );
  }
}
```

- [ ] **Step 5: Run verifier tests**

Run:

```bash
flutter test test/citation_verifier_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit citation verification**

Run:

```bash
git add lib/src/rag test/citation_verifier_test.dart
git commit -m "feat: verify local answer citations"
```

Expected: commit succeeds.

---

### Task 6: Add ObjectBox Knowledge Repository And Local Retriever

**Files:**
- Create: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Create: `lib/src/rag/retrieval/local_retriever.dart`
- Test: `test/local_retriever_test.dart`

- [ ] **Step 1: Write failing retrieval filter test**

Create `test/local_retriever_test.dart` using in-memory repository fakes first:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';

void main() {
  test('retriever excludes rejected flowchart evidence', () async {
    final retriever = MemoryLocalRetriever([
      SourceEvidence(
        id: 'node-rejected',
        sourceType: EvidenceSourceType.flowchartNode,
        text: 'Rejected',
        label: 'Nem validált flowchart',
        validationState: ValidationState.rejected,
        score: 0.99,
      ),
      SourceEvidence(
        id: 'chunk-accepted',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Accepted',
        label: 'Szöveges PDF-részlet',
        validationState: ValidationState.validated,
        score: 0.91,
      ),
    ]);

    final result = await retriever.retrieve(
      queryVector: List<double>.filled(3072, 0.1),
      limit: 5,
      minimumSimilarity: 0.7,
    );

    expect(result.map((item) => item.id), ['chunk-accepted']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/local_retriever_test.dart
```

Expected: FAIL because `local_retriever.dart` does not exist.

- [ ] **Step 3: Create retriever interface and memory fake**

Create `lib/src/rag/retrieval/local_retriever.dart`:

```dart
import '../../local_store/entities.dart';
import '../models/source_evidence.dart';

abstract class LocalRetriever {
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
  });
}

class MemoryLocalRetriever implements LocalRetriever {
  MemoryLocalRetriever(this._items);
  final List<SourceEvidence> _items;

  @override
  Future<List<SourceEvidence>> retrieve({
    required List<double> queryVector,
    required int limit,
    required double minimumSimilarity,
  }) async {
    return _items
        .where((item) => item.validationState != ValidationState.rejected)
        .where((item) => (item.score ?? 1) >= minimumSimilarity)
        .take(limit)
        .toList(growable: false);
  }
}
```

- [ ] **Step 4: Create ObjectBox repository class**

Create `lib/src/knowledge/data/objectbox_knowledge_repository.dart` with methods:

```dart
abstract class KnowledgeRepository {
  Future<KnowledgeDocumentEntity> addImportedDocument({
    required String filename,
    required String localPath,
    required int sizeBytes,
  });
  Future<List<KnowledgeDocumentEntity>> listDocuments();
  Future<void> updateProcessingState(String documentPublicId, ProcessingState state, {String? errorMessage});
  Future<void> saveChunk(DocumentChunkEntity chunk, ChunkEmbeddingEntity embedding);
  Future<bool> hasReadyDocuments();
}
```

Implement `ObjectBoxKnowledgeRepository` using `Store.box<T>()`. Use `uuid.v4()` for public IDs. For `hasReadyDocuments()`, query `KnowledgeDocumentEntity_.processingState.equals(ProcessingState.ready.wireName)`.

- [ ] **Step 5: Add ObjectBox vector retriever implementation**

In `local_retriever.dart`, add `ObjectBoxLocalRetriever` that queries `ChunkEmbeddingEntity` HNSW index and maps accepted results to `SourceEvidence` by looking up `DocumentChunkEntity`, `FlowchartNodeEntity`, or `FlowchartEdgeEntity` by public ID. Exclude `ValidationState.rejected` before returning evidence.

Use the generated nearest-neighbor query style from ObjectBox after code generation. The shape should be:

```dart
final query = embeddingBox
    .query(ChunkEmbeddingEntity_.vector.nearestNeighborsF32(queryVector, limit))
    .build();
final scored = query.findWithScores();
query.close();
```

If generated API names differ after ObjectBox generation, use the generated property method shown in `lib/objectbox.g.dart` and keep the test behavior unchanged.

- [ ] **Step 6: Run retriever tests**

Run:

```bash
flutter test test/local_retriever_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit retrieval repository**

Run:

```bash
git add lib/src/knowledge/data/objectbox_knowledge_repository.dart lib/src/rag/retrieval/local_retriever.dart test/local_retriever_test.dart
git commit -m "feat: add local ObjectBox retrieval boundary"
```

Expected: commit succeeds.

---

### Task 7: Add Local Answer Service And Replace Backend Chat Dependency

**Files:**
- Create: `lib/src/chat/data/objectbox_chat_repository.dart`
- Create: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/chat/data/chat_service.dart`
- Modify: `lib/src/chat/models/chat_citation.dart`
- Modify: `lib/src/chat/models/chat_message.dart`
- Test: `test/local_answer_service_test.dart`
- Update: `test/chat_service_test.dart`

- [ ] **Step 1: Write failing local answer tests**

Create `test/local_answer_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/chat/data/local_answer_service.dart';
import 'package:djinn/src/local_store/entities.dart';
import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/rag/models/source_evidence.dart';
import 'package:djinn/src/rag/retrieval/local_retriever.dart';
import 'package:djinn/src/rag/verification/citation_verifier.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  test('returns insufficient evidence before generation when retrieval is empty', () async {
    final service = LocalAnswerService(
      openAiClient: FakeOpenAiClient(),
      retriever: MemoryLocalRetriever(const []),
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('Mi a teendo?');

    expect(result.status, 'insufficient_evidence');
    expect(result.refusalReason, 'insufficient_evidence');
  });

  test('returns grounded answer with validation warning', () async {
    final service = LocalAnswerService(
      openAiClient: FakeOpenAiClient(answerText: 'Kovesd az algoritmust.'),
      retriever: MemoryLocalRetriever([
        SourceEvidence(
          id: 'node-1',
          sourceType: EvidenceSourceType.flowchartNode,
          text: 'Algoritmus node',
          label: 'Nem validált flowchart',
          validationState: ValidationState.unreviewed,
          score: 0.95,
        ),
      ]),
      citationVerifier: CitationVerifier(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      hasReadyDocuments: () async => true,
    );

    final result = await service.answer('Mi a teendo?');

    expect(result.status, 'grounded');
    expect(result.hasValidationWarning, isTrue);
    expect(result.citations.single.sourceId, 'node-1');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/local_answer_service_test.dart
```

Expected: FAIL because local answer service does not exist.

- [ ] **Step 3: Extend chat citation and message models**

Modify `lib/src/chat/models/chat_citation.dart` to include:

```dart
final String? sourceId;
final String? sourceLabel;
final String? validationState;
```

Keep existing JSON fields backward-compatible by reading missing fields as null.

Modify `lib/src/chat/models/chat_message.dart` to include:

```dart
final bool hasValidationWarning;
final String? warningText;
```

Default `hasValidationWarning` to false. Include both fields in `toJson()` and `fromJson()`.

- [ ] **Step 4: Create local answer service**

Create `lib/src/chat/data/local_answer_service.dart` with:

```dart
class LocalAnswerResult {
  const LocalAnswerResult({
    required this.text,
    required this.status,
    required this.citations,
    this.refusalReason,
    this.hasValidationWarning = false,
    this.warningText,
  });

  final String text;
  final String status;
  final List<ChatCitation> citations;
  final String? refusalReason;
  final bool hasValidationWarning;
  final String? warningText;
}
```

`LocalAnswerService.answer(String question)` must:

1. return `missing_api_key` if `hasApiKey()` is false;
2. return `empty_knowledge_base` if `hasReadyDocuments()` is false;
3. load settings;
4. call `openAiClient.createEmbedding`;
5. retrieve evidence;
6. return `insufficient_evidence` if retrieval is empty;
7. call `openAiClient.generateAnswer` with only retrieved evidence;
8. verify citations;
9. optionally call groundedness check;
10. return grounded answer or refusal.

Use this refusal text for no evidence:

```dart
const insufficientEvidenceText =
    'A helyi tudásbázisban nincs elég forrás ehhez a válaszhoz.';
```

- [ ] **Step 5: Modify ChatService to use LocalAnswerService**

Change constructor from `BackendChatClient backend` to `LocalAnswerService answerService`. In `sendMessage`, append user message, call `answerService.answer`, append assistant message with status, refusal reason, citations, and warning metadata. Keep a catch block for `OpenAiException` that writes `openai_error` instead of backend wording.

- [ ] **Step 6: Run local answer and chat service tests**

Run:

```bash
flutter test test/local_answer_service_test.dart test/chat_service_test.dart
```

Expected: PASS after updating `test/chat_service_test.dart` to use `LocalAnswerService` fakes instead of `BackendChatClient` fakes.

- [ ] **Step 7: Commit local answer service**

Run:

```bash
git add lib/src/chat lib/src/rag test/local_answer_service_test.dart test/chat_service_test.dart
git commit -m "feat: answer chat from local ObjectBox evidence"
```

Expected: commit succeeds.

---

### Task 8: Add Local Document Processing Jobs

**Files:**
- Create: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart` or replace call sites with `ObjectBoxKnowledgeRepository`
- Test: `test/document_processing_service_test.dart`

- [ ] **Step 1: Write failing processing tests**

Create `test/document_processing_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/knowledge/data/document_processing_service.dart';
import 'package:djinn/src/openai/openai_client.dart';
import 'package:djinn/src/settings/models/app_settings.dart';

void main() {
  test('blocks processing when API key is missing', () async {
    final service = DocumentProcessingService(
      openAiClient: FakeOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => false,
      repository: MemoryProcessingRepository(),
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'blocked_missing_api_key');
  });

  test('stores extracted chunks and embeddings', () async {
    final repository = MemoryProcessingRepository();
    final service = DocumentProcessingService(
      openAiClient: _ExtractingOpenAiClient(),
      loadSettings: () async => AppSettings.defaults(),
      hasApiKey: () async => true,
      repository: repository,
    );

    final result = await service.processDocument('doc-1');

    expect(result.state, 'ready');
    expect(repository.savedChunks, hasLength(1));
    expect(repository.savedEmbeddings.single.vector, hasLength(3072));
  });
}

class _ExtractingOpenAiClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({required String pdfPath, required String model}) async {
    return const OpenAiExtractionResult(
      chunks: [OpenAiExtractedChunk(id: 'c1', text: 'ABCDE protokoll', pageNumber: 1)],
    );
  }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/document_processing_service_test.dart
```

Expected: FAIL because processing service does not exist.

- [ ] **Step 3: Create processing service**

Create `lib/src/knowledge/data/document_processing_service.dart` with a repository interface suited for tests:

```dart
class ProcessingResult {
  const ProcessingResult({required this.state, this.errorMessage});
  final String state;
  final String? errorMessage;
}

abstract class ProcessingRepository {
  Future<String> localPathForDocument(String documentPublicId);
  Future<void> markState(String documentPublicId, ProcessingState state, {String? errorMessage});
  Future<void> saveExtractedChunk({
    required String documentPublicId,
    required OpenAiExtractedChunk chunk,
    required List<double> embedding,
    required String embeddingModel,
  });
}
```

`DocumentProcessingService.processDocument` must mark states in this order for a successful run: `processing`, `embedded`, `ready`. On missing API key, mark `blockedMissingApiKey`. On `OpenAiException`, mark `failed` with the exception message.

- [ ] **Step 4: Add memory processing repository for tests**

In the test file, define `MemoryProcessingRepository` implementing `ProcessingRepository`. Store `savedChunks` and `savedEmbeddings` lists so assertions stay deterministic.

- [ ] **Step 5: Wire ObjectBox repository to ProcessingRepository**

Make `ObjectBoxKnowledgeRepository` implement `ProcessingRepository`. `saveExtractedChunk` must create `DocumentChunkEntity` and `ChunkEmbeddingEntity` with the document public ID and embedding model.

- [ ] **Step 6: Run processing tests**

Run:

```bash
flutter test test/document_processing_service_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit document processing service**

Run:

```bash
git add lib/src/knowledge test/document_processing_service_test.dart
git commit -m "feat: process PDFs into local knowledge jobs"
```

Expected: commit succeeds.

---

### Task 9: Build Settings Screen

**Files:**
- Create: `lib/src/settings/ui/settings_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Test: `test/settings_screen_test.dart`

- [ ] **Step 1: Write failing settings screen test**

Create `test/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/settings/models/app_settings.dart';
import 'package:djinn/src/settings/ui/settings_screen.dart';

void main() {
  testWidgets('saves and deletes OpenAI API key', (tester) async {
    final keyStore = MemoryApiKeyStore();
    var settings = AppSettings.defaults();

    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        apiKeyStore: keyStore,
        loadSettings: () async => settings,
        saveSettings: (value) async => settings = value,
        testApiKey: () async => true,
      ),
    ));

    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('openai-api-key-field')), 'sk-test');
    await tester.tap(find.text('Mentés'));
    await tester.pumpAndSettle();

    expect(await keyStore.readKey(), 'sk-test');

    await tester.tap(find.text('Kulcs törlése'));
    await tester.pumpAndSettle();

    expect(await keyStore.hasKey(), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/settings_screen_test.dart
```

Expected: FAIL because `SettingsScreen` does not exist.

- [ ] **Step 3: Create settings UI**

Create `SettingsScreen` with:

- `TextField(key: Key('openai-api-key-field'), obscureText: true)`;
- buttons `Mentés`, `Kulcs tesztelése`, `Kulcs törlése`;
- switches for `OpenAI fájlok törlése feldolgozás után` and `Második groundedness check`;
- expansion tile `Haladó modellbeállítások` with editable answer, extraction, groundedness, embedding model fields;
- read-only mode section showing `B mód: Local ObjectBox` active and `A mód: Backend` unavailable.

- [ ] **Step 4: Add hamburger drawer entry**

Modify `MainScreen` to use a `Drawer` with entries:

```dart
ListTile(leading: const Icon(Icons.chat), title: const Text('Beszélgetések'))
ListTile(leading: const Icon(Icons.folder), title: const Text('Tudástár'))
ListTile(leading: const Icon(Icons.account_tree), title: const Text('Flowchart validáció'))
ListTile(leading: const Icon(Icons.settings), title: const Text('Beállítások'))
```

Settings entry pushes `SettingsScreen`.

- [ ] **Step 5: Run settings UI test**

Run:

```bash
flutter test test/settings_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit settings UI**

Run:

```bash
git add lib/src/settings/ui/settings_screen.dart lib/src/chat/ui/main_screen.dart test/settings_screen_test.dart
git commit -m "feat: add in-app OpenAI settings"
```

Expected: commit succeeds.

---

### Task 10: Convert Knowledge Base UI To Local Processing

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/knowledge/data/pdf_import_service.dart`
- Test: `test/knowledge_base_screen_test.dart`

- [ ] **Step 1: Rewrite widget tests for local processing language**

Update `test/knowledge_base_screen_test.dart` so it expects:

```dart
expect(find.text('Nincs importált PDF'), findsOneWidget);
expect(find.text('Feldolgozásra vár'), findsOneWidget);
expect(find.text('Helyi ObjectBox tudástár'), findsOneWidget);
```

Remove backend status tests that expect `Backend nem erheto el` or `AI backend nincs beallitva`. Replace them with a missing-key test that expects `OpenAI API kulcs szükséges`.

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart
```

Expected: FAIL because UI still shows backend readiness wording.

- [ ] **Step 3: Modify KnowledgeBaseScreen dependencies**

Replace `KnowledgeSyncService` dependency with `DocumentProcessingService`. After PDF import, add document to local repository and call `processDocument(document.id)`. Display local processing state from repository.

UI states:

```dart
'blocked_missing_api_key' -> 'OpenAI API kulcs szükséges'
'imported' -> 'Feldolgozásra vár'
'processing' -> 'Feldolgozás folyamatban'
'embedded' -> 'Embedding kész'
'ready' -> 'Kész'
'needs_review' -> 'Validáció szükséges'
'failed' -> 'Hiba'
```

- [ ] **Step 4: Add retry/reprocess action**

For `failed`, `blocked_missing_api_key`, and `blocked_offline`, show an icon button with tooltip `Újrapróbálás` that calls `processDocument(document.id)`.

- [ ] **Step 5: Run knowledge UI tests**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit local knowledge UI**

Run:

```bash
git add lib/src/knowledge test/knowledge_base_screen_test.dart
git commit -m "feat: show local knowledge processing state"
```

Expected: commit succeeds.

---

### Task 11: Render Answer Warnings And Local Citation Labels

**Files:**
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Test: `test/chat_bubble_test.dart`

- [ ] **Step 1: Write failing chat bubble test**

Create `test/chat_bubble_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/chat/models/chat_citation.dart';
import 'package:djinn/src/chat/models/chat_message.dart';
import 'package:djinn/src/chat/ui/chat_bubble.dart';

void main() {
  testWidgets('renders validation warning and citation label', (tester) async {
    final message = ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      sender: ChatSender.assistant,
      text: 'Válasz.',
      createdAt: DateTime.utc(2026),
      status: 'grounded',
      hasValidationWarning: true,
      warningText: 'A válasz nem validált flowchart elemet használ.',
      citations: const [
        ChatCitation(
          documentId: 'doc-1',
          title: 'omsz.pdf',
          page: 1,
          section: null,
          excerpt: 'Forrás',
          sourceId: 'node-1',
          sourceLabel: 'Nem validált flowchart',
          validationState: 'unreviewed',
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ChatBubble(message: message))));

    expect(find.textContaining('nem validált'), findsWidgets);
    expect(find.text('Nem validált flowchart'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/chat_bubble_test.dart
```

Expected: FAIL if `ChatBubble` does not render warning/citation labels yet.

- [ ] **Step 3: Modify ChatBubble rendering**

For assistant messages:

- if `message.hasValidationWarning`, render a compact amber banner above answer text;
- render citations below text as small rows/chips containing `sourceLabel`, title, and page;
- keep existing assistant/user alignment behavior.

- [ ] **Step 4: Run chat bubble test**

Run:

```bash
flutter test test/chat_bubble_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit warning UI**

Run:

```bash
git add lib/src/chat/ui lib/src/chat/models test/chat_bubble_test.dart
git commit -m "feat: render local citation warnings"
```

Expected: commit succeeds.

---

### Task 12: Add Flowchart Validation Simple Mode

**Files:**
- Create: `lib/src/flowchart/models/flowchart_view_model.dart`
- Create: `lib/src/flowchart/data/flowchart_validation_repository.dart`
- Create: `lib/src/flowchart/ui/flowchart_validation_screen.dart`
- Create: `lib/src/flowchart/ui/simple_flowchart_editor.dart`
- Test: `test/flowchart_validation_test.dart`

- [ ] **Step 1: Write failing validation repository test**

Create `test/flowchart_validation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/flowchart/data/flowchart_validation_repository.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  test('rejecting a node prevents it from being answerable', () async {
    final repository = MemoryFlowchartValidationRepository();
    repository.addNode('node-1', ValidationState.unreviewed);

    await repository.updateNodeValidation(
      nodePublicId: 'node-1',
      state: ValidationState.rejected,
      rejectionReason: 'Hibás OCR',
    );

    expect(await repository.isNodeAnswerable('node-1'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/flowchart_validation_test.dart
```

Expected: FAIL because flowchart validation files do not exist.

- [ ] **Step 3: Create validation repository**

Create `FlowchartValidationRepository` with methods:

```dart
Future<List<FlowchartEntity>> listFlowchartsNeedingReview();
Future<List<FlowchartNodeEntity>> listNodes(String flowchartPublicId);
Future<List<FlowchartEdgeEntity>> listEdges(String flowchartPublicId);
Future<void> updateNodeValidation({required String nodePublicId, required ValidationState state, String? rejectionReason});
Future<void> updateEdgeValidation({required String edgePublicId, required ValidationState state, String? rejectionReason});
Future<bool> isNodeAnswerable(String nodePublicId);
```

Add `MemoryFlowchartValidationRepository` in the test file for deterministic tests. Add ObjectBox implementation in the production repository file.

- [ ] **Step 4: Create simple editor UI**

Create `SimpleFlowchartEditor` that lists nodes and edges. Each node row has:

- editable text field;
- `Validálás` button;
- `Elutasítás` button;
- optional rejection reason field.

Each edge row has editable label, target node text, and the same validate/reject actions.

- [ ] **Step 5: Run flowchart tests**

Run:

```bash
flutter test test/flowchart_validation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit simple validation mode**

Run:

```bash
git add lib/src/flowchart test/flowchart_validation_test.dart
git commit -m "feat: add flowchart validation list mode"
```

Expected: commit succeeds.

---

### Task 13: Add Graphical Flowchart Editor

**Files:**
- Create: `lib/src/flowchart/ui/graph_flowchart_editor.dart`
- Test: `test/graph_flowchart_editor_test.dart`

- [ ] **Step 1: Write failing graph editor smoke test**

Create `test/graph_flowchart_editor_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/flowchart/models/flowchart_view_model.dart';
import 'package:djinn/src/flowchart/ui/graph_flowchart_editor.dart';
import 'package:djinn/src/local_store/entities.dart';

void main() {
  testWidgets('renders nodes and edge labels on canvas', (tester) async {
    final model = FlowchartViewModel(
      id: 'flow-1',
      nodes: const [
        FlowchartNodeViewModel(id: 'n1', label: 'Start', x: 20, y: 20, validationState: ValidationState.unreviewed),
        FlowchartNodeViewModel(id: 'n2', label: 'Döntés', x: 180, y: 20, validationState: ValidationState.unreviewed),
      ],
      edges: const [
        FlowchartEdgeViewModel(id: 'e1', fromNodeId: 'n1', toNodeId: 'n2', label: 'igen', validationState: ValidationState.unreviewed),
      ],
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: GraphFlowchartEditor(model: model))));

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Döntés'), findsOneWidget);
    expect(find.text('igen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
flutter test test/graph_flowchart_editor_test.dart
```

Expected: FAIL because graph editor files do not exist.

- [ ] **Step 3: Create view models**

Create `lib/src/flowchart/models/flowchart_view_model.dart` with immutable `FlowchartViewModel`, `FlowchartNodeViewModel`, and `FlowchartEdgeViewModel` classes matching the test constructor.

- [ ] **Step 4: Create graphical editor**

Create `GraphFlowchartEditor` with:

- `InteractiveViewer` for pan/zoom;
- `Stack` for positioned node cards;
- `CustomPaint` behind nodes for arrows;
- editable node labels using dialogs;
- action buttons for automatic layout and save.

The first automatic layout can be deterministic: place nodes in rows by index using 160 px horizontal spacing and 96 px vertical spacing.

- [ ] **Step 5: Run graph editor test**

Run:

```bash
flutter test test/graph_flowchart_editor_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit graph editor**

Run:

```bash
git add lib/src/flowchart test/graph_flowchart_editor_test.dart
git commit -m "feat: add graphical flowchart editor"
```

Expected: commit succeeds.

---

### Task 14: Wire B Mode Dependencies In App Startup

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write or update startup widget test**

Update `test/widget_test.dart` to assert the app opens without backend config and shows an actionable chat empty state:

```dart
expect(find.textContaining('Nincs még beszélgetés'), findsOneWidget);
expect(find.byTooltip('Új chat'), findsOneWidget);
```

- [ ] **Step 2: Run startup test to verify it fails**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL if the old text or backend dependency remains.

- [ ] **Step 3: Modify main dependency loading**

In `lib/main.dart`:

- remove default construction of `BackendChatClient`, `KnowledgeApiClient`, and `KnowledgeSyncService` for app runtime;
- open `ObjectBoxStore` under `getApplicationDocumentsDirectory()`;
- create `SecureApiKeyStore`, `AppSettingsRepository`, `OpenAiHttpClient`, `ObjectBoxKnowledgeRepository`, `ObjectBoxLocalRetriever`, `CitationVerifier`, `LocalAnswerService`, `ObjectBoxChatRepository`, `DocumentProcessingService`, and `PdfImportService`;
- pass these services into `MainScreen`.

Keep constructor injection for tests so widget tests can pass fakes without opening platform storage.

- [ ] **Step 4: Update MainScreen constructor**

Replace backend-era fields with local B mode dependencies:

```dart
final ObjectBoxChatRepository chatRepository;
final ChatService chatService;
final ObjectBoxKnowledgeRepository knowledgeRepository;
final PdfImportService pdfImportService;
final DocumentProcessingService processingService;
final ApiKeyStore apiKeyStore;
final AppSettingsRepository settingsRepository;
```

If tests still use `LocalChatRepository`, provide a small adapter or update tests to use memory repositories.

- [ ] **Step 5: Run startup test**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 6: Run full Flutter tests**

Run:

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 7: Commit app wiring**

Run:

```bash
git add lib/main.dart lib/src/chat/ui/main_screen.dart test/widget_test.dart
git commit -m "feat: wire app to local B mode runtime"
```

Expected: commit succeeds.

---

### Task 15: Update README And Run Android Build

**Files:**
- Modify: `README.md`
- Verify: `.github/workflows/android-native-build.yml`

- [ ] **Step 1: Update README**

Add a section named `Local APK B mode` containing these points:

```markdown
## Local APK B mode

Djinn runs the first usable AI mode inside the Android APK. The user enters an OpenAI API key in Settings. The app imports PDFs into app-private storage, processes them through OpenAI using the user's key, stores chunks, embeddings, flowchart structures, validation state, and chat history locally in ObjectBox, and answers only from retrieved local sources.

Termux, FastAPI, Qdrant, and PostgreSQL are not required for B mode. Backend mode is a separate future runtime path and does not act as an automatic fallback.
```

- [ ] **Step 2: Run README grep check**

Run:

```bash
rg -n "Local APK B mode|Termux, FastAPI, Qdrant, and PostgreSQL are not required" README.md
```

Expected: both phrases found.

- [ ] **Step 3: Run analyzer**

Run:

```bash
flutter analyze
```

Expected: exits 0.

- [ ] **Step 4: Run tests**

Run:

```bash
flutter test
```

Expected: exits 0.

- [ ] **Step 5: Build APK**

Run:

```bash
flutter build apk --debug
```

Expected: exits 0 and writes a debug APK under `build/app/outputs/flutter-apk/`.

- [ ] **Step 6: Commit docs and build fixes**

Run:

```bash
git add README.md lib test pubspec.yaml pubspec.lock objectbox-model.json
git commit -m "docs: document local APK B mode"
```

Expected: commit succeeds if there are changes.

- [ ] **Step 7: Push all commits**

Run:

```bash
git status --short
git push
```

Expected: status is clean before push, and push updates `main` on GitHub.

## Final Verification Checklist

Run these commands after Task 15:

```bash
flutter analyze
flutter test
flutter build apk --debug
git status --short
```

Expected final state:

- analyzer passes;
- tests pass;
- debug APK builds;
- `git status --short` prints nothing;
- GitHub `main` contains all local commits.

## Self-Review Notes

Spec coverage:

- Settings/API key: Tasks 3 and 9.
- ObjectBox local storage and vector search: Tasks 1, 2, and 6.
- PDF import and processing: Tasks 8 and 10.
- Chat, retrieval, citation verification, and hallucination protection: Tasks 5, 6, 7, and 11.
- Flowchart validation simple and graphical modes: Tasks 12 and 13.
- No Termux/backend runtime for B mode: Tasks 14 and 15.
- Tests and build verification: each task plus Task 15.

Plan consistency:

- `gpt-5.5` and `text-embedding-3-large` match the approved spec.
- ObjectBox vectors use 3072 dimensions to match `text-embedding-3-large` defaults.
- Runtime mode remains `local_objectbox`; backend mode is not wired as an automatic fallback.
