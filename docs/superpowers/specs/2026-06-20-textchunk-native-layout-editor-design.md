# Textchunk Native Layout Editor Design

Date: 2026-06-20

## Source Of Truth

This file is the only active spec for the notes textchunk editor rewrite.

Authoritative source instructions:

- User message on 2026-06-20 requesting a full native Flutter textchunk layout/editor rewrite.
- User follow-up on 2026-06-20 requiring this new dated spec and deletion of the old misleading specs.

Do not use older textchunk rail specs, old HTML prototypes, old textchunk implementation plans, or old textchunk widget tests as requirements. They were explicitly marked misleading by the user.

## Goal

Build a Google Keep-like native Flutter textchunk editor with a custom text layout/editor layer. The editor stores one holistic textchunk, supports paragraphs inside that chunk, keeps the whole text content selectable/editable as one continuous text model, and inserts the existing rail design as real inline content between visual text lines.

This is not a patch to the current body. The current textchunk body/layout implementation must be removed and rebuilt.

## Non-Goals

- Do not keep the current `TextField` plus `TextPainter` plus overlay rail architecture.
- Do not use WebView, HTML, or contenteditable.
- Do not split the textchunk into separate isolated note blocks.
- Do not treat paragraphs as separate menu/editor blocks.
- Do not use old specs, plans, checklists, screenshots, or prototypes as requirements.
- Do not claim completion because tests, analyze, CI, or APK build pass while checklist items remain unfinished.

## Editor Model

The textchunk is one continuous text model. Paragraphs are internal structure inside that model.

Paragraph rules:

- A paragraph is text separated from another paragraph by one empty line.
- Pressing Enter once creates a new visual/manual line inside the same paragraph.
- Automatic wrapping creates a visual line inside the same paragraph.
- Enter-created lines and automatically wrapped lines have the same layout semantics: both are paragraph-internal lines.
- Pressing Enter twice creates one empty line. Text below that empty line belongs to a new paragraph.
- New paragraphs are still part of the same textchunk and same editor, not separate app blocks.

The whole textchunk remains holistic:

- The screen represents one editable textchunk.
- The user can select text across paragraph boundaries when needed.
- If the text does not fit the screen, the editor/page scrolls and the bottom of the text is not clipped.
- No small internal scroll window may cut off the text.

## Paragraph Step Behavior

Step left and step right operate on the active paragraph.

Active paragraph:

- The paragraph containing the caret, the selected range start, or the active rail selection.
- The paragraph is bounded only by empty lines.

Step behavior:

- Step right moves the active paragraph inward.
- Step left moves the active paragraph outward.
- The paragraph's left margin/indent applies to every paragraph-internal visual line.
- Manual Enter lines and automatic wrapped lines must respect the same current left margin.
- Step operations must not affect text in the paragraph after an empty line.
- Step operations must not create isolated blocks.

## Rail Design And Behavior

The existing rail visual design stays. The current button set and functions stay:

- step left / outdent;
- step right / indent;
- tag selected text;
- clear/delete tags for the active selected range;
- previous tagged range;
- next tagged range;
- collapse/expand pill row;
- pill row with the active range tags.

The rail implementation must change:

- The rail is real inline content in the text layout.
- The rail is inserted below the selected visual line.
- The text opens at that point and every following line is pushed down by normal layout.
- The rail must not be painted on top of selected text.
- The rail must not be a global bottom menu.
- The rail must not be a floating popup.

Selection anchor rules:

- If the user selects one word or any text range on one visual line, the rail opens below that visual line.
- If the user selects text spanning multiple visual lines, the rail opens below the lowest selected visual line.
- The rail is tied to the selected text/range inside the paragraph layout.
- Menu button taps must not lose the active text selection/range.

## Tag Rendering

Selected text can be tagged through the rail tag button, which opens the existing tag editor sheet.

Rendering rules:

