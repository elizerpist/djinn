# Knowledge Export Offline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Finish the Tudastar file-manager flow without touching the working PDF chunking pipeline.

**Architecture:** Keep chunk extraction unchanged. Add missing UI bindings around existing ObjectBox chunk package import/export, route all PDF-specific operations through the header selection menu, make imports folder-aware, and expose offline non-LLM answer behavior through settings. Use focused tests around UI behavior and service contracts before implementation.

**Tech Stack:** Flutter, Dart, FilePicker, ObjectBox-backed repositories, existing `ChunkPackage` JSON format, existing `OfflineSearchService`.

---

## Guardrails

- Do not edit `DocumentProcessingService.processDocument` chunk extraction logic except tests proving existing behavior still passes.
- Do not change Gemini/OpenAI extraction prompts or embedding generation.
- Do not add a second APK build; build only once online after all tests pass.

## File Map

- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: folder-aware import target, header-only menus, sort bottom sheet, chunk package import/export UI glue.
- Modify `lib/src/knowledge/ui/knowledge_document_row.dart`: remove per-row 3-dot menu and keep single-tap / long-tap selection behavior.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`: add repository-level chunk package methods for tests and JSON fallback.
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: expose ObjectBox chunk package import/export through the UI-facing repository.
- Modify `lib/src/settings/models/app_settings.dart`: replace boolean-only offline fallback with explicit answer mode while preserving old boolean compatibility.
- Modify `lib/src/settings/data/app_settings_repository.dart`: persist/load explicit answer mode.
- Modify `lib/src/settings/ui/settings_screen.dart`: show answer mode control in `Mukodesi mod`.
- Modify `lib/src/chat/data/local_answer_service.dart`: make forced offline mode bypass API key and AI client calls.
- Modify `test/knowledge_base_screen_test.dart`: UI regression tests for menus, folder-aware import, sort, chunk import/export.
- Modify `test/settings_screen_test.dart`, `test/settings_repository_test.dart`, `test/local_answer_service_test.dart`: offline mode tests.

## Task 1: Header-only PDF menu and active-folder import

- [x] **Step 1: Write failing tests in `test/knowledge_base_screen_test.dart`**

Add tests that:

```dart
testWidgets('imports PDFs into the active folder', (tester) async {
  final repository = KnowledgeDocumentRepository();
  final folder = await repository.createFolder('Eljarasrendek');
  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
      pickPdfs: () async => [
        PickedPdfFile(filename: 'folder.pdf', bytes: [37, 80, 68, 70]),
      ],
    ),
  ));
  await _pumpUntilFound(tester, find.byKey(Key('folder-pill-${folder.id}')));
  await tester.tap(find.byKey(Key('folder-pill-${folder.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('PDF hozzaadasa'));
  await _pumpUntilFound(tester, find.text('folder.pdf'));
  expect((await repository.listDocuments()).single.folderId, folder.id);
});

testWidgets('PDF rows do not show per-row overflow menus', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(
    filename: 'a.pdf',
    localPath: '/memory/a.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 10),
    sha256: 'a',
  );
  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(
      repository: repository,
      importService: _FakePdfImportService(),
    ),
  ));
  await _pumpUntilFound(tester, find.text('a.pdf'));
  expect(find.byKey(const Key('knowledge-general-menu')), findsOneWidget);
  expect(find.byKey(const Key('document-menu-document-1')), findsNothing);
});
```

- [x] **Step 2: Run tests and verify RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /home/flutteruser/flutterapps/djinn/.worktrees/knowledge-ai-voice-upgrades && /home/flutteruser/flutter/bin/flutter test test/knowledge_base_screen_test.dart'
```

Expected: fails because active-folder import stores `folderId == null`, and row menu still exists.

- [x] **Step 3: Implement minimal UI changes**

In `KnowledgeBaseScreen._importPdfs`, pass `folderId: _activeFolderId` to `repository.addDocument`.

In `KnowledgeDocumentRow`, remove:

```dart
required this.onMenu,
final VoidCallback onMenu;
IconButton(
  key: Key('document-menu-${document.id}'),
  tooltip: 'PDF műveletek',
  onPressed: onMenu,
  icon: const Icon(Icons.more_vert),
)
```

In `KnowledgeBaseScreen`, stop passing `onMenu`.

- [x] **Step 4: Run test and verify GREEN**

Run the same `knowledge_base_screen_test.dart` command. Expected: pass for new tests and existing row tests after updating old assertions that expected per-row menu.

## Task 2: Android-style selection menu and sort bottom sheet

- [x] **Step 1: Write failing tests**

Add tests that:

