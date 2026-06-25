# Manual PDF Chunk Flow Design

## Goal

Make manual PDF chunking stay in the viewer after saving, show completed manual source boxes immediately on the PDF, remove page editing from manual sheets, allow drag-down cancellation, and make PDF chunk cards behave like note chunk cards through a shared chunk UI/editor contract.

## Root Cause

`ManualChunkEditorScreen` saves a manual chunk and then calls `Navigator.pop(true)`, which closes the whole viewer route. The selected source box is persisted in `sourceRectJson`, but the editor does not reload the saved `ExtractedKnowledgeItem` list or render saved manual boxes after save.

The manual save sheet contains its own page text field even though the active page is already owned by the PDF viewer.

The PDF chunk list uses `ChunkCard` with `ExpansionTile` and a validation bottom sheet. The note chunk list uses `NoteChunkCard`, where card tap opens a fullscreen editor and the expand icon controls inline preview. This creates divergent scroll, expand, and edit behavior.

## Requirements Checklist

| ID | Source Instruction | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| MAN-01 | User: "manuális chnk: szedd ki a sheetekből az oldal boxot" | `lib/src/knowledge/ui/manual_chunk_editor_screen.dart` | Manual chunk save sheet has no editable page field; save uses the active viewer page | Widget test verifies `manual-chunk-page-field` is absent and saved item has the active page | DONE |
| MAN-02 | User: "a sheeteket lehessen cancelezni a sheet lefele draggolásával" | `lib/src/shared/ui/inline_bottom_sheet_card.dart`, `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`, validation/tag/editor sheets touched by this flow | Manual chunk save sheet and PDF chunk edit sheets can be dismissed by downward drag | Widget tests drag sheet down and verify sheet closes without saving | DONE |
| MAN-03 | User: after selecting colored box and saving, return to viewer with colored box printed on PDF | `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`, `lib/src/knowledge/ui/source_chunk_box_overlay.dart` | Saving a manual selection keeps `ManualChunkEditorScreen` visible, hides the save sheet, reloads saved manual boxes, and displays a tappable colored box for the saved chunk | Widget test saves a manual chunk and expects viewer route plus `source-chunk-box-<id>` | DONE |
| MAN-04 | User: after saved box is printed, a new box trigger can be made | `lib/src/knowledge/ui/manual_chunk_editor_screen.dart` | After save, the new-selection FAB is visible and a second manual selection can be started | Widget test verifies `manual-chunk-new-selection` is visible after save | DONE |
| PDF-01 | User: PDF chunk cards should behave like note chunk menu chunks | `lib/src/shared/chunks/`, `lib/src/notes/ui/note_chunk_card.dart`, `lib/src/knowledge/ui/extracted_knowledge_screen.dart` | Notes and PDF chunk lists share one card implementation/contract for title row, expand icon, tap-to-editor, tags, delete/action slots, and preview body | Source inspection verifies shared card is used by both note and PDF lists; widget tests cover both contexts | DONE |
| PDF-02 | User: expanded PDF chunk page cannot scroll | `lib/src/knowledge/ui/extracted_knowledge_screen.dart`, shared chunk card | Expanding a PDF chunk does not trap scrolling; the surrounding chunk list remains scrollable | Widget test expands a large PDF chunk and scrolls the list | DONE |
| PDF-03 | User: tapping the icon/card should open a fullscreen editor like notes | `lib/src/knowledge/ui/extracted_knowledge_screen.dart`, new PDF chunk editor route/screens | Tapping a PDF chunk card/icon opens a fullscreen editor route; bottom navigation is hidden when opened from the tabbed chunk list, matching note chunk editors | Widget test opens PDF text/list/table/flowchart editor paths from the chunk list | DONE |
| PDF-04 | User: common design/layout and no code duplication | `lib/src/shared/chunks/`, note/PDF adapters | PDF and note chunk lists use shared widgets/adapters instead of duplicate card layout code | Source inspection and focused unit/widget tests | DONE |
| REV-01 | Code review: PDF list/flowchart edits are lossy | `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart`, editor route tests | PDF chunk editor serialization preserves edited list indentation/checkbox state and regenerates flowchart text from edited nodes/edges instead of stale text | Unit tests for list and flowchart adapter round-trip behavior | DONE |
| REV-02 | Code review: mixed flowchart extraction rows route into a no-op update API | `lib/src/knowledge/ui/extracted_knowledge_screen.dart` | Any extracted item with a `flowchartId` opens the existing interactive flowchart editor, even in mixed chunk lists | Widget test with mixed text+flowchart list opens `flowchart-editor-canvas`, not PDF note editor | DONE |
| REV-03 | Code review: ObjectBox update leaves graph/evidence/search stale | `lib/src/knowledge/data/objectbox_knowledge_repository.dart` | Updating a local PDF chunk updates chunk, audit item, knowledge node, evidence quote, and invalidates old embeddings for that source | ObjectBox repository regression test inspects affected boxes after update; local run skips because `libobjectbox.so` is unavailable | DONE |
| REV-04 | Code review: saved source-box painter can block PDF gestures | `lib/src/knowledge/ui/source_chunk_box_overlay.dart` | Overlay painter does not participate in hit testing; only the visible source box taps remain interactive | Source inspection plus existing manual overlay widget tests | DONE |
| REV-05 | Code review: PDF note-style editor delete is misleading | `lib/src/knowledge/ui/pdf_chunk_editor_route.dart`, `lib/src/notes/ui/note_chunk_editor_header.dart`, note editor screens | PDF chunk editor hides the note "Chunk törlése" action until a real PDF chunk delete API exists; note editors still show it where deletion is supported | Widget test opens PDF editor menu and verifies delete item is absent; note editor contract remains covered by existing tests | DONE |
| REV-06 | Code review: AI table chunks can reload as text after embedding invalidation | `lib/src/knowledge/data/objectbox_knowledge_repository.dart` | When an AI chunk has no embedding after an edit, `sourceType` is derived from persisted `chunkKind` instead of falling back to text | ObjectBox repository regression test edits an AI table chunk and expects `tableChunk` after reload; local run skips because `libobjectbox.so` is unavailable | DONE |
| REV-07 | Code review: validation editor audit path leaves graph/evidence/search stale | `lib/src/knowledge/data/objectbox_knowledge_repository.dart` | `updateExtractedKnowledgeAuditState` text edits update chunk-derived knowledge node/evidence rows and invalidate embeddings just like fullscreen edits | ObjectBox repository regression test edits via audit update and inspects graph/evidence/embedding rows; local run skips because `libobjectbox.so` is unavailable | DONE |
| REV-08 | Code review: section graph edge is stale after title change | `lib/src/knowledge/data/objectbox_knowledge_repository.dart` | Changing a PDF chunk section title rewires its `part_of` edge to the new section node | ObjectBox repository regression test changes section title and inspects `part_of` edge target; local run skips because `libobjectbox.so` is unavailable | DONE |
| REV-09 | Code review: PDF table adapter drops empty cells | `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart` | Table serialization/parsing preserves empty middle cells so table shape survives reopen | Adapter unit test round-trips `A |  | C` and an edited empty middle cell | DONE |