- The first tag is the primary tag.
- The primary tag colors only the tagged text background.
- Each additional tag creates one underline under the tagged text range.
- Each underline uses that tag's color.
- Underlines must be exactly under the tagged range, not the whole row and not the whole paragraph.
- If there are many underlines, line spacing grows automatically so the underlines do not collide with the next line.
- Underline spacing is part of the real text layout, not a loose overlay guess.

## Architecture

Create a native Flutter custom textchunk layout/editor layer.

Required boundaries:

- A layout model that converts the one continuous text value into paragraphs, visual lines, selection boxes, rail insertion point, and underline lanes.
- An editor widget that renders visual lines and inserts the rail as a normal widget below the selected visual line.
- A selection controller that stores selection as continuous text offsets, so selection can span paragraphs.
- A paragraph step service that edits paragraph indent without splitting the chunk into blocks.
- Tag range adjustment logic that keeps range tags aligned when text changes.

The existing persistence model should be reused:

- `NoteBlock.text`
- `NoteBlock.rangeTags`
- `NoteBlock.tags`
- `NoteKnowledgeTag`
- `NoteTextRangeTag`
- existing `showTagManagerSheet`
- existing `NoteSelectionActionRail` visual rail component, with the same button functions.

The current textchunk body can be emptied and rebuilt. Existing route/header/storage integration should remain unless it directly depends on the old body architecture.

## Testing Requirements

Delete the old textchunk editor tests and write new tests only from this spec.

Required test groups:

- model tests for paragraph parsing and visual line layout;
- model tests for Enter-created and auto-wrapped lines sharing the same paragraph indent behavior;
- widget tests proving the rail is an inserted widget below the selected visual line;
- widget tests proving multi-line selection opens the rail below the lowest selected visual line;
- widget tests proving underlines match tagged text range width and location;
- widget tests proving stacked underlines increase spacing before the next line;
- widget tests proving text can grow and page/editor scrolling keeps the bottom reachable;
- widget tests proving tag sheet flow stores primary background plus secondary underline tags;
- route/autosave tests proving the holistic textchunk still saves through `NoteBlock`.

Run tests under Ubuntu/Flutter. Do not run local Android APK builds on Termux.

