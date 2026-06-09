# Djinn Knowledge AI Voice Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved knowledge-base, AI provider/settings, Gemini hardening, PDF viewer, folder, chunk export/import, voice, and flowchart diagnostics upgrades.

**Architecture:** Keep the current local ObjectBox B-mode architecture. Add provider-neutral AI interfaces above the existing OpenAI client, add Gemini as a second adapter, keep settings and API keys provider-aware, and make knowledge workflows explicit/manual instead of auto-processing imports. UI work is split into small widgets so the Android-file-manager selection model can be tested without relying on full app navigation.

**Tech Stack:** Flutter/Dart, Material 3, ObjectBox, `http`, `flutter_secure_storage`, `file_picker`, `pdfrx` for in-app PDF viewing, `speech_to_text` for native STT, `flutter_tts` for native TTS, `flutter_test`.

**External package notes checked 2026-06-09:** `pdfrx` is MIT-licensed and supports Android PDF viewing via PDFium; `speech_to_text` exposes platform speech recognition and is intended for commands/short phrases rather than always-on dictation; `flutter_tts` supports Android TTS. Sources: https://pub.dev/packages/pdfrx, https://pub.dev/packages/speech_to_text, https://pub.dev/packages/flutter_tts.

---

## File Structure Map

Create:

- `lib/src/ai/ai_provider.dart` - provider and capability enums plus model selection helpers.
- `lib/src/ai/ai_client.dart` - provider-neutral AI client contract and shared result types.
- `lib/src/ai/ai_error.dart` - structured provider failure classification.
- `lib/src/ai/ai_client_resolver.dart` - selects provider client and key store from settings.
- `lib/src/google/gemini_http_client.dart` - Gemini HTTP implementation.
- `lib/src/settings/models/model_catalog.dart` - static dropdown model options.
- `lib/src/knowledge/models/knowledge_folder.dart` - UI/domain folder model.
- `lib/src/knowledge/data/chunk_package_service.dart` - chunk export/import.
- `lib/src/knowledge/models/chunk_package.dart` - JSON schema model for chunk packages.
- `lib/src/knowledge/ui/knowledge_document_row.dart` - compact PDF row.
- `lib/src/knowledge/ui/knowledge_header.dart` - normal/selection headers and overlay menus.
- `lib/src/knowledge/ui/pdf_viewer_screen.dart` - in-app PDF viewer.
- `lib/src/voice/speech_adapter.dart` - interface plus plugin adapter for STT.
- `lib/src/voice/tts_adapter.dart` - interface plus plugin adapter for TTS.
- `lib/src/voice/voice_controller.dart` - tested voice state machine.
- `lib/src/voice/voice_controls.dart` - chat composer voice controls.
- `lib/src/offline/offline_search_service.dart` - non-LLM source excerpt search.
- Tests mirroring the above in `test/*_test.dart`.

Modify:

- `pubspec.yaml` - add PDF/STT/TTS packages.
- `lib/src/local_store/entities.dart` - add folder/hash/provider/error fields and `KnowledgeFolderEntity`.
- `lib/src/settings/models/app_settings.dart` - provider-aware model selections.
- `lib/src/settings/data/api_key_store.dart` - provider-specific secure keys.
- `lib/src/settings/data/app_settings_repository.dart` - ObjectBox persistence for new settings fields.
- `lib/src/settings/ui/settings_screen.dart` - AI/Speech/Mode/Validation block redesign.
- `lib/src/openai/openai_client.dart` and `lib/src/openai/openai_http_client.dart` - implement provider-neutral contract or adapter methods.
- `lib/src/knowledge/data/document_processing_service.dart` - provider-aware training with structured errors.
- `lib/src/knowledge/data/objectbox_knowledge_repository.dart` - folders, hash, chunk package support.
- `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart` - map new model/entity fields.
- `lib/src/knowledge/ui/knowledge_base_screen.dart` - file-manager UI and manual sync.
- `lib/src/chat/data/local_answer_service.dart` - provider-aware answer/embedding key checks.
- `lib/src/chat/ui/message_composer.dart` and `lib/src/chat/ui/chat_screen.dart` - voice controls.
- `lib/src/flowchart/data/flowchart_validation_repository.dart` and `lib/src/flowchart/ui/flowchart_validation_screen.dart` - zero-state diagnostics.
- `lib/main.dart` - dependency wiring.
- `lib/objectbox-model.json` and `lib/objectbox.g.dart` - regenerate after entity changes.

Run ObjectBox code generation after entity changes:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Do not run local APK builds in Termux. APK build is GitHub Actions only.

---

### Task 1: Provider-Aware Settings Domain And Key Stores

**Files:**
- Create: `lib/src/ai/ai_provider.dart`
- Create: `lib/src/settings/models/model_catalog.dart`
- Modify: `lib/src/settings/models/app_settings.dart`
- Modify: `lib/src/settings/data/api_key_store.dart`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `lib/src/local_store/entities.dart`
- Test: `test/settings_repository_test.dart`

- [ ] **Step 1: Write failing domain tests**

Add these tests to `test/settings_repository_test.dart`:

```dart
import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/settings/models/model_catalog.dart';

test('default settings use OpenAI provider with per-provider model selections', () {
  final settings = AppSettings.defaults();

  expect(settings.activeProvider, AiProvider.openAi);
  expect(settings.modelFor(AiProvider.openAi, AiModelSlot.answer), 'gpt-5.5');
  expect(settings.modelFor(AiProvider.openAi, AiModelSlot.extraction), 'gpt-5.5');
  expect(
    settings.modelFor(AiProvider.openAi, AiModelSlot.embedding),
    'text-embedding-3-large',
  );
  expect(
    settings.modelFor(AiProvider.gemini, AiModelSlot.extraction),
    'gemini-2.5-flash-lite',
  );
  expect(ModelCatalog.options(AiProvider.openAi, AiModelSlot.answer), isNotEmpty);
  expect(ModelCatalog.options(AiProvider.gemini, AiModelSlot.extraction), isNotEmpty);
});

test('memory API key store keeps OpenAI and Gemini keys separate', () async {
  final store = MemoryApiKeyStore();

  await store.saveKeyForProvider(AiProvider.openAi, 'sk-openai');
  await store.saveKeyForProvider(AiProvider.gemini, 'AIza-gemini');

  expect(await store.readKeyForProvider(AiProvider.openAi), 'sk-openai');
  expect(await store.readKeyForProvider(AiProvider.gemini), 'AIza-gemini');
  expect(await store.hasKeyForProvider(AiProvider.openAi), isTrue);
  expect(await store.hasKeyForProvider(AiProvider.gemini), isTrue);

  await store.deleteKeyForProvider(AiProvider.openAi);
  expect(await store.hasKeyForProvider(AiProvider.openAi), isFalse);
  expect(await store.readKeyForProvider(AiProvider.gemini), 'AIza-gemini');
});
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/settings_repository_test.dart
```

Expected: FAIL because `AiProvider`, `AiModelSlot`, model catalog, and provider-specific key methods do not exist.

- [ ] **Step 3: Add provider enums and model catalog**

Create `lib/src/ai/ai_provider.dart`:

```dart
enum AiProvider {
  openAi('openai', 'OpenAI'),
  gemini('gemini', 'Gemini');

  const AiProvider(this.wireName, this.label);

  final String wireName;
  final String label;

  static AiProvider fromWireName(String? value) {
    return AiProvider.values.firstWhere(
      (provider) => provider.wireName == value,
      orElse: () => AiProvider.openAi,
    );
  }
}

enum AiModelSlot {
  answer('answer'),
  extraction('extraction'),
  groundedness('groundedness'),
  embedding('embedding');

  const AiModelSlot(this.wireName);

  final String wireName;
}
```

Create `lib/src/settings/models/model_catalog.dart`:

```dart
import '../../ai/ai_provider.dart';

class ModelCatalog {
  const ModelCatalog._();

  static const openAiAnswerModels = ['gpt-5.5', 'gpt-5-mini', 'gpt-4.1'];
  static const openAiEmbeddingModels = [
    'text-embedding-3-large',
    'text-embedding-3-small',
  ];
  static const geminiTextModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const geminiEmbeddingModels = ['gemini-embedding-001'];

  static List<String> options(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.embedding) => openAiEmbeddingModels,
      (AiProvider.openAi, _) => openAiAnswerModels,
      (AiProvider.gemini, AiModelSlot.embedding) => geminiEmbeddingModels,
      (AiProvider.gemini, _) => geminiTextModels,
    };
  }
}
```

- [ ] **Step 4: Extend `AppSettings`**

Modify `lib/src/settings/models/app_settings.dart` so it imports `AiProvider` and stores provider-specific model IDs:

