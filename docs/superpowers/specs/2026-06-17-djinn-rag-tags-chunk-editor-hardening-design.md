# Djinn RAG, Tags, And Chunk Editors Design Spec

Date: 2026-06-17

## Goal

Make note retrieval precise across overlapping medical topics, make graph answers readable with compact chunk-level citations, and unify tagging across text, list, table, and flowchart chunk editors.

## Background

The current logs show two important retrieval problems:

1. Branch expansion is over-eager. Positive branch signals such as `sulyos=igen` and `legzesi elegtelen=igen` can still create candidate pressure toward sibling edges whose text contains `nem`.
2. Search scope is sometimes too narrow after one seed is selected. A later question may see both notes in the index, but retrieval can collapse to one note or one item and ignore the other relevant chunks.

The current UI also has inconsistent tag entry points and weak visual feedback. The user should be able to tag an entire chunk or a selected component/range from the same mental model in every editor.

## Non-Goals

- Do not add hardcoded medical-topic rules such as special handling for respiratory failure, severe injury, DO2, or VO2.
- Do not put tag pills inside dense table cells.
- Do not put tag pills on the flowchart canvas.
- Do not make a marketing or explanatory screen; the editors remain the primary work surfaces.
- Do not attempt local Flutter APK builds on Termux/Android.

## Retrieval Requirements

### Query And Turn Scope

- Every retrieval request must carry a request id or chat turn identity through retrieval, answer composition, and citation rendering.
- A new question starts from its own query and selected conversation context. It must not reuse the previous answer's citation set as a hard filter unless the question is explicitly a follow-up.
- Follow-up resolution may carry a referenced entity. Example: after a DO2 answer, "mashol nem emliti?" means search for DO2 across eligible chunks.

### Multi-Note Selection

- Retrieval must retain multiple note candidates through the first ranking phase.
- Note title and note-level tags may boost or scope candidates, but local evidence from chunk text, table content, list items, or flowchart elements must decide final inclusion.
- Generic terms such as `sulyos` are weak by themselves. A note named "Sulyos serult" should not outrank "Legzesi elegtelenseg" for "sulyos legzesi elegtelenseg" unless it also has respiratory-failure evidence.
- A mixed query such as "sulyos serult legzesi elegtelensege" is valid for both topics if both contain matching domain evidence.

### Graph Expansion

- Branch matching must compare key, value, polarity, and local condition context.
- `value=igen` cannot match a target whose explicit branch value is `nem`.
- `value=nem` cannot match a target whose explicit branch value is `igen`.
- Same-key opposite-value sibling edges may be linked as flowchart context, but they must not be treated as supporting branch-value evidence.
- A table row can match a branch if the row contains the domain key and the branch value or an equivalent column/label; it must not match just because a generic adjective overlaps.
- When query intent is exhaustive, graph expansion should include same-block siblings after at least one strong local seed has been found.

### Definition And Symbol Expansion

- Symbol expansions such as DO2 and VO2 should trigger for definition, abbreviation, entity, or "mit jelent" questions.
- Symbol expansions should not dominate therapy, process, or branch-outcome questions.

### Logging

Logs should make retrieval failures diagnosable:

- request id
- query terms
- note id and chunk id
- seed source
- score before and after graph expansion
- note gate reason
- branch gate reason
- citation grouping result

## Answer And Citation Requirements

- Local graph answers must be structured into short sections.
- Flowchart evidence must be verbalized as conditions: "Ha a legzesi elegtelenseg sulyos, akkor magas aramlasu oxygen."
- Raw arrows may appear in debug logs, but not as the primary chat answer form.
- Sources must be grouped by chunk. One source link should represent a text chunk, list chunk, table row group, or flowchart chunk.
- Tapping a source opens a fullscreen read-only preview using the real chunk design.
- Flowchart source preview is fullscreen and scrollable/pannable.
- Source previews are not editable from chat.

## Tag Data Model

### Tag Definition

Each tag has:

- stable id
- display name
- color value from a controlled slot palette
- optional updated timestamp for conflict resolution

### Tag Assignment

Assignments support these scopes:

- whole chunk
- text range
- list item
- table row
- table column
- table cell
- flowchart node
- flowchart edge

Assignments support multiple tags on one target. The assignment target must store enough identity to survive normal editing, reorder, and persistence.

### Search Semantics

Tags are searchable metadata, but they should not by themselves make a note the best match for an unrelated query. A tag can boost a chunk when the query mentions the tag or when the user filters by tag.

Whole chunk tags may be included in chunk-level search metadata. Local tag metadata is narrower:

