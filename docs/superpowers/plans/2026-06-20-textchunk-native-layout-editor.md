# Textchunk Native Layout Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development only for independent investigation/review tasks; implement the tightly coupled editor work inline with superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current notes textchunk body with a native Flutter custom layout/editor layer where the rail is inserted between visual lines, paragraph stepping treats manual and wrapped lines consistently, and tag underlines belong exactly to tagged ranges.

**Architecture:** Keep the existing note model, route/header integration, tag manager sheet, and `NoteSelectionActionRail` visual component. Remove the current visible `TextField`/overlay body from `NoteTextChunkEditorScreen` and create focused textchunk files: a layout model, tag range editing helpers, a visible custom editor widget, and tests derived only from `docs/superpowers/specs/2026-06-20-textchunk-native-layout-editor-design.md`. The visible editor renders visual lines as Flutter widgets and inserts the rail as a real child below the active visual line; any native `EditableText` bridge may be used only for keyboard/IME text input, not as the visible layout implementation.

**Tech Stack:** Flutter/Dart, existing notes model, existing `NoteSelectionActionRail`, existing `showTagManagerSheet`, Flutter widget tests under Ubuntu.

## Global Constraints

- Source of truth is only `docs/superpowers/specs/2026-06-20-textchunk-native-layout-editor-design.md`.
- Do not use old textchunk specs, old HTML prototypes, old textchunk implementation plans, old screenshots, or old textchunk tests as requirements.
- Do not keep the current visible `TextField` plus `TextPainter` plus overlay rail architecture.
- Do not use WebView, HTML, or contenteditable.
- Do not split one textchunk into separate note blocks.
- Keep the rail design and current rail buttons/functions.
- Flutter APK builds must run on GitHub Actions, not locally on Termux.

---

## File Structure

- Delete/replace: `test/note_text_chunk_editor_screen_test.dart`
  - Old tests encode the rejected implementation and must be replaced.
- Modify: `test/note_editor_route_test.dart`
  - Update the textchunk edit interaction to the new keyed native editor input.
- Create: `test/text_chunk_layout_model_test.dart`
  - Pure/model-heavy tests for paragraphs, visual lines, rail anchors, indent, tag ranges, and underline lanes.
- Create: `lib/src/notes/ui/text_chunk_layout_model.dart`
  - Converts continuous text into paragraph and visual line records, computes active paragraph, rail insertion index, and underline lanes.
- Create: `lib/src/notes/ui/text_chunk_text_editing.dart`
  - Adjusts `NoteTextRangeTag` offsets after text edits and applies paragraph indent/outdent.
- Create: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
  - Visible custom native Flutter editor body. Renders visual lines, selection highlight, tag highlights/underlines, and inserts `NoteSelectionActionRail` as real inline content.
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
  - Keep screen shell, header, chunk tags, tag sheet calls, route contract, and persistence. Remove current body/layout helpers and wire the new editor widget.
- Modify: `docs/superpowers/specs/2026-06-20-textchunk-native-layout-editor-design.md`
  - Update checklist statuses honestly after implementation and verification.

## Task 1: Replace Old Textchunk Tests With Spec Tests

**Files:**
- Delete/recreate: `test/note_text_chunk_editor_screen_test.dart`
- Create: `test/text_chunk_layout_model_test.dart`

**Interfaces:**
- Consumes: `NoteBlock`, `NoteKnowledgeTag`, `NoteTextRangeTag`.
- Produces expected public API for later tasks:
  - `TextChunkLayout buildTextChunkLayout({required String text, required double maxWidth, required TextStyle textStyle, required TextScaler textScaler, required List<NoteTextRangeTag> rangeTags, TextRange? selection, double railHeight = 0})`
  - `TextRange? textChunkParagraphRangeForOffset(String text, int offset)`
  - `ParagraphStepResult applyTextChunkParagraphStep({required String text, required List<NoteTextRangeTag> rangeTags, required int offset, required int delta, required double maxWidth, required TextStyle textStyle, required TextScaler textScaler})`