```dart
import '../../ai/ai_provider.dart';

class AppSettings {
  const AppSettings({
    required this.runtimeMode,
    required this.activeProvider,
    required this.openAiAnswerModel,
    required this.openAiExtractionModel,
    required this.openAiGroundednessModel,
    required this.openAiEmbeddingModel,
    required this.geminiAnswerModel,
    required this.geminiExtractionModel,
    required this.geminiGroundednessModel,
    required this.geminiEmbeddingModel,
    required this.deleteOpenAiFilesAfterProcessing,
    required this.groundednessCheckEnabled,
    required this.retrievalLimit,
    required this.minimumSimilarity,
    required this.voiceMode,
    required this.voiceLocale,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      runtimeMode: 'local_objectbox',
      activeProvider: AiProvider.openAi,
      openAiAnswerModel: 'gpt-5.5',
      openAiExtractionModel: 'gpt-5.5',
      openAiGroundednessModel: 'gpt-5.5',
      openAiEmbeddingModel: 'text-embedding-3-large',
      geminiAnswerModel: 'gemini-2.5-flash-lite',
      geminiExtractionModel: 'gemini-2.5-flash-lite',
      geminiGroundednessModel: 'gemini-2.5-flash-lite',
      geminiEmbeddingModel: 'gemini-embedding-001',
      deleteOpenAiFilesAfterProcessing: true,
      groundednessCheckEnabled: false,
      retrievalLimit: 8,
      minimumSimilarity: 0.72,
      voiceMode: 'push_to_talk',
      voiceLocale: 'hu-HU',
    );
  }

  final String runtimeMode;
  final AiProvider activeProvider;
  final String openAiAnswerModel;
  final String openAiExtractionModel;
  final String openAiGroundednessModel;
  final String openAiEmbeddingModel;
  final String geminiAnswerModel;
  final String geminiExtractionModel;
  final String geminiGroundednessModel;
  final String geminiEmbeddingModel;
  final bool deleteOpenAiFilesAfterProcessing;
  final bool groundednessCheckEnabled;
  final int retrievalLimit;
  final double minimumSimilarity;
  final String voiceMode;
  final String voiceLocale;

  String get answerModel => modelFor(activeProvider, AiModelSlot.answer);
  String get extractionModel => modelFor(activeProvider, AiModelSlot.extraction);
  String get groundednessModel =>
      modelFor(activeProvider, AiModelSlot.groundedness);
  String get embeddingModel => modelFor(activeProvider, AiModelSlot.embedding);

  String modelFor(AiProvider provider, AiModelSlot slot) {
    return switch ((provider, slot)) {
      (AiProvider.openAi, AiModelSlot.answer) => openAiAnswerModel,
      (AiProvider.openAi, AiModelSlot.extraction) => openAiExtractionModel,
      (AiProvider.openAi, AiModelSlot.groundedness) =>
        openAiGroundednessModel,
      (AiProvider.openAi, AiModelSlot.embedding) => openAiEmbeddingModel,
      (AiProvider.gemini, AiModelSlot.answer) => geminiAnswerModel,
      (AiProvider.gemini, AiModelSlot.extraction) => geminiExtractionModel,
      (AiProvider.gemini, AiModelSlot.groundedness) =>
        geminiGroundednessModel,
      (AiProvider.gemini, AiModelSlot.embedding) => geminiEmbeddingModel,
    };
  }

  AppSettings copyWith({
    String? runtimeMode,
    AiProvider? activeProvider,
    String? openAiAnswerModel,
    String? openAiExtractionModel,
    String? openAiGroundednessModel,
    String? openAiEmbeddingModel,
    String? geminiAnswerModel,
    String? geminiExtractionModel,
    String? geminiGroundednessModel,
    String? geminiEmbeddingModel,
    bool? deleteOpenAiFilesAfterProcessing,
    bool? groundednessCheckEnabled,
    int? retrievalLimit,
    double? minimumSimilarity,
    String? voiceMode,
    String? voiceLocale,
  }) {
    return AppSettings(
      runtimeMode: runtimeMode ?? this.runtimeMode,
      activeProvider: activeProvider ?? this.activeProvider,
      openAiAnswerModel: openAiAnswerModel ?? this.openAiAnswerModel,
      openAiExtractionModel:
          openAiExtractionModel ?? this.openAiExtractionModel,
      openAiGroundednessModel:
          openAiGroundednessModel ?? this.openAiGroundednessModel,
      openAiEmbeddingModel: openAiEmbeddingModel ?? this.openAiEmbeddingModel,
      geminiAnswerModel: geminiAnswerModel ?? this.geminiAnswerModel,
      geminiExtractionModel:
          geminiExtractionModel ?? this.geminiExtractionModel,
      geminiGroundednessModel:
          geminiGroundednessModel ?? this.geminiGroundednessModel,
      geminiEmbeddingModel:
          geminiEmbeddingModel ?? this.geminiEmbeddingModel,
      deleteOpenAiFilesAfterProcessing:
          deleteOpenAiFilesAfterProcessing ??
          this.deleteOpenAiFilesAfterProcessing,
      groundednessCheckEnabled:
          groundednessCheckEnabled ?? this.groundednessCheckEnabled,
      retrievalLimit: retrievalLimit ?? this.retrievalLimit,
      minimumSimilarity: minimumSimilarity ?? this.minimumSimilarity,
      voiceMode: voiceMode ?? this.voiceMode,
      voiceLocale: voiceLocale ?? this.voiceLocale,
    );
  }
}
```

- [ ] **Step 5: Add provider-aware key storage**

Modify `lib/src/settings/data/api_key_store.dart`:

```dart
import '../../ai/ai_provider.dart';

abstract class ApiKeyStore {
  Future<bool> hasKey();
  Future<String?> readKey();
  Future<void> saveKey(String value);
  Future<void> deleteKey();

  Future<bool> hasKeyForProvider(AiProvider provider) async {
    final value = await readKeyForProvider(provider);
    return value != null && value.trim().isNotEmpty;
  }

  Future<String?> readKeyForProvider(AiProvider provider);
  Future<void> saveKeyForProvider(AiProvider provider, String value);
  Future<void> deleteKeyForProvider(AiProvider provider);
}
```

For backward compatibility, implement the old OpenAI methods as wrappers in both stores:

```dart
static String keyNameForProvider(AiProvider provider) {
  return switch (provider) {
    AiProvider.openAi => 'openai_api_key',
    AiProvider.gemini => 'gemini_api_key',
  };
}

@override
Future<bool> hasKey() => hasKeyForProvider(AiProvider.openAi);

@override
Future<String?> readKey() => readKeyForProvider(AiProvider.openAi);

@override
Future<void> saveKey(String value) =>
    saveKeyForProvider(AiProvider.openAi, value);

@override
Future<void> deleteKey() => deleteKeyForProvider(AiProvider.openAi);
```

In `MemoryApiKeyStore`, store values in a map:

```dart
final Map<AiProvider, String> _values = {};

@override
Future<String?> readKeyForProvider(AiProvider provider) async =>
    _values[provider];

@override
Future<void> saveKeyForProvider(AiProvider provider, String value) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('${provider.label} API key must not be blank');
  }
  _values[provider] = trimmed;
}

@override
Future<void> deleteKeyForProvider(AiProvider provider) async {
  _values.remove(provider);
}
```

- [ ] **Step 6: Persist new settings fields in ObjectBox**

Add fields to `AppSettingsEntity` in `lib/src/local_store/entities.dart`:

```dart
String activeProvider;
String openAiAnswerModel;
String openAiExtractionModel;
String openAiGroundednessModel;
String openAiEmbeddingModel;
String geminiAnswerModel;
String geminiExtractionModel;
String geminiGroundednessModel;
String geminiEmbeddingModel;
String voiceMode;
String voiceLocale;
```

Keep the old `answerModel`, `extractionModel`, `groundednessModel`, and
`embeddingModel` fields during the first migration if ObjectBox requires them
for compatibility. Map them to OpenAI values until a later cleanup.

Update `AppSettingsRepository._fromEntity` and `_toEntity` so missing/empty new
fields fall back to `AppSettings.defaults()`.

- [ ] **Step 7: Regenerate ObjectBox and run tests**

Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter test test/settings_repository_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/ai/ai_provider.dart lib/src/settings/models/model_catalog.dart lib/src/settings/models/app_settings.dart lib/src/settings/data/api_key_store.dart lib/src/settings/data/app_settings_repository.dart lib/src/local_store/entities.dart lib/objectbox-model.json lib/objectbox.g.dart test/settings_repository_test.dart
git commit -m "feat: add provider-aware settings domain"
```

---

### Task 2: Provider Error Model, AI Client Contract, And Gemini Client

**Files:**
- Create: `lib/src/ai/ai_error.dart`
- Create: `lib/src/ai/ai_client.dart`
- Create: `lib/src/google/gemini_http_client.dart`
- Modify: `lib/src/openai/openai_client.dart`
- Modify: `lib/src/openai/openai_http_client.dart`
- Test: `test/provider_error_test.dart`
- Test: `test/gemini_http_client_test.dart`
- Test: `test/openai_http_client_test.dart`

- [ ] **Step 1: Write failing provider error tests**

Create `test/provider_error_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/ai/ai_provider.dart';

void main() {
  test('classifies Gemini quota, high demand, network abort, and invalid schema', () {
    expect(
      AiFailure.quota(AiProvider.gemini, 'prepayment credits are depleted')
          .code,
      AiFailureCode.quotaOrBilling,
    );
    expect(
      AiFailure.highDemand(AiProvider.gemini, '503 high demand').retryable,
      isTrue,
    );
    expect(
      AiFailure.networkAbort(AiProvider.gemini, 'Software caused connection abort')
          .retryable,
      isTrue,
    );
    expect(
      AiFailure.invalidStructuredResponse(
        AiProvider.gemini,
        'chunks must be a list',
      ).userMessage,
      contains('Gemini hibas strukturalt valaszt adott'),
    );
  });
}
```

- [ ] **Step 2: Write failing Gemini HTTP tests**

Create `test/gemini_http_client_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:djinn/src/ai/ai_error.dart';
import 'package:djinn/src/google/gemini_http_client.dart';
import 'package:djinn/src/settings/data/api_key_store.dart';
import 'package:djinn/src/ai/ai_provider.dart';

void main() {
  test('sends Gemini extraction with JSON mime type and schema', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'AIza-test');
    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((request) async {
        expect(request.url.toString(), contains(':generateContent'));
        expect(request.url.query, contains('key=AIza-test'));
        final body = request.body;
        expect(body, contains('"responseMimeType":"application/json"'));
        expect(body, contains('"responseSchema"'));
        return http.Response(
          '{"candidates":[{"content":{"parts":[{"text":"{\\"chunks\\":[{\\"id\\":\\"p1-main\\",\\"text\\":\\"abc\\",\\"page_number\\":1,\\"section_title\\":null}]}"}]}}]}',
          200,
        );
      }),
      baseUri: Uri.parse('https://generativelanguage.googleapis.test'),
    );

    final file = File('${Directory.systemTemp.path}/gemini-test.pdf');
    await file.writeAsBytes([37, 80, 68, 70]);
    final result = await client.extractDocument(
      pdfPath: file.path,
      model: 'gemini-2.5-flash-lite',
    );

    expect(result.chunks.single.id, 'p1-main');
  });

  test('maps Gemini 503 to retryable high demand failure', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'AIza-test');
    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((_) async => http.Response(
        '{"error":{"message":"This model is currently experiencing high demand."}}',
        503,
      )),
      baseUri: Uri.parse('https://generativelanguage.googleapis.test'),
    );

    expect(
      () => client.createEmbedding(input: 'abc', model: 'gemini-embedding-001'),
      throwsA(
        isA<AiProviderException>().having(
          (error) => error.failure.code,
          'code',
          AiFailureCode.highDemand,
        ),
      ),
    );
  });

  test('maps invalid Gemini structured response to validation failure', () async {
    final keyStore = MemoryApiKeyStore();
    await keyStore.saveKeyForProvider(AiProvider.gemini, 'AIza-test');
    final client = GeminiHttpClient(
      apiKeyStore: keyStore,
      httpClient: MockClient((_) async => http.Response(
        '{"candidates":[{"content":{"parts":[{"text":"{\\"not_chunks\\":[]}"}]}}]}',
        200,
      )),
      baseUri: Uri.parse('https://generativelanguage.googleapis.test'),
    );

    expect(
      () => client.extractDocument(
        pdfPath: '${Directory.systemTemp.path}/missing.pdf',
        model: 'gemini-2.5-flash-lite',
      ),
      throwsA(
        isA<AiProviderException>().having(
          (error) => error.failure.code,
          'code',
          AiFailureCode.invalidStructuredResponse,
        ),
      ),
    );
  });
}
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
flutter test test/provider_error_test.dart test/gemini_http_client_test.dart
```

Expected: FAIL because AI error/client/Gemini files do not exist.

- [ ] **Step 4: Add structured provider failure model**

Create `lib/src/ai/ai_error.dart`:

```dart
import 'ai_provider.dart';

