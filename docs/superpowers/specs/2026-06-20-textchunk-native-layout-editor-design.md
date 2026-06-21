# Textchunk Native Layout Editor Design

Date: 2026-06-20

## Source Of Truth

This file is the only active spec for the notes textchunk editor rewrite.

Authoritative source instructions:

- User message on 2026-06-20 requesting a full native Flutter textchunk layout/editor rewrite.
- User follow-up on 2026-06-20 requiring this new dated spec and deletion of the old misleading specs.
- User follow-up on 2026-06-20 after external research: prioritize native Flutter caret, selection handles, and copy/paste context menu by moving to a hybrid visible `EditableText`/`RenderEditable` implementation; keep the previous custom editor file archived so rollback is possible.

Do not use older textchunk rail specs, old HTML prototypes, old textchunk implementation plans, or old textchunk widget tests as requirements. They were explicitly marked misleading by the user.

## Goal

Build a Google Keep-like native Flutter textchunk editor. The editor stores one holistic textchunk, supports paragraphs inside that chunk, keeps the whole text content selectable/editable as one continuous text model, and shows the existing rail design near the selected visual line.

Current latest direction: use a hybrid native editor. The visible text editing surface must be `EditableText`/`RenderEditable` so Flutter owns the native caret, selection handles, and copy/paste/select-all context menu. The rail may be inserted through the editable text span as a `WidgetSpan`/layout spacer rather than by fully custom-rendering the text.

The previous custom line-rendered editor must be preserved in an archive file before replacement, so the project can roll back if the hybrid path proves worse on device.

## Non-Goals

- Do not keep the hidden 1x1 `EditableText` plus fully custom visible text/caret/handle renderer as the active implementation.
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

The original custom implementation inserted the rail as real content between custom-rendered visual lines. The current hybrid implementation must instead keep native editing first:

- The rail is inserted into the visible `EditableText` layout through a `WidgetSpan`/spacer or equivalent native-editable-compatible mechanism.
- The rail is inserted below the selected visual line when possible.
- The text opens at that point and following text is pushed down by the editable text layout, without replacing the native `RenderEditable` caret/selection system.
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

Create a hybrid native Flutter textchunk layout/editor layer.

Required boundaries:

- A layout model that converts the one continuous text value into paragraphs, visual lines, selection boxes, rail insertion point, and underline lanes.
- A visible `EditableText` editor widget that owns the native cursor, selection handles, keyboard integration, and context menu.
- A styled text controller/span builder that applies tag highlighting and inserts the rail spacer/widget at the selected visual line boundary.
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

Existing route/header/storage integration should remain unless it directly depends on the old body architecture.

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

## Native EditableText Hybrid Checklist

Source: user message on 2026-06-20 after external research. This section supersedes the custom-only implementation constraints above when they conflict.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-024 | User 2026-06-20: "korábbi fájl meglegyen, ha vissza akarunk lépni" | `docs/superpowers/rollback` | The previous custom textchunk editor files are archived outside the active `lib` tree before replacement. | Git diff inspection | DONE |
| TC-REQ-025 | User 2026-06-20: native Flutter caret/handles/copy actions | `text_chunk_canvas_editor.dart` | The visible editor is a real `EditableText`, not a hidden 1x1 input bridge plus custom-rendered text. | Widget/code inspection test | DONE |
| TC-REQ-026 | User 2026-06-20: keep rail and current functions | `text_chunk_canvas_editor.dart`, `note_text_chunk_editor_screen.dart` | The existing rail component and buttons still appear for selected text and remain tappable. | Widget test | DONE |
| TC-REQ-027 | User 2026-06-20: hybrid rail/spacer compromise | styled controller/editor span | The rail is inserted into the editable layout through a widget span/spacer at the selected visual line boundary, pushing following text instead of covering selected text. | Widget rect/order test | DONE |
| TC-REQ-028 | User 2026-06-20: selection must remain usable after inline rail insertion | editor selection normalization | Tapping/selecting text after the inserted rail keeps controller selection offsets valid for the underlying text value. | Widget test | DONE |
| TC-REQ-029 | User 2026-06-20: do not lose blank Enter behavior | layout/editor | Repeated Enter still renders reachable empty lines in the visible native editor. | Widget test | DONE |

