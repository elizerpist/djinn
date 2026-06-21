# Textchunk In-Flow Rail Native Drag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the text selection rail insert between visual text rows after a settled selection while keeping native handle drag fluent.

**Architecture:** A settled rail reserves native text layout space with a temporary invisible spacer so the actual `EditableText` rows below the rail move down. Native handle pointer down and drag immediately suppress that spacer and rail; drag updates are not normalized or written back by the editor. A non-drag selection change settles the interaction and reinserts the rail at the final selected visual line.

**Tech Stack:** Flutter, `EditableText`, Material text selection controls, widget tests, GitHub Actions Android build.

## Global Constraints

- Do not run local Flutter APK builds on Termux/Android ARM64.
- Add failing widget tests before production changes.
- The rail is not an overlay in the settled state; it must push below content down.
- During native handle drag, the rail must not recompute or shift layout under the handle.
- Android APK verification must run through GitHub Actions after commit and push.

---

### Task 1: Encode In-Flow Rail And Native-Only Drag Tests

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: existing `_pumpTextChunkEditor`, `_setEditorSelection`, `_simulateNativeSelectionDrag`, `_nativeEditableSubstringRect`, `_nativeEditableNonEmptyLineBounds`.
- Produces: failing tests for in-flow rail spacing and drag suppression.

- [ ] **Step 1: Update settled rail expectations**

Change tests that currently assert overlay behavior so they assert `lineBelow.top >= rail.bottom`, and expect `note-text-inline-selection-spacer` while settled selection is visible.

- [ ] **Step 2: Add handle pointer tests**

Add tests that long-press text, confirm native toolbar and rail are visible, touch `note-text-native-selection-handle-right`, and assert the rail/spacer disappears before drag deltas.

- [ ] **Step 3: Run targeted tests red**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart`

Expected: fail before production changes because the current code has no settled spacer and no native handle pointer hook.

### Task 2: Restore Settled In-Flow Rail Spacer

**Files:**
- Modify: `lib/src/notes/ui/text_chunk_canvas_editor.dart`

**Interfaces:**
- Consumes: `buildTextChunkLayout(...)`, `_railTop(...)`, `_lineTop(...)`, `_LineMarker`.
- Produces: settled rail placeholder and visual spacer only when `_selectionHandleDragActive == false`.

- [ ] **Step 1: Compute rail spacer only outside drag**

When a rail line exists and native handle drag is inactive, compute `railTargetSpacerHeight`, `railNativeLineCount`, `railLineBreakCount`, `railNativeSpacerHeight`, and a `rail-line-*` native placeholder at `_insertionOffsetForLine(railLine)`.

- [ ] **Step 2: Shift editor line markers**

Pass `railLine?.index` and `railNativeSpacerHeight` to `_LineMarker` so markers below the selected visual line move down with the native spacer.

- [ ] **Step 3: Render visible spacer and rail**

Render `note-text-inline-selection-spacer` from the selected line bottom through the rail slot, then render `note-text-inline-selection-rail` at `_railTop(...)`.

- [ ] **Step 4: Keep spacer out of drag**

When `_selectionHandleDragActive` is true, `railLine` must be null, `railPlaceholderCount` must be zero, and the rail/spacer widgets must not exist.

### Task 3: Add Native Handle Contact Suppression

**Files:**
- Modify: `lib/src/notes/ui/text_chunk_canvas_editor.dart`

**Interfaces:**
- Consumes: `EditableText.selectionControls`, `SelectionChangedCause.drag`.
- Produces: `_TextChunkSelectionControls` wrapping native Material handles with pointer listeners.

- [ ] **Step 1: Add pointer tracking**

Add `_selectionHandlePointer`, pointer router registration, and release cleanup. Pointer up schedules a post-frame settle that restores the rail from the final native selection; pointer cancel only untracks the pointer and keeps drag suppression active.

- [ ] **Step 2: Wrap native handles**

Replace `materialTextSelectionHandleControls` with `_TextChunkSelectionControls`, which extends `MaterialTextSelectionControls with TextSelectionHandleControls` and wraps `buildHandle(...)` in a `Listener`.

- [ ] **Step 3: Suppress rail before drag**

On handle pointer down/move and `SelectionChangedCause.drag`, call `_startSelectionHandleDrag()`. This hides the toolbar and sets `_selectionHandleDragActive`.

- [ ] **Step 4: Settle only on non-drag selection changes**

For `SelectionChangedCause.drag`, return without normalizing or writing `controller.selection`. For tap, long press, keyboard, and toolbar actions, cancel drag suppression, normalize selection, and allow toolbar display.

### Task 4: Verify, Commit, Push

**Files:**
- Modify: `docs/superpowers/specs/2026-06-21-textchunk-inflow-rail-native-drag-design.md`
- Modify: `docs/superpowers/plans/2026-06-21-textchunk-inflow-rail-native-drag.md`

**Interfaces:**
- Consumes: acceptance checklist `TIR-001` through `TIR-005`.
- Produces: checked-off local statuses, commit, branch push for GitHub Actions.

- [ ] **Step 1: Run focused verification**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart`

Expected: all tests in the file pass.

- [ ] **Step 2: Run broader verification**

Run: `flutter analyze`

Expected: no issues.

Run: `flutter test`

Expected: all runnable tests pass; ObjectBox host-library skips are acceptable if they match existing environment skips.

- [ ] **Step 3: Update checklist statuses**

Mark TIR-001 through TIR-004 `DONE` if the tests pass. Leave TIR-005 `PARTIAL` until GitHub Actions confirms the Android build.

- [ ] **Step 4: Commit and push**

Commit all implementation, test, spec, and plan updates. Push the current branch so GitHub Actions can build the APK.