enum AiFailureCode {
  missingApiKey,
  keyTestFailed,
  quotaOrBilling,
  highDemand,
  networkAbort,
  invalidJson,
  invalidStructuredResponse,
  unsupportedEmbedding,
  unknown,
}

class AiFailure {
  const AiFailure({
    required this.provider,
    required this.code,
    required this.message,
    required this.userMessage,
    required this.retryable,
  });

  final AiProvider provider;
  final AiFailureCode code;
  final String message;
  final String userMessage;
  final bool retryable;

  factory AiFailure.missingApiKey(AiProvider provider) => AiFailure(
    provider: provider,
    code: AiFailureCode.missingApiKey,
    message: '${provider.label} API key is missing',
    userMessage: '${provider.label} API kulcs nincs beállítva.',
    retryable: false,
  );

  factory AiFailure.quota(AiProvider provider, String message) => AiFailure(
    provider: provider,
    code: AiFailureCode.quotaOrBilling,
    message: message,
    userMessage: '${provider.label} kvóta vagy billing hiba.',
    retryable: false,
  );

  factory AiFailure.highDemand(AiProvider provider, String message) => AiFailure(
    provider: provider,
    code: AiFailureCode.highDemand,
    message: message,
    userMessage: '${provider.label} modell túlterhelt. Próbáld újra később.',
    retryable: true,
  );

  factory AiFailure.networkAbort(AiProvider provider, String message) =>
      AiFailure(
        provider: provider,
        code: AiFailureCode.networkAbort,
        message: message,
        userMessage: 'Hálózati kapcsolat megszakadt. Újrapróbálható.',
        retryable: true,
      );

  factory AiFailure.invalidJson(AiProvider provider, String message) =>
      AiFailure(
        provider: provider,
        code: AiFailureCode.invalidJson,
        message: message,
        userMessage: '${provider.label} hibás JSON választ adott.',
        retryable: true,
      );

  factory AiFailure.invalidStructuredResponse(
    AiProvider provider,
    String message,
  ) => AiFailure(
    provider: provider,
    code: AiFailureCode.invalidStructuredResponse,
    message: message,
    userMessage: '${provider.label} hibas strukturalt valaszt adott.',
    retryable: true,
  );
}

class AiProviderException implements Exception {
  const AiProviderException(this.failure);

  final AiFailure failure;

  @override
  String toString() => '${failure.provider.label}: ${failure.message}';
}
```

- [ ] **Step 5: Add provider-neutral AI client contract**

Create `lib/src/ai/ai_client.dart` by reusing current OpenAI result shapes:

```dart
import '../openai/openai_client.dart';

typedef AiEvidence = OpenAiEvidence;
typedef AiAnswer = OpenAiAnswer;
typedef AiExtractedChunk = OpenAiExtractedChunk;
typedef AiExtractionResult = OpenAiExtractionResult;

abstract class AiClient {
  Future<void> testApiKey({required String apiKey});

  Future<List<double>> createEmbedding({
    required String input,
    required String model,
  });

  Future<AiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  });

  Future<AiAnswer> generateAnswer({
    required String model,
    required String question,
    required List<AiEvidence> evidence,
  });

  Future<bool> verifyGroundedness({
    required String model,
    required String answer,
    required List<AiEvidence> evidence,
  });
}
```

Make `OpenAiClient implements AiClient` or update the abstract class to extend
`AiClient`.

- [ ] **Step 6: Implement Gemini HTTP client**

Create `lib/src/google/gemini_http_client.dart` with these core pieces:

```dart
class GeminiHttpClient implements AiClient {
  GeminiHttpClient({
    required ApiKeyStore apiKeyStore,
    http.Client? httpClient,
    Uri? baseUri,
  }) : _apiKeyStore = apiKeyStore,
       _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri ?? Uri.parse('https://generativelanguage.googleapis.com');

  final ApiKeyStore _apiKeyStore;
  final http.Client _httpClient;
  final Uri _baseUri;