- [x] Delete the existing `test/note_text_chunk_editor_screen_test.dart` contents.
- [x] Add layout model tests for paragraph boundaries:
  - Enter once keeps lines in the same paragraph.
  - Two Enters create an empty separator and a new paragraph.
  - Active paragraph range stops before the empty line.
- [x] Add layout model tests for step behavior:
  - Manual Enter lines and auto-wrapped lines receive the same indent delta.
  - Text after an empty line is unchanged.
- [x] Add widget tests for the new editor:
  - One-line selection inserts `note-text-inline-selection-rail` after the selected visual line.
  - Multi-line selection inserts the rail after the lowest selected visual line.
  - Long content scrolls without clipping the final line.
  - Rail tag action opens the existing tag manager sheet and saves tags to the selected range.
  - Primary tag paints only tagged text background.
  - Secondary tags render exact range underlines and stacked spacing.
- [x] Run the new tests before implementation and confirm they fail for missing APIs/widgets.

## Task 2: Implement Text Layout Model

**Files:**
- Create: `lib/src/notes/ui/text_chunk_layout_model.dart`
- Test: `test/text_chunk_layout_model_test.dart`

**Interfaces:**
- Produces:
  - `TextChunkParagraph`
  - `TextChunkVisualLine`
  - `TextChunkTagSegment`
  - `TextChunkUnderlineLane`
  - `TextChunkLayout`
  - `buildTextChunkLayout(...)`
  - `textChunkParagraphRangeForOffset(...)`
  - `textChunkRailLineIndexForSelection(...)`

- [x] Implement paragraph parsing from one continuous text string.
- [x] Use `TextPainter` only as a measurement primitive for visual line boundaries, not as an overlay positioning strategy.
- [x] Build visual lines with continuous `start`/`end` offsets, paragraph index, line-in-paragraph index, `hardBreakAfter`, and indentation level.
- [x] Compute tag segments per visual line from `NoteTextRangeTag` ranges.
- [x] Compute underline lanes per visual line from secondary tags.
- [x] Compute rail insertion line:
  - collapsed caret inside a tagged range uses that tagged range;
  - one-line selection uses that selected line;
  - multi-line selection uses the lowest selected visual line.
- [x] Run `flutter test test/text_chunk_layout_model_test.dart` under Ubuntu.

## Task 3: Implement Text Editing Helpers

**Files:**
- Create: `lib/src/notes/ui/text_chunk_text_editing.dart`
- Test: `test/text_chunk_layout_model_test.dart`

**Interfaces:**
- Consumes `TextChunkLayout` and `NoteTextRangeTag`.
- Produces:
  - `TextChunkTextEdit`
  - `TextChunkEditResult`
  - `adjustTextChunkRangeTagsForEdit(...)`
  - `applyTextChunkTextEdit(...)`
  - `applyTextChunkParagraphStep(...)`

- [x] Implement range tag offset adjustment for insert/delete/replace.
- [x] Implement paragraph step by editing the active paragraph text.
- [x] Preserve one continuous text string.
- [x] Ensure manual and wrapped lines share the same paragraph indent value in layout.
- [x] Ensure stepping does not touch text after a blank separator line.
- [x] Run `flutter test test/text_chunk_layout_model_test.dart` under Ubuntu.

## Task 4: Build Visible Custom Editor Widget

**Files:**
- Create: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes:
  - `buildTextChunkLayout(...)`
  - `applyTextChunkTextEdit(...)`
  - `applyTextChunkParagraphStep(...)`
  - existing `NoteSelectionActionRail`
- Produces:
  - `TextChunkCanvasEditor`
  - widget key `note-text-chunk-field`
  - widget key `note-text-line-<index>`
  - widget key `note-text-inline-selection-rail`
  - widget key `note-text-primary-highlight-<rangeId>-<lineIndex>-<segmentIndex>`
  - widget key `note-text-secondary-underline-<rangeId>-<tagIndex>-<lineIndex>-<segmentIndex>`