```dart
testWidgets('header menu changes from general to PDF actions after selection', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(
    filename: 'a.pdf',
    localPath: '/memory/a.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 10),
    sha256: 'a',
  );
  await tester.pumpWidget(MaterialApp(
    home: KnowledgeBaseScreen(repository: repository, importService: _FakePdfImportService()),
  ));
  await _pumpUntilFound(tester, find.text('a.pdf'));
  await tester.tap(find.byKey(const Key('knowledge-general-menu')));
  await tester.pumpAndSettle();
  expect(find.text('Rendezés'), findsOneWidget);
  expect(find.text('Chunk csomag export'), findsNothing);
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
  await tester.longPress(find.text('a.pdf'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('knowledge-selection-menu')));
  await tester.pumpAndSettle();
  expect(find.text('Rendezés'), findsNothing);
  expect(find.text('Chunk csomag export'), findsOneWidget);
});

testWidgets('sort opens Android-style bottom sheet and reorders PDFs', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await repository.addDocument(filename: 'b.pdf', localPath: '/memory/b.pdf', sizeBytes: 20, importedAt: DateTime.utc(2026, 6, 9), sha256: 'b');
  await repository.addDocument(filename: 'a.pdf', localPath: '/memory/a.pdf', sizeBytes: 10, importedAt: DateTime.utc(2026, 6, 10), sha256: 'a');
  await tester.pumpWidget(MaterialApp(home: KnowledgeBaseScreen(repository: repository, importService: _FakePdfImportService())));
  await _pumpUntilFound(tester, find.text('a.pdf'));
  await tester.tap(find.byKey(const Key('knowledge-general-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rendezés'));
  await tester.pumpAndSettle();
  expect(find.text('Legújabb legelöl'), findsOneWidget);
  expect(find.text('Név (A→Z)'), findsOneWidget);
  await tester.tap(find.text('Név (A→Z)'));
  await tester.pumpAndSettle();
  final aTop = tester.getTopLeft(find.text('a.pdf')).dy;
  final bTop = tester.getTopLeft(find.text('b.pdf')).dy;
  expect(aTop, lessThan(bTop));
});
```

- [x] **Step 2: Run tests and verify RED**

Expected: sort is popup/no-op and selection menu still contains disabled/incomplete items.

- [x] **Step 3: Implement sort and menu split**

Add private enum:

```dart
enum _KnowledgeSortMode {
  newestFirst,
  oldestFirst,
  largestFirst,
  smallestFirst,
  nameAsc,
  nameDesc,
}
```

Apply sorting in `_visibleDocuments`.

Add `_showSortSheet()` using `showModalBottomSheet` with radio list tiles for all six labels from the screenshot.

General menu actions: `select_all`, `sort`, `new_folder`, `import_knowledge` disabled only if not implemented.

Selection menu actions: `sync`, `move`, `export_chunks`, `import_chunks`, `delete`.

- [x] **Step 4: Run tests and verify GREEN**

Run `flutter test test/knowledge_base_screen_test.dart`.

## Task 3: Chunk package import/export UI

- [x] **Step 1: Add repository contract tests**

In `test/knowledge_document_repository_test.dart`, add tests for JSON fallback repository:

```dart
test('JSON repository exports and imports chunk packages for UI tests', () async {
  final repository = KnowledgeDocumentRepository();
  final document = await repository.addDocument(
    filename: 'a.pdf',
    localPath: '/memory/a.pdf',
    sizeBytes: 4,
    importedAt: DateTime.utc(2026, 6, 10),
    sha256: 'hash-a',
  );
  await repository.saveExtractedChunk(
    documentPublicId: document.id,
    chunk: const OpenAiExtractedChunk(id: 'p1-main', text: 'ABCDE protokoll', pageNumber: 1),
    embedding: List<double>.filled(3072, 0.1),
    embeddingModel: 'text-embedding-3-large',
  );
  final package = await repository.exportChunkPackage(document.id);
  expect(package.documentHash, 'hash-a');
  await repository.importChunkPackage(document.id, package);
  expect((await repository.listDocuments()).single.status, KnowledgeDocumentStatus.ready);
});
```

- [x] **Step 2: Run repository test and verify RED**

Expected: `exportChunkPackage/importChunkPackage` not exposed on `KnowledgeDocumentRepository`.

- [x] **Step 3: Implement repository contract**

Add methods to `KnowledgeDocumentRepository`:

```dart
Future<ChunkPackage> exportChunkPackage(String documentPublicId)
Future<void> importChunkPackage(String documentPublicId, ChunkPackage package)
```

Store JSON fallback chunks in memory only for tests, using the same schema validation rules as `ChunkPackageService`.

Expose ObjectBox adapter:

