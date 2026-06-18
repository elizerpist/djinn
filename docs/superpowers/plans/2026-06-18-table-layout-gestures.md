# Table Layout Gestures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add table pinch zoom, row/column drag reorder, column/row size adjustment, and temporary rail style toggles.

**Architecture:** Persist table layout dimensions on `NoteBlock` as optional `tableColumnWidths` and `tableRowHeights`. Keep pinch zoom and rail toggle choices as editor-session UI state. Implement row/column reorder in `NoteTableEditorScreen` so table data, layout metadata, scoped tag targets, and text controllers stay aligned.

**Tech Stack:** Flutter widgets, widget tests, existing `NoteBlock` JSON model, existing `NoteSelectionActionRail`.

## Global Constraints

- Existing table rows, scoped tags, and old serialized notes must remain readable.
- Max zoom-in is the current default scale (`1.0`); pinch only zooms out down to a readable minimum.
- Row/column reorder must remap `tableCell`, `tableRow`, and `tableColumn` tag targets.
- Column width and row height changes must persist through `NoteBlock.toJson` / `fromJson`.
- Rail style toggle 1 switches between separator-only rail and rounded cell-card rail.
- Rail style toggle 2 switches rail background between white and transparent.
- No unrelated table tag behavior changes in this pass.

---

### Task 1: Model Layout Metadata

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Test: `test/note_document_test.dart`

**Interfaces:**
- Produces: `NoteBlock.tableColumnWidths`, `NoteBlock.tableRowHeights`, `NoteBlock.copyWith(tableColumnWidths:, tableRowHeights:)`.

- [x] Write a failing test that serializes a table block with widths/heights and parses it back.
- [x] Add model fields with JSON parsing/serialization.
- [ ] Run `flutter test test/note_document_test.dart` (local Flutter SDK unavailable; verify through GitHub Actions).

### Task 2: Row And Column Reorder

**Files:**
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Test: `test/note_table_editor_screen_test.dart`

**Interfaces:**
- Produces: `_moveRow(int from, int to)`, `_moveColumn(int from, int to)`.

- [x] Write failing widget tests for row reorder and column reorder, including scoped tag remap.
- [x] Implement long-press draggable row heads and column heads with drag targets.
- [x] Move persisted row heights and column widths with their row/column.
- [ ] Run `flutter test test/note_table_editor_screen_test.dart` (local Flutter SDK unavailable; verify through GitHub Actions).

### Task 3: Resize And Pinch Zoom

**Files:**
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Test: `test/note_table_editor_screen_test.dart`

**Interfaces:**
- Produces: resize handles keyed `note-table-column-resize-<column>` and `note-table-row-resize-<row>`.

- [x] Write failing widget tests for persisted column width, persisted row height, cell-edge resizing, and pinch zoom-out transform.
- [x] Add drag handles for column width and row height on heads and cell edges.
- [x] Add two-finger scale handling with max scale `1.0`.
- [ ] Run `flutter test test/note_table_editor_screen_test.dart` (local Flutter SDK unavailable; verify through GitHub Actions).

### Task 4: Rail Toggle Buttons

**Files:**
- Modify: `lib/src/notes/ui/note_tag_pills.dart`
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Test: `test/note_table_editor_screen_test.dart`

**Interfaces:**
- Produces: `NoteSelectionActionRail.roundedCard`, `NoteSelectionActionRail.transparentBackground`, and table rail action keys `note-table-rail-toggle-rounded` / `note-table-rail-toggle-transparent`.

- [x] Write failing widget tests for rounded rail and transparent rail toggles.
- [x] Add optional style parameters to `NoteSelectionActionRail`.
- [x] Add table-only toggle action buttons.
- [ ] Run targeted table tests (local Flutter SDK unavailable; verify through GitHub Actions).

### Task 5: Verification

- [x] Run `git diff --check`.
- [x] Run targeted Flutter tests locally if available (attempted; `flutter: not found`).
- [ ] Commit and push.
- [ ] Verify GitHub Actions build and APK publish.
