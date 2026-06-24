# Shared PDF And Note Chunks Design

## Goal

PDF-derived chunks, image-derived chunks, and user note chunks must behave like the same product concept. A chunk is a user-editable knowledge unit regardless of whether it came from a note, a PDF, or an imported image.

This design uses the approved incremental approach: introduce a shared chunk adapter and shared UI layer first, while keeping existing note and PDF persistence in place. A full database migration to one physical chunk table is a later step, after the shared behavior is stable.

## Current Problems

- The PDF knowledge menu exposes too many pipeline concepts: AI, local, manual, and comparison. The user-facing workflow should only expose AI and manual OCR-assisted chunking.
- The PDF manual chunk editor can create several extra chunk kinds. The app should have exactly four chunk types: text, list, table, and flowchart.
- Manual PDF chunk save writes through the repository, but the current navigation and extracted chunk screen make saved chunks hard to see because the screen separates AI, local, manual, comparison, and type filters.
- The manual chunk bottom card can leave a white sheet surface covering the PDF after swipe-down.
- The knowledge document row does not match the notes row behavior. Notes open chunks from the whole card and show a right chevron. PDF rows should do the same, while the left PDF/image icon opens the viewer.
- PDF chunk UI is separate from note chunk UI. This causes design drift and duplicate behavior.
- PDF chunk debug logs are not detailed enough for the onscreen debug console workflow.
- Images in the knowledge base should behave like PDF documents waiting for chunking.

## Approved Approach

Use a shared chunk adapter and shared UI surface.

```text
NoteBlock / NoteDocument
ExtractedKnowledgeItem / LocalChunk
        |
        v
SharedChunkViewModel
        |
        v
SharedChunkCard
SharedChunkEditor routing
Shared tag UI
```

Notes can continue storing chunks as `NoteBlock` values. PDF and image imports can continue storing extracted chunks as `DocumentChunkEntity` / `ExtractedKnowledgeItem` values. The shared layer converts both sources into the same UI model.

The UI must not care whether the chunk originated from a note or a PDF except where source-specific actions are explicitly required, such as opening the source PDF viewer.

## Non-Goals For This Slice

- Do not migrate all note and PDF chunks into one physical database table yet.
- Do not redesign the note editors from scratch.
- Do not introduce chunk categories beyond text, list, table, and flowchart.
- Do not keep local-vs-manual-vs-comparison as user-facing PDF chunk modes.
- Do not implement full AI chunk generation changes in this slice beyond making the UI able to show AI chunks as one of two modes.

## Shared Concepts

### Shared Chunk Kind

The shared chunk kind enum has exactly four values:

- `text`
- `list`
- `table`
- `flowchart`

Legacy PDF kinds must be mapped as follows:

- `score` becomes `table`
- `image_region` becomes `text` unless later promoted to image-specific source metadata
- `visual_fact` becomes `text`
- `unknown` becomes `text`

New writes must only use the four approved kinds.

### Shared Chunk Origin

The shared origin describes where the chunk came from:

- `note`
- `pdf`
- `image`

Origin is not a chunk type. It controls source-specific actions, such as opening the PDF viewer or showing source rectangles.

### Shared Chunk Mode

PDF/image chunk menus expose exactly two modes:

- `manual`: OCR-assisted user-created chunks
- `ai`: automatic chunks

Generated local OCR/table/flowchart pipelines are implementation details. In user-facing PDF chunk menus they are treated as manual/OCR-assisted legacy content unless a later migration removes them.

### Shared Chunk View Model

The shared view model includes:

- stable chunk id;
- origin;
- kind;
- title;
- preview text;
- full editable content;
- page label when available;
- source rectangle metadata when available;
- audit/index state;
- direct chunk tags;
- inherited/global tags when available;
- source-specific actions.

## PDF Knowledge Menu Behavior

The PDF chunk menu is based on the note chunk menu design:

- No grouping by chunk type.
- One selected mode at a time: AI or manual.
- Same card visual language as notes.
- Same chunk action placement as notes where applicable.
- Same tag chip behavior as notes where applicable.

The PDF chunk menu differs from notes only in source-specific controls:

- it has a mode selector for AI vs manual chunks;
- it can open the source PDF/image viewer;
- it can show source page and source rectangle metadata;
- it can start manual OCR-assisted chunking.

## Knowledge List Row Behavior

Knowledge document rows must match the notes list interaction model:

- Tapping anywhere on the document card opens the chunk menu.
- A right chevron visually indicates that the card opens the chunk menu.
- Long press keeps selection behavior.
- In selection mode, card taps toggle selection.
- The left PDF/image icon opens the source viewer instead of the chunk menu.
- The source viewer opens with chunk source boxes available when chunk metadata exists.

## Source Viewer Behavior

The PDF/image viewer needs a source-box display mode:

- hidden;
- AI chunks;
- manual chunks.

Only one source-box group is shown at a time. There is no comparison mode in this viewer. Tapping a visible source box opens the shared chunk editor for that chunk.

Manual OCR-assisted chunk creation still starts from the source viewer/manual chunk screen and creates a shared-view compatible chunk.