- text range tags are indexed only on text units whose character range overlaps the tag range
- table row tags are indexed only on that row's evidence
- table column tags are indexed only on that column's cell evidence or row evidence that represents the tagged column
- table cell tags are indexed only on that cell, or the containing row when the row is the only emitted table evidence
- flowchart node tags are indexed only on that node evidence
- flowchart edge tags are indexed only on that edge evidence

Local tags must not be copied into `NoteBlock.searchMetadataText`, because that makes every granular evidence item inside the block look tagged.

Keyword/BM25 fallback must use the same granular evidence path for local tags. Otherwise tag-only keyword queries cannot see text range, table scoped, or flowchart scoped assignments after they are removed from whole-block metadata.

Text range matching must compare against offsets in the original block text, not a trimmed copy. Table definition splitting must preserve physical row and column coordinates even when empty cells are skipped or a packed definition cell is split into multiple evidence items.

### Scoped Target Stability

Scoped tag targets must survive normal editing:

- inserting a table column before a tagged column/cell increments the target column index
- deleting a tagged table row, column, or cell drops the assignment
- deleting a table row/column before a tagged target decrements the target index
- deleting a flowchart node drops node tags and all edge tags attached to removed edges
- deleting a flowchart edge drops that edge's scoped tags

The tag manager must derive available tag recall from persisted document data and the current editor block state, including document tags, chunk tags, text range tags, scoped table/flowchart tags, and list item tags. It must not rely on a process-static registry as the source of truth.

## Shared Chunk Editor UX

All four editors use the same header rule:

- The header text is the editable chunk name.
- The header contains a global tag icon. This opens the tag editor for the whole chunk.
- The header contains a right-side three-dot menu.
- The dropdown contains selected part tagging, selected tag deletion, and chunk deletion.
- Selected tag deletion is disabled when the selection has no tag.
- Whole chunk tag capsules appear in the subheader.
- Capsules are pill-shaped and full-opacity colored. They are not grey rounded boxes.

## Text Chunk UX

- Header actions: global tag, paragraph indent, paragraph outdent, three-dot menu.
- Selected text is tagged through the three-dot menu.
- Tagged text uses the tag color as a highlight background.
- Local tag pills appear below the text.
- The bottom grey tip bar may remain and should contain direct instructions.
- Remove redundant bottom "Tag manager", "Tag/multitag", "multitag pelda", and "kijeloles taggelese" controls.

## List Chunk UX

- Header text is the editable list title.
- Header actions: global tag, add row, three-dot menu.
- The old list-name field leaves the subheader.
- The bottom add button leaves the editor.
- List items remain draggable and keep their indent/outdent controls.
- A list item can be selected independently of dragging.
- The three-dot menu tags the selected list item.
- List item tags appear below the item.

## Table Chunk UX

- Header text is the editable table title.
- Header actions: global tag, add row, add column, three-dot menu.
- Existing header add-row and add-column buttons must work.
- Row, column, and cell selection are supported.
- Each column keeps plus and x controls.
- Column plus inserts a column to the right.
- Tag pills do not appear inside cells.
- Row tags use a left rail.
- Column tags use a top rail.
- Cell tags use a small corner marker or stripe.
- Tag pills for the selected row/column/cell appear in an external selected-element tray.

## Flowchart Chunk UX

- Header text is the editable flowchart title.
- Header actions: global tag and three-dot menu.
- Flowchart nodes/boxes and edges are selectable.
- Do not render tag pills on the infinite canvas.
- Tagged nodes/edges use a light outline, glow, or corner marker.
- Edge labels and edge action controls render above node cards so labels remain tappable when routes overlap a node.
- Tag pills for the selected node/edge appear in a tray outside the canvas.
- Creation actions are three separate vertical FABs on the right side at FAB height.
- Zoom in/out controls replace the old top button area.
- Canvas pan, drag, and zoom should be smooth on the target Android phone.
- Canvas should feel infinite in normal use; hard bounds must not become visible during common pan/zoom flows.

## Testing Requirements

- Retriever tests cover cross-note relevance, branch polarity, follow-up entity expansion, exhaustive same-block expansion, and symbol expansion gates.
- Answer service tests cover structured sections and "Ha X, akkor Y" flowchart wording.
- Widget tests cover each editor header, global tag capsules, local tag visuals, selected-tag deletion disabled state, and tag persistence.
- Table tests cover row/column/cell selection and marker rendering.
- Flowchart tests cover vertical FAB placement and tag tray outside the canvas.
- GitHub Actions is the APK build source.