```dart
@override
Future<ChunkPackage> exportChunkPackage(String documentPublicId) {
  return _repository.exportChunkPackage(documentPublicId);
}

@override
Future<void> importChunkPackage(String documentPublicId, ChunkPackage package) {
  return _repository.importChunkPackage(documentPublicId, package);
}
```

- [x] **Step 4: Add UI tests for export/import actions**

Inject test callbacks into `KnowledgeBaseScreen`:

```dart
Future<String?> Function(KnowledgeDocument document, ChunkPackage package)? exportChunkPackageForTest
Future<ChunkPackage?> Function(KnowledgeDocument document)? importChunkPackageForTest
```

Test that selected PDF export calls export callback and import updates the document.

- [x] **Step 5: Implement Android file picker/save glue**

Use FilePicker APIs:

```dart
final path = await FilePicker.platform.saveFile(
  dialogTitle: 'Chunk csomag export',
  fileName: '${_safeBaseName(document.filename)}.djinn-chunks.json',
  type: FileType.custom,
  allowedExtensions: ['json'],
);
```

For import:

```dart
final picked = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['json'],
  allowMultiple: false,
  withData: true,
);
```

Use `jsonEncode(package.toJson())` and `ChunkPackage.fromJson(jsonDecode(text))`.

- [x] **Step 6: Run tests and verify GREEN**

Run:

```bash
flutter test test/knowledge_document_repository_test.dart test/knowledge_base_screen_test.dart test/chunk_package_service_test.dart
```

## Task 4: Offline answer mode settings

- [x] **Step 1: Write failing settings tests**

Add tests:

```dart
test('defaults to ai mode and preserves legacy fallback flag', () {
  final settings = AppSettings.defaults();
  expect(settings.answerMode, 'ai');
  expect(settings.offlineFallbackEnabled, isFalse);
  expect(settings.copyWith(answerMode: 'auto_fallback').offlineFallbackEnabled, isTrue);
});
```

In `settings_screen_test.dart`, assert a segmented control or radio group with:

- `AI válasz`
- `Offline keresés`
- `Automatikus fallback`

- [x] **Step 2: Run tests and verify RED**

Expected: `answerMode` missing and UI missing.

- [x] **Step 3: Implement model/repository/UI**

Add constants:

```dart
class AnswerModes {
  static const ai = 'ai';
  static const offline = 'offline';
  static const autoFallback = 'auto_fallback';
}
```

Persist `answerMode` in `AppSettingsEntity` only if ObjectBox schema can be updated safely in this branch; otherwise derive from existing boolean:

- `offlineFallbackEnabled == false` => `ai`
- `offlineFallbackEnabled == true` with no explicit mode => `auto_fallback`

Add UI control in `Működési mód`.

- [x] **Step 4: Implement forced offline behavior**

In `LocalAnswerService.answer`:

```dart
if (settings.answerMode == AnswerModes.offline) {
  DebugConsole.log('[Offline] mode=forced');
  if (!await hasReadyDocuments()) {
    return const LocalAnswerResult(... empty knowledge ...);
  }
  return _offlineAnswer(question, settings);
}
```

Keep `auto_fallback` behavior equivalent to current boolean fallback.

- [x] **Step 5: Run tests and verify GREEN**

Run:

```bash
flutter test test/settings_repository_test.dart test/settings_screen_test.dart test/local_answer_service_test.dart test/offline_search_service_test.dart
```

## Task 5: Full verification, commit, push, online APK

- [x] **Step 1: Format**

Run:

```bash
dart format lib test
```

- [x] **Step 2: Analyze**

Run:

```bash
flutter analyze
```

Expected: `No issues found`.

- [x] **Step 3: Full tests**

Run:

```bash
flutter test
```

Expected: all pass, with only known local ObjectBox host skips if `libobjectbox.so` is unavailable.

- [x] **Step 4: Diff check**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intended files changed.

- [x] **Step 5: Commit and push**

Run:

```bash
git add docs/superpowers/plans/2026-06-10-knowledge-export-offline.md lib test
git commit -m "feat: finish knowledge file actions"
git push origin feature/knowledge-ai-voice-upgrades
```

- [x] **Step 6: Online APK build**

Run:

```bash
gh workflow run android-native-build.yml --ref feature/knowledge-ai-voice-upgrades
gh run watch <run-id> --exit-status
```

Expected: backend, analyze, tests, debug APK build, and release publish all succeed.

- [x] **Step 7: Verify release asset**

Run:

```bash
gh release view debug-latest --json assets,tagName,url
curl -I -L -H "Authorization: Bearer $(gh auth token)" -H "Accept: application/octet-stream" https://api.github.com/repos/elizerpist/djinn/releases/assets/<asset-id>
```

Expected: `content-type: application/vnd.android.package-archive`.
