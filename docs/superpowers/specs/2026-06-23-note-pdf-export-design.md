# Note PDF Export Design

## Goal

Add `Export as PDF` to the selected note dropdown in the Notes menu. The user can generate an in-app PDF preview, go back without saving, save the actual PDF to a phone-selected location, or share it.

The PDF is a readable document export of the note content. It is not a backup/export of the tag system, search metadata, or editor-only controls.

## Entry Point

- The feature lives in the selected note menu in `NotesScreen`.
- For a single selected note, the menu shows `Export as PDF`.
- Multi-note PDF export is out of scope for the first implementation. Existing JSON export/share remains unchanged for multi-select.
- If the note has no exportable content, the app does not open preview and shows a snackbar.

## User Flow

1. User long-presses or otherwise selects one note.
2. User opens the selected note dropdown.
3. User taps `Export as PDF`.
4. The app generates a temporary PDF file from the note document.
5. A fullscreen PDF preview opens.
6. From preview, the user can:
   - go back without saving;
   - save the PDF through the platform file picker;
   - share the PDF.
7. After save/share, the preview remains open unless the user goes back.

## PDF Structure

The PDF content order is determined only by `NoteDocument.blocks`.

The document layout:

- document title;
- updated date;
- one section per chunk/block in document order;
- page numbers in the footer.

Each section has a compact section header containing the chunk type label and optional block title. The section body is rendered according to block type:

- heading: larger text;
- paragraph: paragraphs with preserved line breaks;
- list item/list chunk: bullet, checkbox, and hierarchy levels;
- table: PDF table with repeated header handling when possible;
- flowchart: static visual flowchart render.

The PDF must not render:

- global note tag chips;
- chunk tag chips;
- text range tag highlights or badges;
- search context, search roles, aliases, or indexing metadata;
- editor rails, buttons, handles, or dropdown UI.

## Architecture

Create a focused PDF export module instead of growing `NotesScreen`.

Recommended units:

- `NotePdfExportService`
  - accepts a `NoteItem`;
  - returns generated PDF bytes and metadata such as filename and page count when available;
  - owns debug logging for export lifecycle.

- `NotePdfDocumentBuilder`
  - converts a `NoteDocument` into PDF widgets/drawing commands;
  - contains block rendering rules.

- `NotePdfPreviewScreen`
  - receives temp PDF path, filename, and bytes;
  - displays preview with the existing `pdfrx` viewer stack style;
  - exposes back, save, and share actions.

- `NotePdfFileWriter`
  - handles temp file creation;
  - handles `FilePicker.saveFile` for final user-selected destination;
  - handles `share_plus` sharing.

## Flowchart Render Requirements

Flowchart export must be visual, not plain text.

The flowchart renderer must be based on note flowchart data:

- node ids, labels, order, x/y positions;
- node visual shapes: rectangle, oval, diamond;
- node sizes;
- edge routes;
- arrowheads;
- edge labels;
- manual waypoints when present;
- auto routing when manual waypoints are not present.

The PDF renderer must not capture a Flutter widget screenshot. It should build a deterministic flowchart render model and draw it into the PDF. This keeps output sharp, testable, and independent from current device screen size.

## Shared Flowchart Render Model

Introduce a shared pure render layer for flowcharts.

The shared layer should provide:

- normalized node list sorted by order;
- node bounding boxes;
- full chart bounding box;
- edge route polylines;
- edge label anchor positions;
- visible shape instructions;
- page/tile layout decisions.

The existing editor and mobile viewer may continue to use their current widgets, but the export should not duplicate routing in an ad hoc way. If needed, extract geometry helpers from the editor/mobile viewer into reusable code so PDF and UI use the same rules.

## Large Flowchart Pagination

Large flowcharts must remain readable.

The export chooses one of these strategies:

1. Portrait single-page fit.
   - Use when the chart fits on the available portrait section area at or above the minimum readable scale.

2. Landscape single-page fit.
   - Use when portrait would be too small, but landscape fits at or above the minimum readable scale.
   - Flowchart pages may be landscape even when ordinary note pages are portrait.

3. Overview plus tiled detail pages.
   - Use when neither portrait nor landscape single-page fit is readable.
   - First page: full flowchart overview, scaled down and labeled as overview.
   - Following pages: readable detail tiles, usually landscape.
   - Tiles proceed left-to-right, then top-to-bottom.
   - Tiles include overlap margins so crossing edges remain understandable.
   - Tile boundaries should avoid cutting through node bodies where possible.
   - If an edge continues outside a tile, the tile shows a continuation indicator with the target/source node label when possible.

Recommended thresholds:

- minimum readable node text size: 8-9 pt;
- prefer single-page only when resulting scale preserves that threshold;
- below threshold, tile instead of shrinking further.

## PDF Preview

The preview screen uses a temporary PDF file rendered by `pdfrx`.

Preview app bar actions:

- Back;
- Save;
- Share.

Save behavior:

- open platform save picker;
- default filename: safe note title plus `.pdf`;
- if the user cancels, stay in preview and log cancellation;
- if save succeeds, show a snackbar with the saved path.

Share behavior:

- use `share_plus` with MIME type `application/pdf`;
- log success or failure.

## Debug Logging

Add detailed logs with `[NotePdfExport]` prefix:

- export start: note id/title/block count;
- block render: block id/type and relevant counts;
- flowchart render: nodes, edges, bounding box, selected pagination strategy, tile count;
- generation result: byte count and temp path;
- preview open;
- save start/cancel/success/failure;
- share start/success/failure.

Logs must avoid dumping full note text.

## Error Handling

- Empty note: snackbar, no preview.
- PDF generation failure: snackbar and debug log.
- Temp write failure: snackbar and debug log.
- Save cancellation: no error snackbar; debug log only.
- Save failure: snackbar and debug log.
- Share failure: snackbar and debug log.

## Testing

Unit tests:

- PDF filename sanitization.
- Empty note export rejection.
- Block order is preserved in export model.
- Paragraph/list/table blocks are included as separate sections.
- Flowchart render model computes bounding box and routes.
- Large flowchart chooses overview plus tiles when it cannot fit readably.

Widget tests:

- selected note menu contains `Export as PDF`;
- tapping export opens preview for a non-empty note;
- preview back returns without saving;
- save cancellation keeps preview open;
- debug logs include key lifecycle entries.

Integration-style tests can validate that generated PDF bytes are non-empty and begin with a PDF signature. Exact visual PDF pixel comparison is out of scope for first pass.

## Acceptance Criteria

- A single selected note has an `Export as PDF` menu item.
- Tapping it opens an in-app PDF preview.
- Back from preview does not save anything.
- Save writes a PDF through the platform save picker.
- Share shares a PDF file.
- The PDF renders note blocks in `NoteDocument.blocks` order.
- Tags and search metadata are not rendered.
- Flowchart chunks render visually.
- Wide or large flowcharts do not become unreadably tiny; they use landscape and/or overview plus tiled detail pages.
- Debug logs are detailed enough to diagnose export, preview, save, share, and flowchart pagination behavior.

## Out of Scope

- Multi-note combined PDF export.
- PDF import back into notes.
- Full visual parity with every editor interaction state.
- Search metadata export.
- Tag system export.
- Editable PDF annotations.
