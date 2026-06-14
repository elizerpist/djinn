# Local OCR VectorGraph Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a fully offline local extraction path beside the existing AI chunking path, with local OCR, local chunking, audit, per-PDF chunk comparison, and ObjectBox VectorGraph storage.

**Architecture:** Keep the current AI `DocumentProcessingService` intact and add a separate local processing path. Store AI and local chunks side by side using pipeline metadata, then expose audit and comparison views without overwriting either pipeline.

**Tech Stack:** Flutter, Dart, ObjectBox, `pdfrx`, `google_mlkit_text_recognition`, existing ObjectBox HNSW vector index, GitHub Actions Android build.

---

## Requirements Locked From Discussion

- Bottom nav must be: `Esetek / Audit / Chat / Tudástár / Beáll.`
- The current Flow/Flowchart validation area becomes `Audit`.
- The `Audit` menu is the `Kinyert tartalom audit` workflow. It is not a PDF dropdown item.
- PDF selection menu must replace `Szinkronizálás` with explicit `AI chunkolás` and `Lokális chunkolás`.
- PDF-specific `Kinyert chunkok` must contain `AI chunkok`, `Lokális chunkok`, and live `Összehasonlítás`.
- `Összehasonlítás` must be implemented now and must use real stored data, not placeholders.
- OCR is fully local. No online OCR fallback.
- Use `google_mlkit_text_recognition` with bundled ML Kit text recognition. APK size is not a concern.
- PDF and PNG both go through the local extraction path.
- Existing AI chunking remains available and must not be broken.
- AI and local chunks must not overwrite each other.
- Local ObjectBox VectorGraph is required.

## Local Extraction Pipeline

1. Import document into app-owned storage.
2. For PDFs, keep original PDF and render pages for OCR when needed.
3. For PNGs, use the image directly as a one-page document.
4. Extract and store per-page raw data:
   - PDF text layer where available.
   - OCR text from ML Kit.
   - OCR block/line bounding boxes.
   - page number.
   - source image/cache path where available.
   - source type and confidence.
5. Build local document blocks:
   - sections,
   - paragraphs,
   - bullet lists,
   - continuation lists across page breaks,
   - tables,
   - scores,
   - flowchart/image regions,
   - uncertain blocks needing audit.
6. Build local chunks from blocks.
7. Save local chunks with audit state.
8. Save graph nodes/edges/evidence for local VectorGraph traversal.
9. Mark document as needing audit if any local item is uncertain or unaccepted.

## ObjectBox Data Design

Extend `DocumentChunkEntity` with `pipeline`, `chunkKind`, `auditState`, `confidence`, and `sourcePageImagePath`.

Add local audit/graph entities:

- `DocumentPageEntity`
- `ExtractionAuditItemEntity`
- `KnowledgeNodeEntity`
- `KnowledgeEdgeEntity`
- `KnowledgeEvidenceEntity`
- `VisualObjectEntity`
- `VisualAttributeEntity`

Graph relation types include `part_of`, `continues`, `contains`, `has_attribute`, `mentioned_in`, `source_of`, `causes`, `symptom_of`, `indicates`, `contraindicates`, `next_step`, `yes_branch`, and `no_branch`.

## UI Design

### Bottom nav

Use: `Esetek / Audit / Chat / Tudástár / Beáll.`

### PDF selection menu

When documents are selected:

- `AI chunkolás` or `AI újrachunkolás`
- `Lokális chunkolás` or `Lokális újrachunkolás`
- `Kinyert chunkok`
- `Mozgatás mappába`
- `Chunk+PDF csomag export`
- `Törlés`

### Kinyert chunkok

Per selected PDF:

- `AI chunkok`: only AI pipeline chunks.
- `Lokális chunkok`: only local pipeline chunks.
- `Összehasonlítás`: page/section/type grouped live comparison.

Comparison must show AI-only chunks, local-only chunks, matched page/type chunks, chunk kind labels, page numbers, and local audit state.

### Audit menu

The current Flowchart hub becomes Audit. It contains filters for `Mind`, `Szöveg`, `Táblázat`, `Flowchart`, `Kép`, `Bizonytalan`, and `Elfogadott`, with `Elfogad`, `Szerkeszt`, `Elvet`, and `Újra OCR` actions.

## Implementation Tasks

### Task 1: Tests for local chunk model and comparison

- [ ] Add tests proving AI and local chunks can coexist for one document.
- [ ] Add tests proving local chunk filtering returns only local chunks.
- [ ] Add tests proving AI chunk filtering returns only AI chunks.
- [ ] Add tests proving comparison identifies AI-only, local-only, and matched chunks by page/type.

### Task 2: Data model and repository

- [ ] Extend chunk entities with pipeline/kind/audit metadata.
- [ ] Add page/audit/graph/visual ObjectBox entities.
- [ ] Add repository APIs for saving local extraction pages, local chunks, audit items, graph nodes/edges/evidence.
- [ ] Preserve AI chunk save behavior with default pipeline `ai`.
- [ ] Preserve existing package export behavior for AI chunks.

### Task 3: Local OCR and chunking service

- [ ] Add `google_mlkit_text_recognition`.
- [ ] Add an abstract OCR engine so unit tests can use fakes.
- [ ] Add ML Kit OCR engine for Android/iOS production.
- [ ] Add local document extractor for PDF/PNG.
- [ ] Add deterministic local chunk builder for sections, paragraphs, lists, tables, flowcharts, image regions.
- [ ] Add cross-page list continuation.

### Task 4: Knowledge UI

- [ ] Rename PDF menu actions.
- [ ] Wire `AI chunkolás` to existing `DocumentProcessingService`.
- [ ] Wire `Lokális chunkolás` to new local service.
- [ ] Add per-PDF `Kinyert chunkok` tabs.
- [ ] Add live comparison UI.

### Task 5: Audit UI

- [ ] Rename bottom nav Flow to Audit.
- [ ] Replace Flowchart-first copy with `Kinyert tartalom audit`.
- [ ] Keep flowchart builder access inside Audit hub.
- [ ] Add audit filters and audit item cards.
- [ ] Wire accept/edit/reject to repository.

### Task 6: VectorGraph retrieval

- [ ] Include accepted local chunks in retrieval.
- [ ] Keep rejected audit content out of retrieval.
- [ ] Add keyword+graph expansion layer over vector results.
- [ ] Add debug logs that show vector, keyword, and graph expansion counts.

### Task 7: Build and CI

- [ ] Add GitHub Actions build_runner step before analyze/test/build so ObjectBox generated code is current.
- [ ] Do not run local Flutter APK build in Termux.
- [ ] Push branch and use GitHub Actions for build.
