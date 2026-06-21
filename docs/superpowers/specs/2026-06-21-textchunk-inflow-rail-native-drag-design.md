# Textchunk In-Flow Rail With Native Handle Drag Design

Date: 2026-06-21

## Context

The text chunk editor currently mixes a native `EditableText` selection path with rail-driven layout work. Earlier fixes removed hidden rail placeholders from the native text span, but the user still sees non-fluent handle dragging, haptic/tick feedback, and character-by-character expansion. The requested behavior is not an overlay rail: after a settled text selection, the rail must be inserted between visual text rows and push the content below it down.

## Approved Behavior

When the user selects text, the native selection handles and native clipboard toolbar appear. The selection action rail appears as in-flow editor content after the selected visual line, so content below that line moves down.

When the user drags a native selection handle, `EditableText` owns the interaction. During the drag, the rail must not continuously reinsert, resize, or shift the text layout under the handle. The editor may hide the rail or keep its previous reserved slot frozen during the drag, but it must not recalculate an in-flow rail position on every selection update. When the user releases the handle, the editor uses the final selection to insert the rail after the final selected visual line.

## Recommended Architecture

Keep the native `EditableText` text span pure. Do not insert rail placeholders or rail spacer text into `TextChunkNativeEditingController.buildTextSpan`.

Represent the rail as an editor-layout item, not as native text. The canvas layout computes visual line rectangles from the same wrapping model used for markers and tag decoration. For a settled selection, it reserves a vertical slot after `textChunkRailLineIndexForSelection(...)` and positions later editor-layer items below that slot.

Introduce a small selection interaction state in `TextChunkCanvasEditor`:

- `settled`: selection is stable; rail can be measured, reserved, and shown in-flow.
- `draggingNativeHandle`: native handle drag is active; no rail recomputation, no app-side selection writes, no toolbar requests.

Selection drag start is detected from `SelectionChangedCause.drag` and/or explicit handle contact if custom controls are needed. Drag end is inferred only from a safe release path, not from a short timer that can fire while the user is still holding the handle.

## Trade-Offs

Option A, live in-flow rail during drag: rejected. It continuously changes layout under the native handle and is the likely source of the tick/haptic/character-step behavior.

Option B, overlay rail only: rejected. It contradicts the requirement that the rail be inserted between rows and push content down.

Option C, in-flow rail when settled and native-only drag while moving: approved. It preserves the requested settled layout while keeping native handle movement fluent.

## Acceptance Checklist

| ID | Source | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| TIR-001 | User: "a rail nem overlay... ket sor koze ekelodjon be" | `lib/src/notes/ui/text_chunk_canvas_editor.dart`, layout model tests | After a settled text selection, the rail is rendered after the selected visual line and content below that line is shifted down by the rail height plus gap. | Widget test compares selected line, rail rect, and following line rect. | NOT DONE |
| TIR-002 | User: "nativ... handlerwkkel expandalni rendesen... szabadon mozgatni" | `TextChunkCanvasEditor` selection handling | During native handle drag, the editor does not write controller selection, does not add native placeholders, does not request toolbar, and does not recompute/move the in-flow rail per drag update. | Widget tests simulate drag callbacks and assert rail is hidden or frozen, plain text is unchanged, and selection updates stay native-owned. | NOT DONE |
| TIR-003 | User: "user kijelol, megjelenik a rail, es a nativ vagolap gombok" | `EditableText` configuration and toolbar path | A settled selection shows native selection handles, native clipboard toolbar, and the in-flow rail together before any handle drag starts. | Widget test long-presses text and asserts non-collapsed native selection, toolbar presence, and rail presence. | NOT DONE |
| TIR-004 | User logs showing `placeholderDelta=0` but persistent ticking | `TextChunkNativeEditingController`, debug logs | Rail insertion must not be represented as hidden text in the native text span. `placeholderDelta` remains zero for rail-only selections and handle drags. | Existing and new regression tests inspect native plain text and debug logs. | NOT DONE |
| TIR-005 | Project constraint: Flutter APK builds are not local on Termux | GitHub Actions workflow after implementation | Local verification runs targeted Flutter tests/analyze where possible; Android APK build is verified through GitHub Actions after commit and push. | Command output plus Actions URL. | NOT DONE |

## Testing Plan

Add failing widget tests before production changes:

- settled in-flow rail pushes the following native/editor line down;
- long press shows native toolbar and in-flow rail;
- simulated native handle drag does not mutate native text presentation or reinsert a moving rail;
- drag release restores the rail at the final selected visual line.

Run targeted widget tests locally if Flutter works in the environment. Do not run a local Flutter APK build on Termux. Use GitHub Actions for the Android build after implementation.