  Future<Map<String, Object?>> _generateContent({
    required String model,
    required Map<String, Object?> body,
  }) async {
    final key = await _apiKeyStore.readKeyForProvider(AiProvider.gemini);
    if (key == null || key.trim().isEmpty) {
      throw AiProviderException(AiFailure.missingApiKey(AiProvider.gemini));
    }
    try {
      final response = await _httpClient.post(
        _baseUri.resolve('/v1beta/models/$model:generateContent?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AiProviderException(_mapGeminiStatus(response.statusCode, response.body));
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
      throw AiProviderException(
        AiFailure.invalidStructuredResponse(AiProvider.gemini, 'top-level response is not an object'),
      );
    } on SocketException catch (error) {
      throw AiProviderException(AiFailure.networkAbort(AiProvider.gemini, error.message));
    } on http.ClientException catch (error) {
      final message = error.message;
      if (message.contains('Software caused connection abort')) {
        throw AiProviderException(AiFailure.networkAbort(AiProvider.gemini, message));
      }
      throw AiProviderException(AiFailure.networkAbort(AiProvider.gemini, message));
    } on FormatException catch (error) {
      throw AiProviderException(AiFailure.invalidJson(AiProvider.gemini, error.message));
    }
  }
}
```

Use Gemini generation config in extraction:

```dart
'generationConfig': {
  'responseMimeType': 'application/json',
  'responseSchema': _documentExtractionSchema,
},
```

Validate decoded extraction:

```dart
AiExtractionResult _parseExtraction(Map<String, Object?> json) {
  final chunks = json['chunks'];
  if (chunks is! List) {
    throw AiProviderException(
      AiFailure.invalidStructuredResponse(AiProvider.gemini, 'chunks must be a list'),
    );
  }
  return AiExtractionResult(
    chunks: chunks.map((item) {
      if (item is! Map) {
        throw AiProviderException(
          AiFailure.invalidStructuredResponse(AiProvider.gemini, 'chunk must be an object'),
        );
      }
      final id = item['id'];
      final text = item['text'];
      final pageNumber = item['page_number'];
      if (id is! String || text is! String || pageNumber is! num) {
        throw AiProviderException(
          AiFailure.invalidStructuredResponse(AiProvider.gemini, 'chunk id/text/page_number invalid'),
        );
      }
      return AiExtractedChunk(
        id: id,
        text: text,
        pageNumber: pageNumber.toInt(),
        sectionTitle: item['section_title'] as String?,
      );
    }).toList(growable: false),
  );
}
```

- [ ] **Step 7: Run AI client tests**

Run:

```bash
flutter test test/provider_error_test.dart test/gemini_http_client_test.dart test/openai_http_client_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/ai lib/src/google lib/src/openai test/provider_error_test.dart test/gemini_http_client_test.dart test/openai_http_client_test.dart
git commit -m "feat: add gemini provider client"
```

---

### Task 3: Provider-Aware Processing And Chat

**Files:**
- Create: `lib/src/ai/ai_client_resolver.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/main.dart`
- Test: `test/document_processing_service_test.dart`
- Test: `test/local_answer_service_test.dart`

- [ ] **Step 1: Write failing processing tests**

Add to `test/document_processing_service_test.dart`:

```dart
import 'package:djinn/src/ai/ai_provider.dart';
import 'package:djinn/src/ai/ai_error.dart';

test('Gemini active provider requires Gemini key, not OpenAI key', () async {
  final repository = MemoryProcessingRepository();
  final service = DocumentProcessingService(
    clientForProvider: (_) => _ExtractingOpenAiClient(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    ),
    hasApiKeyForProvider: (provider) async => provider == AiProvider.gemini,
    repository: repository,
  );

  final result = await service.processDocument('doc-1');

  expect(result.state, 'ready');
  expect(DebugConsole.allText, contains('provider=gemini'));
  expect(DebugConsole.allText, isNot(contains('blocked missing_api_key')));
});

test('provider missing key log includes provider name', () async {
  final repository = MemoryProcessingRepository();
  final service = DocumentProcessingService(
    clientForProvider: (_) => FakeOpenAiClient(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    ),
    hasApiKeyForProvider: (_) async => false,
    repository: repository,
  );

  final result = await service.processDocument('doc-1');

  expect(result.state, 'blocked_missing_api_key');
  expect(
    DebugConsole.allText,
    contains('[AI Training] blocked missing_api_key provider=gemini document=doc-1'),
  );
});

test('transient provider failure remains retryable in processing result', () async {
  final repository = MemoryProcessingRepository();
  final service = DocumentProcessingService(
    clientForProvider: (_) => _NetworkAbortClient(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    ),
    hasApiKeyForProvider: (_) async => true,
    repository: repository,
  );

  final result = await service.processDocument('doc-1');

  expect(result.state, 'failed');
  expect(result.retryable, isTrue);
  expect(result.errorCode, 'networkAbort');
  expect(DebugConsole.allText, contains('retryable=true'));
});

class _NetworkAbortClient extends FakeOpenAiClient {
  @override
  Future<OpenAiExtractionResult> extractDocument({
    required String pdfPath,
    required String model,
  }) async {
    throw AiProviderException(
      AiFailure.networkAbort(AiProvider.gemini, 'Software caused connection abort'),
    );
  }
}
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/document_processing_service_test.dart
```

Expected: FAIL because `DocumentProcessingService` does not accept provider-aware dependencies and `ProcessingResult` has no retry/error code.

- [ ] **Step 3: Add resolver and update service signature**

Create `lib/src/ai/ai_client_resolver.dart`:

```dart
import 'ai_client.dart';
import 'ai_provider.dart';

typedef AiClientForProvider = AiClient Function(AiProvider provider);
typedef HasApiKeyForProvider = Future<bool> Function(AiProvider provider);
```

Change `ProcessingResult` in `document_processing_service.dart`:

```dart
class ProcessingResult {
  const ProcessingResult({
    required this.state,
    this.errorMessage,
    this.errorCode,
    this.retryable = false,
  });

  final String state;
  final String? errorMessage;
  final String? errorCode;
  final bool retryable;
}
```

Update constructor:

```dart
const DocumentProcessingService({
  AiClient? openAiClient,
  AiClientForProvider? clientForProvider,
  required this.loadSettings,
  Future<bool> Function()? hasApiKey,
  HasApiKeyForProvider? hasApiKeyForProvider,
  required this.repository,
}) : _legacyOpenAiClient = openAiClient,
     _clientForProvider = clientForProvider,
     _legacyHasApiKey = hasApiKey,
     _hasApiKeyForProvider = hasApiKeyForProvider;

final AiClient? _legacyOpenAiClient;
final AiClientForProvider? _clientForProvider;
final Future<bool> Function()? _legacyHasApiKey;
final HasApiKeyForProvider? _hasApiKeyForProvider;
```

Add helpers:

```dart
AiClient _client(AppSettings settings) {
  final resolver = _clientForProvider;
  if (resolver != null) {
    return resolver(settings.activeProvider);
  }
  return _legacyOpenAiClient!;
}

Future<bool> _hasKey(AppSettings settings) {
  final checker = _hasApiKeyForProvider;
  if (checker != null) {
    return checker(settings.activeProvider);
  }
  return _legacyHasApiKey!();
}
```

Update `processDocument` to load settings before key check and include provider/model/attempt in logs:

```dart
final settings = await loadSettings();
final provider = settings.activeProvider;
if (!await _hasKey(settings)) {
  DebugConsole.log(
    '[AI Training] blocked missing_api_key provider=${provider.wireName} document=$documentPublicId',
  );
  await repository.markState(documentPublicId, ProcessingState.blockedMissingApiKey);
  return ProcessingResult(state: ProcessingState.blockedMissingApiKey.wireName);
}
```

Catch `AiProviderException` separately:

```dart
} on AiProviderException catch (error) {
  final failure = error.failure;
  DebugConsole.log(
    '[AI Training] failed provider=${failure.provider.wireName} document=$documentPublicId error=${failure.message} code=${failure.code.name} retryable=${failure.retryable}',
  );
  await repository.markState(
    documentPublicId,
    ProcessingState.failed,
    errorMessage: failure.userMessage,
  );
  return ProcessingResult(
    state: ProcessingState.failed.wireName,
    errorMessage: failure.userMessage,
    errorCode: failure.code.name,
    retryable: failure.retryable,
  );
}
```

- [ ] **Step 4: Update `LocalAnswerService` provider checks**

Add this test to `test/local_answer_service_test.dart`:

```dart
import 'package:djinn/src/ai/ai_client.dart';
import 'package:djinn/src/ai/ai_provider.dart';

test('uses Gemini key and client when Gemini is active', () async {
  final usedProviders = <AiProvider>[];
  final service = LocalAnswerService(
    clientForProvider: (provider) {
      usedProviders.add(provider);
      return FakeOpenAiClient(answerText: 'Gemini válasz.');
    },
    retriever: MemoryLocalRetriever(const [
      SourceEvidence(
        id: 'chunk-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Forrás szöveg',
        label: '1. oldal',
        validationState: ValidationState.validated,
        score: 0.95,
      ),
    ]),
    citationVerifier: CitationVerifier(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    ),
    hasApiKeyForProvider: (provider) async => provider == AiProvider.gemini,
    hasReadyDocuments: () async => true,
  );

  final result = await service.answer('Mi a teendő?');

  expect(result.status, 'grounded');
  expect(usedProviders, contains(AiProvider.gemini));
  expect(DebugConsole.allText, contains('[Chat/RAG] query embedding model=gemini-embedding-001'));
});

test('missing provider key log includes provider name in chat', () async {
  final service = LocalAnswerService(
    clientForProvider: (_) => FakeOpenAiClient(),
    retriever: MemoryLocalRetriever(const []),
    citationVerifier: CitationVerifier(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      activeProvider: AiProvider.gemini,
    ),
    hasApiKeyForProvider: (_) async => false,
    hasReadyDocuments: () async => true,
  );

  final result = await service.answer('Mi a teendő?');

  expect(result.status, 'missing_api_key');
  expect(result.text, 'Gemini API kulcs nincs beállítva.');
  expect(
    DebugConsole.allText,
    contains('[Chat/RAG] refused reason=missing_api_key provider=gemini'),
  );
});
```

Then update constructor with compatible optional dependencies:

```dart
LocalAnswerService({
  AiClient? openAiClient,
  AiClientForProvider? clientForProvider,
  required this.retriever,
  required this.citationVerifier,
  required this.loadSettings,
  ReadinessCheck? hasApiKey,
  HasApiKeyForProvider? hasApiKeyForProvider,
  required this.hasReadyDocuments,
}) : _legacyOpenAiClient = openAiClient,
     _clientForProvider = clientForProvider,
     _legacyHasApiKey = hasApiKey,
     _hasApiKeyForProvider = hasApiKeyForProvider;
```

Use `settings.activeProvider` for key checks, embeddings, answers, and groundedness logs:

```dart
final settings = await loadSettings();
final provider = settings.activeProvider;
if (!await _hasKey(settings)) {
  DebugConsole.log('[Chat/RAG] refused reason=missing_api_key provider=${provider.wireName}');
  return LocalAnswerResult(
    text: '${provider.label} API kulcs nincs beállítva.',
    status: 'missing_api_key',
    refusalReason: 'missing_api_key',
    citations: const [],
  );
}
final client = _client(settings);
```

- [ ] **Step 5: Wire providers in `main.dart`**

Instantiate both clients and provider key checker:

```dart
final openAiClient = OpenAiHttpClient(apiKeyStore: apiKeyStore);
final geminiClient = GeminiHttpClient(apiKeyStore: apiKeyStore);
AiClient clientForProvider(AiProvider provider) {
  return switch (provider) {
    AiProvider.openAi => openAiClient,
    AiProvider.gemini => geminiClient,
  };
}
Future<bool> hasKeyForProvider(AiProvider provider) {
  return apiKeyStore.hasKeyForProvider(provider);
}
```

Pass these into `DocumentProcessingService` and `LocalAnswerService`.

- [ ] **Step 6: Run tests**

Run:

```bash
flutter test test/document_processing_service_test.dart test/local_answer_service_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/src/ai/ai_client_resolver.dart lib/src/knowledge/data/document_processing_service.dart lib/src/chat/data/local_answer_service.dart test/document_processing_service_test.dart test/local_answer_service_test.dart
git commit -m "fix: route ai calls by active provider"
```

---

### Task 4: Settings Screen Redesign With Auto-Save Dropdowns

**Files:**
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Modify: `lib/main.dart`
- Test: `test/settings_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Replace or extend `test/settings_screen_test.dart` with:

```dart
testWidgets('shows AI block with provider pills and model dropdowns', (tester) async {
  final keyStore = MemoryApiKeyStore();
  var settings = AppSettings.defaults();

  await tester.pumpWidget(MaterialApp(
    home: SettingsScreen(
      apiKeyStore: keyStore,
      loadSettings: () async => settings,
      saveSettings: (value) async => settings = value,
      testApiKeyForProvider: (_) async => true,
    ),
  ));

  await tester.pumpAndSettle();

  expect(find.text('AI'), findsOneWidget);
  expect(find.text('OpenAI'), findsOneWidget);
  expect(find.text('Gemini'), findsOneWidget);
  expect(find.text('Válaszadó modell'), findsOneWidget);
  expect(find.text('PDF feldolgozó modell'), findsOneWidget);
  expect(find.text('Groundedness modell'), findsOneWidget);
  expect(find.text('Embedding modell'), findsOneWidget);
  expect(find.text('Mentés'), findsNothing);
  expect(find.text('Haladó modellbeállítások'), findsNothing);
});

testWidgets('provider pill changes API key field and autosaves', (tester) async {
  final keyStore = MemoryApiKeyStore();
  var settings = AppSettings.defaults();

  await tester.pumpWidget(MaterialApp(
    home: SettingsScreen(
      apiKeyStore: keyStore,
      loadSettings: () async => settings,
      saveSettings: (value) async => settings = value,
      testApiKeyForProvider: (_) async => true,
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Gemini'));
  await tester.pumpAndSettle();

  expect(settings.activeProvider, AiProvider.gemini);
  expect(find.byKey(const Key('gemini-api-key-field')), findsOneWidget);

  await tester.enterText(find.byKey(const Key('gemini-api-key-field')), 'AIza-test');
  await tester.pumpAndSettle();

  expect(await keyStore.readKeyForProvider(AiProvider.gemini), 'AIza-test');
  expect(DebugConsole.allText, contains('[Google] api key saved length=9'));
});

testWidgets('model dropdown autosaves selected Gemini extraction model', (tester) async {
  final keyStore = MemoryApiKeyStore();
  var settings = AppSettings.defaults().copyWith(activeProvider: AiProvider.gemini);

  await tester.pumpWidget(MaterialApp(
    home: SettingsScreen(
      apiKeyStore: keyStore,
      loadSettings: () async => settings,
      saveSettings: (value) async => settings = value,
      testApiKeyForProvider: (_) async => true,
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('extraction-model-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('gemini-2.5-flash').last);
  await tester.pumpAndSettle();

  expect(settings.geminiExtractionModel, 'gemini-2.5-flash');
  expect(DebugConsole.allText, contains('[Google] model selected slot=extraction model=gemini-2.5-flash'));
});
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/settings_screen_test.dart
```

Expected: FAIL because current UI still has save button, text model fields, no provider pills.

- [ ] **Step 3: Update `SettingsScreen` constructor**

Keep backward compatibility with current tests by making the new provider tester optional:

```dart
final Future<bool> Function(AiProvider provider)? testApiKeyForProvider;
```

Use this helper so older injection sites still work:

```dart
Future<bool> _testProviderKey(AiProvider provider) {
  final providerTester = widget.testApiKeyForProvider;
  if (providerTester != null) {
    return providerTester(provider);
  }
  if (provider == AiProvider.openAi) {
    return widget.testApiKey();
  }
  return Future.value(false);
}
```

- [ ] **Step 4: Replace free-text model fields with dropdown rows**

Add a helper in `settings_screen.dart`:

```dart
class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({
    required this.slot,
    required this.label,
    required this.provider,
    required this.value,
    required this.onChanged,
  });

  final AiModelSlot slot;
  final String label;
  final AiProvider provider;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = ModelCatalog.options(provider, slot);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String>(
        key: Key('${slot.wireName}-model-dropdown'),
        value: options.contains(value) ? value : options.first,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in options)
            DropdownMenuItem(value: option, child: Text(option)),
        ],
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Build AI/Speech/Mode/Validation sections**

Use four `_Section` blocks in this order:

```dart
_Section(title: 'AI', children: [...])
_Section(title: 'Beszéd', children: [...])
_Section(title: 'Működési mód', children: [...])
_Section(title: 'Validálás', children: [...])
```

Provider selector:

```dart
SegmentedButton<AiProvider>(
  segments: const [
    ButtonSegment(value: AiProvider.openAi, label: Text('OpenAI')),
    ButtonSegment(value: AiProvider.gemini, label: Text('Gemini')),
  ],
  selected: {_settings.activeProvider},
  onSelectionChanged: (selection) {
    _autoSave(_settings.copyWith(activeProvider: selection.single));
  },
)
```

API key field key:

```dart
Key('${provider.wireName}-api-key-field')
```

Log prefix:

```dart
String _providerLogPrefix(AiProvider provider) =>
    provider == AiProvider.openAi ? '[OpenAI]' : '[Google]';
```

- [ ] **Step 6: Implement auto-save key and model changes**

On API key editing, save after field submit or focus loss. To keep tests stable,
also save on `onChanged` when trimmed text is non-empty:

```dart
Future<void> _saveProviderKey(AiProvider provider, String value) async {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return;
  }
  await widget.apiKeyStore.saveKeyForProvider(provider, trimmed);
  DebugConsole.log('${_providerLogPrefix(provider)} api key saved length=${trimmed.length}');
}
```

Model update helper:

```dart
Future<void> _updateModel(AiModelSlot slot, String model) async {
  final provider = _settings.activeProvider;
  final next = switch ((provider, slot)) {
    (AiProvider.openAi, AiModelSlot.answer) =>
      _settings.copyWith(openAiAnswerModel: model),
    (AiProvider.openAi, AiModelSlot.extraction) =>
      _settings.copyWith(openAiExtractionModel: model),
    (AiProvider.openAi, AiModelSlot.groundedness) =>
      _settings.copyWith(openAiGroundednessModel: model),
    (AiProvider.openAi, AiModelSlot.embedding) =>
      _settings.copyWith(openAiEmbeddingModel: model),
    (AiProvider.gemini, AiModelSlot.answer) =>
      _settings.copyWith(geminiAnswerModel: model),
    (AiProvider.gemini, AiModelSlot.extraction) =>
      _settings.copyWith(geminiExtractionModel: model),
    (AiProvider.gemini, AiModelSlot.groundedness) =>
      _settings.copyWith(geminiGroundednessModel: model),
    (AiProvider.gemini, AiModelSlot.embedding) =>
      _settings.copyWith(geminiEmbeddingModel: model),
  };
  await _autoSave(next);
  DebugConsole.log('${_providerLogPrefix(provider)} model selected slot=${slot.wireName} model=$model');
}
```

- [ ] **Step 7: Run settings tests**

Run:

```bash
flutter test test/settings_screen_test.dart test/settings_repository_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/settings/ui/settings_screen.dart lib/main.dart test/settings_screen_test.dart
git commit -m "feat: redesign ai settings"
```

---

### Task 5: Knowledge Folders, Document Hashes, And Manual Import State

**Files:**
- Create: `lib/src/knowledge/models/knowledge_folder.dart`
- Modify: `lib/src/local_store/entities.dart`
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/pdf_import_service.dart`
- Test: `test/knowledge_document_repository_test.dart`
- Test: `test/pdf_import_service_test.dart`
- Test: `test/local_store_entities_test.dart`

