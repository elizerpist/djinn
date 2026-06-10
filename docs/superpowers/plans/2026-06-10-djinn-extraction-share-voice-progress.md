# Djinn Extraction Share Voice Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix image/table RAVE extraction, flowchart candidates, answer language, native share, re-sync, settings grouping, voice input, per-bubble TTS, and Tudastar processing progress in one tested release.

**Architecture:** Extend the existing local ObjectBox-first pipeline instead of replacing it. `AiClient.extractDocument` returns richer structured extraction results, `DocumentProcessingService` persists text/table/score evidence plus flowchart candidates while emitting progress, and the Tudastar UI renders compact row-level status. Voice and TTS remain local Android services through adapters so tests can use fakes.

**Tech Stack:** Flutter, Dart, ObjectBox, FilePicker, archive ZIP package, speech_to_text, flutter_tts, planned `share_plus`, pdfrx, existing GitHub Actions APK workflow.

---

## Scope Guardrails

- [ ] Keep current working text chunking green while adding richer extraction.
- [ ] Do not show disabled placeholder menu items.
- [ ] Do not require the original external PDF path after import.
- [ ] Do not run local APK builds in Termux.
- [ ] Run one online APK build only after all implementation tests pass.

## Subagent Partition

- Extraction agent: Tasks 1-3.
- Tudastar UI/share agent: Task 4.
- Settings/language agent: Task 5.
- Voice/chat agent: Task 6.
- Main integrator: Task 7 and all cross-task review.

Do not dispatch agents that edit the same file at the same time. `lib/src/ai/ai_client.dart`, `lib/src/knowledge/data/document_processing_service.dart`, and `lib/src/chat/ui/chat_screen.dart` are integration points and should be reviewed in the main session after each task lands.

## File Map

- Modify `pubspec.yaml`: add `share_plus` for native Android share.
- Modify `lib/src/ai/ai_client.dart`: add table, score, and flowchart extraction models.
- Modify `lib/src/google/gemini_http_client.dart`: richer extraction schema, RAVE/table/flowchart parse, answer language instruction.
- Modify `lib/src/openai/openai_http_client.dart`: same extraction model and answer language instruction.
- Modify `lib/src/knowledge/data/document_processing_service.dart`: progress events, re-sync mode, save generated evidence and flowchart candidates.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`: JSON/in-memory clear generated knowledge, save evidence, save flowchart candidates.
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: ObjectBox clear generated knowledge, save evidence source type, save flowchart records.
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: expose new repository methods to UI/service layer.
- Modify `lib/src/local_store/entities.dart`: add source types for table/score evidence if needed.
- Regenerate `objectbox.g.dart` and `lib/objectbox-model.json` only if entity fields change.
- Create `lib/src/knowledge/data/knowledge_pack_share_service.dart`: build/share a `.djinnpack` through an adapter.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: share action, re-sync label, row progress state wiring.
- Modify `lib/src/knowledge/ui/knowledge_document_row.dart`: row-bottom progress strip and status text.
- Modify `lib/src/settings/ui/settings_screen.dart`: move TTS/language controls out of AI block.
- Modify `lib/src/voice/speech_adapter.dart`: resolved locale diagnostics and server-disconnected handling.
- Modify `lib/src/voice/voice_controller.dart`: active message id for TTS and cleaner listener state.
- Modify `lib/src/voice/voice_controls.dart`: mic-only input control.
- Modify `lib/src/chat/ui/message_composer.dart`: input row only has text, mic, send.
- Modify `lib/src/chat/ui/chat_bubble.dart`: per-bubble play/pause/resume/stop.
- Modify `lib/src/chat/ui/chat_screen.dart`: conversation vs push-to-talk routing, per-message TTS state.
- Modify tests in `test/gemini_http_client_test.dart`, `test/openai_http_client_test.dart`, `test/document_processing_service_test.dart`, `test/knowledge_base_screen_test.dart`, `test/knowledge_pack_service_test.dart`, `test/settings_screen_test.dart`, `test/voice_controller_test.dart`, `test/chat_bubble_test.dart`, `test/chat_screen_voice_test.dart`.

---

## Task 1: Extraction Model And Repository Contract

**Files:**
- Modify: `lib/src/ai/ai_client.dart`
- Modify: `lib/src/local_store/entities.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Test: `test/document_processing_service_test.dart`
- Test: `test/knowledge_document_repository_test.dart`

