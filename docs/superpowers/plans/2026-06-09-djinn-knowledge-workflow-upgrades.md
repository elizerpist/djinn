# Djinn Knowledge Workflow Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first working version of Djinn's manual, reusable, provider-flexible knowledge workflow with flowchart validation, voice input, TTS, and admin maintenance.

**Architecture:** Add a provider-neutral AI interface, extend ObjectBox document metadata, move PDF training behind explicit user actions, and keep reusable knowledge artifacts in local ObjectBox plus `.djinnpack` export/import. Voice and TTS are isolated behind service interfaces so widget tests use fakes and Android uses native plugins.

**Tech Stack:** Flutter, Dart, ObjectBox, `http`, `file_picker`, `flutter_secure_storage`, `crypto`, `speech_to_text`, `flutter_tts`, `permission_handler`, OpenAI Responses/Embeddings API, Google Gemini REST API.

---

## File Structure

- Modify `pubspec.yaml`: add `crypto`, `speech_to_text`, `flutter_tts`, `permission_handler`.
- Modify `android/app/src/main/AndroidManifest.xml`: add microphone permissions and speech recognition query.
- Modify `lib/src/local_store/entities.dart`: document metadata fields.
- Regenerate `lib/objectbox.g.dart` and `lib/objectbox-model.json`.
- Create `lib/src/ai/ai_client.dart`: provider-neutral AI contracts.
- Create `lib/src/ai/ai_provider.dart`: provider enum and defaults.
- Create `lib/src/ai/openai_ai_client.dart`: OpenAI adapter around current HTTP behavior.
- Create `lib/src/ai/gemini_ai_client.dart`: Gemini REST client.
- Modify `lib/src/openai/openai_client.dart` and `lib/src/openai/openai_http_client.dart`: keep compatibility or delegate to AI contracts.
- Modify `lib/src/settings/data/api_key_store.dart`: provider-key storage.
- Modify `lib/src/settings/models/app_settings.dart`: provider, models, voice/TTS/cost settings.
- Modify `lib/src/settings/data/app_settings_repository.dart`: map new settings fields.
- Modify `lib/src/settings/ui/settings_screen.dart`: provider/key/model/voice/TTS/cost UI.
- Modify `lib/src/knowledge/models/knowledge_document.dart`: metadata fields and statuses.
- Modify `lib/src/knowledge/data/pdf_import_service.dart`: content hash and OCR heuristic.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`: in-memory metadata, collections, pack support.
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: ObjectBox metadata, chunks, embeddings, flowcharts, pack support.
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: expose new repository operations.
- Modify `lib/src/knowledge/data/document_processing_service.dart`: AI provider, flowchart save, queue-friendly processing.
- Create `lib/src/knowledge/data/training_pack_service.dart`: JSON `.djinnpack` import/export.
- Create `lib/src/knowledge/data/training_queue.dart`: sequential queue state.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: manual sync, badges, selected queue, import/export.
- Create `lib/src/knowledge/ui/source_page_screen.dart`: citation jump target.
- Modify `lib/src/rag/retrieval/local_retriever.dart`: RAG enabled and collection filtering.
- Modify `lib/src/chat/data/local_answer_service.dart`: collection filter wiring.
- Modify `lib/src/chat/ui/chat_screen.dart`: collection selector, voice/TTS services.
- Modify `lib/src/chat/ui/message_composer.dart`: microphone button and transcript input.
- Modify `lib/src/chat/ui/chat_bubble.dart`: citation jump and TTS controls.
- Create `lib/src/voice/voice_input_service.dart`: native/fakeable speech-to-text.
- Create `lib/src/voice/text_to_speech_service.dart`: native/fakeable TTS.
- Create `lib/src/admin/ui/admin_screen.dart`: maintenance entry point.
- Modify `lib/src/chat/ui/main_screen.dart`: Admin drawer item and dependency injection.
- Modify `lib/main.dart`: dependency wiring.
- Add tests listed below.

---

### Task 1: Dependencies And Android Permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add dependencies**

Run:

```bash
/home/flutteruser/flutter/bin/flutter pub add crypto speech_to_text flutter_tts permission_handler
```

Expected: `pubspec.yaml` and `pubspec.lock` include the packages.

- [ ] **Step 2: Add Android permissions**

Add:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

Inside existing `<queries>`, add:

```xml
<intent>
    <action android:name="android.speech.RecognitionService" />
