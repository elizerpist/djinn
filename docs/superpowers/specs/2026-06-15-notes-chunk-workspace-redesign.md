# Notes Chunk Workspace Redesign

Date: 2026-06-15

## Goal

Redesign notes from a preview-card creation flow into a full-screen chunk
workspace. A note is a user-authored knowledge document made of ordered,
typed chunks. The user's structure is the chunk structure: one chunk card maps
to one note block and normally produces one searchable chunk.

This replaces the temporary slide-up create card and preview flow introduced
for mixed notes. The notes feature should feel closer to a PDF knowledge
workspace than to a simple form.

## Non-Goals

- No duplicate-note action.
- No save buttons in note or chunk editors.
- No inline editing inside expanded chunk cards.
- No audit chip for user-authored notes.
- No bottom footer toolbar for adding note elements.

## Notes List

The notes menu remains a list of compact note boxes, visually aligned with PDF
boxes.

Actions:

- Tap a note box: open the full-screen note editor with a right-side slide-in
  transition.
- Tap the notes FAB: create a new note and open the same full-screen editor.
- Long press/select notes: switch the header into selected-note mode.

The old creation sheet must be removed from this flow:

- no slide-up create card;
- no preview box;
- no note type picker;
- no folder dropdown in the create flow.

Folder movement remains available through menus.

## Selected Note Header Menu

For one selected note, the header dropdown contains:

- Edit
- View chunks
- Index / re-index
- Extracted content audit
- Move to folder
- Export
- Share
- Rename
- Delete

For multiple selected notes, only batch-safe actions remain:

- Index / re-index
- Move to folder
- Export
- Share
- Delete

There is no duplicate action.

## Full-Screen Note Editor

The editor opens as a right-side slide-in page.

Header:

- Back arrow on the left.
- Center title is short, e.g. `Jegyzet` or the shortened current note title.
- Three-dot menu on the right.
- The editable note title lives below the app bar as a full-width inline title
  field.

Editor menu:

- Index / re-index
- View chunks
- Extracted content audit
- Move to folder
- Export
- Share
- Delete

There is no Rename menu item inside the editor because the title is directly
editable.

All modifications use immediate autosave:

- title edits;
- text edits;
- list edits;
- table edits;
- flowchart edits;
- chunk add/delete;
- chunk reorder.

Destructive chunk delete uses immediate removal plus an undo snackbar:

- the card disappears immediately;
- snackbar: `Chunk torolve` with `Visszavonas`;
- undo restores the chunk at its previous position and autosaves again.

## Chunk Card Model

The note editor body is an ordered list of chunk cards.

Rules:

- One chunk card equals one note block.
- One note block normally equals one chunk.
- Chunk cards are typed: text, list, table, and flowchart.
- Each type has its own icon and color.
- Cards can be collapsed or expanded.
- Expanded content is read-only.
- Body tap opens the type-specific full-screen editor.
- Expand/collapse state is transient UI state and is not saved into the note
  data model.

Expanded card rendering must mirror the editor content 1:1:

- paragraph spacing and line breaks are preserved;
- lists render as list items with hierarchy;
- tables render as tables;
- flowcharts render visually, not as plain text.

The card header includes status chips:

- `Kinyerve`: the chunk has user-authored content.
- `Indexelve`: the current content has fresh embedding/index data.
- `Ujraindexelendo`: content changed after the last index.

There is no audit chip for user-authored notes.

## Chunk Reordering

Chunk cards are reorderable through a drag handle on the left side.

Interaction:

- long press on the handle starts drag;
- the dragged ghost card keeps the same size as the original card;
- live reorder is required: as the user drags down/up, nearby cards swap
  positions during the drag, not only after drop;
- the new order autosaves immediately.

Dragging the body should not start reorder, because body tap opens the chunk
editor.

## Editor FAB

The full-screen note editor owns one icon-only FAB.

Activating the FAB ejects icon-only sub-FABs:

- text chunk;
- list chunk;
- table chunk;
- flowchart chunk;

The FAB and sub-FABs must not contain text labels. Tooltips/accessibility labels
are still required.

## Text Chunk Editor

The text chunk editor is full-screen.

Behavior:

- immediate autosave;
- no save button;
- header includes indent and outdent icon actions;
- Enter creates a new paragraph;
- Shift+Enter creates a new line inside the current paragraph;
- indent/outdent affects only the paragraph where the cursor currently is,
  not previous paragraphs.