- [ ] **Step 1: Write failing model/repository tests**

Add a test proving generated knowledge can be cleared before re-sync:

```dart
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

  expect((await repository.exportChunkPackage(document.id)).chunks, hasLength(1));

  await repository.clearGeneratedKnowledge(document.id);

  expect((await repository.exportChunkPackage(document.id)).chunks, isEmpty);
});
```

Add a processing repository fake assertion in `test/document_processing_service_test.dart`:

```dart
test('re-sync clears generated knowledge before extraction', () async {
  final repository = MemoryProcessingRepository();
  final service = DocumentProcessingService(
    openAiClient: _ExtractingOpenAiClient(),
    loadSettings: () async => AppSettings.defaults(),
    hasApiKey: () async => true,
    repository: repository,
  );

  await service.processDocument('doc-1', forceReprocess: true);

  expect(repository.clearedDocuments, ['doc-1']);
});
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
flutter test test/document_processing_service_test.dart test/knowledge_document_repository_test.dart
```

Expected: FAIL because `AiExtractedEvidence`, `AiEvidenceSourceType`, `saveExtractedEvidence`, `clearGeneratedKnowledge`, and `forceReprocess` do not exist.

- [ ] **Step 3: Add extraction model classes**

In `lib/src/ai/ai_client.dart`, add focused types while preserving old chunk compatibility:

```dart
enum AiEvidenceSourceType {
  textChunk('text_chunk'),
  table('table_chunk'),
  score('score_chunk');

  const AiEvidenceSourceType(this.wireName);
  final String wireName;
}

class AiExtractedEvidence {
  const AiExtractedEvidence({
    required this.id,
    required this.text,
    required this.pageNumber,
    required this.sourceType,
    this.sectionTitle,
  });

  final String id;
  final String text;
  final int pageNumber;
  final AiEvidenceSourceType sourceType;
  final String? sectionTitle;
}

class AiFlowchartCandidate {
  const AiFlowchartCandidate({
    required this.id,
    required this.pageNumber,
    required this.nodes,
    required this.edges,
    this.title,
    this.confidence,
  });

  final String id;
  final int pageNumber;
  final String? title;
  final double? confidence;
  final List<AiFlowchartNode> nodes;
  final List<AiFlowchartEdge> edges;
}

class AiFlowchartNode {
  const AiFlowchartNode({required this.id, required this.label});
  final String id;
  final String label;
}

class AiFlowchartEdge {
  const AiFlowchartEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.label,
  });

  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String label;
}
```

Extend `AiExtractionResult`:

```dart
class AiExtractionResult {
  const AiExtractionResult({
    required this.chunks,
    this.evidence = const [],
    this.flowcharts = const [],
  });

  final List<AiExtractedChunk> chunks;
  final List<AiExtractedEvidence> evidence;
  final List<AiFlowchartCandidate> flowcharts;

  List<AiExtractedEvidence> get allEvidence => [
    for (final chunk in chunks)
      AiExtractedEvidence(
        id: chunk.id,
        text: chunk.text,
        pageNumber: chunk.pageNumber,
        sectionTitle: chunk.sectionTitle,
        sourceType: AiEvidenceSourceType.textChunk,
      ),
    ...evidence,
  ];
}
```

- [ ] **Step 4: Add repository contract methods**

In `ProcessingRepository`, add:

```dart
Future<void> clearGeneratedKnowledge(String documentPublicId);

Future<void> saveExtractedEvidence({
  required String documentPublicId,
  required AiExtractedEvidence evidence,
  required List<double> embedding,
  required String embeddingModel,
});

Future<void> saveFlowchartCandidate({
  required String documentPublicId,
  required AiFlowchartCandidate flowchart,
});
```