## 2026-06-21 Native Rail Regression Checklist

Source: user message on 2026-06-21 after testing APK `6c3eaf7`: the text does not split open, the rail prints over lower lines, native Android copy/selection handles are still not visible, and the cursor still looks like the previous custom behavior. User also requested detailed debug logs after the fix.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-030 | User 2026-06-21: "nem válik szét a szöveg, a rail az alsó sorokra ráprintel" | `text_chunk_canvas_editor.dart`, text layout/rail host | The actual visible text below the selected visual line is laid out below the rail gap; verification must inspect native editable/rendered text geometry, not only helper line markers. | Widget test using native editable geometry | DONE |
| TC-REQ-031 | User 2026-06-21: "natív android textet sem látom, nem lehet másolni, kijelölést módosítani" | native text editor surface and selection wiring | The active visible editor remains a real `EditableText`/`RenderEditable` path with Flutter selection controls and context menu available; the implementation must not rely on custom cursor/handle widgets. | Widget/code inspection and focused interaction test | DONE |
| TC-REQ-032 | User 2026-06-21: "ha kész a fix adj hozzá részletes debug logokat" | `text_chunk_canvas_editor.dart`, debug console | Log selection range, visual line list, rail line/index/top/bottom/height, native editable geometry, text/layout widths, line gaps, and rail overlap diagnostics whenever the textchunk layout updates. | Code inspection and test/log smoke check | DONE |

## 2026-06-21 Second Native Regression Checklist

Source: user message on 2026-06-21 after testing APK `fc80b82`: native Android clipboard pills still do not appear, paragraph step affects only the first native wrapped row, and many underlines do not reserve native text spacing.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-033 | User 2026-06-21: "a natív android vágólap pillek nem ugornak fel" | `text_chunk_canvas_editor.dart`, native selection/context menu wiring | A real text selection can show the native Flutter/Android text selection toolbar with copy/select actions; verification must trigger or show the toolbar, not only inspect that a builder exists. | Widget interaction test using `EditableTextState.showToolbar()`/toolbar UI | DONE |
| TC-REQ-034 | User 2026-06-21: "a bekezdés step kezelés nem jó, csak az első sor steppel" | paragraph step and native editable layout | After paragraph step-in, every native-rendered wrapped row of the active paragraph starts at the paragraph indent, not only the first hard line. | Widget test using `RenderEditable` glyph box geometry | DONE |
| TC-REQ-035 | User 2026-06-21: "a sorköz sem automatikus, ha sok aláhúzás van nem tolja lejjebb az android szöveget" | underline spacing/native text layout | Multiple secondary underline lanes increase the native editable line spacing enough that following native-rendered text is below the last underline. | Widget geometry test comparing underline rects to native glyph boxes | DONE |

## 2026-06-21 Third Native Geometry Regression Checklist

