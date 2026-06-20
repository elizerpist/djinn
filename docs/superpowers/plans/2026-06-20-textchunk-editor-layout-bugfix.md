# Textchunk Editor Layout Bugfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the notes textchunk editor so paragraphs, inline selection rail placement, and tag underlines follow the June 20 user request.

**Architecture:** Keep the textchunk as one native Flutter `TextField` so the full chunk remains selectable. Use `TextPainter`-based visual line geometry to insert rail/gap space at the selected visual line and reserve per-line space for stacked secondary tag underlines.

**Tech Stack:** Flutter, Dart widget tests, existing notes editor widgets.

## Global Constraints

- Use only the requirements in the June 20 user message; do not read or reuse older specs.
- Keep the whole textchunk selectable as one editor.
- Keep existing default line spacing unless a selected rail or stacked tag underlines require extra space under a specific visual line.
- Flutter APK builds must run online through GitHub/GitHub Actions, not locally in Termux.

---

## Acceptance Checklist

| ID | Source | Intended Code Area | Acceptance Condition | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| TC-01 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` paragraph helpers | A paragraph can contain multiple manual or automatic visual lines; only an empty line separates paragraphs. | Widget tests | DONE |
| TC-02 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` indent actions | Header/rail step left/right changes every manual line in the active paragraph and leaves other paragraphs unchanged. | Widget tests | DONE |
| TC-03 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` editor widget tree | The textchunk remains one native editable chunk, not split into per-paragraph fields. | Existing and new widget tests | DONE |
| TC-04 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` rail layout | The selection rail appears directly under the selected word's visual line and pushes following text down. | Widget tests and code inspection | DONE |
| TC-05 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` underline painter/layout | Secondary tag underlines draw only under the selected tagged text range, not across the full line or paragraph. | Widget tests | DONE |
| TC-06 | User message, 2026-06-20 | `note_text_chunk_editor_screen.dart` underline spacing | Stacked tag underlines reserve enough vertical space under the affected visual line so they do not cover the next line. | Widget tests and code inspection | DONE |

## Task 1: Failing Tests

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`

**Steps:**
- [x] Add a test that selects text on the first visual/manual line and expects `note-text-inline-selection-rail` to appear above later text in the same chunk.
- [x] Add a test that many secondary tags increase the affected editor height while preserving `TextField.style.height == null`.
- [x] Add a test that rail step indent changes the whole active paragraph, including all manual lines before a blank line.
- [x] Run the targeted tests and confirm failures are caused by current missing behavior.

## Task 2: Line Geometry And Layout

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

**Steps:**
- [x] Add `TextPainter` geometry helpers that compute visual line boxes for selections and range tags using the same text style and width as the `TextField`.
- [x] Replace the after-field rail placement with a selected-line gap inside the text field stack.
- [x] Keep the single `TextField` and preserve default text style height.

## Task 3: Underline Scope And Spacing

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

**Steps:**
- [x] Draw secondary underlines for each exact tagged selection box.
- [x] Reserve per-line vertical spacing when stacked secondary underlines would otherwise overlap following text.
- [x] Keep marker keys for tests.

## Task 4: Verification, Commit, Push, Build

**Files:**
- Verify changed source and tests.

**Steps:**
- [x] Run targeted Flutter widget tests where Flutter is available.
- [x] Run formatting/analyze where Flutter/Dart tools are available.
- [x] Update checklist statuses honestly.
- [ ] Commit the source, tests, and plan.
- [ ] Push the branch to the user's GitHub remote.
- [ ] Trigger or locate the GitHub Actions build/release and report the link.