Keep `saveExtractedChunk` as a compatibility wrapper that calls `saveExtractedEvidence`.

- [ ] **Step 5: Implement JSON and ObjectBox repositories**

In the JSON repository, remove `_chunksByDocument[documentId]` and model metadata in `clearGeneratedKnowledge`.

In ObjectBox repository, clear text/table/score embeddings and flowchart records for the document. Use these source type mappings:

```dart
EvidenceSourceType.textChunk.wireName
'table_chunk'
'score_chunk'
```

If adding enum cases to `EvidenceSourceType`, regenerate ObjectBox only if entity shape changes; enum constants alone do not require model regeneration.

- [ ] **Step 6: Run targeted tests GREEN**

Run:

```bash
flutter test test/document_processing_service_test.dart test/knowledge_document_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/ai/ai_client.dart lib/src/local_store/entities.dart lib/src/knowledge/data/document_processing_service.dart lib/src/knowledge/data/knowledge_document_repository.dart lib/src/knowledge/data/objectbox_knowledge_repository.dart lib/src/knowledge/data/objectbox_knowledge_document_repository.dart test/document_processing_service_test.dart test/knowledge_document_repository_test.dart
git commit -m "feat: add rich extraction repository contract"
```

---

## Task 2: Gemini/OpenAI Table, RAVE, Flowchart, And Language Schemas

**Files:**
- Modify: `lib/src/google/gemini_http_client.dart`
- Modify: `lib/src/openai/openai_http_client.dart`
- Test: `test/gemini_http_client_test.dart`
- Test: `test/openai_http_client_test.dart`

- [ ] **Step 1: Write failing Gemini extraction test**

Add a test response with one RAVE score row and one flowchart:

```dart
test('parses Gemini tables scores and flowchart candidates', () async {
  final keyStore = MemoryApiKeyStore();
  await keyStore.saveKeyForProvider(AiProvider.gemini, 'gemini-key');
  final tempDir = await Directory.systemTemp.createTemp('djinn_gemini_test_');
  addTearDown(() => tempDir.delete(recursive: true));
  final pdf = File('${tempDir.path}/rave.pdf')..writeAsBytesSync([1, 2, 3]);

  final client = GeminiHttpClient(
    apiKeyStore: keyStore,
    baseUri: Uri.parse('https://gemini.test'),
    httpClient: MockClient((request) async {
      expect(request.body, contains('"scores"'));
      expect(request.body, contains('"flowcharts"'));
      return http.Response(jsonEncode({
        'candidates': [{
          'content': {'parts': [{'text': jsonEncode({
            'chunks': [],
            'tables': [{
              'id': 'table-1',
              'page_number': 2,
              'title': 'RAVE score',
              'rows': [{'label': 'Arcparesis', 'value': '1', 'text': 'Arcparesis - 1 pont'}]
            }],
            'scores': [{
              'id': 'rave-arc',
              'page_number': 2,
              'score_name': 'RAVE',
              'criterion': 'Arcparesis',
              'value': '1',
              'text': 'RAVE Arcparesis 1 pont'
            }],
            'flowcharts': [{
              'id': 'flow-1',
              'page_number': 3,
              'title': 'Stroke dontesi fa',
              'confidence': 0.82,
              'nodes': [{'id': 'n1', 'label': 'FAST pozitiv'}],
              'edges': []
            }]
          })}]}
        }]
      }), 200);
    }),
  );

  final result = await client.extractDocument(
    pdfPath: pdf.path,
    model: 'gemini-2.5-flash-lite',
    chunkingMode: ChunkingModes.normal,
  );

  expect(result.evidence.single.sourceType, AiEvidenceSourceType.score);
  expect(result.evidence.single.text, contains('RAVE'));
  expect(result.flowcharts.single.nodes.single.label, 'FAST pozitiv');
});
```

- [ ] **Step 2: Write failing answer language tests**

In Gemini and OpenAI HTTP client tests, assert request bodies include the rule:

```dart
expect(request.body, contains('Hungarian'));
expect(request.body, contains('ambiguous'));
expect(request.body, contains('English'));
```