## Architecture

Create a shared chunk card widget under `lib/src/shared/chunks/` that expresses the note chunk card interaction model without knowing whether the source is a note or PDF. Notes keep their note-specific adapter; PDF chunks get an `ExtractedKnowledgeItem` adapter. The shared card owns the consistent layout, expand toggle placement, tap-to-editor behavior, tags/action slots, and inline preview slot.

Manual chunk save stays inside `ManualChunkEditorScreen`. Saving persists the `LocalChunk`, reloads extracted items for the document, switches the overlay to manual source boxes, clears transient selection state, and leaves the viewer route open. The saved source rectangle is displayed through the same `SourceChunkBoxOverlay` used by the source viewer.

PDF chunk editing uses fullscreen routes. The route adapts `ExtractedKnowledgeItem` to a `NoteBlock` for text/list/table/flowchart editor screens and writes changes back through repository update APIs. Where current repository APIs are too narrow, add a focused update method that updates local chunk text/title/kind/tags while preserving source rectangle, page, pipeline, and audit state.

## Testing Strategy

Use widget tests first:

- Manual sheet has no page field and drag-down cancellation closes the sheet.
- Manual save remains in viewer, shows saved source box, and exposes the new-selection FAB.
- PDF chunk card expand keeps the list scrollable.
- PDF chunk card tap opens fullscreen editor.
- Note and PDF lists both render through the shared card contract.

Run targeted Flutter tests and `flutter analyze` inside Ubuntu proot. APK builds are not run locally on Termux; after implementation is committed and pushed, GitHub Actions produces the debug APK.

## Verification Notes

- Targeted tests: PASS for `test/knowledge_base_screen_test.dart`, `test/extracted_knowledge_screen_test.dart`, `test/note_chunk_card_test.dart`, `test/main_screen_navigation_test.dart`, and `test/objectbox_knowledge_repository_test.dart` with 68 passing tests and 3 ObjectBox tests skipped locally because `libobjectbox.so` is unavailable in this proot host.
- Note editor regression tests: PASS for `test/note_text_chunk_editor_screen_test.dart`, `test/note_list_chunk_editor_screen_test.dart`, `test/note_table_editor_screen_test.dart`, and `test/note_flowchart_editor_screen_test.dart` with 63 passing tests.
- Analyzer: PASS, `flutter analyze` reported no issues.
- Whitespace: PASS, `git diff --check` reported no issues.
- Source review: `NoteChunkCard` and `ExtractedKnowledgeScreen` both render through `SharedChunkCard`; PDF fullscreen editing uses `PdfChunkEditorRoute` and `pdf_chunk_note_block_adapter.dart`.