The rendered chunk card must preserve paragraph structure.

## List Chunk Editor

The list chunk editor follows the latest screenshot direction: a Google
Keep-like list editing surface.

Behavior:

- full-screen;
- inline editable title/content area when applicable;
- draggable list rows with a left drag handle;
- live reorder during drag;
- checkbox/list marker next to each item;
- `X` delete action on the active/current list row;
- add-new row action below the last list item;
- immediate autosave;
- no save button.

The old footer add controls should not be used for this editor.

## Table Chunk Editor

The table chunk editor remains full-screen.

Required behavior:

- editable cells;
- add row;
- add column;
- delete row/column where valid;
- immediate autosave;
- no save button.

The chunk card expanded body renders the table as a table, not as flattened
text.

## Flowchart Chunk Editor

The flowchart editor is a real canvas editor, not a workaround card editor.

Canvas:

- full-screen;
- pinch zoom;
- pan/drag in every direction;
- canvas can be wider and taller than the screen;
- no forced screen-width layout.

Palette:

- a vertical icon-only palette starts from the right-side FAB area;
- elements are added by long-press/drag from the palette onto the canvas;
- drag shows a ghost clone;
- drop places a new flowchart element.

Initial element set:

- Start: terminator with one bottom output node.
- Flow/process: rectangular process with one top input and one bottom output.
- Decision: diamond decision with one top input and two bottom outputs,
  labelled yes/no.
- End: terminator with one top input and no output.

Connection model:

- elements expose connection nodes;
- tapping a node starts connection mode;
- compatible target nodes on other elements show visual target indicators;
- tapping a target node creates an edge;
- multiple incoming edges may connect to the same input node.

The expanded chunk card must render the flowchart visually and use the same
underlying model as the editor. It must not degrade to plain text.

## Indexing Semantics

Notes are user-authored, so their chunks start as extracted content.

State rules:

- New non-empty chunk: `Kinyerve`.
- Successful embedding/index generation: `Kinyerve` + `Indexelve`.
- User modifies a previously indexed chunk: `Kinyerve` + `Ujraindexelendo`.
- Re-indexing clears `Ujraindexelendo` and restores `Indexelve`.

Index freshness should be based on a stable content hash or equivalent
timestamp comparison. The implementation must not claim `Indexelve` for stale
embeddings.

## Data Model Direction

The current `NoteDocument` / `NoteBlock` model remains the conceptual base, but
it must support workspace behavior explicitly:

- stable block ids;
- block order;
- block type;
- block payload;
- per-block indexing metadata;
- per-block content hash or revision marker;
- enough flowchart payload to render and edit nodes/edges visually.

Legacy notes continue to migrate into a one-block or multi-block note document.

## Error Handling

- Failed autosave should show a non-blocking error and keep the local UI state
  in memory.
- Failed re-index should leave the chunk in `Ujraindexelendo` or unindexed
  state and surface the provider/offline embedding error.
- Invalid flowchart edge attempts should be ignored with a subtle UI cue.
- Undo after delete should be available only while the snackbar is visible.

## Test Requirements

Widget/model tests should cover:

- FAB opens a new full-screen note editor, not the old creation sheet.
- Tapping a note opens the same full-screen editor.
- The old preview/create card is not present in the notes creation flow.
- Adding text/list/table/flowchart chunks from icon-only FAB actions.
- Expanded chunk card renders text/list/table/flowchart content, read-only.
- Body tap opens the correct type-specific editor.
- Live reorder persists new order.
- Delete removes a chunk and snackbar undo restores it at the same index.
- Title edits autosave immediately.
- Editing a chunk marks it `Ujraindexelendo` when it had an existing fresh
  index.
- Re-index marks chunks `Indexelve`.
- List editor supports row add/delete and reorder.
- Flowchart editor supports adding start/process/decision/end nodes and
  connecting nodes, including multiple incoming edges to one input node.

## Open Implementation Notes

This redesign is large enough that implementation should be split by subsystem:

- data/index metadata;
- note list and editor shell;
- chunk cards and reorder;
- text/list/table editors;
- flowchart canvas editor;
- tests and migration cleanup.

The first implementation must remove placeholder controls from the user-facing
notes workflow. If a menu item remains visible, it must either work or be
removed until it works.
