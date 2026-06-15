# Flowchart Viewer And Editor Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Djinn flowcharts readable on mobile and make the note flowchart editor support large graphs without lag-prone full rendering.

**Architecture:** Add a shared mobile flowchart viewer widget for notes and extracted PDF flowcharts. Keep editing in `NoteFlowchartEditorScreen`, but move the editor canvas to a dynamically expanding virtual coordinate space, render only visible nodes/edges, and replace grouped port chips with a per-port popup editor.

**Tech Stack:** Flutter widgets, `InteractiveViewer`, existing `NoteBlock`/`NoteFlowchart*` models, existing `FlowchartHierarchyGroup` extraction model, widget tests, GitHub Actions for Flutter verification.

---

### Task 1: Editor Regression Tests

**Files:**
- Modify: `test/note_flowchart_editor_screen_test.dart`

- [ ] Add a test that a far-away node keeps expanding the canvas and nearby-only widgets remain visible.
- [ ] Add a test that binary decision `Igen`/`Nem` ports cannot be deleted in the popup.
- [ ] Add a test that a multi-decision branch port label can be edited and the port can be moved to another side.
- [ ] Add a test that preview port dots are aligned around the preview card using deterministic keys.

### Task 2: Mobile Viewer Tests

**Files:**
- Create: `test/mobile_flowchart_viewer_test.dart`
- Modify: `test/extracted_knowledge_screen_test.dart`
- Modify: `test/note_flowchart_editor_screen_test.dart` if note preview integration needs coverage.

- [ ] Test `Lista` default branch cards: decision question and answer in the same card.
- [ ] Test closing a root branch hides only descendants while sibling branch remains visible.
- [ ] Test `Canvas` selector shows a read-only zoomable canvas and no editor controls.
- [ ] Test `Guide` starts at a decision, answer selection shows subprocess, and `Vissza` returns.

### Task 3: Editor Virtual Canvas And Lazy Render

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`

- [ ] Replace fixed `_canvasSize` with dynamic bounds computed from node coordinates plus large margins.
- [ ] Allow node coordinates to expand beyond the initial canvas instead of clamping to 1800x1300.
- [ ] Track the visible `InteractiveViewer` viewport and render only nodes/edges intersecting a padded visible rect.
- [ ] Keep debug logs for viewport, visible node count, canvas bounds, drag/drop, and route decisions.

### Task 4: Popup Port Editor

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Modify: `lib/src/notes/models/note_document.dart` only if model defaults need normalization.

- [ ] Replace grouped side chips with editable per-port rows.
- [ ] Keep binary `Igen` and `Nem` ports mandatory: no delete action, only side relocation.
- [ ] Allow multi-decision custom ports to be renamed inline and moved to any side.
- [ ] Fix popup preview geometry so preview shape and port dots share one coordinate model.

### Task 5: Shared Mobile Flowchart Viewer

**Files:**
- Create: `lib/src/flowchart/ui/mobile_flowchart_viewer.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify: `lib/src/notes/ui/note_chunk_card.dart`

- [ ] Define lightweight `MobileFlowchartData`, `MobileFlowchartNode`, and `MobileFlowchartEdge` classes.
- [ ] Implement `MobileFlowchartViewer` with `Lista`, `Canvas`, and `Guide` segmented control.
- [ ] Convert extracted flowchart groups into `MobileFlowchartData`.
- [ ] Convert note flowchart blocks into `MobileFlowchartData`.

### Task 6: Verification And Push

**Files:**
- Modified files from previous tasks.

- [ ] Run `git diff --check` locally.
- [ ] Commit changes.
- [ ] Push `feature/knowledge-ocr-inspector`.
- [ ] Watch GitHub Actions to verify backend tests, ObjectBox generation, Flutter analyze, Flutter tests, APK build, and release publish.