- [ ] **Step 1: Write failing repository tests**

Add to `test/knowledge_document_repository_test.dart`:

```dart
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

test('imported documents start unsynced and retryable only after explicit sync', () async {
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
});
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/knowledge_document_repository_test.dart test/local_store_entities_test.dart
```

Expected: FAIL because folders and hashes do not exist.

- [ ] **Step 3: Add folder and document fields**

Create `lib/src/knowledge/models/knowledge_folder.dart`:

```dart
class KnowledgeFolder {
  const KnowledgeFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

Add `KnowledgeFolderEntity` to `entities.dart`:

```dart
@Entity()
class KnowledgeFolderEntity {
  KnowledgeFolderEntity({
    this.id = 0,
    required this.publicId,
    required this.name,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.sortOrder = 0,
  });

  @Id()
  int id;

  @Unique()
  String publicId;

  @Index()
  String name;

  int createdAtMillis;
  int updatedAtMillis;
  int sortOrder;
}
```

Extend `KnowledgeDocumentEntity`:

```dart
String? folderPublicId;
String? sha256;
String? activeProvider;
String? activeModel;
String? lastErrorCode;
bool retryable = false;
```

Extend `KnowledgeDocument` with matching fields and:

```dart
String get syncStatusLabel {
  return switch (status) {
    KnowledgeDocumentStatus.imported => 'Nincs sync',
    KnowledgeDocumentStatus.processing => 'Chunkolás',
    KnowledgeDocumentStatus.embedded || KnowledgeDocumentStatus.ready => 'Kész',
    KnowledgeDocumentStatus.failed => 'Hiba',
    _ => 'Feldolgozásra vár',
  };
}
```

- [ ] **Step 4: Add repository operations**

Add to `KnowledgeDocumentRepository` interface/implementation:

```dart
Future<List<KnowledgeFolder>> listFolders();
Future<KnowledgeFolder> createFolder(String name);
Future<KnowledgeFolder> renameFolder(String folderId, String name);
Future<void> deleteFolder(String folderId);
Future<void> moveDocumentsToFolder(List<String> documentIds, String? folderId);
Future<List<KnowledgeDocument>> listDocuments({String? folderId});
```

For the in-memory repository, store folders in a list:

```dart
final List<KnowledgeFolder> _folders = [];

Future<KnowledgeFolder> createFolder(String name) async {
  final now = DateTime.now();
  final folder = KnowledgeFolder(
    id: const Uuid().v4(),
    name: name.trim(),
    createdAt: now,
    updatedAt: now,
  );
  _folders.add(folder);
  return folder;
}

Future<void> moveDocumentsToFolder(List<String> documentIds, String? folderId) async {
  _documents = [
    for (final document in _documents)
      if (documentIds.contains(document.id))
        document.copyWith(folderId: folderId)
      else
        document,
  ];
}

Future<List<KnowledgeDocument>> listDocuments({String? folderId}) async {
  final filtered = folderId == null
      ? _documents
      : _documents.where((document) => document.folderId == folderId);
  return filtered.toList(growable: false);
}
```

For ObjectBox repository, add folder box and query by folder:

```dart
final Box<KnowledgeFolderEntity> _folderBox;

Future<List<KnowledgeDocumentEntity>> listDocuments({String? folderId}) async {
  if (folderId == null) {
    return _documentBox.getAll();
  }
  final query = _documentBox
      .query(KnowledgeDocumentEntity_.folderPublicId.equals(folderId))
      .build();
  try {
    return query.find();
  } finally {
    query.close();
  }
}

Future<void> moveDocumentsToFolder(List<String> documentIds, String? folderId) async {
  for (final documentId in documentIds) {
    final document = _findDocument(documentId);
    if (document == null) {
      continue;
    }
    document.folderPublicId = folderId;
    _documentBox.put(document);
  }
}
```

- [ ] **Step 5: Compute SHA-256 on import**

Add `crypto` if not already available through transitive dependencies:

```bash
flutter pub add crypto
```

In `PdfImportResult` add:

```dart
final String sha256;
```

Compute it in `PdfImportService`:

```dart
final digest = sha256.convert(bytes).toString();
```

- [ ] **Step 6: Regenerate ObjectBox and run tests**

Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
flutter test test/knowledge_document_repository_test.dart test/pdf_import_service_test.dart test/local_store_entities_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/local_store/entities.dart lib/objectbox-model.json lib/objectbox.g.dart lib/src/knowledge test/knowledge_document_repository_test.dart test/pdf_import_service_test.dart test/local_store_entities_test.dart
git commit -m "feat: add knowledge folders and document hashes"
```

---

### Task 6: Android File-Manager Knowledge UI And PDF Viewer

**Files:**
- Create: `lib/src/knowledge/ui/knowledge_header.dart`
- Create: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Create: `lib/src/knowledge/ui/pdf_viewer_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `pubspec.yaml`
- Test: `test/knowledge_base_screen_test.dart`

- [ ] **Step 1: Add dependency**

Run:

```bash
flutter pub add pdfrx
```

- [ ] **Step 2: Write failing UI tests**

Add to `test/knowledge_base_screen_test.dart`:

```dart
testWidgets('single tap opens in-app PDF viewer callback', (tester) async {
  final repository = KnowledgeDocumentRepository();
  final document = await repository.addDocument(
    filename: 'stroke.pdf',
    localPath: '/memory/stroke.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 9),
    sha256: 'hash',
  );
  String? openedId;

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      onOpenDocumentForTest: (doc) => openedId = doc.id,
    ),
  ));
  await _pumpUntilFound(tester, find.text('stroke.pdf'));

  await tester.tap(find.text('stroke.pdf'));
  await tester.pumpAndSettle();

  expect(openedId, document.id);
});

testWidgets('long tap enters selection mode and checkboxes appear on all rows', (tester) async {
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

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
    ),
  ));
  await _pumpUntilFound(tester, find.text('a.pdf'));

  await tester.longPress(find.text('a.pdf'));
  await tester.pumpAndSettle();

  expect(find.text('1 kijelölve'), findsOneWidget);
  expect(find.byType(Checkbox), findsNWidgets(2));
});

testWidgets('three-dot menu is an overlay and does not remove PDF rows', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(
    filename: 'a.pdf',
    localPath: '/memory/a.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 9),
    sha256: 'a',
  );

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
    ),
  ));
  await _pumpUntilFound(tester, find.text('a.pdf'));

  await tester.tap(find.byKey(const Key('knowledge-general-menu')));
  await tester.pumpAndSettle();

  expect(find.text('a.pdf'), findsOneWidget);
  expect(find.text('Összes kijelölése'), findsOneWidget);
  expect(find.text('Rendezés'), findsOneWidget);
});
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart
```

Expected: FAIL because callbacks, selection mode, and overlay menus do not exist.

- [ ] **Step 4: Create compact row widget**

Create `knowledge_document_row.dart`:

```dart
class KnowledgeDocumentRow extends StatelessWidget {
  const KnowledgeDocumentRow({
    super.key,
    required this.document,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onSelectionChanged,
    required this.onMenu,
  });

