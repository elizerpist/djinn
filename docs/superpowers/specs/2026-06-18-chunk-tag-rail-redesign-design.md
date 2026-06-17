# Chunk Tag Rail Redesign Design Spec

Date: 2026-06-18

## Goal

Make chunk-level and local scoped tagging feel consistent across text, list, table, and flowchart editors, with visible color feedback in the content and the actionable tag pills/actions in a selected-scope rail.

## Background

The current implementation already has persisted tag definitions, color slots, whole chunk tags, text range tags, list item tags, table scoped tags, and flowchart scoped tags. The remaining UX problem is that each editor exposes local tagging differently:

- list items still use a separate selector icon and render local pills below the card;
- text ranges show local pills below the whole text chunk instead of a range rail;
- table selection is split across cell selector icons, row/delete columns, DataTable headers, corner markers, and an external selected tray;
- flowchart pills must stay off the infinite canvas.

The accepted design direction is: content shows colored highlight feedback, while the selected target opens a rail that owns tag pills and actions.

## Non-Goals

- Do not rewrite the note document tag model unless a test proves the existing model cannot represent the accepted UX.
- Do not put tag pills inside table cells.
- Do not put tag pills on the flowchart canvas.
- Do not keep separate tiny selection icons for table cells or list items.
- Do not attempt a local Flutter APK build on Termux/Android.

## Shared UX Model

Every editor keeps the existing shared header rules:

- editable chunk title in the header;
- global tag icon for whole chunk tags;
- right-side three-dot menu for selected part tagging, selected tag deletion, and chunk deletion;
- selected tag deletion disabled when the current selection has no tag;
- whole chunk tag capsules in the subheader, full-opacity, pill-shaped, colored by the tag slot.

Local scoped tags follow one rule everywhere:

- the content itself shows color feedback with a tag-colored text background or selected outline;
- the selected target opens an inline rail;
- the rail shows local tag pills and direct actions;
- pills are not duplicated inside dense content;
- multi-tag targets show multiple pills in the rail;
- if space is tight, the closed content may only show highlight feedback, not pill text.

## Shared Rail

The rail is an inline expansion, not a floating overlay. It appears directly under the selected scope, moves content downward, and uses the same visual language in list, table, and text:

- white surface;
- thin border;
- compact vertical padding;
- full-opacity colored tag pills on the left;
- icon actions on the right;
- available actions: tag, indent/outdent where relevant, delete selected tag when relevant, delete item/row/column/cell where relevant;
- no explanatory feature text inside the rail.

## Text Chunk

Text range selection must support the same rail model:

- user selects a text range in the text field;
- the selected range receives a temporary highlight;
- when the selection is active, a range rail appears under the affected paragraph; if the selection spans paragraphs, the rail appears under the last affected paragraph;
- saved range tags render as tag-colored text background;
- range tag pills appear in the selected range rail, not as a generic bottom tag section;
- the bottom grey tip bar may remain and should contain only short instructions.

The native mobile text selection menu can coexist with the rail. The rail must not be a floating toolbar that competes with the OS selection handles.

## List Chunk

List item selection uses the accepted "action rail" design:

- tapping non-text space on a list item selects it and gives the item a border;
- tapping the text field also selects the item and keeps text editing available;
- the old selector dot/radio icon is removed;
- the checkbox remains next to the drag handle;
- the selected item expands downward and shows the rail;
- rail actions are tag, outdent, indent, and delete;
- tagged list item content uses tag-colored text background;
- local tag pills appear in the selected item rail only.

The list card must stay dense: no permanent tag manager button, no bottom add button, and no local tag pills below every item.

## Table Chunk

The table editor moves away from the broken split DataTable layout. It should behave like a compact Excel-style grid:

- a real corner cell, column heads, row heads, and body cells;
- tapping a column head selects the whole column;
- tapping a row head selects the whole row;
- tapping a cell selects that cell;
- tapping a text cell also allows editing;
- there is no tiny cell selection icon;
- there are no per-cell plus/x controls;
- row/column/cell selected state is clear from border/background.

Expansion behavior is physical, not floating:

- selecting a column expands the column head downward and pushes all table cells down;
- selecting a row expands that row downward;
- selecting a cell also expands the whole row downward;
- the rail design must match the list rail design;
- header add-row and add-column actions remain and must work.

Tag feedback:

- cell text background is highlighted for matching cell tags;
- if a row is tagged, every cell in that row highlights;
- if a column is tagged, every cell in that column highlights;
- if multiple scopes apply, use the highest-priority direct cell tag color first, then row, then column;
- pills for row/column/cell tags appear only in the expanded rail;
- row/column/cell tag assignments still use `NoteScopedTagAssignment`.

Deletion and insertion:

- rail actions replace the old visible x controls in the top grid cells;
- deleting a row, deleting a column, and inserting a column must keep the existing scoped tag remapping behavior.

## Flowchart Chunk

The flowchart canvas remains visually sparse:

- no tag pills on the canvas;
- selected/tagged nodes and edges use outline/glow/marker feedback;
- tag pills live in the selected element rail/tray outside the canvas;
- creation buttons remain three separate vertical FAB-height buttons on the right;
- zoom controls remain in the old top button area;
- drag/pan work must avoid unnecessary full-editor rebuilds during pointer movement.

## Acceptance Criteria

- A user can tag whole chunks, text ranges, list items, table rows, table columns, table cells, and flowchart elements with the same tag sheet.
- A tagged list item visibly highlights its text and shows pills only when that item is selected.
- A selected text range can show a rail and saved range tags highlight the tagged words.
- A selected table column/head/cell physically expands the grid and shows a rail, with no floating control cluster.
- Table row/column/cell tag feedback is visible as text background highlights in affected cells.
- Flowchart tags never render as pills on the canvas.
- Existing scoped tag persistence and retrieval tests remain valid.