Source: user message on 2026-06-21 after testing the APK built from `de1f83b`: latest screenshot shows duplicated tagged-word highlight, tag background/underlines not following the tagged word when the rail expands, rail gap larger than the rail, rail gap not following open/closed tag-row height, underlines growing upward over the tagged word, and paragraph step leaving stale wrap points after margin changes. Native toolbar and basic paragraph step behavior are considered preserved and must not regress.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-036 | User 2026-06-21: "duplán ad highlight hátteret a taggelt szónak" | `text_chunk_canvas_editor.dart`, styled text/tag overlay | A tagged range has exactly one primary background source; the separate overlay must not duplicate the native `TextSpan` background. | Widget/code inspection test for absence of primary overlay and native tag span still active | DONE |
| TC-REQ-037 | User 2026-06-21: "a szót nem követi a tag háttérszín/underline vonalak" | `text_chunk_canvas_editor.dart`, native tag geometry sync | Tag highlight/underline geometry is derived from current `RenderEditable` glyph boxes so it follows the word after rail insertion, selection movement, text edits, and line reflow. | Widget geometry tests comparing tag overlay rects to native substring rects before and after rail insertion/text edits | DONE |
| TC-REQ-038 | User 2026-06-21: "a lefele expand jóval nagyobb teret hagy ki, mint a rail magassága" | `text_chunk_canvas_editor.dart`, rail spacer measurement | The native inline spacer height equals the measured rail height plus the configured rail gap, not a fixed oversized placeholder stack. | Widget rect test comparing rail height, spacer height, and following native text top | DONE |
| TC-REQ-039 | User 2026-06-21: "ha a rail magassága változik ... dinamikusan kell illeszkednie" | `text_chunk_canvas_editor.dart`, `NoteSelectionActionRail` host | Collapsing/expanding the rail tag row updates the inline spacer height and the text below moves to the new rail bottom. | Widget interaction test toggling tag row and comparing native text geometry | DONE |
| TC-REQ-040 | User 2026-06-21: "több underline vonal ... felfele nő, az adott szót fedik" | underline renderer/native line spacing | Secondary underline lanes are drawn below the tagged glyph area and line spacing grows downward enough that underlines do not cover the word or the following line. | Widget geometry test comparing native tagged-word rect, underline rects, and following native line rect | DONE |
| TC-REQ-041 | User 2026-06-21: "step in/out ... automatikus sor layout ... nem számol dinamikusan" | `text_chunk_text_editing.dart`, paragraph step reflow | Paragraph step recalculates current wrap points from a normalized paragraph source for the current width/margin; repeated step in/out must not accumulate stale hard wrap fragments or stop early before the right edge. | Model/widget tests for repeated step reflow and native row widths | DONE |
| TC-REQ-042 | User 2026-06-21: "ha kész a fix még több debug logot adj hozzá" | `text_chunk_canvas_editor.dart`, `text_chunk_text_editing.dart`, debug console | Debug logs include measured rail height/spacer/gap, native tag geometry rects, underline lane rects, stale-wrap normalization/reflow counts, and rail/text overlap diagnostics. | Code inspection and debug log smoke tests | DONE |

## 2026-06-21 Fourth Native Spacing Regression Checklist

Source: user message on 2026-06-21 after the latest screenshot: underline positions are now correct, but underline-created line spacing must only affect the visual lines that actually contain many underline lanes. The same screenshot shows paragraph step-in moving the right wrap boundary inward even though only the left margin should change.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-043 | User 2026-06-21: "ha sok underline van ... ez csak azokban a sorokban legyen ervenyes, ne az egesz bekezdesben" | `text_chunk_canvas_editor.dart`, native placeholder/underline spacing | Extra vertical space for secondary underline lanes is inserted only after visual lines that contain those underline lanes; untagged lines keep the normal native line distance. | Widget geometry test comparing unaffected line gaps and tagged-line underline clearance | DONE |
| TC-REQ-044 | User 2026-06-21: "step innel ... a jobb oldali is beljebb kerul ... a szoveg jobb szele mindig a screen jobb szele" | `text_chunk_layout_model.dart`, `text_chunk_text_editing.dart` | Paragraph step-in changes the left indent only; wrapped native text still uses the full editor width and can reach the right screen/editor edge. | Widget/model tests using native glyph line bounds after step-in | DONE |

## 2026-06-21 Fifth Native Rail/Underline Spacing Regression Checklist

Source: user message on 2026-06-21 after screenshot `Screenshot_20260621-122833.png`: the rail is still miscalculating its opened gap, text is not split open correctly, and many secondary underline lanes can still run into the following line instead of increasing the spacing below the underline.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-045 | User 2026-06-21: "a rail nem jól számol, nem megfelelően nyílik szét a szöveg" | `text_chunk_canvas_editor.dart`, native placeholder/spacer host | When the inline rail opens under a selected visual line, the following native editable text starts at or below the visible rail bottom with only the expected rounded line-height slack. | Widget geometry test with native `EditableText` glyph rects, visible rail rect, and following soft-wrapped text rect | DONE |
| TC-REQ-046 | User 2026-06-21: "beleér a sok aláhúzás az alatta lévő sorba ... nő meg az aláhúzás alatti sorköz" | `text_chunk_canvas_editor.dart`, secondary underline spacing | Multiple secondary underline lanes increase the vertical space below that exact visual line before any following native line or rail, including soft-wrapped lines. | Widget geometry test comparing the last underline rect to the next native visual line and to the rail rect when rail is visible | DONE |