Use a Hungarian question and verify the request body still tells the provider to answer Hungarian by default.

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
flutter test test/gemini_http_client_test.dart test/openai_http_client_test.dart
```

Expected: FAIL because schemas only contain `chunks` and answer language rule is missing.

- [ ] **Step 4: Extend extraction instructions and schemas**

Add extraction instruction text for image/table content:

```dart
const _visualExtractionInstruction = '''
If a page contains a table, score, or flowchart as an image, extract it from the PDF image content. Preserve clinically relevant table rows. For RAVE or other scores, return each criterion as a score item. For flowcharts, return candidate nodes and directed edges; do not invent uncertain nodes.
''';
```

Extend provider schemas with:

```dart
'tables': {'type': 'array', 'items': _tableSchema},
'scores': {'type': 'array', 'items': _scoreSchema},
'flowcharts': {'type': 'array', 'items': _flowchartSchema},
```

For Gemini, use single string `type` values and `nullable: true`; do not use JSON Schema type arrays.

- [ ] **Step 5: Parse tables/scores/flowcharts**

Convert table rows and score rows to `AiExtractedEvidence`:

```dart
AiExtractedEvidence(
  id: id,
  text: '$scoreName: $criterion - $value. $text',
  pageNumber: pageNumber,
  sectionTitle: scoreName,
  sourceType: AiEvidenceSourceType.score,
)
```

Convert flowcharts to `AiFlowchartCandidate`. If a flowchart has no nodes, skip it and log invalid structured response only if the shape is malformed.

- [ ] **Step 6: Add answer language rule**

For both providers, add this exact policy to the answer instruction:

```text
Answer language policy: detect the latest user question language. If it is Hungarian, answer in Hungarian. If it is ambiguous or mixed, answer in Hungarian. If it is clearly English, answer in English. Do not choose the answer language from the source document language alone.
```

In `LocalAnswerService.answer`, before `generateAnswer`, log:

```dart
DebugConsole.log('[Chat/RAG] answer language=auto default=hu');
```

- [ ] **Step 7: Run targeted tests GREEN**

Run:

```bash
flutter test test/gemini_http_client_test.dart test/openai_http_client_test.dart test/chat_service_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/google/gemini_http_client.dart lib/src/openai/openai_http_client.dart test/gemini_http_client_test.dart test/openai_http_client_test.dart test/chat_service_test.dart
git commit -m "feat: extract tables scores flowcharts and enforce answer language"
```

---

## Task 3: Processing Progress, Flowchart Persistence, And Re-Sync

**Files:**
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/knowledge/models/knowledge_document.dart`
- Test: `test/document_processing_service_test.dart`
- Test: `test/flowchart_validation_test.dart`

- [ ] **Step 1: Write failing processing progress test**

```dart
test('emits extraction and embedding progress', () async {
  final repository = MemoryProcessingRepository();
  final events = <ProcessingProgress>[];
  final service = DocumentProcessingService(
    openAiClient: _ExtractingTwoChunkClient(),
    loadSettings: () async => AppSettings.defaults(),
    hasApiKey: () async => true,
    repository: repository,
    onProgress: events.add,
  );

  await service.processDocument('doc-1');

  expect(events.map((event) => event.phase), containsAll([
    ProcessingPhase.extracting,
    ProcessingPhase.embedding,
    ProcessingPhase.complete,
  ]));
  expect(events.where((event) => event.phase == ProcessingPhase.embedding).last.current, 2);
  expect(events.where((event) => event.phase == ProcessingPhase.embedding).last.total, 2);
});
```

- [ ] **Step 2: Write failing flowchart persistence test**

```dart
test('persists flowchart candidates from extraction', () async {
  final repository = MemoryProcessingRepository();
  final service = DocumentProcessingService(
    openAiClient: _FlowchartExtractingClient(),
    loadSettings: () async => AppSettings.defaults(),
    hasApiKey: () async => true,
    repository: repository,
  );

  await service.processDocument('doc-1');

  expect(repository.savedFlowcharts.single.id, 'flow-1');
  expect(DebugConsole.allText, contains('[Flowchart] extraction candidates=1'));
  expect(DebugConsole.allText, isNot(contains('text_chunk_schema_only')));
});
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
flutter test test/document_processing_service_test.dart test/flowchart_validation_test.dart
```

