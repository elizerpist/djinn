# Text Chunk Zero Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken text chunk editor with a new native-editing implementation and restyle the keyboard rail to match the table/list rail.

**Architecture:** The new text chunk editor is split into focused files under `lib/src/notes/ui/text_chunk/`. The editor keeps native Flutter text selection clean, uses separate range/tag helpers for metadata, paints tag backgrounds/underlines without hidden placeholder text, and drives the existing native keyboard rail bridge through a simple state contract. The Android native rail renderer keeps the IME-synced positioning behavior but redraws itself as a table/list rail equivalent.

**Tech Stack:** Flutter/Dart widgets and tests, Android Kotlin native view bridge, Flutter MethodChannel, GitHub Actions for APK build.

## Global Constraints

- Delete the old text chunk canvas/layout/paragraph-step implementation instead of patching it.
- Keep controller text equal to user text; no rail/underline placeholders in `EditableText`.
- Keep rail keyboard following through native IME insets.
- Match `NoteSelectionActionRail` visual behavior: action row, closable tag row, scrollable rows, icons, colors, separator/border.
- Do not run local Android APK builds in Termux; use GitHub Actions.

---

## File Structure

- Delete: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
- Delete: `lib/src/notes/ui/text_chunk_layout_model.dart`
- Delete: `lib/src/notes/ui/text_chunk_text_editing.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_controller.dart`
  - Owns tagged text span styling and keeps native text pure.
- Create: `lib/src/notes/ui/text_chunk/text_chunk_ranges.dart`
  - Owns text edit diffing, range-tag adjustment, paragraph lookup, and target range calculation.
- Create: `lib/src/notes/ui/text_chunk/text_chunk_underlines.dart`
  - Paints secondary tag underlines and reserves visual spacing without text placeholders.
- Create: `lib/src/notes/ui/text_chunk/text_chunk_editor.dart`
  - Plain native editing surface around `EditableText`.
- Create: `lib/src/notes/ui/text_chunk/text_chunk_rail_state.dart`
  - Converts selection/range state into `NativeSelectionRailState`.
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
  - Wire the new editor files and remove paragraph-step dependency.
- Modify: `lib/src/notes/ui/native_selection_rail_bridge.dart`
  - Keep action model, remove old style toggles if not needed, keep table/list rail style flags.
- Modify: `android/app/src/main/kotlin/com/elizerpist/djinn/rail/NativeSelectionRailBridge.kt`
  - Keep keyboard positioning; rewrite view styling/actions to match table/list rail.
- Replace: `test/note_text_chunk_editor_screen_test.dart`
  - New focused tests for native text purity, rail visibility, whole-chunk selection, underlines.
- Replace: `test/text_chunk_layout_model_test.dart`
  - Delete old layout/paragraph-step tests; add range helper tests.
- Modify: `test/native_selection_rail_bridge_test.dart`
  - Assert new action/style payload contract.

## Task 1: Red Tests for Deletion Boundary and Range Helpers

**Files:**
- Replace: `test/text_chunk_layout_model_test.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_ranges.dart`

**Interfaces:**
- Produces:
  - `class TextChunkTextEdit { int offset; int deleteCount; String insertText; }`
  - `List<NoteTextRangeTag> adjustTextChunkRangeTagsForEdit(...)`
  - `TextRange? textChunkTargetRangeForSelection({required TextSelection selection, required String text, required List<NoteTextRangeTag> rangeTags})`

- [x] Write tests that import `text_chunk_ranges.dart`, not old layout files.
- [x] Verify tests fail because the new file/functions do not exist.
- [x] Implement only range edit adjustment and target-range lookup.
- [x] Verify targeted tests pass.

## Task 2: Red Tests for New Native Editor Surface

**Files:**
- Replace: `test/note_text_chunk_editor_screen_test.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_controller.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_underlines.dart`
- Create: `lib/src/notes/ui/text_chunk/text_chunk_editor.dart`

**Interfaces:**
- Produces:
  - `TextChunkEditingController extends TextEditingController`
  - `NativeTextChunkEditor`
  - `TextChunkSecondaryUnderlineOverlay`

- [x] Write tests that assert the `EditableText` plain text equals `NoteBlock.text`.
- [x] Write tests that assert no `rail-line-`, `underline-line-`, or `placeholderDelta` debug artifacts remain.
- [x] Write tests for whole-chunk text selection across paragraph/newline boundaries.
- [x] Write tests that many secondary tags create underline overlay and extra visual room without changing controller text.
- [x] Verify the tests fail against the current code.
- [x] Implement the new files with a plain `EditableText`, tagged span styling, and RenderEditable-based underline overlay.
- [x] Verify targeted tests pass.

## Task 3: Replace Screen Wiring and Delete Old Implementation

**Files:**
- Delete: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
- Delete: `lib/src/notes/ui/text_chunk_layout_model.dart`
- Delete: `lib/src/notes/ui/text_chunk_text_editing.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Modify: `docs/superpowers/checklists/2026-06-22-textchunk-zero-rewrite.md`

**Interfaces:**
- Consumes: new text chunk files from Tasks 1-2.
- Produces: `NoteTextChunkEditorScreen` with no old canvas/layout imports.

- [x] Remove imports of old text chunk files.
- [x] Delete header paragraph step buttons from text chunk screen.
- [x] Route native rail indent/outdent actions to a new minimal paragraph-margin transform only if required by the current action contract; otherwise disable until rewritten.
- [x] Verify `rg "TextChunkCanvasEditor|buildTextChunkLayout|applyTextChunkParagraphStep|TextChunkStep"` has no production hits.
- [x] Update checklist statuses for TCZR-01/02/03/09.

## Task 4: Restyle Native Keyboard Rail

**Files:**
- Modify: `lib/src/notes/ui/native_selection_rail_bridge.dart`
- Modify: `android/app/src/main/kotlin/com/elizerpist/djinn/rail/NativeSelectionRailBridge.kt`
- Modify: `test/native_selection_rail_bridge_test.dart`

**Interfaces:**
- Produces same MethodChannel method `setState`.
- Actions remain wire-compatible: `toggleTags`, `outdent`, `indent`, `tagSelection`, `clearTags`, `previousTag`, `nextTag`, `toggleRounded`, `toggleGrey`, `toggleBorder`, `deleteTag`.

- [x] Add/adjust Dart tests for action payload order and style flags.
- [x] Verify tests fail if payload/style contract is missing.
- [x] Rewrite Android action buttons to use Material icon glyphs and dimensions matching table/list rail.
- [x] Implement action row as horizontal scroll view with 64 dp total row height.
- [x] Implement optional tag row as horizontal scroll view with divider and 48 dp row height.
- [x] Keep IME `WindowInsetsAnimation` positioning unchanged.
- [x] Verify Dart tests pass and inspect Kotlin source for text-label removal.

## Task 5: Verification, Commit, Push, CI

**Files:**
- Modify checklist statuses.

- [x] Run Dart format on touched Dart files.
- [x] Run targeted tests:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_layout_model_test.dart test/native_selection_rail_bridge_test.dart test/note_text_chunk_editor_screen_test.dart'
```

- [x] Run analyze:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter analyze'
```

- [x] Run full tests:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test'
```

- [x] Re-read checklist and mark only verified requirements `DONE`.
- [ ] Commit and push branch.
- [ ] Dispatch GitHub Android native build and wait for result.