- [x] Empty/remove the current textchunk body implementation in `NoteTextChunkEditorScreen`.
- [x] Keep header title edit, chunk tags, tag manager sheet methods, delete flow, and `onChanged`.
- [x] Add `TextChunkCanvasEditor` below the global tag pills.
- [x] Render visual lines as real line widgets from `TextChunkLayout`.
- [x] Insert `NoteSelectionActionRail` in the `Column` immediately after the active visual line.
- [x] Render primary tag background only around tagged text segments.
- [x] Render secondary underline widgets only under tagged text segments.
- [x] Add bottom padding/line spacing from underline lane count so following text is pushed down.
- [x] Add long-content scroll support so the final line remains reachable.
- [x] Add keyboard/IME input support while keeping the visible layout custom and continuous.
- [x] Run `flutter test test/note_text_chunk_editor_screen_test.dart` under Ubuntu.

## Task 5: Wire Rail Actions And Tag Flow

**Files:**
- Modify: `lib/src/notes/ui/text_chunk_canvas_editor.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes current screen methods:
  - tag selected range through `showTagManagerSheet`
  - delete selected tags
  - focus previous/next tagged range
  - paragraph step left/right

- [x] Keep rail button set and tooltips/functionality.
- [x] Preserve active selection when a rail button is tapped.
- [x] Make rail tag button open the existing tag manager sheet.
- [x] Save first selected tag as primary and all additional tags as secondary tags on `NoteTextRangeTag`.
- [x] Make clear/delete remove tags for only the active selected range overlap.
- [x] Make previous/next select the previous/next tagged range and move the rail there.
- [x] Make rail step left/right call paragraph step for the active paragraph.
- [x] Run `flutter test test/note_text_chunk_editor_screen_test.dart` under Ubuntu.

## Task 6: Route Autosave And Regression Updates

**Files:**
- Modify: `test/note_editor_route_test.dart`
- Modify: `docs/superpowers/specs/2026-06-20-textchunk-native-layout-editor-design.md`

**Interfaces:**
- Consumes `NoteTextChunkEditorScreen`.
- Produces updated route test using new editor key/input interaction.

- [x] Update route test to edit through the new textchunk editor input surface.
- [x] Verify `NoteBlock.text`, `NoteBlock.rangeTags`, and `NoteBlock.tags` persist through `onChanged`.
- [x] Update acceptance checklist statuses in the 2026-06-20 spec.
- [x] Run:
  - `flutter test test/text_chunk_layout_model_test.dart`
  - `flutter test test/note_text_chunk_editor_screen_test.dart`
  - `flutter test test/note_editor_route_test.dart`

## Task 7: Full Verification, Commit, Push, Build

**Files:**
- Verify all changed files.

- [x] Run `dart format` on changed Dart files.
- [x] Run focused tests under Ubuntu:
  - `flutter test test/text_chunk_layout_model_test.dart test/note_text_chunk_editor_screen_test.dart test/note_editor_route_test.dart`
- [x] Run related notes tests under Ubuntu:
  - `flutter test test/note_selection_action_rail_test.dart test/note_list_chunk_editor_screen_test.dart test/note_table_editor_screen_test.dart`
- [x] Run `flutter analyze` under Ubuntu.
- [x] Run full `flutter test` under Ubuntu; if ObjectBox host libraries are unavailable, report exact skipped/failing reason.
- [x] Re-read `docs/superpowers/specs/2026-06-20-textchunk-native-layout-editor-design.md` and ensure no checklist item is falsely marked DONE.
- [x] Commit all changes.
- [x] Push branch `feature/textchunk-editor-layout-bugfix` to the user's GitHub remote.
- [x] Wait for GitHub Actions Android debug APK build/release.
- [x] Report branch, commit, Actions run, release page, APK download link, and any incomplete checklist item.