Expected: FAIL because progress and flowchart saves are not implemented.

- [ ] **Step 4: Add progress model**

In `document_processing_service.dart`, add:

```dart
enum ProcessingPhase { queued, extracting, embedding, complete, failed }

class ProcessingProgress {
  const ProcessingProgress({
    required this.documentId,
    required this.phase,
    this.current,
    this.total,
    this.label,
  });

  final String documentId;
  final ProcessingPhase phase;
  final int? current;
  final int? total;
  final String? label;
}
```

Add constructor callback:

```dart
final void Function(ProcessingProgress progress)? onProgress;
```

- [ ] **Step 5: Implement re-sync and persistence**

Change `processDocument` signature:

```dart
Future<ProcessingResult> processDocument(
  String documentPublicId, {
  bool forceReprocess = false,
}) async
```

If `forceReprocess` is true, call:

```dart
await repository.clearGeneratedKnowledge(documentPublicId);
```

Then embed `extraction.allEvidence`, not only `extraction.chunks`, and save flowcharts:

```dart
for (final flowchart in extraction.flowcharts) {
  await repository.saveFlowchartCandidate(
    documentPublicId: documentPublicId,
    flowchart: flowchart,
  );
}
```

Log:

```dart
DebugConsole.log('[Flowchart] extraction candidates=${extraction.flowcharts.length} document=$documentPublicId');
```

- [ ] **Step 6: Run tests GREEN**

Run:

```bash
flutter test test/document_processing_service_test.dart test/flowchart_validation_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/src/knowledge/data/document_processing_service.dart lib/src/knowledge/models/knowledge_document.dart test/document_processing_service_test.dart test/flowchart_validation_test.dart
git commit -m "feat: persist extraction progress and flowchart candidates"
```

---

## Task 4: Tudastar Share, Re-Sync Labels, And Row Progress UI

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/src/knowledge/data/knowledge_pack_share_service.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Test: `test/knowledge_base_screen_test.dart`
- Test: `test/knowledge_pack_service_test.dart`

- [ ] **Step 1: Write failing share service test**

```dart
test('shares encoded knowledge pack through adapter', () async {
  final shared = <SharedFile>[];
  final service = KnowledgePackShareService(
    packService: const KnowledgePackService(),
    tempDirectoryProvider: () async => Directory.systemTemp.createTemp('djinn_share_test_'),
    shareAdapter: (file) async => shared.add(file),
  );

  await service.share(
    KnowledgePack(schemaVersion: 1, documents: [
      KnowledgePackDocument(
        filename: 'stroke.pdf',
        documentHash: 'hash',
        pdfBytes: [37, 80, 68, 70],
        chunkPackage: ChunkPackage(
          schemaVersion: 1,
          documentHash: 'hash',
          filename: 'stroke.pdf',
          provider: 'gemini',
          extractionModel: 'gemini-2.5-flash-lite',
          embeddingModel: 'gemini-embedding-001',
          embeddingDimension: 3072,
          chunks: const [],
        ),
      ),
    ]),
  );

  expect(shared.single.path, endsWith('.djinnpack'));
  expect(File(shared.single.path).existsSync(), isTrue);
});
```

- [ ] **Step 2: Write failing UI tests for labels and progress**

Add tests:

