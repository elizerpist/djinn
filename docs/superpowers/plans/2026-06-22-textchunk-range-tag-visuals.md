# Text Chunk Range Tag Visuals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore inline text range tag visuals while preserving the plain native `TextField` editing surface.

**Architecture:** A tagged text controller returns styled `TextSpan`s with unchanged plain text. First tag becomes the range background; secondary tags are exposed to a pointer-ignoring underline paint layer that uses the same text layout and adds one underline per secondary tag. The controller text is never rewritten.

**Tech Stack:** Flutter, Dart widget tests, existing `NoteTextRangeTag` and `NoteKnowledgeTag` models.

## Global Constraints

- Do not reintroduce old textchunk runtime files, native rail bridge files, placeholders, `WidgetSpan`s, or hidden spacer text.
- Keep the editable surface a single stock `TextField`.
- Reuse the existing tag visual color rule used by table/list chunks: first tag background, remaining tags underlines.

---

### Task 1: Failing Tests

**Files:**
- Modify: `test/tagged_text_visual_test.dart`
- Modify: `test/note_text_chunk_editor_screen_test.dart`

- [x] Add a helper test for first-tag background, secondary underline colors, and line-height expansion.
- [x] Add an editor widget test proving the controller text stays plain while the editor exposes range background and underline visuals.
- [x] Run targeted tests and verify they fail because the editor visuals are missing. Local execution is blocked before compile by the Dart ARM64 TLS alignment error, so CI must provide the real RED/GREEN signal.

### Task 2: Tagged Text Visual Implementation

**Files:**
- Modify: `lib/src/notes/ui/tagged_text_visual.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`

- [x] Add a tagged text controller that builds plain-text spans with first-tag background styling.
- [x] Add secondary underline geometry/painter data without `WidgetSpan`s or text placeholders.
- [x] Wire the controller and underline layer into the text chunk editor.
- [x] Keep text/range tag updates synchronized when block metadata changes.

### Task 3: Verification

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-22-textchunk-range-tag-visuals.md`
- Modify: this plan

- [ ] Run targeted tests in CI.
- [ ] Run focused regressions around text editor, tagged text visuals, and rail.
- [ ] Run `flutter analyze`.
- [ ] Run old-symbol scan for deleted textchunk/native placeholder artifacts.
- [ ] Update checklist and plan statuses honestly.
