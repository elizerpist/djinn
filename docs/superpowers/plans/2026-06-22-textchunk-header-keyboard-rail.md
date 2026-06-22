# Text Chunk Header Keyboard Rail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the text chunk header and keyboard-top rail while keeping the editor surface a plain native Flutter `TextField`.

**Architecture:** The editor owns a single `TextEditingController` and `TextField`. Header actions and the rail mutate only `NoteBlock` metadata (`title`, `tags`, `rangeTags`, `paragraphStyles`) and never insert hidden text. The rail is a reused `NoteSelectionActionRail` positioned outside the editor content with bottom padding driven by `MediaQuery.viewInsets.bottom`.

**Tech Stack:** Flutter, Dart widget tests, existing notes models, `NoteChunkEditorHeader`, `NoteSelectionActionRail`, `showTagManagerSheet`.

## Global Constraints

- Do not reintroduce textchunk runtime files, native rail bridge files, placeholder spans, or text-mutating paragraph indentation.
- Keep the editable surface a single stock `TextField`.
- Reuse the table/list rail component instead of building a new rail renderer.
- For this pass, style toggle buttons only affect rail presentation state.

---

### Task 1: Header And Selection Tests

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NoteTextChunkEditorScreen(block, availableTags, onChanged, onDelete)`
- Produces: failing tests for `note-chunk-title-field`, `note-text-header-outdent`, `note-text-header-indent`, `note-text-keyboard-rail`, and metadata preservation.

- [x] Write widget tests for header rendering/title autosave, selection rail visibility, collapsed tagged cursor rail visibility, and step metadata updates without text mutation.
- [x] Run the targeted test file and verify failures are caused by missing header/rail behavior.

### Task 2: Editor Implementation

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

**Interfaces:**
- Produces: header callbacks, selection listener, `NoteSelectionActionRail` overlay, tag/range helpers, paragraph style helpers.

- [x] Replace the plain `AppBar` with `NoteChunkEditorHeader`.
- [x] Add a controller listener that tracks selection and text changes without adding gesture wrappers.
- [x] Add global tag and selected range tag sheet callbacks.
- [x] Add paragraph step out/in helpers that update metadata only.
- [x] Add keyboard-top `NoteSelectionActionRail` below the `TextField`, animated by `viewInsets.bottom`.
- [x] Add rail action buttons matching table/list icon style.

### Task 3: Verification And Integration

**Files:**
- Modify: checklist status in `docs/superpowers/checklists/2026-06-22-textchunk-header-keyboard-rail.md`

- [x] Run targeted widget tests.
- [x] Run route/document tests that cover autosave.
- [x] Run `flutter analyze`.
- [x] Run old-symbol scan for deleted textchunk/native rail artifacts.
- [x] Update checklist statuses honestly.
- [ ] Commit and push the branch, then check GitHub Actions Android build.