```dart
testWidgets('processed selection shows re-sync label', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(
    filename: 'ready.pdf',
    localPath: '/memory/ready.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026),
    sha256: 'hash',
  );
  await repository.updateStatus('document-1', KnowledgeDocumentStatus.ready);

  await tester.pumpWidget(MaterialApp(home: KnowledgeBaseScreen(
    repository: repository,
    importService: _FakePdfImportService(),
    processingService: _NoopProcessingService(repository),
  )));
  await _pumpUntilFound(tester, find.text('ready.pdf'));
  await tester.longPress(find.text('ready.pdf'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
  await tester.pumpAndSettle();

  expect(find.textContaining('Ujraszinkron'), findsOneWidget);
});

testWidgets('processing row shows progress strip', (tester) async {
  final document = KnowledgeDocument(
    id: 'doc-1',
    filename: 'syncing.pdf',
    localPath: '/memory/syncing.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026),
    status: KnowledgeDocumentStatus.processing,
  );
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: KnowledgeDocumentRow(
    document: document,
    selectionMode: false,
    selected: false,
    processing: true,
    progressLabel: 'Embedding 4/15',
    progressValue: 4 / 15,
    onTap: () {},
    onLongPress: () {},
    onSelectionChanged: (_) {},
  ))));

  expect(find.text('Embedding 4/15'), findsOneWidget);
  expect(find.byKey(const Key('document-progress-doc-1')), findsOneWidget);
});
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart test/knowledge_pack_service_test.dart
```

Expected: FAIL because share service, re-sync label, and row progress props do not exist.

- [ ] **Step 4: Add native share dependency**

Run:

```bash
flutter pub add share_plus
```

Expected: `pubspec.yaml` and `pubspec.lock` update.

- [ ] **Step 5: Implement share service**

Create `knowledge_pack_share_service.dart` with:

```dart
class SharedFile {
  const SharedFile({required this.path, required this.filename});
  final String path;
  final String filename;
}

typedef ShareAdapter = Future<void> Function(SharedFile file);
```

Use `XFile(file.path, mimeType: 'application/octet-stream', name: filename)` with `SharePlus.instance.share(...)` or the current `share_plus` API resolved by `flutter pub add`.

- [ ] **Step 6: Wire UI**

In selected menu:

- if any selected document is ready, label sync action `Ujraszinkronizalas`;
- otherwise label `Szinkronizalas`;
- add `Megosztas` using native share icon only when exactly one selected document can be packed;
- call `_processDocument(id, forceReprocess: document.status.isReady)`.

In `KnowledgeDocumentRow`, add:

```dart
final String? progressLabel;
final double? progressValue;
```

At row bottom render:

```dart
if (progressLabel != null) ...[
  const SizedBox(height: 6),
  LinearProgressIndicator(
    key: Key('document-progress-${document.id}'),
    value: progressValue,
  ),
  const SizedBox(height: 4),
  Text(progressLabel!, style: const TextStyle(fontSize: 11)),
]
```

- [ ] **Step 7: Run targeted tests GREEN**

Run:

```bash
flutter test test/knowledge_base_screen_test.dart test/knowledge_pack_service_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/knowledge/data/knowledge_pack_share_service.dart lib/src/knowledge/ui/knowledge_base_screen.dart lib/src/knowledge/ui/knowledge_document_row.dart test/knowledge_base_screen_test.dart test/knowledge_pack_service_test.dart
git commit -m "feat: share packs and show knowledge processing progress"
```

---

## Task 5: Settings Grouping And Language Placement

**Files:**
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Test: `test/settings_screen_test.dart`

- [ ] **Step 1: Write failing settings grouping test**

