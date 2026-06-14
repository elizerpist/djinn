# Manual Chunk Local Embedding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the form-only manual chunk editor with a PDF selection workflow, restore grouped extracted-content navigation, fix local chunk granularity, and expose real offline indexing choices.

**Architecture:** Keep the current ObjectBox-first local architecture. Add small, focused model/controller units for extracted-content filtering and local chunk grouping, then wire them into existing screens. Local semantic engines are selectable as settings metadata, while the first working offline index path uses deterministic keyword/BM25-style indexing and retrieval without fake embeddings.

**Tech Stack:** Flutter, Dart, ObjectBox, pdfrx, google_mlkit_text_recognition, existing ObjectBox HNSW vector index, GitHub Actions for Android build.

---

## File Map

- Modify `lib/src/knowledge/data/local_chunk_builder.dart`: block-based chunk grouping, flowchart-like detection, source metadata group ids.
- Modify `test/local_chunk_builder_test.dart`: regression tests for headings, lists, page continuation, and flowchart-like OCR blocks.
- Modify `lib/src/knowledge/ui/extracted_knowledge_screen.dart`: app-bar pipeline menu and type subheader filters.
- Modify `test/extracted_knowledge_screen_test.dart`: UI tests for pipeline menu and type filters.
- Modify `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`: full-screen PDF selection UI and slide-in chunk card.
- Modify `test/manual_chunk_editor_screen_test.dart`: selection-card save flow tests.
- Modify `lib/src/settings/models/app_settings.dart`, `lib/src/settings/data/app_settings_repository.dart`, `lib/src/settings/ui/settings_screen.dart`: offline indexing mode settings.
- Modify `lib/src/local_store/entities.dart`: settings field for local indexing mode if needed; regenerate ObjectBox if entity changes.
- Create `lib/src/offline/local_keyword_index_service.dart`: deterministic keyword/BM25-like scoring over extracted chunks.
- Create `test/local_keyword_index_service_test.dart`: working offline index tests.
- Modify `lib/src/chat/data/local_answer_service.dart` and/or `lib/src/rag/retrieval/local_retriever.dart`: use keyword fallback/expansion when selected.

## Task 1: Local Chunk Builder Granularity

**Files:**
- Modify: `test/local_chunk_builder_test.dart`
- Modify: `lib/src/knowledge/data/local_chunk_builder.dart`

- [ ] **Step 1: Write failing tests**

Add tests that assert:

```dart
test('local builder keeps headings with following paragraph instead of standalone chunks', () {
  final chunks = const LocalChunkBuilder().build(
    documentId: 'doc-1',
    pages: const [
      LocalDocumentPage(
        pageNumber: 1,
        rawText: 'Bevezetes
II
A COPDAE kivaltó okai koze tartozik az infekcio, a dohanyzas es a legszennyezes.',
        ocrText: null,
        textPipeline: LocalExtractionPipeline.localPdfText,
      ),
    ],
  );

  expect(chunks.map((chunk) => chunk.text), isNot(contains('II')));
  expect(chunks.single.text, contains('Bevezetes'));
  expect(chunks.single.text, contains('COPDAE'));
});

test('local builder keeps continued list items in one logical chunk', () {
  final chunks = const LocalChunkBuilder().build(
    documentId: 'doc-1',
    pages: const [
      LocalDocumentPage(
        pageNumber: 1,
        rawText: 'Kivalto okok:
- infekcio
- dohanyzas',
        ocrText: null,
        textPipeline: LocalExtractionPipeline.localPdfText,
      ),
      LocalDocumentPage(
        pageNumber: 2,
        rawText: '- legszennyezes
- terapia elhagyasa',
        ocrText: null,
        textPipeline: LocalExtractionPipeline.localPdfText,
      ),
    ],
  );

  final list = chunks.singleWhere((chunk) => chunk.kind == LocalChunkKind.list);
  expect(list.pageNumber, 1);
  expect(list.endPageNumber, 2);
  expect(list.text, contains('terapia elhagyasa'));
});

test('local builder classifies flowchart-like OCR as flowchart chunk', () {
  final chunks = const LocalChunkBuilder().build(
    documentId: 'doc-1',
    pages: const [
      LocalDocumentPage(
        pageNumber: 1,
        rawText: 'Legzesi elegtelenseg?
IGEN -> Oxigen
NEM -> Celzott O2 terapia
Javult?
IGEN -> Szallitas',
        ocrText: null,
        textPipeline: LocalExtractionPipeline.localOcr,
      ),
    ],
  );

  expect(chunks.single.kind, LocalChunkKind.flowchart);
});
```

- [ ] **Step 2: Run red test**

Run: `flutter test test/local_chunk_builder_test.dart`
Expected: fail because current builder emits heading/line chunks and does not detect flowchart-like blocks.

- [ ] **Step 3: Implement block builder**

Refactor `LocalChunkBuilder` to collect blocks: headings, paragraphs, lists, tables/scores, flowchart-like blocks. Keep public API unchanged.

- [ ] **Step 4: Run green test**

Run: `flutter test test/local_chunk_builder_test.dart`
Expected: pass locally if Flutter works; otherwise verify through GitHub Actions after push.

## Task 2: Extracted Content Pipeline Menu and Type Subheader

**Files:**
- Modify: `test/extracted_knowledge_screen_test.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`

- [ ] **Step 1: Write failing widget tests**

