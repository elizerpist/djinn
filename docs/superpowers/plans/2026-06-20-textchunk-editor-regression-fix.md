# Textchunk Editor Regression Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the current textchunk editor regressions shown in the latest two Android screenshots: rail placement, tag underlines, line expansion, paragraph stepping, debug logging, and full-canvas text editing.

**Architecture:** Keep one native Flutter `TextField` for the whole textchunk. Measure visual text lines with the same style, width, padding, and text scale used by the field, compute per-line reserved gaps, and place rail/underline overlays in that same coordinate system while disabling internal text scrolling.

**Tech Stack:** Flutter, widget tests, `TextPainter`, native `TextField`, existing `DebugConsole`.

## Global Constraints

- Do not read older specs; use the current bug report and the latest two Android screenshots only.
- Keep the whole textchunk as one selectable/editable native text field.
- Do not run local Flutter APK builds on Termux/Android; APK build must run through GitHub Actions after push.
- Add detailed debug logs for layout, selection, paragraph stepping, rail placement, and underline placement.

---

## Acceptance Checklist

| ID | Source | Intended code area | Acceptance condition | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| TC2-01 | Latest two screenshots and current message | `note_text_chunk_editor_screen.dart` text layout | The selection rail is inserted below the selected visual line and never covers the selected word/selection highlight. | Widget test compares selected range box and rail rect; screenshot-informed code inspection. | DONE |
| TC2-02 | Current message | `note_text_chunk_editor_screen.dart` canvas/body | The text is rendered on the page canvas, not in a small independently scrollable text window; page scroll owns overflow. | Widget test asserts `TextField.scrollPhysics` is non-scrollable and field height expands to content. | DONE |
| TC2-03 | Current message | tag underline painter/helpers | Secondary tag underlines are drawn only under the tagged range boxes, not under the whole row or paragraph. | Widget test compares marker rect to expected selected/tagged word width and x-position. | DONE |
| TC2-04 | Latest screenshots and current message | line gap calculation/text span layout | Multiple underlines reserve enough vertical space below that visual line so they cannot cover the next line. | Widget test checks next-line top is below final underline marker with margin. | DONE |
| TC2-05 | Current message | header and inline rail indent/outdent | Step left/right operates on the full active paragraph, where paragraph means text separated only by an empty line; manual Enter rows and automatic wrap rows are both part of the same stepped paragraph. | Widget tests for long wrapped paragraph and manual-line paragraph; only next paragraph after blank line remains unchanged. | DONE |
| TC2-06 | Current message | `DebugConsole` logging calls | Detailed logs show selection range, visual line index, rail top/height, line gaps, underline markers, paragraph range, and scroll/canvas sizing. | Widget test or source inspection asserts log prefixes; manual debug console output after interactions. | DONE |

## Tasks

### Task 1: RED Regression Tests

**Files:**
- Modify: `test/note_text_chunk_editor_screen_test.dart`

- [x] Add a rail placement test that selects a word on a wrapped visual line and asserts the inline rail top is below the selection box bottom plus margin.
- [x] Add a no-inner-scroll test that asserts the text field uses non-scrollable physics and expands beyond a short-field baseline for long text.
- [x] Add an underline precision test that asserts the marker is near the target word width and x-position.
- [x] Add a line expansion test that asserts a later line is below stacked underline markers.
- [x] Add wrapped paragraph stepping tests for header and inline rail controls.
- [x] Run targeted tests and confirm the new assertions fail on the current implementation for the layout regressions.

### Task 2: Layout Fix and Debug Logs

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

- [x] Introduce a shared text layout model that uses field content padding, text scale, width, line metrics, per-line gaps, and marker positions in one coordinate system.
- [x] Disable internal `TextField` scrolling and make the field height equal to measured content height plus reserved per-line gaps.
- [x] Place the inline rail inside the reserved gap below the selected visual line, below the selection box, not on top of text.
- [x] Draw underline markers only from `TextPainter.getBoxesForSelection` boxes and account for cumulative line gaps.
- [x] Expand the line gap below any line with stacked underlines.
- [x] Apply paragraph indent/outdent to the full blank-line-delimited paragraph for both header and rail buttons.
- [x] Add detailed throttled `DebugConsole` logs for layout, rail, underline, and paragraph stepping.

### Task 3: GREEN Verification, Commit, Push, Build

**Files:**
- Modify: checklist statuses in this plan

- [x] Run formatter.
- [x] Run targeted textchunk editor tests.
- [x] Run related notes UI tests.
- [x] Run `flutter analyze`.
- [x] Run full `flutter test`.
- [x] Mark checklist items DONE/PARTIAL/BLOCKED honestly.
- [ ] Commit changes.
- [ ] Push branch to GitHub.
- [ ] Wait for GitHub Actions debug APK build and provide release link.
