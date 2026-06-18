# Chunk Tag Rail Final Design Spec

Date: 2026-06-18

## Goal

Implement the final chunk tagging, selected-scope rail, flowchart editor, flowchart preview, and RAG answer/source behavior agreed in the design sessions.

This spec supersedes `docs/superpowers/specs/2026-06-18-chunk-tag-rail-redesign-design.md` where the two differ. The older document captured an intermediate state; this document is the source of truth for implementation.

## Required Visual References

Before implementation, read these approved interactive HTML references and match them 1:1 for layout, spacing, colors, rail behavior, and interaction logic:

- Text chunk: `.superpowers/brainstorm/12103-1781765637/content/text-chunk-two-row-rail-v6.html`
- List chunk: `.superpowers/brainstorm/12103-1781765637/content/list-chunk-code-derived-rail-v2.html`
- Table sticky inline rail: `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-v2.html`
- Table overflow rail: `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-overflow-v1.html`
- Flowchart canvas/tag editor: `.superpowers/brainstorm/12103-1781765637/content/flowchart-canvas-tag-system-v4.html`

The production Flutter UI must be treated as a native implementation of these approved references, not a new visual interpretation.

## Non-Goals

- Do not run a local Flutter APK build on Termux/Android. APK builds must run in GitHub Actions.
- Do not put tag pills inside table cells.
- Do not put tag pills or rails directly on the infinite flowchart canvas.
- Do not keep tiny selector dots for list or table selection.
- Do not keep flowchart visual shape selection. Flowchart nodes are rounded boxes only.
- Do not add explanatory feature copy inside rails. Rails contain buttons and pills only.

## Tag Model

Tags have both a name and a unique color. The tag manager is a slide-up/bottom sheet card with:

- tag name input;
- fixed color slots;
- save/update behavior;
- reusable saved tags;
- no duplicate inline tag-manager buttons inside chunk content.

The tag menu must be reachable from:

- the notes root where it already exists;
- each individual note dropdown;
- each selected-scope rail through its tag button;
- each chunk header global tag button.

Whole-chunk tags and local scoped tags are different scopes:

- whole-chunk tag: triggered by the chunk header tag icon and displayed as global tag capsules in the chunk subheader;
- local tag: applied to selected text/list/table/flowchart targets and displayed in the selected target's rail or flowchart edit card.

Global tag capsules:

- are a single horizontally scrollable row in every chunk subheader;
- are full-opacity pill/capsule shapes;
- use the tag color as the visible fill;
- include an `x` affordance for removing that global tag.

## Shared Rail Contract

Text, list, and table use the same rail model.

The rail is not a floating card. It is an inline appendix created by expanding the selected component:

- text range: expands directly under the selected paragraph/range area;
- list item: expands the selected list item downward;
- table column: expands below the column header row and pushes body cells down;
- table row: expands below the selected row;
- table cell: expands below the selected row;
- selected component content remains aligned with its normal text start point, with no right offset introduced by the rail.

Rail visual style:

- white background;
- thin top separator line;
- thin bottom separator line only when it separates the rail from following normal content;
- no card shadow;
- no title text;
- no "selected item" label;
- no full-component color fill;
- top row and bottom row are each horizontally scrollable;
- rail rows capture horizontal gestures before parent horizontal scroll.

Rail rows:

- top row: action buttons only, left aligned;
- bottom row: tag pills with per-tag `x`; if there are no tags, show `Nincs tag`;
- open/close button in top row collapses or opens only the bottom pill row;
- bottom-row open/closed state is remembered when next/previous navigation moves the rail to another target.

Universal top-row buttons:

- open/close bottom row;
- tag: opens the slide-up tag editor/sheet;
- trash: clears all tags on the current selected target;
- previous: jumps to the previous tagged unit in the note and opens/focuses its rail;
- next: jumps to the next tagged unit in the note and opens/focuses its rail.

Chunk-specific actions may appear after the universal buttons:

- list: outdent, indent, delete list item;
- table: insert/delete row/column where relevant, clear scope, resize/reorder controls where appropriate;
- text: selected-range delete/clear actions when relevant.

If a user taps outside the active target, the rail closes.

## Multi-Tag Rendering

For text, list, and table cell content:

- first tag is the primary tag;
- primary tag renders as text background highlight;
- every secondary tag renders as a separate underline line;
- if there are multiple secondary tags, there are multiple underline lines;
- underline lines must expand the component downward, not push the text baseline upward;
- wrapped lines must not collide with underline lines from the previous line;
- the whole component/card background must never become the tag color.

Navigation treats adjacent same-tag text as one unit:

- if multiple adjacent words share the same tag and form one tagged range, next/previous skips the internal words;
- if a word at the end of that unit has an extra secondary tag, that multitag word can be a separate navigation target;
- next/previous can jump to another unit with the same tag or to a different tag, depending on document order.

Tapping a highlighted word opens the rail with no focus border around the word.

Selecting tagged or untagged text opens the rail.

## Text Chunk

Header:

- header text is editable and is the chunk name;
- header includes global tag button;
- header includes paragraph indent and outdent controls;
- header includes three-dot dropdown.

