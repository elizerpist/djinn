# Textchunk Blank Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the textchunk editor with a blank Google Keep-style plain text baseline.

**Architecture:** Keep only the surrounding chunk editor route contract and `NoteBlock.text` persistence. Delete the textchunk runtime modules, native selection rail bridge, range tag editor behavior, paragraph step behavior, and custom `EditableText`; render one `TextField` owned by Flutter.

**Tech Stack:** Flutter widgets, existing `NoteBlock` model, existing widget tests.

## Global Constraints

- Do not preserve textchunk rail, tag span, underline, paragraph step, or custom controller code.
- Use TDD: tests that reject old runtime must fail before production changes.
- Do not delete unrelated note chunk editors, note models, retrieval code, or `text_chunk` evidence enum values.

---

### Task 1: Red Tests For Blank Editor

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`
- Modify: `test/note_editor_route_test.dart`

**Interfaces:**
- Consumes: `NoteTextChunkEditorScreen(block, onChanged, availableTags, onDelete)`
- Produces: failing tests that require a `TextField` baseline and reject old textchunk runtime.

- [ ] Replace old textchunk screen tests with assertions that:
  - `find.byKey(ValueKey('note-text-plain-field'))` finds one widget.
  - `find.byType(TextField)` finds one widget.
  - old keys `note-text-native-editor`, `note-text-indent`, `note-text-outdent`, `note-text-chunk-field`, `note-text-scroll` are absent.
  - entering text updates `NoteBlock.text`.

- [ ] Update route test to enter text through `note-text-plain-field`.

- [ ] Run:
  `flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart`
  Expected: FAIL because the current implementation still uses old runtime.

### Task 2: Delete Old Runtime And Implement Plain TextField

**Files:**
- Delete: `lib/src/notes/ui/text_chunk/`
- Delete: `lib/src/notes/ui/native_selection_rail_bridge.dart`
- Delete: `android/app/src/main/kotlin/com/elizerpist/djinn/rail/`
- Modify: `android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt`
- Replace: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Delete: `test/native_selection_rail_bridge_test.dart`
- Delete: `test/text_chunk_paragraphs_test.dart`
- Delete: `test/text_chunk_span_controller_test.dart`

**Interfaces:**
- Produces: `NoteTextChunkEditorScreen` with one `TextField` keyed `note-text-plain-field`.

- [ ] Remove native rail setup from `MainActivity.kt`.
- [ ] Replace screen state with a `TextEditingController`, `FocusNode`, and `TextField`.
- [ ] On text change, update `_block = _block.copyWith(text: value, clearIndex: true)` and call `widget.onChanged(_block)`.
- [ ] Keep only minimal delete/title scaffolding necessary for route compatibility.
- [ ] Run the tests from Task 1; expected PASS.

### Task 3: Verification And Checklist

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-22-textchunk-blank-reset.md`

- [ ] Run old-symbol search:
  `rg "NativeSelectionRail|TextChunkSpanController|TextChunkParagraph|textChunkNativeRailState|note-text-native-editor|note-text-indent|note-text-outdent" lib android test`
  Expected: no production/test hits except docs if any.

- [ ] Run:
  `flutter test test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart test/note_document_test.dart`
  Expected: PASS.

- [ ] Run:
  `flutter analyze`
  Expected: no issues.

- [ ] Update checklist statuses.