Add tests that open `Kinyert chunkok`, verify header menu entries `AI chunkok`, `Lokalis chunkok`, `Manualis chunkok`, `Osszehasonlitas`, and verify subheader filter chips `Osszes`, `Szoveg`, `Tablazat`, `Flowchart` filter the visible list.

- [ ] **Step 2: Run red test**

Run: `flutter test test/extracted_knowledge_screen_test.dart`
Expected: fail because pipeline mode is currently a `TabBar` occupying the grouping area.

- [ ] **Step 3: Implement UI state**

Add `_ExtractionPipelineView` and `_ExtractionTypeFilter` enums. Replace `DefaultTabController` with local state. Put pipeline selection in `AppBar.actions` as `PopupMenuButton`. Render horizontal filter chips below document summary. Apply pipeline then type filter before rendering.

- [ ] **Step 4: Preserve flowchart hierarchy views**

When the filtered result is entirely flowchart items, keep routing to `_FlowchartHierarchyList`.

- [ ] **Step 5: Run green test**

Run: `flutter test test/extracted_knowledge_screen_test.dart`.

## Task 3: Manual PDF Selection Editor

**Files:**
- Modify: `test/manual_chunk_editor_screen_test.dart`
- Modify: `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`

- [ ] **Step 1: Write failing widget tests**

Test that the screen shows a full-screen PDF selection surface, a selection FAB, a selectable rectangle placeholder after tapping the FAB, a slide-in card with type/title/content fields, and a real save button that calls `saveLocalChunks(... replaceExisting: false)`.

- [ ] **Step 2: Run red test**

Run: `flutter test test/manual_chunk_editor_screen_test.dart`
Expected: fail because current screen is a form-only list.

- [ ] **Step 3: Implement screen shell**

Use the document PDF viewer surface already used by `PdfViewerScreen` where practical. Add overlay selection mode and a bottom sheet/card. If direct PDF text scraping by rectangle is not available, prefill from page text/OCR repository data when available and keep editable content required before save.

- [ ] **Step 4: Implement real save**

Save `LocalExtractionPipeline.manual`, selected `LocalChunkKind`, page number, section title, content, and source rectangle JSON. Do not replace AI or local chunks.

- [ ] **Step 5: Run green test**

Run: `flutter test test/manual_chunk_editor_screen_test.dart`.

## Task 4: Offline Indexing Settings and Keyword Index

**Files:**
- Modify: `lib/src/settings/models/app_settings.dart`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Create: `lib/src/offline/local_keyword_index_service.dart`
- Create: `test/local_keyword_index_service_test.dart`
- Modify: `test/settings_repository_test.dart`
- Modify: `test/settings_screen_test.dart`

- [ ] **Step 1: Write failing settings tests**

Assert settings can persist and render local indexing mode values:

- `mediapipe_text_embedder`
- `onnx_multilingual_e5`
- `embedding_gemma`
- `keyword_bm25`

- [ ] **Step 2: Write failing keyword index tests**

Assert `LocalKeywordIndexService` ranks a COPD deterioration question above unrelated chunks when the relevant chunk contains `COPDAE kivalto okai` and related terms.

- [ ] **Step 3: Run red tests**

Run: `flutter test test/settings_repository_test.dart test/settings_screen_test.dart test/local_keyword_index_service_test.dart`.

- [ ] **Step 4: Implement settings model**

Add a persisted local indexing mode field. If ObjectBox entity changes, regenerate `objectbox.g.dart` and `objectbox-model.json`.

- [ ] **Step 5: Implement keyword/BM25 service**

Tokenize lowercased Hungarian-friendly text, strip common punctuation, score overlap with term frequency and small field boosts for audited/indexed metadata where available.

- [ ] **Step 6: Surface unavailable semantic engines honestly**

MediaPipe, ONNX E5, and EmbeddingGemma are selectable settings, but until model assets are bundled they must show `Modell nincs telepitve`/`Nem indexelt` rather than fake vectors. `keyword_bm25` must work immediately.

- [ ] **Step 7: Run green tests**

Run focused settings and offline index tests.

## Task 5: Status Chips and Retrieval Integration

**Files:**
- Modify: `lib/src/knowledge/models/extracted_knowledge_item.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Modify: `lib/src/rag/retrieval/local_retriever.dart` or `lib/src/chat/data/local_answer_service.dart`
- Modify tests covering document row/status and retrieval fallback.

- [ ] **Step 1: Write failing tests**

Assert extracted items and/or document rows display `Kinyerve`, `Indexelve`, and `Auditalt + indexelt` according to chunk audit/index metadata.

- [ ] **Step 2: Implement status labels and colors**

Use existing chip styling. Do not add large badges that make PDF rows bulky.

- [ ] **Step 3: Integrate keyword fallback/expansion**

When selected indexing mode is `keyword_bm25`, retrieval should use keyword results. When AI vector search is available, keyword results can supplement evidence without replacing higher-score vector matches.

- [ ] **Step 4: Run focused tests**

Run the new and modified tests.

## Verification

- [ ] Run `git diff --check`.
- [ ] Run focused tests where Termux allows it.
- [ ] Commit changes.
- [ ] Push `feature/knowledge-ocr-inspector`.
- [ ] Watch GitHub Actions until backend, ObjectBox generation, analyze, Flutter tests, and debug APK build complete.
