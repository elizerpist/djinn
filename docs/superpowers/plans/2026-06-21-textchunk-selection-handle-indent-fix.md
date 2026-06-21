# Textchunk Selection Handle Indent Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the text chunk editor so indented wrapped rows keep their left margin and native selection handles drag freely without rail-induced ticks.

**Architecture:** Keep the existing native `EditableText` host. Make paragraph reflow use native-width-aware wrapping, and replace timer-based selection drag settling with explicit handle pointer contact state from custom Material selection controls.

**Tech Stack:** Flutter, `EditableText`, Material text selection controls, widget tests, GitHub Actions for Flutter verification.

## Global Constraints

- Do not run local Flutter APK builds on Termux/Android ARM64.
- Local Flutter commands may fail on this device with `TLS segment is underaligned`; use GitHub Actions for authoritative test and build results.
- Update the acceptance checklist before production code changes.
- Follow TDD: add failing widget tests before production changes.

---

### Task 1: Indent Reflow Regression

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/text_chunk_text_editing.dart`

**Interfaces:**
- Consumes: `applyTextChunkParagraphStep(...)`
- Produces: corrected paragraph text with generated hard wraps that native `EditableText` does not re-wrap to the old left margin.

- [ ] **Step 1: Write the failing test**

Add a widget test that builds a paragraph matching the screenshot pattern, applies stacked secondary underlines to the first line, indents repeatedly, outdents partially, and asserts every native line left is at least the active indent left.

- [ ] **Step 2: Verify RED**

Run the widget test in GitHub Actions because local Flutter cannot execute in Termux ARM64. Expected: FAIL showing at least one native line starts left of the indented paragraph margin.

- [ ] **Step 3: Implement minimal reflow fix**

Update paragraph step wrapping so generated hard-wrap insertions are based on the full native text width with the indent spaces included, instead of subtracting indent width and then adding the indent again.

- [ ] **Step 4: Verify GREEN**

Run the same widget test and the full Flutter test workflow in GitHub Actions. Expected: PASS.

### Task 2: Selection Handle Contact Rail State

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`
- Modify: `lib/src/notes/ui/text_chunk_canvas_editor.dart`

**Interfaces:**
- Consumes: `EditableText.selectionControls`, `SelectionChangedCause.drag`
- Produces: custom selection controls that hide the rail on handle pointer down and restore it on pointer up/cancel.

- [ ] **Step 1: Write failing tests**

Add tests for sparse drag updates and handle pointer down/up. Sparse drag must keep the rail hidden across idle time; pointer down must hide the rail before a drag update.

- [ ] **Step 2: Verify RED**

Run the widget tests in GitHub Actions. Expected: FAIL because the current 160 ms settle timer restores the rail mid-drag and there is no handle pointer hook.

- [ ] **Step 3: Implement minimal selection controls fix**

Remove the timer-driven drag settle. Add Material selection controls with `TextSelectionHandleControls` that wrap `buildHandle` in a `Listener`; pointer down sets handle-contact active, pointer up/cancel clears it and restores the rail after the final selection is available.

- [ ] **Step 4: Verify GREEN**

Run the targeted widget tests and the full CI workflow. Expected: PASS.