  final KnowledgeDocument document;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selectionMode ? () => onSelectionChanged(!selected) : onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              if (selectionMode) ...[
                Checkbox(value: selected, onChanged: (value) => onSelectionChanged(value ?? false)),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.picture_as_pdf, color: Color(0xFFB91C1C)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _Badge(text: document.syncStatusLabel),
                        if (document.status.isReady) const _Badge(text: 'RAG'),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('document-menu-${document.id}'),
                tooltip: 'PDF műveletek',
                onPressed: onMenu,
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Create header widget with normal and selection modes**

Create `knowledge_header.dart` with:

```dart
class KnowledgeHeader extends StatelessWidget implements PreferredSizeWidget {
  const KnowledgeHeader({
    super.key,
    required this.selectionCount,
    required this.selectionSummary,
    required this.onExitSelection,
    required this.onSendSelected,
    required this.onDeleteSelected,
    required this.onGeneralMenu,
    required this.onSelectionMenu,
  });

  final int selectionCount;
  final String selectionSummary;
  final VoidCallback onExitSelection;
  final VoidCallback onSendSelected;
  final VoidCallback onDeleteSelected;
  final VoidCallback onGeneralMenu;
  final VoidCallback onSelectionMenu;

  bool get selectionMode => selectionCount > 0;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return AppBar(
        leading: IconButton(
          tooltip: 'Kijelölés megszüntetése',
          onPressed: onExitSelection,
          icon: const Icon(Icons.close),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$selectionCount kijelölve'),
            Text(selectionSummary, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('knowledge-send-selected'),
            tooltip: 'Küldés feldolgozásra',
            onPressed: onSendSelected,
            icon: const Icon(Icons.upload),
          ),
          IconButton(
            key: const Key('knowledge-delete-selected'),
            tooltip: 'Törlés',
            onPressed: onDeleteSelected,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            key: const Key('knowledge-selection-menu'),
            tooltip: 'Kijelölt műveletek',
            onPressed: onSelectionMenu,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      );
    }
    return AppBar(
      title: const Text('Tudástár'),
      actions: [
        IconButton(
          key: const Key('knowledge-general-menu'),
          tooltip: 'Tudástár menü',
          onPressed: onGeneralMenu,
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Implement overlay menus in `KnowledgeBaseScreen`**

Use `showMenu` or `MenuAnchor`; prefer `showMenu` for testable overlay behavior:

```dart
Future<void> _showGeneralMenu() async {
  final selected = await showMenu<String>(
    context: context,
    position: const RelativeRect.fromLTRB(1000, kToolbarHeight, 12, 0),
    items: const [
      PopupMenuItem(value: 'select_all', child: Text('Összes kijelölése')),
      PopupMenuItem(value: 'sort', child: Text('Rendezés')),
      PopupMenuItem(value: 'new_folder', child: Text('Új mappa')),
      PopupMenuItem(value: 'import_chunks', child: Text('Chunk csomag import')),
      PopupMenuItem(value: 'export_knowledge', child: Text('Tudástár export')),
    ],
  );
  if (selected == 'select_all') {
    setState(() => _selectedDocumentIds = _documents.map((d) => d.id).toSet());
  }
}
```

Selection menu items:

```dart
const [
  PopupMenuItem(value: 'rag_on', child: Text('RAG bekapcsolása')),
  PopupMenuItem(value: 'move', child: Text('Mozgatás mappába')),
  PopupMenuItem(value: 'export_chunks', child: Text('Chunk csomag export')),
  PopupMenuItem(value: 'refresh_embeddings', child: Text('Embedding frissítés')),
  PopupMenuItem(value: 'flowchart_review', child: Text('Flowchart validálásra')),
  PopupMenuItem(value: 'offline_index', child: Text('Offline index frissítés')),
]
```

- [ ] **Step 7: Add PDF viewer screen**

Create `pdf_viewer_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfViewerScreen extends StatelessWidget {
  const PdfViewerScreen({
    super.key,
    required this.title,
    required this.path,
  });

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfViewer.file(path),
    );
  }
}
```

In `KnowledgeBaseScreen`, add optional test callback:

```dart
final void Function(KnowledgeDocument document)? onOpenDocumentForTest;
```

Open behavior:

```dart
void _openDocument(KnowledgeDocument document) {
  final callback = widget.onOpenDocumentForTest;
  if (callback != null) {
    callback(document);
    return;
  }
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PdfViewerScreen(title: document.filename, path: document.localPath),
  ));
}
```

- [ ] **Step 8: Run tests**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/knowledge/ui test/knowledge_base_screen_test.dart
git commit -m "feat: add file-manager knowledge ui"
```

---

### Task 7: Manual Sync Queue And Batch Processing

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Test: `test/knowledge_base_screen_test.dart`
- Test: `test/document_processing_service_test.dart`

- [ ] **Step 1: Write failing tests**

Add to `test/knowledge_base_screen_test.dart`:

```dart
testWidgets('import does not auto-process when processing service exists', (tester) async {
  final repository = KnowledgeDocumentRepository();
  var processCount = 0;
  final processingService = _CountingProcessingService(() => processCount += 1);

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      processingService: processingService,
      pickPdfs: () async => [
        PickedPdfFile(filename: 'omsz.pdf', bytes: [37, 80, 68, 70]),
      ],
    ),
  ));
  await _pumpUntilFound(tester, find.text('Nincs importált PDF'));

  await tester.tap(find.byTooltip('PDF hozzáadása'));
  await _pumpUntilFound(tester, find.text('omsz.pdf'));

  expect(processCount, 0);
  expect(find.text('Nincs sync'), findsOneWidget);
});

testWidgets('selection send processes only selected PDFs', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(filename: 'a.pdf', localPath: '/a.pdf', sizeBytes: 1, importedAt: DateTime.utc(2026), sha256: 'a');
  await repository.addDocument(filename: 'b.pdf', localPath: '/b.pdf', sizeBytes: 1, importedAt: DateTime.utc(2026), sha256: 'b');
  final processed = <String>[];

  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      processingService: _RecordingProcessingService(processed),
    ),
  ));
  await _pumpUntilFound(tester, find.text('a.pdf'));
  await tester.longPress(find.text('a.pdf'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('knowledge-send-selected')));
  await tester.pumpAndSettle();

  expect(processed, hasLength(1));
});
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart
```

Expected: FAIL because import currently auto-processes when `processingService` exists.

- [ ] **Step 3: Remove auto-processing from import**

In `_importPdfs`, delete this behavior:

```dart
if (widget.processingService != null) {
  await _processDocument(document.id);
}
```

After importing, only reload documents and show imported status.

- [ ] **Step 4: Add selected batch processing**

Maintain selected IDs:

```dart
Set<String> _selectedDocumentIds = {};

Future<void> _processSelectedDocuments() async {
  final ids = _selectedDocumentIds.toList(growable: false);
  if (ids.isEmpty) {
    return;
  }
  for (final id in ids) {
    await _processDocument(id);
  }
  if (!mounted) {
    return;
  }
  setState(() => _selectedDocumentIds = {});
  await _loadDocuments();
}
```

Wire `KnowledgeHeader.onSendSelected` to `_processSelectedDocuments`.

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart test/document_processing_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/knowledge/ui/knowledge_base_screen.dart test/knowledge_base_screen_test.dart
git commit -m "feat: make pdf sync manual and batchable"
```

---

### Task 8: Chunk Export And Import

**Files:**
- Create: `lib/src/knowledge/models/chunk_package.dart`
- Create: `lib/src/knowledge/data/chunk_package_service.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Test: `test/chunk_package_service_test.dart`

- [ ] **Step 1: Write failing chunk package tests**

Create `test/chunk_package_service_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/knowledge/models/chunk_package.dart';
import 'package:djinn/src/knowledge/data/chunk_package_service.dart';

void main() {
  test('exports chunk package with hash model and dimension metadata', () {
    final package = ChunkPackage(
      schemaVersion: 1,
      documentHash: 'hash',
      filename: 'stroke.pdf',
      provider: 'openai',
      extractionModel: 'gpt-5.5',
      embeddingModel: 'text-embedding-3-large',
      embeddingDimension: 3072,
      chunks: const [
        ChunkPackageItem(
          id: 'p1-main',
          text: 'ABCDE',
          pageNumber: 1,
          sectionTitle: null,
          embedding: [0.1, 0.2],
        ),
      ],
    );

    final json = package.toJson();
    expect(json['document_hash'], 'hash');
    expect(json['embedding_dimension'], 3072);
    expect(ChunkPackage.fromJson(json).chunks.single.id, 'p1-main');
  });

  test('rejects import when document hash differs', () {
    final service = ChunkPackageService();
    final package = ChunkPackage.fromJson(jsonDecode('''
    {
      "schema_version": 1,
      "document_hash": "hash-a",
      "filename": "a.pdf",
      "provider": "openai",
      "extraction_model": "gpt-5.5",
      "embedding_model": "text-embedding-3-large",
      "embedding_dimension": 3072,
      "chunks": []
    }
    ''') as Map<String, Object?>);

    expect(
      () => service.validateForImport(package, documentHash: 'hash-b', expectedDimension: 3072),
      throwsA(isA<ChunkPackageException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify red**

Run:

```bash
flutter test test/chunk_package_service_test.dart
```

Expected: FAIL because chunk package files do not exist.

- [ ] **Step 3: Implement JSON package model**

Create `chunk_package.dart` with immutable classes:

```dart
class ChunkPackage {
  const ChunkPackage({
    required this.schemaVersion,
    required this.documentHash,
    required this.filename,
    required this.provider,
    required this.extractionModel,
    required this.embeddingModel,
    required this.embeddingDimension,
    required this.chunks,
  });

