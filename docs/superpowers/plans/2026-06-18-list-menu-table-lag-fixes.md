# List Menu And Table Lag Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the missing list chunk layout/menu behavior and remove the table zoom/height lag regressions.

**Architecture:** Keep the shared `NoteSelectionActionRail` as the list/table rail implementation. Add list layout mode persistence on `NoteBlock`, render checkbox or dynamic hierarchy markers from the same `NoteListItem.level`, and remove table scale state so sticky rail math is based only on table width and scroll offset. Table multiline edits update intrinsic row height while typing.

**Tech Stack:** Flutter widgets, widget tests, existing note model JSON serialization, Ubuntu/proot Flutter test runner.

## Global Constraints

- List item selection must not add a blue focus border or tag-colored item background.
- List tag feedback is text-only: first tag is text background; secondary tags are underline layers when implemented.
- List three-dot menu must expose checkbox layout and hierarchical `1, 2, 3` layout.
- Hierarchical numbering is dynamic: `level == 0` items are numbered mothers; `level > 0` items are child dashes.
- Table zoom is removed for now; no pinch scale state, no transform scale wrapper.
- Table cell multiline height updates while typing, not only after focus loss.
- Debug logging must stay sparse enough for the 500-line log limit.

---

### Task 1: List Model And Menu Tests

**Files:**
- Modify: `test/note_document_test.dart`
- Modify: `test/note_list_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/models/note_document.dart`
- Modify: `lib/src/notes/ui/note_chunk_editor_header.dart`
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`

**Interfaces:**
- Produces: `NoteListLayoutMode` and `NoteBlock.listLayoutMode`.
- Produces header extra popup menu entries through `NoteChunkEditorHeader.extraMenuItems`.

- [ ] Add failing model test that serializes/parses `listLayoutMode: hierarchy`.
- [ ] Add failing widget test that the list overflow menu has checkbox and hierarchy layout entries.
- [ ] Add failing widget test that selected list items do not render a blue selected border.

### Task 2: Hierarchical Numbering

**Files:**
- Modify: `test/note_list_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`

**Interfaces:**
- Consumes: `NoteBlock.listLayoutMode`.
- Produces marker keys `note-list-marker-<itemId>` and menu keys `note-list-menu-layout-checkbox` / `note-list-menu-layout-hierarchy`.

- [ ] Add failing widget test for hierarchy markers: level 0 items render `1.`, `2.`, `3.` and level > 0 renders `-`.
- [ ] Add failing widget test for numbering cascade after indent/outdent and reorder.
- [ ] Implement marker rendering and layout switching.

### Task 3: Table Zoom Removal And Live Height Tests

**Files:**
- Modify: `test/note_table_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`

**Interfaces:**
- Removes: `note-table-zoom-gesture`, `note-table-zoom-transform`, `_scale`, pinch pointer tracking.
- Keeps: `note-table-zoomable-content` key as the stable table content key for existing sticky rail tests.
- Produces: live row height updates through text-change measurement/intrinsic row tracking.

- [ ] Replace pinch zoom test with a failing test asserting no zoom transform/gesture exists and pinch does not change table visual width.
- [ ] Add failing widget test that entering multiline cell text immediately increases the row head and cell height after a pump.
- [ ] Remove table scale state and simplify sticky rail viewport math.
- [ ] Update cell text change path to mark edited rows intrinsic immediately.

### Task 4: Verification

- [ ] Run focused tests in Ubuntu/proot:
  - `/root/flutter/bin/flutter test test/note_document_test.dart test/note_list_chunk_editor_screen_test.dart test/note_table_editor_screen_test.dart`
- [ ] Run analyze in Ubuntu/proot:
  - `/root/flutter/bin/flutter analyze`
- [ ] Run `git diff --check`.
- [ ] Commit and push after tests pass.