## 2026-06-21 Sixth Native Rail Dynamic Spacing Regression Checklist

Source: user message on 2026-06-21 after testing the latest APK: the rail still cannot find its place and does not split rows correctly; underline spacing now opens but must shrink dynamically when underlines are removed; step in/out still misses some rows and outdented rows can remain offset from the margin.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-047 | User 2026-06-21: "még mindig nem találja meg a rail a helyét, nem húzza szét megfelelően a sorokat" | `text_chunk_canvas_editor.dart`, native rail placeholder/spacer host | A rail opened after a soft-wrapped selected line reserves enough native editable line breaks for the measured rail height plus gap; the next native text line starts below the rail after rail height changes. | Widget geometry test on a soft-wrapped line using native glyph rects, rail rect, and debug placeholder logs | DONE |
| TC-REQ-048 | User 2026-06-21: "ha user underlinet töröl ... annyival kisebb legyen a sorköz" | `text_chunk_canvas_editor.dart`, underline spacer planning | Removing secondary underline lanes immediately reduces the native placeholder count and the following line moves upward; removing all secondary underlines removes the underline spacer entirely. | Widget test that repumps the same range with many, one, and zero underline lanes and compares native line gaps/logs | DONE |
| TC-REQ-049 | User 2026-06-21: "step in step out nem minden sort észlel rendesen ... van hogy sor nem a margótól kezdődik" | `text_chunk_text_editing.dart`, paragraph step normalization/reflow | Repeated step-in followed by step-out normalizes all synthetic wrap breaks; when indent returns to zero, every active paragraph native row starts at the editor left edge. | Widget/model test with repeated step in/out and native glyph line left bounds | DONE |

## 2026-06-21 Seventh Native Underline And Selection Drag Checklist

Source: user message on 2026-06-21 after testing the latest APK and debug logs: one underline should not stretch line spacing; underline spacing must shrink more dynamically when many underline lanes are removed; selection handles should drag freely. User approved the updated drag model where the rail disappears while a selection handle is being dragged and reappears under the final lowest selected line after the drag ends.

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TC-REQ-050 | User 2026-06-21: "ha csak 1 underline van, annak nem kell széthúznia a szöveget" | `text_chunk_canvas_editor.dart`, underline spacer planning | A single secondary underline is drawn below the tagged text but does not insert an underline native placeholder and does not increase the following native line gap. | Widget geometry/log test comparing one secondary underline to no secondary underline | DONE |
| TC-REQ-051 | User 2026-06-21: "még nem dinamikus eléggé az underline-sorköz számítás ... 10 vonalat ... letöröl 5-öt" | `text_chunk_canvas_editor.dart`, underline spacer planning and underline geometry | Reducing a stacked underline range from many lanes to fewer lanes immediately reduces the reserved native spacer rows; five lanes must use less vertical space than eight or more lanes, and one lane must use no spacer. | Widget geometry/log test repumping the same range with eight, five, one, and zero secondary lanes | DONE |
| TC-REQ-052 | User 2026-06-21: "amíg a user a handlet draggeli, addig eltűnik a rail, csak akkor jön vissza, ha vége a dragnek" | `text_chunk_canvas_editor.dart`, native selection change handling and rail visibility state | During `SelectionChangedCause.drag`, the inline rail and its native placeholder are removed so the handle can move over normal text layout; after drag idle/end, the rail reappears below the lowest line of the final selected range. | Widget test simulating native selection drag and verifying rail absence during drag plus final re-anchoring | DONE |