Three-dot dropdown:

- selected range tagging;
- selected tag deletion, disabled when selected range has no tag;
- chunk deletion.

Subheader:

- global tag capsules only.

Content:

- text editor remains editable;
- saved local text-range tags render by primary highlight plus secondary underlines;
- selected text range opens the inline two-row rail under the affected text/paragraph;
- bottom grey tip bar remains and contains short instructions only;
- no grey "tag manager", "multitag", or "selected range tagging" buttons under the text content.

## List Chunk

Header:

- header text is editable and is the list name;
- header includes global tag button;
- header includes plus button for adding a new item;
- header includes three-dot dropdown.

Three-dot dropdown:

- selected list item tagging;
- selected list item tag deletion, disabled when selected item has no tag;
- layout mode switch;
- chunk deletion.

List layout modes:

- checkbox mode: current checkbox UI remains;
- hierarchical numbering mode:
  - mother item is any item at level 0;
  - child item is any item with level greater than 0;
  - mother items are numbered 1, 2, 3 dynamically by current order;
  - child items use a dash or centered bullet, not a number;
  - reorder regenerates mother numbers by current order;
  - indenting a mother item makes it a child of the previous mother and cascades numbering of later mothers;
  - outdenting can make a child a mother and cascades numbering.

Item interaction:

- checkbox remains beside the drag handle;
- tap on non-text area selects the list item with border-only focus;
- tap on text selects the list item and keeps text editing active;
- no selector dot or indicator;
- selected item expands downward and shows the two-row rail;
- item content does not shift right because of the rail;
- local tag feedback applies to text only;
- no local tag pills under every list item.

Editing:

- pressing Enter inside a list item creates a new item below;
- cursor moves into the new item text field.

Layout:

- item text wraps automatically and remains readable;
- item height expands for wrapped content;
- multiple underline lines expand vertical spacing and never overlap lower wrapped text.

Drag/reorder:

- list item reorder keeps the existing ghost behavior: dragged item appears as an identical floating ghost, original slot hides or collapses cleanly;
- after reorder, hierarchical numbering recalculates.

## Table Chunk

The table must use an Excel-like grid, not the current split/marker layout.

Grid structure:

- real corner head;
- column heads;
- row heads;
- body cells;
- rounded-square cell/card corners matching list item radius;
- row head height always matches its row cell height;
- cell height is content-driven;
- cell text wraps and never overflows the cell boundary.

Selection:

- tap column head selects the entire column;
- tap row head selects the entire row;
- tap cell selects and edits that cell;
- no tiny selection tap point;
- no visible plus/x controls in the top grid cells;
- old top-cell x and plus controls are removed because the rail handles these actions.

Expansion:

- column selection expands the column head/header area downward and pushes all body rows down;
- row selection expands the selected row downward;
- cell selection expands the selected row downward;
- rail design matches the list rail;
- rail is as wide as the expanded table area;
- rail content is horizontally sticky to the current horizontal viewport.

Horizontal sticky rail:

- if the user has scrolled to a far-right cell and selects it, the rail action buttons are visible in that same viewport;
- user must not have to scroll back left just to use the rail;
- if there are many actions or pills, each rail row scrolls horizontally within itself;
- rail horizontal scrolling must not be swallowed by the background table scroll.

Table tagging:

- rows and columns are poly-tagging scopes;
- row and column heads do not persist their own row/column tag targets in new writes; they apply or remove tags on the affected cell targets;
- tagging a row applies effective tag feedback to every cell in that row;
- tagging a column applies effective tag feedback to every cell in that column;
- tapping a row or column head and opening the rail lists all tags currently present in the affected cells/scope;
- removing a tag from a cell removes it only from that cell;
- removing a tag from a row head removes that row-scope tag from every affected row cell;
- removing a tag from a column head removes that column-scope tag from every affected column cell;
- direct cell tag has priority for primary color over row and column inherited tags;
- remaining inherited/direct tags render as secondary underline lines.

Row/column operations:

- header add-row and add-column buttons must work;
- rail includes insert/delete operations for row/column/cell scope where relevant;
- scoped tag assignments are remapped on row/column insertion, deletion, and reorder.

Reorder and resize:

- long-tap column head starts horizontal column reorder;
- long-tap row head starts vertical row reorder;
- reorder ghost is identical to the original row/column visual;
- original row/column slot hides cleanly while dragging;
- long-tap drag on any cell edge or column-head edge resizes column width;
- resize affects the entire column;
- cell height remains automatic from wrapped content.

Zoom:

- table supports pinch zoom out for dense tables;
- maximum zoom-in is the current base scale;
- zoom out must preserve row/column selection and rail usability.

## Flowchart Chunk

Canvas:

- no tag pills on the canvas;
- no rail on the canvas;
- no text highlight on canvas labels;
- all nodes render as rounded boxes only;
- visual shape choice is removed everywhere;
- canvas should feel infinite, not like a fixed giant edge-limited area;
- flowchart editor drag/pan must be smooth and avoid full rebuilds during pointer movement where possible.

