# Chunk Tag Rail Redesign Checklist

Date: 2026-06-18

## Spec And Plan

- [x] Capture the accepted list action-rail design.
- [x] Capture the accepted table Excel-style head/grid design.
- [x] Capture the accepted text selection rail design.
- [x] Capture the accepted flowchart no-canvas-pills rule.
- [x] Save the implementation plan.

## Shared Rail

- [x] Build/reuse one compact selected-scope rail component.
- [x] Rail appears as the selected component's own downward appendix.
- [x] Rail uses a very light grey surface with a thin top separator.
- [x] Rail renders local tag pills with full-opacity tag colors.
- [x] Rail action buttons are icon-first and dense.
- [x] Local pills are removed from dense content below list items and table cells.
- [x] Tag feedback colors only the affected text background, never the whole component card.

## Text Chunk

- [x] Active text selection can expose a rail.
- [x] Saved range tags highlight tagged text.
- [x] Local range pills appear in the range rail, not as a generic bottom pill row.
- [x] Existing selected-tag deletion behavior still works.

## List Chunk

- [x] Remove the list item selector dot/radio icon.
- [x] Tapping list item non-text space selects the item.
- [x] Tapping list item text selects the item and still edits text.
- [x] Checkbox remains beside the drag handle.
- [x] Selected item expands downward with the rail.
- [x] Rail actions: tag, outdent, indent, delete.
- [x] Tagged item text background uses the tag color.
- [x] Local list item pills appear only in the selected rail.

## Table Chunk

- [x] Replace split DataTable row/action layout with an Excel-like grid.
- [x] Provide a real corner cell, column heads, row heads, and body cells.
- [x] Tapping a column head selects the whole column.
- [x] Tapping a row head selects the whole row.
- [x] Tapping a cell selects the cell and keeps editing available.
- [x] Remove tiny cell selector icons.
- [x] Remove visible top-cell plus/x controls from the grid.
- [x] Column selection expands the column head downward.
- [x] Row selection expands the row downward.
- [x] Cell selection expands the whole row downward.
- [x] Table rail design matches the list rail design.
- [x] Row tags highlight every cell in the row.
- [x] Column tags highlight every cell in the column.
- [x] Cell tags highlight the direct cell.
- [x] Row/column/cell tag pills appear only in the expanded rail.
- [x] Existing scoped tag remap/drop behavior still passes.

## Flowchart Chunk

- [x] No tag pills render on the canvas.
- [x] Selected/tagged nodes and edges keep outline/marker feedback.
- [x] Flowchart local tag pills remain outside the canvas.
- [x] Vertical create FABs remain three separate buttons.
- [x] Remove the node visual shape chooser from the flowchart editor.
- [x] Render editor nodes, popup previews, and note-menu previews as rounded boxes only.
- [x] Inline note-menu flowchart previews start fit-to-view.
- [x] Inline note-menu flowchart previews reserve one-finger gestures for parent scroll and use two fingers for chart pan/zoom.

## Verification

- [x] Add failing tests before production UI changes.
- [ ] Verify RED/GREEN on GitHub Actions because local Flutter/Dart is not runnable on Termux ARM64.
- [x] Implement minimal production changes.
- [ ] Verify GREEN on GitHub Actions.
- [ ] Commit and push final branch.

## Follow-Up

- [ ] Paragraph-anchored text range rail: the spec asks for the rail under the affected paragraph, but the current editor is one full-height `TextField`. The implemented rail follows the implementation plan and appears above the tip bar; paragraph anchoring needs a future text editor layout refactor.
