# Knowledge Inspector and PDF Scroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Make extracted tables and flowcharts understandable in the app, improve PDF navigation for fast use, and color knowledge status chips.

**Architecture:** Keep the existing OCR/extraction pipeline intact. Add presentation-layer structure for table rows and flowchart node/edge relationships, pass evidence source type into chat citations, and tune the pdfrx viewer with controller-based page navigation plus scroll physics.

**Tech Stack:** Flutter, Dart, Material widgets, pdfrx, ObjectBox-backed repositories, existing GitHub Actions Android build.

---

### Task 1: PDF Viewer Fast Navigation

**Files:**
- Modify: `lib/src/knowledge/ui/pdf_viewer_screen.dart`
- Covered by analyzer and existing widget/regression tests; PDF rendering is plugin-backed.
- [x] Convert `PdfViewerScreen` from stateless to stateful for PDFs.
- [x] Use `PdfViewerController` with `PdfViewer.file` and `PdfViewerParams` scroll physics/cache parameters.
- [x] Add non-blocking overlay controls for jump previous/next 5 pages and display current/total page.

### Task 2: Extracted Tables and Flowcharts Inspector

**Files:**
- Modify: `lib/src/knowledge/models/extracted_knowledge_item.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/knowledge_base_screen_test.dart`

- [x] Add tests for grouped table rows and flowchart connection display.
- [x] Extend extracted item data with optional flowchart node/edge details.
- [x] Render table/score rows in compact data-like rows instead of only large text blocks.
- [x] Render flowchart nodes and edges separately as logical relationships.

### Task 3: Chat Source Cards

**Files:**
- Modify: `lib/src/chat/models/chat_citation.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/chat/data/objectbox_chat_repository.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Test: `test/chat_bubble_test.dart`
- Test: `test/local_answer_service_test.dart`
- Test: `test/objectbox_chat_repository_test.dart`

- [x] Add source type to chat citations and persistence.
- [x] Add tests for table and flowchart citation source cards.
- [x] Render table citations with compact tabular styling and flowchart citations with route/relationship styling.

### Task 4: Status Chip Colors

**Files:**
- Modify: `lib/src/knowledge/ui/knowledge_document_row.dart`
- Test: `test/knowledge_base_screen_test.dart`

- [x] Keep the existing status badge color test.
- [x] Add semantic color mapping for imported, processing, ready/RAG, review, blocked, and failed states.

### Task 5: Verification and Delivery

- [x] Run `git diff --check`.
- [x] Run available local tests when the toolchain exists; otherwise rely on GitHub Actions.
- [ ] Commit, push branch, trigger Android native build workflow, and report APK link.