Creation controls:

- three create buttons are separate vertical buttons on the right at FAB height, not grouped in one large box;
- zoom in/out controls occupy the old top control location.

Node/branch edit card:

- all flowchart tagging lives in the add/edit card;
- node name is editable;
- node type selector lives inside the node-name rail;
- role selector is removed;
- branch/port add uses one plus button only;
- new branch defaults to top position;
- branch side position is changed from the branch rail;
- branch name is editable where allowed;
- branch delete exists where allowed;
- preview is part of the card;
- box name and each branch are separately taggable.

Edit-card rail style:

- node name card: name input/text, separator, two-row rail;
- branch card: branch name input/text, separator, two-row rail;
- if the rail bottom row is closed, do not add an extra separator at card bottom;
- if the inline tag picker opens, add a separator between rail and picker;
- do not add a separator below the picker if it touches the card bottom;
- branch rail includes side-position buttons and delete button when deletion is allowed;
- node-name rail includes type selector buttons.

Editor-card tag feedback:

- node name and branch name use text-only primary highlight plus secondary underline rendering;
- the surrounding input/card is never filled with tag color.

Canvas tag feedback:

- tagged node gets tag-colored outline;
- multiple node tags create multiple outline layers;
- tagged edge changes the edge line/trunk color;
- multiple edge tags create multiple parallel/layered line strokes;
- arrowheads keep the normal flowchart style and are not tag-colored;
- loop-closing edge keeps the loop style described below.

Binary decision rules:

- yes/no branches are fixed binary output branches;
- yes/no branch labels cannot be renamed;
- yes/no branches cannot be deleted;
- yes/no ports can only be outputs;
- in a binary decision node, newly added ports are input-only;
- direction state does not need to be described in the edit card, but must be visible/understandable on canvas;
- existing port rule remains: a port may be input and output only if it became output first; once a port has been used as input, it can no longer become an output.

Loop rule:

- loop style is dashed orange;
- only the last-created edge that closes a loop becomes dashed orange;
- earlier edges in the path remain normal/tag-colored according to their own state;
- creating a later loop must not retroactively recolor all cycle edges.

Flowchart preview in note/chunk menus:

- preview uses the same rounded-box design as the editor;
- preview initially fits all nodes and routes into the preview viewport;
- one-finger vertical gesture scrolls the outer note menu;
- two-finger gesture pans/zooms the preview like inline Google Maps;
- preview must no longer trap menu scroll with one finger;
- preview and editor shape/rendering must match.

## Chat/RAG Fixes

The logs showed retrieval and answer-design issues that are part of this package.

Branch-value matching:

- key, normalized value, and polarity must match together;
- positive `igen` must not match a `nem` branch candidate;
- `sulyos=igen` must not match `sulyos oxygen nem`;
- `javult=igen` must not match `javult oxygen nem`;
- branch context-only matches must not create a branch-value link without matching value/polarity.

Note-aware retrieval:

- broad adjective matches like `sulyos` must not pull an unrelated `sulyos serult` note when the query is `sulyos legzesi elegtelenseg`;
- phrase/topic overlap must outrank single common adjectives;
- if the query is a combined topic like `sulyos serult legzesi elegtelensege`, both the `sulyos serult` and `legzesi elegtelenseg` notes can be included when both pass thresholds;
- retrieval must not lock onto only one note when two notes are clearly relevant.

Answer formatting:

- offline graph answers must be sectioned and readable, not one dense paragraph;
- flowchart relationships should be verbal `ha X, akkor Y`, not arrow notation;
- table/rule content should be summarized as condition/action statements where possible.

Sources:

- source list shows one link per source chunk, not every evidence item line by line;
- tapping a source opens a fullscreen read-only chunk preview that matches the real chunk design;
- text/list/table previews use the real chunk visual language but are not editable;
- flowchart source opens a fullscreen scrollable/fit preview;
- source section must not be visually longer than the answer for normal answers.

## Acceptance Criteria

- Whole-chunk tags work in all chunk types and render global removable capsules in subheaders.
- Text-range, list-item, table-cell, row/column poly-tagging scope, flowchart-node, and flowchart-branch tags are visible and editable.
- Text/list/table rail matches the approved two-row inline rail references.
- Multi-tag primary/secondary rendering works without baseline jumps or overlap.
- List Enter creates a new focused item.
- List hierarchical numbering cascades correctly after indent/outdent/reorder.
- Table grid is Excel-like with real row/column heads, sticky rail content, row/column reorder, column resize, and zoom out.
- Row/column poly-tagging visibly affects all relevant cells.
- Flowchart edit card owns flowchart tagging; no canvas pills.
- Flowchart nodes are rounded boxes only in editor, preview, and source preview.
- Binary decision branch constraints and port direction constraints are enforced.
- Only the last-created loop-closing edge uses dashed orange loop style.
- Inline flowchart previews fit-to-view and use one-finger parent scroll plus two-finger preview pan/zoom.
- RAG branch-value matching no longer cross-matches `igen` and `nem`.
- RAG answers and source citations are concise, structured, and chunk-linked.