  final int schemaVersion;
  final String documentHash;
  final String filename;
  final String provider;
  final String extractionModel;
  final String embeddingModel;
  final int embeddingDimension;
  final List<ChunkPackageItem> chunks;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'document_hash': documentHash,
    'filename': filename,
    'provider': provider,
    'extraction_model': extractionModel,
    'embedding_model': embeddingModel,
    'embedding_dimension': embeddingDimension,
    'chunks': chunks.map((chunk) => chunk.toJson()).toList(),
  };

  factory ChunkPackage.fromJson(Map<String, Object?> json) {
    final chunks = json['chunks'];
    return ChunkPackage(
      schemaVersion: json['schema_version'] as int? ?? 0,
      documentHash: json['document_hash'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      extractionModel: json['extraction_model'] as String? ?? '',
      embeddingModel: json['embedding_model'] as String? ?? '',
      embeddingDimension: json['embedding_dimension'] as int? ?? 0,
      chunks: chunks is List
          ? chunks
              .whereType<Map>()
              .map((item) => ChunkPackageItem.fromJson(Map<String, Object?>.from(item)))
              .toList(growable: false)
          : const [],
    );
  }
}
```

Add `ChunkPackageItem` with `id`, `text`, `pageNumber`, `sectionTitle`, and `embedding`.

- [ ] **Step 4: Implement validation service**

Create `chunk_package_service.dart`:

```dart
class ChunkPackageException implements Exception {
  const ChunkPackageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ChunkPackageService {
  void validateForImport(
    ChunkPackage package, {
    required String documentHash,
    required int expectedDimension,
  }) {
    if (package.schemaVersion != 1) {
      throw const ChunkPackageException('Unsupported chunk package schema.');
    }
    if (package.documentHash != documentHash) {
      throw const ChunkPackageException('Document hash does not match package.');
    }
    if (package.embeddingDimension != expectedDimension) {
      throw const ChunkPackageException('Embedding dimension mismatch.');
    }
  }
}
```

- [ ] **Step 5: Add ObjectBox export/import methods**

Add repository methods:

```dart
Future<ChunkPackage> exportChunkPackage(String documentPublicId);
Future<void> importChunkPackage(String documentPublicId, ChunkPackage package);
```

Use existing chunk and embedding boxes:

```dart
Future<ChunkPackage> exportChunkPackage(String documentPublicId) async {
  final document = _findDocument(documentPublicId);
  if (document == null) {
    throw StateError('knowledge document not found: $documentPublicId');
  }
  final chunks = _chunkBox
      .getAll()
      .where((chunk) => chunk.documentPublicId == documentPublicId)
      .toList(growable: false);
  final items = <ChunkPackageItem>[];
  for (final chunk in chunks) {
    ChunkEmbeddingEntity? embedding;
    for (final candidate in _embeddingBox.getAll()) {
      if (candidate.sourceId == chunk.publicId) {
        embedding = candidate;
        break;
      }
    }
    items.add(ChunkPackageItem(
      id: chunk.publicId.split(':').last,
      text: chunk.text,
      pageNumber: chunk.pageNumber,
      sectionTitle: chunk.sectionTitle,
      embedding: embedding?.vector ?? const [],
    ));
  }
  return ChunkPackage(
    schemaVersion: 1,
    documentHash: document.sha256 ?? '',
    filename: document.filename,
    provider: document.activeProvider ?? '',
    extractionModel: document.activeModel ?? '',
    embeddingModel: items.isEmpty ? '' : _embeddingBox.getAll().first.model,
    embeddingDimension: items.isEmpty ? 0 : items.first.embedding.length,
    chunks: items,
  );
}

Future<void> importChunkPackage(String documentPublicId, ChunkPackage package) async {
  for (final item in package.chunks) {
    final sourceId = '$documentPublicId:${item.id}';
    await saveChunk(
      DocumentChunkEntity(
        publicId: sourceId,
        documentPublicId: documentPublicId,
        text: item.text,
        pageNumber: item.pageNumber,
        sectionTitle: item.sectionTitle,
      ),
      ChunkEmbeddingEntity(
        sourceId: sourceId,
        sourceType: EvidenceSourceType.textChunk.wireName,
        vector: item.embedding,
        model: package.embeddingModel,
        createdAtMillis: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
flutter test test/chunk_package_service_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/knowledge/models/chunk_package.dart lib/src/knowledge/data/chunk_package_service.dart lib/src/knowledge/data/objectbox_knowledge_repository.dart test/chunk_package_service_test.dart
git commit -m "feat: add chunk package import export"
```

---

### Task 9: Voice STT/TTS State Machine And Chat Controls

**Files:**
- Create: `lib/src/voice/speech_adapter.dart`
- Create: `lib/src/voice/tts_adapter.dart`
- Create: `lib/src/voice/voice_controller.dart`
- Create: `lib/src/voice/voice_controls.dart`
- Modify: `lib/src/chat/ui/message_composer.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `pubspec.yaml`
- Test: `test/voice_controller_test.dart`
- Test: `test/message_composer_test.dart`

- [ ] **Step 1: Add dependencies**

Run:

```bash
flutter pub add speech_to_text flutter_tts
```

- [ ] **Step 2: Write failing voice controller tests**

Create `test/voice_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/debug/debug_console.dart';
import 'package:djinn/src/voice/voice_controller.dart';
import 'package:djinn/src/voice/speech_adapter.dart';
import 'package:djinn/src/voice/tts_adapter.dart';

void main() {
  setUp(DebugConsole.clear);

  test('speech timeout becomes noSpeech and does not send chat', () async {
    var sent = 0;
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const [
        SpeechEvent.status('listening'),
        SpeechEvent.error('error_speech_timeout'),
      ]),
      tts: FakeTtsAdapter(),
      onFinalTranscript: (_) async => sent += 1,
    );

    await controller.listenOnce(locale: 'hu-HU');

    expect(controller.state, VoiceState.noSpeech);
    expect(sent, 0);
    expect(DebugConsole.allText, contains('[Voice/STT] error code=error_speech_timeout'));
  });

  test('empty interim results are ignored and final transcript is sent once', () async {
    final sent = <String>[];
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const [
        SpeechEvent.result('', false),
        SpeechEvent.result('szia', false),
        SpeechEvent.result('szia djinn', true),
      ]),
      tts: FakeTtsAdapter(),
      onFinalTranscript: (text) async => sent.add(text),
    );

    await controller.listenOnce(locale: 'hu-HU');

    expect(sent, ['szia djinn']);
  });

  test('speak does not start duplicate TTS sessions', () async {
    final tts = FakeTtsAdapter();
    final controller = VoiceController(
      speech: FakeSpeechAdapter(events: const []),
      tts: tts,
      onFinalTranscript: (_) async {},
    );

    await controller.speak('válasz', locale: 'hu-HU');
    await controller.speak('válasz', locale: 'hu-HU');

    expect(tts.spokenTexts, ['válasz']);
  });
}
```

- [ ] **Step 3: Run tests to verify red**

Run:

```bash
flutter test test/voice_controller_test.dart
```

Expected: FAIL because voice files do not exist.

- [ ] **Step 4: Add STT/TTS adapter contracts and fakes**

Create `speech_adapter.dart`:

```dart
sealed class SpeechEvent {
  const SpeechEvent();
  const factory SpeechEvent.status(String status) = SpeechStatusEvent;
  const factory SpeechEvent.result(String text, bool finalResult) =
      SpeechResultEvent;
  const factory SpeechEvent.error(String code) = SpeechErrorEvent;
}

class SpeechStatusEvent extends SpeechEvent {
  const SpeechStatusEvent(this.status);
  final String status;
}

class SpeechResultEvent extends SpeechEvent {
  const SpeechResultEvent(this.text, this.finalResult);
  final String text;
  final bool finalResult;
}

class SpeechErrorEvent extends SpeechEvent {
  const SpeechErrorEvent(this.code);
  final String code;
}

abstract class SpeechAdapter {
  Stream<SpeechEvent> listen({required String locale});
  Future<void> stop();
}

class FakeSpeechAdapter implements SpeechAdapter {
  FakeSpeechAdapter({required this.events});
  final List<SpeechEvent> events;
  @override
  Stream<SpeechEvent> listen({required String locale}) => Stream.fromIterable(events);
  @override
  Future<void> stop() async {}
}
```

Create `tts_adapter.dart`:

```dart
abstract class TtsAdapter {
  Future<bool> isLanguageAvailable(String locale);
  Future<void> speak(String text, {required String locale, double rate, double pitch});
  Future<void> pause();
  Future<void> stop();
}

class FakeTtsAdapter implements TtsAdapter {
  final spokenTexts = <String>[];
  bool available = true;

  @override
  Future<bool> isLanguageAvailable(String locale) async => available;

  @override
  Future<void> speak(String text, {required String locale, double rate = 0.5, double pitch = 1.0}) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}
}
```

- [ ] **Step 5: Implement voice controller**

Create `voice_controller.dart`:

```dart
enum VoiceState { idle, listening, noSpeech, sending, speaking, paused, error }

class VoiceController {
  VoiceController({
    required this.speech,
    required this.tts,
    required this.onFinalTranscript,
  });

  final SpeechAdapter speech;
  final TtsAdapter tts;
  final Future<void> Function(String text) onFinalTranscript;

  VoiceState state = VoiceState.idle;
  String? _lastSpeakingText;

  Future<void> listenOnce({required String locale}) async {
    state = VoiceState.listening;
    DebugConsole.log('[Voice/STT] listen start locale=$locale');
    await for (final event in speech.listen(locale: locale)) {
      switch (event) {
        case SpeechStatusEvent(:final status):
          DebugConsole.log('[Voice/STT] status=$status');
        case SpeechResultEvent(:final text, :final finalResult):
          DebugConsole.log('[Voice/STT] result chars=${text.length} final=$finalResult');
          if (finalResult && text.trim().isNotEmpty) {
            state = VoiceState.sending;
            await onFinalTranscript(text.trim());
            state = VoiceState.idle;
          }
        case SpeechErrorEvent(:final code):
          DebugConsole.log('[Voice/STT] error code=$code');
          state = code == 'error_speech_timeout' ? VoiceState.noSpeech : VoiceState.error;
      }
    }
  }

  Future<void> speak(String text, {required String locale}) async {
    if (state == VoiceState.speaking && _lastSpeakingText == text) {
      return;
    }
    final available = await tts.isLanguageAvailable(locale);
    if (!available) {
      DebugConsole.log('[Voice/TTS] language unavailable locale=$locale');
      state = VoiceState.error;
      return;
    }
    state = VoiceState.speaking;
    _lastSpeakingText = text;
    DebugConsole.log('[Voice/TTS] speak chars=${text.length} locale=$locale rate=0.5 pitch=1.0');
    await tts.speak(text, locale: locale, rate: 0.5, pitch: 1.0);
  }

  Future<void> stopTts() async {
    DebugConsole.log('[Voice/TTS] stop');
    await tts.stop();
    _lastSpeakingText = null;
    state = VoiceState.idle;
  }
}
```

- [ ] **Step 6: Add plugin adapters**

Implement plugin adapters in the same adapter files or separate `plugin_*` files.
STT adapter:

```dart
class SpeechToTextAdapter implements SpeechAdapter {
  SpeechToTextAdapter({speech_to_text.SpeechToText? speech})
    : _speech = speech ?? speech_to_text.SpeechToText();

  final speech_to_text.SpeechToText _speech;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    _speech.initialize(
      onStatus: (status) => controller.add(SpeechEvent.status(status)),
      onError: (error) => controller.add(SpeechEvent.error(error.errorMsg)),
    ).then((available) {
      if (!available) {
        controller.add(const SpeechEvent.error('speech_unavailable'));
        controller.close();
        return;
      }
      _speech.listen(
        localeId: locale,
        onResult: (result) => controller.add(
          SpeechEvent.result(result.recognizedWords, result.finalResult),
        ),
      );
    });
    return controller.stream;
  }

  @override
  Future<void> stop() => _speech.stop();
}
```

TTS adapter:

```dart
class FlutterTtsAdapter implements TtsAdapter {
  FlutterTtsAdapter({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> isLanguageAvailable(String locale) async {
    final result = await _tts.isLanguageAvailable(locale);
    return result == true;
  }

  @override
  Future<void> speak(
    String text, {
    required String locale,
    double rate = 0.5,
    double pitch = 1.0,
  }) async {
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await _tts.speak(text);
  }

  @override
  Future<void> pause() => _tts.pause();

  @override
  Future<void> stop() => _tts.stop();
}
```

Keep plugin imports out of tests by testing only the interfaces/fakes.

- [ ] **Step 7: Wire voice controls into composer**

Add optional `VoiceController? voiceController` and `String voiceLocale` to
`MessageComposer`. Add icon buttons:

```dart
IconButton(
  key: const Key('voice-listen'),
  tooltip: 'Hangbevitel',
  onPressed: widget.sending || widget.voiceController == null
      ? null
      : () => widget.voiceController!.listenOnce(locale: widget.voiceLocale),
  icon: const Icon(Icons.mic),
)
```

After assistant response, `ChatScreen` can call TTS only when voice mode
requests it. Keep default push-to-talk conservative.

- [ ] **Step 8: Run tests**

Run:

```bash
flutter test test/voice_controller_test.dart test/message_composer_test.dart
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/voice lib/src/chat/ui test/voice_controller_test.dart test/message_composer_test.dart
git commit -m "feat: add voice conversation controls"
```

---

### Task 10: Flowchart Validation Diagnostics

**Files:**
- Modify: `lib/src/flowchart/data/flowchart_validation_repository.dart`
- Modify: `lib/src/flowchart/ui/flowchart_validation_screen.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Test: `test/flowchart_validation_test.dart`
- Test: `test/document_processing_service_test.dart`

- [ ] **Step 1: Write failing zero-state tests**

Add to `test/flowchart_validation_test.dart`:

```dart
testWidgets('empty flowchart validation screen explains zero reason', (tester) async {
  final repository = _FakeFlowchartValidationRepository(
    flowcharts: const [],
    zeroReason: FlowchartZeroReason.noDetectedFlowcharts,
  );

  await tester.pumpWidget(MaterialApp(
    home: FlowchartValidationScreen(repository: repository),
  ));
  await tester.pumpAndSettle();

  expect(find.text('Nincs feldolgozott vagy felismert flowchart'), findsOneWidget);
  expect(DebugConsole.allText, contains('[Flowchart] validation screen loaded count=0 reason=no_detected_flowcharts'));
});
```

- [ ] **Step 2: Run test to verify red**

Run:

```bash
flutter test test/flowchart_validation_test.dart
```

Expected: FAIL because zero reason API does not exist.

- [ ] **Step 3: Add zero reason model**

In `flowchart_validation_repository.dart`:

```dart
enum FlowchartZeroReason {
  noProcessedDocuments('no_processed_documents'),
  noDetectedFlowcharts('no_detected_flowcharts'),
  alreadyValidated('already_validated'),
  extractionFailed('extraction_failed');

  const FlowchartZeroReason(this.wireName);
  final String wireName;
}

class FlowchartReviewList {
  const FlowchartReviewList({required this.items, this.zeroReason});
  final List<FlowchartEntity> items;
  final FlowchartZeroReason? zeroReason;
}
```

Add repository method:

```dart
Future<FlowchartReviewList> listFlowchartReviewState();
```

Make old `listFlowchartsNeedingReview()` call the new method and return items.

- [ ] **Step 4: Update UI logging and text**

In `FlowchartValidationScreen._load()`:

```dart
final review = await widget.repository.listFlowchartReviewState();
DebugConsole.log(
  '[Flowchart] validation screen loaded count=${review.items.length} reason=${review.zeroReason?.wireName ?? 'has_candidates'}',
);
```

Zero text:

```dart
String _zeroText(FlowchartZeroReason? reason) {
  return switch (reason) {
    FlowchartZeroReason.noProcessedDocuments => 'Nincs feldolgozott dokumentum',
    FlowchartZeroReason.noDetectedFlowcharts => 'Nincs feldolgozott vagy felismert flowchart',
    FlowchartZeroReason.alreadyValidated => 'Minden flowchart validálva van',
    FlowchartZeroReason.extractionFailed => 'A flowchart feldolgozás hibára futott',
    null => 'Nincs validálandó flowchart',
  };
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/flowchart_validation_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/flowchart test/flowchart_validation_test.dart
git commit -m "fix: explain empty flowchart validation states"
```

---

### Task 11: Offline Non-LLM Fallback Search

**Files:**
- Create: `lib/src/offline/offline_search_service.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/settings/models/app_settings.dart`
- Test: `test/offline_search_service_test.dart`
- Test: `test/local_answer_service_test.dart`

- [ ] **Step 1: Write failing offline search tests**

Create `test/offline_search_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:djinn/src/offline/offline_search_service.dart';

void main() {
  test('returns source excerpts without generated answer', () {
    final service = OfflineSearchService();
    final results = service.search(
      query: 'thrombectomia',
      chunks: const [
        OfflineChunk(id: 'c1', label: '1. oldal', text: 'Thrombectomia indikációk részletezése.'),
        OfflineChunk(id: 'c2', label: '2. oldal', text: 'Más téma.'),
      ],
    );

    expect(results.single.id, 'c1');
    expect(results.single.generatedAnswer, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify red**

Run:

```bash
flutter test test/offline_search_service_test.dart
```

Expected: FAIL because offline service does not exist.

- [ ] **Step 3: Implement minimal keyword search**

Create `offline_search_service.dart`:

```dart
class OfflineChunk {
  const OfflineChunk({
    required this.id,
    required this.label,
    required this.text,
  });

  final String id;
  final String label;
  final String text;
}

class OfflineSearchResult {
  const OfflineSearchResult({
    required this.id,
    required this.label,
    required this.excerpt,
    this.generatedAnswer = false,
  });

  final String id;
  final String label;
  final String excerpt;
  final bool generatedAnswer;
}

class OfflineSearchService {
  List<OfflineSearchResult> search({
    required String query,
    required List<OfflineChunk> chunks,
    int limit = 8,
  }) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.length > 2)
        .toList(growable: false);
    final scored = <({OfflineChunk chunk, int score})>[];
    for (final chunk in chunks) {
      final text = chunk.text.toLowerCase();
      final score = terms.where(text.contains).length;
      if (score > 0) {
        scored.add((chunk: chunk, score: score));
      }
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((item) {
      return OfflineSearchResult(
        id: item.chunk.id,
        label: item.chunk.label,
        excerpt: item.chunk.text,
      );
    }).toList(growable: false);
  }
}
```

- [ ] **Step 4: Integrate as explicit fallback mode**

Add setting field:

```dart
final bool offlineFallbackEnabled;
```

Add this test to `test/local_answer_service_test.dart`:

```dart
test('offline fallback returns source excerpts without generated answer text', () async {
  final service = LocalAnswerService(
    openAiClient: FakeOpenAiClient(),
    retriever: MemoryLocalRetriever(const [
      SourceEvidence(
        id: 'chunk-1',
        sourceType: EvidenceSourceType.textChunk,
        text: 'Thrombectomia indikációk.',
        label: '1. oldal',
        validationState: ValidationState.validated,
        score: 0.9,
      ),
    ]),
    citationVerifier: CitationVerifier(),
    loadSettings: () async => AppSettings.defaults().copyWith(
      offlineFallbackEnabled: true,
    ),
    hasApiKey: () async => false,
    hasReadyDocuments: () async => true,
  );

  final result = await service.answer('thrombectomia');

  expect(result.status, 'offline_search');
  expect(result.text, contains('Offline keresési találatok'));
  expect(result.text, contains('Ez nem AI által generált válasz.'));
});
```

In `LocalAnswerService`, only use offline fallback when enabled and provider key
or network prevents LLM use. Return text that clearly says this is search
results, not generated AI:

```dart
'Offline keresési találatok. Ez nem AI által generált válasz.'
```

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/offline_search_service_test.dart test/local_answer_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/offline lib/src/chat/data/local_answer_service.dart lib/src/settings/models/app_settings.dart test/offline_search_service_test.dart test/local_answer_service_test.dart
git commit -m "feat: add offline non-llm search fallback"
```

---

### Task 12: Final Wiring, Full Verification, Push, And Online APK Build

**Files:**
- Modify: `lib/main.dart`
- Modify: `.github/workflows/*` only if the existing debug APK workflow is missing or broken.
- Test: all tests.

- [ ] **Step 1: Full static analysis**

Run:

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 2: Full test suite**

Run:

```bash
flutter test
```

Expected: all tests pass. Existing ObjectBox tests that are already skipped in
this Termux/proot environment may remain skipped if their skip condition is
pre-existing and documented in output.

- [ ] **Step 3: Review git diff**

Run:

```bash
git status --short
git diff --stat HEAD
```

Expected: only intended app, tests, generated ObjectBox, and dependency files
changed.

- [ ] **Step 4: Final commit if uncommitted changes remain**

```bash
git add .
git commit -m "feat: upgrade knowledge ai and voice workflows"
```

Skip this commit only if all task commits already left the worktree clean.

- [ ] **Step 5: Push branch**

Run:

```bash
git branch --show-current
git push -u origin "$(git branch --show-current)"
```

Expected: branch pushed to GitHub.

- [ ] **Step 6: Trigger/monitor GitHub Actions**

Run:

```bash
gh run list --limit 5
```

Then monitor the newest run for the pushed branch:

```bash
gh run watch <run-id>
```

Expected: debug APK workflow succeeds.

- [ ] **Step 7: Provide one direct APK link**

If the repo's latest debug release workflow is unchanged, final APK link should
remain:

```text
https://github.com/elizerpist/djinn/releases/download/debug-latest/djinn-debug.apk
```

Verify the link after Actions completes. Final response should include only the
working debug APK link plus a concise change summary.