## Manual OCR-Assisted Chunking

Manual chunking is the current semi-automatic flow:

1. User opens PDF/image source.
2. User chooses one of the four chunk types.
3. User draws or adjusts a source box.
4. OCR/PDF text prefill assists the draft.
5. User edits the draft in a chunk sheet/editor.
6. User saves.
7. The saved chunk appears immediately in the manual PDF chunk list.

Each chunk type can have specialized editing later, but the first fix must at least save and display the correct kind and content.

## Sheet Behavior

The manual chunk sheet must not leave a white surface over the PDF after being dragged down or dismissed.

The current `DraggableBottomCard` behavior is unsafe for this screen because it translates only the child. The implementation should either:

- use a real route/modal dismissal that removes the sheet surface; or
- keep the sheet inside the page stack and remove the full widget when dismissed, without retaining a full-height white route surface.

The sheet must be adaptive: it should not take maximum height when its content is short.

## Tags

The PDF chunk UI must use the same tag design direction as note chunks. Tags are not categories; they are user-created relationship markers.

The tag sheet rules from `2026-06-21-tag-sheet-redesign-design.md` apply:

- one adaptive tag pill area;
- fixed folder bar;
- fixed editor area;
- immediate tag changes;
- central tag registry as source of truth;
- no user-facing tag type dropdown.

PDF-specific tag persistence can be bridged through the shared adapter first. Full persistence unification is deferred.

## Debug Logging

All relevant PDF chunk workflows must write to `DebugConsole` so the onscreen debug panel can be used during testing.

Required log groups:

- `[Knowledge/List]` for row navigation and document open decisions;
- `[Knowledge/Viewer]` for PDF/image viewer open, page changes, display mode changes, and box taps;
- `[PDFChunks]` for chunk menu load, selected mode, loaded counts, empty states, and editor opens;
- `[ManualChunk]` for selection type, box geometry, prefill source, save start, save success, save failure, and reload trigger;
- `[Knowledge/Import]` for PDF/image picker and import status.

Logs should include document id, filename where useful, mode, chunk id, chunk kind, page number, and source rect availability.

## Acceptance Checklist

| ID | Requirement | Intended Code Area | Acceptance Condition | Verification |
| --- | --- | --- | --- | --- |
| PDF-01 | User-facing PDF modes are only AI and manual OCR-assisted | `extracted_knowledge_screen.dart`, knowledge menus | No local/comparison user-facing modes remain in PDF chunk menu | Widget test and screenshot |
| PDF-02 | Only four chunk types are exposed and written | `local_extraction.dart`, manual chunk editor, shared chunk models | New UI exposes text/list/table/flowchart only | Unit/widget tests |
| PDF-03 | Manual chunk save appears in manual chunk list | repository + PDF chunk screen | Save returns to/reloads chunk list and shows the new chunk | Repository test and manual debug log |
| PDF-04 | Debug logs reach onscreen debug panel | `DebugConsole` call sites | Open/select/extract/save/list paths are logged | Manual test with debug panel |
| PDF-05 | Bottom sheet does not leave white overlay | manual chunk editor / shared sheet | Dragging down or canceling removes the sheet surface | Screenshot/manual test |
| PDF-06 | Knowledge card tap opens chunk menu | `KnowledgeDocumentRow`, `KnowledgeBaseScreen` | Whole non-selection card opens chunks | Widget test |
| PDF-07 | Knowledge left icon opens source viewer | `KnowledgeDocumentRow`, `KnowledgeBaseScreen` | Icon tap opens PDF/image viewer | Widget test |
| PDF-08 | Right chevron appears on knowledge rows | `KnowledgeDocumentRow` | Row visually matches notes card navigation affordance | Screenshot/widget test |
| PDF-09 | Source viewer has box display modes | `pdf_viewer_screen.dart` or shared viewer | Hidden/AI/manual toggle exists and logs changes | Manual/screenshot test |
| PDF-10 | PDF chunk cards use shared note-like design | shared chunk UI | PDF and note chunks render through shared card model | Screenshot/code inspection |
| PDF-11 | PDF chunks can use shared tag UI | shared chunk adapter/tag integration | Chunk tag entry points use same tag sheet direction | Widget/manual test |
| PDF-12 | Image import behaves like chunkable document | import and row/viewer paths | PNG row opens chunk menu; icon opens image viewer; manual chunking works | Manual test |

## Implementation Order

1. Add shared chunk model and adapters.
2. Restrict PDF chunk kinds and map legacy kinds.
3. Replace PDF extracted screen modes with AI/manual.
4. Fix manual chunk save visibility and add reload/count logs.
5. Fix the sheet dismissal/white surface issue.
6. Update knowledge row navigation and left-icon viewer action.
7. Add source viewer display mode state and logs.
8. Start using shared chunk card styling for PDF chunk list.
9. Bridge chunk tag entry points to the shared tag sheet path.
10. Add focused tests for repository save/list, row navigation, mode filtering, and manual chunk sheet behavior.

## Open Follow-Up After This Slice

After this slice is stable, decide whether to migrate persistence to a single physical shared chunk table. That migration should get a separate design and migration plan.
