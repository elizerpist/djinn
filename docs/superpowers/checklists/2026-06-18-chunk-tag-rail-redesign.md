# Chunk Tag Rail Redesign Checklist

Date: 2026-06-18

## Spec And Plan

- [x] Capture the accepted list action-rail design.
- [x] Capture the accepted table Excel-style head/grid design.
- [x] Capture the accepted text selection rail design.
- [x] Capture the accepted flowchart no-canvas-pills rule.
- [ ] Save the implementation plan.

## Shared Rail

- [ ] Build/reuse one compact selected-scope rail component.
- [ ] Rail renders local tag pills with full-opacity tag colors.
- [ ] Rail action buttons are icon-first and dense.
- [ ] Local pills are removed from dense content below list items and table cells.

## Text Chunk

- [ ] Active text selection can expose a rail.
- [ ] Saved range tags highlight tagged text.
- [ ] Local range pills appear in the range rail, not as a generic bottom pill row.
- [ ] Existing selected-tag deletion behavior still works.

## List Chunk

- [ ] Remove the list item selector dot/radio icon.
- [ ] Tapping list item non-text space selects the item.
- [ ] Tapping list item text selects the item and still edits text.
- [ ] Checkbox remains beside the drag handle.
- [ ] Selected item expands downward with the rail.
- [ ] Rail actions: tag, outdent, indent, delete.
- [ ] Tagged item text background uses the tag color.
- [ ] Local list item pills appear only in the selected rail.

## Table Chunk

- [ ] Replace split DataTable row/action layout with an Excel-like grid.
- [ ] Provide a real corner cell, column heads, row heads, and body cells.
- [ ] Tapping a column head selects the whole column.
- [ ] Tapping a row head selects the whole row.
- [ ] Tapping a cell selects the cell and keeps editing available.
- [ ] Remove tiny cell selector icons.
- [ ] Remove visible top-cell plus/x controls from the grid.
- [ ] Column selection expands the column head downward.
- [ ] Row selection expands the row downward.
- [ ] Cell selection expands the whole row downward.
- [ ] Table rail design matches the list rail design.
- [ ] Row tags highlight every cell in the row.
- [ ] Column tags highlight every cell in the column.
- [ ] Cell tags highlight the direct cell.
- [ ] Row/column/cell tag pills appear only in the expanded rail.
- [ ] Existing scoped tag remap/drop behavior still passes.

## Flowchart Chunk

- [ ] No tag pills render on the canvas.
- [ ] Selected/tagged nodes and edges keep outline/marker feedback.
- [ ] Flowchart local tag pills remain outside the canvas.
- [ ] Vertical create FABs remain three separate buttons.

## Verification

- [ ] Add failing tests before production UI changes.
- [ ] Verify RED on GitHub Actions because local Flutter/Dart is not runnable on Termux ARM64.
- [ ] Implement minimal production changes.
- [ ] Verify GREEN on GitHub Actions.
- [ ] Commit and push final branch.