</intent>
<intent>
    <action android:name="android.intent.action.TTS_SERVICE" />
</intent>
```

- [ ] **Step 3: Verify dependency resolution**

Run:

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && /home/flutteruser/flutter/bin/flutter pub get'
```

Expected: exit 0.

---

### Task 2: ObjectBox Metadata Model

**Files:**
- Modify: `lib/src/local_store/entities.dart`
- Modify generated: `lib/objectbox.g.dart`
- Modify generated: `lib/objectbox-model.json`
- Test: `test/local_store_entities_test.dart`

- [ ] **Step 1: Write failing entity tests**

Add expectations that `KnowledgeDocumentEntity` stores `contentHash`, `ragEnabled`, `collectionName`, `ocrStatus`, `trainedAtMillis`, and `packVersion`.

Run:

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && /home/flutteruser/flutter/bin/flutter test test/local_store_entities_test.dart'
```

Expected: fail because fields do not exist.

- [ ] **Step 2: Add entity fields**

Add defaults:

```dart
this.contentHash,
this.ragEnabled = true,
this.collectionName = 'Alap',
this.ocrStatus = 'unknown',
this.trainedAtMillis,
this.packVersion,
```

- [ ] **Step 3: Regenerate ObjectBox files**

Run:

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && /home/flutteruser/flutter/bin/dart run build_runner build --delete-conflicting-outputs'
```

Expected: generated files update cleanly.

- [ ] **Step 4: Run entity test**

Expected: pass.

---

### Task 3: Provider-Neutral AI Contracts

**Files:**
- Create: `lib/src/ai/ai_client.dart`
- Create: `lib/src/ai/ai_provider.dart`
- Modify: `lib/src/openai/openai_client.dart`
- Test: `test/ai_client_contract_test.dart`

- [ ] **Step 1: Write failing contract tests**

Test that extraction result can contain chunks and flowcharts, and provider defaults resolve OpenAI/Gemini model names.

Expected: fail because files do not exist.

- [ ] **Step 2: Add AI models and provider enum**

Define `AiClient`, `AiExtractionResult`, `AiExtractedChunk`, `AiExtractedFlowchart`, `AiExtractedFlowchartNode`, `AiExtractedFlowchartEdge`, `AiAnswer`, `AiEvidence`, `AiException`, and `AiProvider`.

- [ ] **Step 3: Add compatibility adapters**

Keep current tests compiling by mapping current OpenAI model classes to AI classes or by updating imports in implementation files.

- [ ] **Step 4: Run contract tests**

Expected: pass.

---

### Task 4: Gemini REST Client

**Files:**
- Create: `lib/src/ai/gemini_ai_client.dart`
- Test: `test/gemini_ai_client_test.dart`

- [ ] **Step 1: Write RED tests with `MockClient`**

Cover:

- key test succeeds on a mocked model call
- `createEmbedding` returns a 3072 vector
- `extractDocument` parses chunks and flowcharts from JSON text
- 429 billing/rate errors produce `AiException`

Expected: fail because client does not exist.

- [ ] **Step 2: Implement client**

Use REST:

- `POST /v1beta/models/{model}:generateContent?key=...`
- `POST /v1beta/models/{model}:embedContent?key=...`

Parse structured JSON from response text.

- [ ] **Step 3: Run Gemini tests**

Expected: pass.

---

### Task 5: Settings For Providers, Cost, Voice, TTS