```dart
testWidgets('language and TTS controls live outside AI block', (tester) async {
  final keyStore = MemoryApiKeyStore();
  var settings = AppSettings.defaults();

  await tester.pumpWidget(MaterialApp(home: SettingsScreen(
    apiKeyStore: keyStore,
    loadSettings: () async => settings,
    saveSettings: (value) async => settings = value,
    testApiKey: () async => true,
    testApiKeyForProvider: (_) async => true,
  )));
  await tester.pumpAndSettle();

  expect(find.text('AI'), findsOneWidget);
  expect(find.text('Nyelv es felolvasas'), findsOneWidget);
  expect(find.byKey(const Key('tts-locale-dropdown')), findsOneWidget);
  expect(find.text('Push-to-talk'), findsNothing);
  expect(find.text('Parbeszed'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify RED**

Run:

```bash
flutter test test/settings_screen_test.dart
```

Expected: FAIL because `Felolvasas hangja` is still inside the AI block and the section title does not exist.

- [ ] **Step 3: Move controls**

In `SettingsScreen`, remove `_TtsLocaleDropdown` from AI `_Section`. Add a new `_Section` after AI:

```dart
_Section(
  title: 'Nyelv es felolvasas',
  children: [
    _TtsLocaleDropdown(
      value: _settings.voiceLocale,
      onChanged: (value) => _autoSave(_settings.copyWith(voiceLocale: value)),
    ),
  ],
),
```

Keep chunking mode in AI.

- [ ] **Step 4: Run settings tests GREEN**

Run:

```bash
flutter test test/settings_screen_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/settings/ui/settings_screen.dart test/settings_screen_test.dart
git commit -m "fix: move language controls out of ai settings"
```

---

## Task 6: Voice Diagnostics And Per-Bubble TTS Controls

**Files:**
- Modify: `lib/src/voice/speech_adapter.dart`
- Modify: `lib/src/voice/voice_controller.dart`
- Modify: `lib/src/voice/voice_controls.dart`
- Modify: `lib/src/chat/ui/message_composer.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Test: `test/voice_controller_test.dart`
- Test: `test/chat_bubble_test.dart`
- Test: `test/chat_screen_voice_test.dart`

- [ ] **Step 1: Write failing voice diagnostic tests**

Add a fake engine test in `test/voice_controller_test.dart` or new `test/speech_adapter_test.dart`:

```dart
test('speech adapter logs requested normalized system and selected locale', () async {
  final adapter = SpeechToTextAdapter(engine: _LocaleRecordingEngine(
    locales: ['hu_HU', 'en_US'],
    systemLocale: 'en_US',
  ));

  await adapter.listen(locale: 'hu-HU').drain<void>();

  expect(DebugConsole.allText, contains('requested=hu-HU'));
  expect(DebugConsole.allText, contains('normalized=hu_HU'));
  expect(DebugConsole.allText, contains('selected=hu_HU'));
});

test('server disconnected does not retry endlessly', () async {
  final engine = _FailingEngine(errorCode: 'error_server_disconnected');
  final adapter = SpeechToTextAdapter(engine: engine);

  await adapter.listen(locale: 'hu-HU').drain<void>();

  expect(engine.listenCount, 1);
  expect(DebugConsole.allText, contains('error_server_disconnected'));
});
```

- [ ] **Step 2: Write failing per-bubble TTS tests**

In `test/chat_bubble_test.dart`:

```dart
testWidgets('speaking assistant bubble shows pause and stop', (tester) async {
  final message = ChatMessage(
    id: 'assistant-1',
    conversationId: 'c1',
    sender: ChatSender.assistant,
    text: 'Valasz.',
    createdAt: DateTime.utc(2026),
  );

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: ChatBubble(
    message: message,
    ttsState: BubbleTtsState.speaking,
    onPause: (_) {},
    onStop: (_) {},
  ))));

  expect(find.byKey(const ValueKey('assistant-pause-assistant-1')), findsOneWidget);
  expect(find.byKey(const ValueKey('assistant-stop-assistant-1')), findsOneWidget);
  expect(find.byKey(const ValueKey('assistant-play-assistant-1')), findsNothing);
});
```

In `test/chat_screen_voice_test.dart`, assert the input row has no global TTS controls:

```dart
expect(find.byKey(const ValueKey('voice-pause')), findsNothing);
expect(find.byKey(const ValueKey('voice-stop')), findsNothing);
expect(find.byKey(const ValueKey('voice-listen')), findsOneWidget);
```

- [ ] **Step 3: Run tests to verify RED**

Run:

```bash
flutter test test/voice_controller_test.dart test/chat_bubble_test.dart test/chat_screen_voice_test.dart
```

Expected: FAIL because diagnostics and per-bubble state do not exist.

- [ ] **Step 4: Improve speech diagnostics**

In `SpeechToTextAdapter._resolveLocale`, log:

```dart
DebugConsole.log(
  '[Voice/STT] locale requested=$requestedLocale normalized=$normalized system=${systemLocale ?? 'none'} available=${locales.length} selected=$selected',
);
```

For `error_server_disconnected`, emit the error and close; do not call `_listenWithResolvedLocale` again.

- [ ] **Step 5: Make input mic-only**

In `VoiceControls`, remove pause/stop rendering. It should only render:

```dart
IconButton(
  key: const ValueKey('voice-listen'),
  tooltip: 'Hangbevitel',
  onPressed: busy ? null : () => _startListening(VoiceInputMode.conversation),
  onLongPress: busy ? null : () => _startListening(VoiceInputMode.pushToTalk),
  icon: Icon(listening ? Icons.graphic_eq : Icons.mic),
)
```

- [ ] **Step 6: Add per-bubble TTS state**

In `chat_bubble.dart`, add:

```dart
enum BubbleTtsState { idle, speaking, paused }
```

Add callbacks:

```dart
final BubbleTtsState ttsState;
final ValueChanged<ChatMessage>? onPlay;
final ValueChanged<ChatMessage>? onPause;
final ValueChanged<ChatMessage>? onResume;
final ValueChanged<ChatMessage>? onStop;
```

Render play/pause/resume/stop based on `ttsState`.

In `ChatScreen`, track:

```dart
String? _speakingMessageId;
String? _pausedMessageId;
```

Set the ids when calling `_voiceController.speak`, `pauseTts`, and `stopTts`.

- [ ] **Step 7: Run targeted tests GREEN**

Run:

```bash
flutter test test/voice_controller_test.dart test/chat_bubble_test.dart test/chat_screen_voice_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/src/voice/speech_adapter.dart lib/src/voice/voice_controller.dart lib/src/voice/voice_controls.dart lib/src/chat/ui/message_composer.dart lib/src/chat/ui/chat_bubble.dart lib/src/chat/ui/chat_screen.dart test/voice_controller_test.dart test/chat_bubble_test.dart test/chat_screen_voice_test.dart
git commit -m "fix: stabilize voice input and move tts controls to bubbles"
```

---

## Task 7: Full Verification, Push, And One Online APK

**Files:**
- Verify all touched files.

- [ ] **Step 1: Format**

Run:

```bash
dart format lib test
```

Expected: command completes without formatting errors.

- [ ] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Test**

Run:

```bash
flutter test
```

Expected: all normal tests pass; existing ObjectBox host-library skips remain acceptable if they match the previous pattern.

- [ ] **Step 4: Diff check**

Run:

```bash
git diff --check
```

Expected: no output.

- [ ] **Step 5: Review user-visible checklist**

Confirm in the final implementation notes:

- RAVE image/table evidence path exists.
- Flowchart candidates persist and validation list can show them.
- Hungarian default answer policy is in both providers.
- Native share uses `.djinnpack`.
- Ready PDFs show re-sync.
- Language/TTS is outside AI settings.
- Voice has diagnostics and no retry loop on server disconnect.
- Input has only mic; AI bubbles own TTS controls.
- PDF rows show progress strip.

- [ ] **Step 6: Push branch**

Run:

```bash
git status --short --branch
git push origin feature/knowledge-ai-voice-upgrades
```

Expected: branch pushed to GitHub.

- [ ] **Step 7: Trigger exactly one online Android debug build**

Run the existing GitHub Actions workflow for debug APK, then wait for completion. Do not run a local APK build.

Expected final artifact:

```text
https://github.com/elizerpist/djinn/releases/download/debug-latest/djinn-debug.apk
```

---

## Self-Review Notes

- Spec coverage: all 06-10 follow-up spec items map to Tasks 1-6.
- Placeholder scan: visible unfinished menu actions are explicitly forbidden; plan contains no implementation placeholders.
- Type consistency: `AiExtractedEvidence`, `AiFlowchartCandidate`, `ProcessingProgress`, and `BubbleTtsState` are introduced before later tasks use them.
- Scope: this is a multi-subsystem plan, but each task produces testable app behavior and can be assigned to independent agents with integration review.