## Acceptance Checklist

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-001 | User 2026-06-20: old specs misleading; new 0620 spec | `docs/superpowers/specs`, `docs/superpowers/plans`, `docs/superpowers/checklists` | Old misleading textchunk/rail specs, plans, and checklists are removed; this file is the only active textchunk rewrite spec. | Git diff inspection | DONE |
| TC-REQ-002 | User 2026-06-20: "sajat textchunk layout/editor reteg" | `lib/src/notes/ui/note_text_chunk_editor_screen.dart`, new textchunk editor files | Current body/layout is removed and replaced with a custom native Flutter textchunk layout/editor layer. | Code inspection and widget tests | DONE |
| TC-REQ-003 | User 2026-06-20: Google Keep-like holistic editor | editor widget/state | One screen edits one continuous textchunk; paragraphs are internal structure, not separate blocks. | Widget tests and route autosave test | DONE |
| TC-REQ-004 | User 2026-06-20: whole screen selectable | selection controller/editor widget | Selection is stored as continuous offsets and can span visual lines and paragraph boundaries. | Widget/model tests | DONE |
| TC-REQ-005 | User 2026-06-20: overflow scrolls, bottom not clipped | editor scroll/container | Long text grows and remains reachable by page/editor scrolling; no small clipping text window. | Widget scroll test | DONE |
| TC-REQ-006 | User 2026-06-20: paragraphs separated by double Enter/empty line | layout model | One Enter creates a paragraph-internal line; two Enters create an empty separator and a new paragraph. | Model tests | DONE |
| TC-REQ-007 | User 2026-06-20: Enter trigger equals autowrap mechanism | layout model/paragraph step service | Manual lines and automatically wrapped visual lines use the same paragraph indent/margin rules. | Model tests with forced narrow width | DONE |
| TC-REQ-008 | User 2026-06-20: step left/right paragraph behavior | paragraph step service, header and rail actions | Step left/right changes the entire active paragraph and does not affect text after an empty line. | Model and widget tests | DONE |
| TC-REQ-009 | User 2026-06-20: rail design remains | `NoteSelectionActionRail`, text rail wrapper | Existing rail design, buttons, and functions remain available in the textchunk editor. | Widget tests for rail buttons | DONE |
| TC-REQ-010 | User 2026-06-20: rail inserted under selected line | editor widget/layout model | One-line selection opens the rail as inserted content below that visual line and pushes following text down. | Widget rect/order test | DONE |
| TC-REQ-011 | User 2026-06-20: multi-line selection rail below lowest line | editor widget/layout model | Multi-line selection opens the rail below the lowest selected visual line. | Widget test | DONE |
| TC-REQ-012 | User 2026-06-20: tag via rail sheet | text rail actions/tag manager integration | Rail tag button opens existing tag editor sheet and stores tags on the selected text range. | Widget interaction test | DONE |
| TC-REQ-013 | User 2026-06-20: first tag background | tag renderer/layout model | First tag colors only the tagged text background. | Widget visual/keyed renderer test | DONE |
| TC-REQ-014 | User 2026-06-20: every extra tag underline | tag renderer/layout model | Every additional tag renders one underline in that tag color under only the tagged range. | Widget visual/keyed renderer test | DONE |
| TC-REQ-015 | User 2026-06-20: many underlines need spacing | tag renderer/layout model | Multiple underlines reserve vertical space so they never overlap following text. | Widget spacing test | DONE |
| TC-REQ-016 | User 2026-06-20: old tests misleading | `test/note_text_chunk_editor_screen_test.dart`, new tests | Old textchunk editor tests are deleted/replaced with tests derived only from this spec. | Git diff and test names | DONE |
| TC-REQ-017 | User 2026-06-20: commit, push, build link | GitHub branch/actions/release | Changes are committed, pushed, GitHub Actions APK build completes, and download link is reported. | Git/GitHub Actions/release verification | DONE |

## Follow-Up Patch Checklist

Source: user message on 2026-06-20 after testing the first native textchunk APK. The current custom textchunk workaround and inline rail architecture must remain; only targeted patches are allowed.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-018 | User 2026-06-20: "nincs kurzor" | `text_chunk_canvas_editor.dart` | A collapsed selection renders a visible caret on the custom text line, including empty lines. | Widget tests | DONE |
| TC-REQ-019 | User 2026-06-20: selection cannot be stretched; missing points | `text_chunk_canvas_editor.dart` | A selected range renders draggable start/end handles, and dragging a handle updates the continuous selection. | Widget tests | DONE |
| TC-REQ-020 | User 2026-06-20: repeated Enter blank line not visible | `text_chunk_layout_model.dart`, `text_chunk_canvas_editor.dart` | Empty manual/separator lines created by repeated Enter are rendered as real visual lines. | Model and widget tests | DONE |
| TC-REQ-021 | User 2026-06-20: after tagging cannot tap text to show keyboard/write again | `text_chunk_canvas_editor.dart`, `note_text_chunk_editor_screen.dart` | Tapping visible text after tagging collapses/moves the selection, focuses the input bridge, and leaves the editor ready for text input. | Widget tests | DONE |
| TC-REQ-022 | User 2026-06-20: textchunk rail needs table-like design buttons | `note_text_chunk_editor_screen.dart`, `note_tag_pills.dart` | Textchunk rail exposes rounded, white/grey background, and border toggles like the table rail, with white/grey background behavior. | Widget tests | DONE |
| TC-REQ-023 | User 2026-06-20: many text rail buttons need horizontal scroll | `NoteSelectionActionRail`, text rail actions | Textchunk rail action row remains horizontally scrollable with the expanded action set; tag row remains scrollable. | Widget tests | DONE |