**Files:**
- Modify: `lib/src/settings/data/api_key_store.dart`
- Modify: `lib/src/settings/models/app_settings.dart`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Test: `test/settings_repository_test.dart`
- Test: `test/settings_screen_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- OpenAI and Google keys save/read independently.
- provider selector persists Gemini.
- paid AI disabled blocks processing confirmation state.
- voice/TTS settings persist.

Expected: fail because fields/UI do not exist.

- [ ] **Step 2: Implement storage and settings**

Use secure storage keys:

- `openai_api_key`
- `google_api_key`

Add settings defaults:

- provider `openai`
- Gemini answer/extraction `gemini-2.5-flash`
- Gemini embedding `gemini-embedding-001`
- `allowPaidAi = false`
- `confirmBeforeAiProcessing = true`
- voice/TTS `hu-HU`

- [ ] **Step 3: Implement UI**

Use segmented/dropdown controls and text fields. Keep current OpenAI key behavior.

- [ ] **Step 4: Run settings tests**

Expected: pass.

---

### Task 6: Manual PDF Import, Fingerprint, Duplicate Prevention

**Files:**
- Modify: `lib/src/knowledge/data/pdf_import_service.dart`
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/pdf_import_service_test.dart`
- Test: `test/knowledge_base_screen_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- importing multiple PDFs lists all immediately
- import does not call `processDocument`
- duplicate hash is skipped
- every row has status badge and sync button

Expected: fail on auto-processing and missing hash/sync UI.

- [ ] **Step 2: Add SHA-256 fingerprint**

Use `crypto` to hash bytes or copied file bytes.

- [ ] **Step 3: Add repository duplicate lookup**

Skip existing `contentHash`.

- [ ] **Step 4: Remove auto-processing from import**

Import only adds documents.

- [ ] **Step 5: Add per-document sync button**

Button tooltip: `Chunkolás indítása`.

- [ ] **Step 6: Run focused tests**

Expected: pass.

---

### Task 7: Training Queue

**Files:**
- Create: `lib/src/knowledge/data/training_queue.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/training_queue_test.dart`
- Test: `test/knowledge_base_screen_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- queue processes selected IDs sequentially
- retry requeues failed document
- cancel stops before next document

Expected: fail because queue does not exist.

- [ ] **Step 2: Implement queue**

Keep v1 in-memory with state: idle, running, cancelRequested.

- [ ] **Step 3: Wire selected-doc action**

Add checkbox selection and `Kijelöltek chunkolása`.

- [ ] **Step 4: Run queue tests**

Expected: pass.

---

### Task 8: Flowchart Extraction And Persistence

**Files:**
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/openai/openai_http_client.dart`
- Modify: `lib/src/ai/gemini_ai_client.dart`
- Test: `test/document_processing_service_test.dart`
- Test: `test/flowchart_validation_screen_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- extraction with one flowchart saves flowchart, nodes, edges
- document becomes `needs_review`
- validation screen lists the extracted flowchart
- flowchart nodes and edges receive embeddings

Expected: fail because extraction does not save flowcharts.

- [ ] **Step 2: Expand extraction schema**

Add `flowcharts` with nodes and edges to OpenAI and Gemini parsing.

- [ ] **Step 3: Save flowchart records**

Save all flowchart records as `unreviewed`.

- [ ] **Step 4: Embed node and edge labels**

Use existing embedding store with source types `flowchart_node` and `flowchart_edge`.

- [ ] **Step 5: Run flowchart tests**

Expected: pass.

---

### Task 9: Training Pack Export/Import

**Files:**
- Create: `lib/src/knowledge/data/training_pack_service.dart`
- Modify: knowledge repositories to list/import chunks, embeddings, flowcharts
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/training_pack_service_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- export contains schema version, document metadata, chunks, embeddings, flowcharts
- import restores ready document without AI calls
- import updates matching content hash instead of duplicating

Expected: fail because pack service does not exist.

- [ ] **Step 2: Implement JSON pack service**

Serialize deterministic JSON. Use `.djinnpack` extension.

- [ ] **Step 3: Wire UI import/export**

Use `FilePicker.platform.saveFile` and `FilePicker.platform.pickFiles` where supported; tests call service directly.

- [ ] **Step 4: Run pack tests**

Expected: pass.

---

### Task 10: RAG Enable Toggle, Collections, Citation Jump

**Files:**
- Modify: `lib/src/rag/retrieval/local_retriever.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Create: `lib/src/knowledge/ui/source_page_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Test: `test/local_retriever_test.dart`
- Test: `test/chat_bubble_test.dart`
- Test: `test/chat_screen_test.dart`

- [ ] **Step 1: Write RED tests**

Tests:

- disabled document chunks are skipped
- collection filter excludes other collections
- citation tap opens source page

Expected: fail because filters and page do not exist.

- [ ] **Step 2: Add repository metadata lookups**

Retriever checks document `ragEnabled` and collection.

- [ ] **Step 3: Add UI controls**

Knowledge row toggle for RAG. Chat collection dropdown.

- [ ] **Step 4: Add source page**

Show filename, page, excerpt, source type.

- [ ] **Step 5: Run retrieval/chat tests**

Expected: pass.

---

### Task 11: Voice-To-Text

**Files:**
- Create: `lib/src/voice/voice_input_service.dart`
- Modify: `lib/src/chat/ui/message_composer.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Test: `test/message_composer_voice_test.dart`

- [ ] **Step 1: Write RED widget test**

Fake service returns `Mi a stroke protokoll?`; tapping microphone fills composer.

Expected: fail because mic support does not exist.

- [ ] **Step 2: Implement service interface and native adapter**

Use `SpeechToText.initialize`, `listen(localeId: 'hu_HU')`, `stop`.

- [ ] **Step 3: Add mic UI**

Use icon button tooltip `Diktálás`.

- [ ] **Step 4: Run voice test**

Expected: pass.

---

### Task 12: Text-To-Speech

**Files:**
- Create: `lib/src/voice/text_to_speech_service.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Test: `test/chat_bubble_tts_test.dart`

- [ ] **Step 1: Write RED widget test**

Fake service records `speak`, `pause`, `stop` calls for assistant message.

Expected: fail because controls do not exist.

- [ ] **Step 2: Implement TTS interface and native adapter**

Use `FlutterTts.setLanguage`, `setSpeechRate`, `setPitch`, `speak`, `pause`, `stop`.

- [ ] **Step 3: Add assistant controls**

Show play/pause/stop only for assistant messages.

- [ ] **Step 4: Run TTS test**

Expected: pass.

---

### Task 13: Admin/Maintenance Screen

**Files:**
- Create: `lib/src/admin/ui/admin_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Add repository maintenance methods
- Test: `test/admin_screen_test.dart`

- [ ] **Step 1: Write RED test**

Test drawer opens Admin, summary is visible, destructive clear requires confirmation.

Expected: fail because screen does not exist.

- [ ] **Step 2: Implement screen**

Show document/chunk/flowchart counts, pack import/export actions, clear knowledge action, rebuild embeddings action.

- [ ] **Step 3: Wire drawer**

Add `Admin` item below settings.

- [ ] **Step 4: Run admin test**

Expected: pass.

---

### Task 14: Integration Wiring

**Files:**
- Modify: `lib/main.dart`
- Modify all constructor call sites
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write RED integration test**

Test app opens knowledge base, imports PDF without auto-processing, opens settings provider controls, opens admin, and chat composer shows mic.

Expected: fail until dependencies are wired.

- [ ] **Step 2: Wire dependencies**

Instantiate provider-aware AI client, key stores, voice/TTS services, repositories and pack service.

- [ ] **Step 3: Run integration test**

Expected: pass.

---

### Task 15: Full Verification And Release

**Files:**
- All changed files

- [ ] **Step 1: Format**

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && /home/flutteruser/flutter/bin/dart format lib test'
```

- [ ] **Step 2: Analyze**

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && timeout 300s /home/flutteruser/flutter/bin/flutter analyze'
```

Expected: no issues.

- [ ] **Step 3: Test**

```bash
proot-distro login --user flutteruser ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-workflow-upgrades && timeout 420s /home/flutteruser/flutter/bin/flutter test'
```

Expected: all tests pass with the known ObjectBox host-library skip if present.

- [ ] **Step 4: Commit and push**

```bash
git status --short
git add .
git commit -m "feat: upgrade knowledge workflow"
git push origin feature/knowledge-workflow-upgrades
```

- [ ] **Step 5: Run one online APK build**

```bash
gh -R elizerpist/djinn workflow run android-native-build.yml --ref feature/knowledge-workflow-upgrades
gh -R elizerpist/djinn run watch <run-id> --exit-status
```

Expected: workflow success and `debug-latest` release asset updated.
