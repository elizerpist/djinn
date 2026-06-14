# Universal Notes Document Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert notes from separate typed chunk cards into mixed user documents that can contain text, lists, tables, and flowcharts, then be chunked like PDFs.

**Architecture:** Keep `NoteItem` as the top-level persisted library item, but introduce a block document model stored in `payloadJson` and rendered through dedicated UI helpers. Reuse existing notes repository patterns, existing chunk cards for display where useful, and existing flowchart canvas/editor code for flowchart blocks. Add focused tests around migration, UI behavior, editor persistence, navigation, and chunk extraction.

**Tech Stack:** Flutter, Dart, Material widgets, JSON-backed note repository, existing flowchart editor canvas, existing chunk card and local extraction models.

---

## File Structure

- Modify `lib/src/notes/models/note_item.dart`: keep legacy fields, add document/block helpers and top-level document semantics.
- Create `lib/src/notes/models/note_document.dart`: serializable document block model.
- Modify `lib/src/notes/data/note_repository.dart`: create/update notes through block documents and keep legacy migration.
- Create `lib/src/notes/data/note_chunk_builder.dart`: convert note document blocks into inspectable note chunks.
- Modify `lib/src/notes/ui/notes_screen.dart`: PDF-like note boxes, folder bar styling, circular FAB, open slide-up editor card.
- Modify `lib/src/notes/ui/note_creation_sheet.dart`: replace typed note creation with name/folder/preview/full-editor workflow.
- Create `lib/src/notes/ui/note_document_editor_screen.dart`: full-screen freeform document editor.
- Create `lib/src/notes/ui/note_table_editor_screen.dart`: full-screen table block editor.
- Create `lib/src/notes/ui/note_flowchart_editor_screen.dart`: full-screen note-owned flowchart block editor or adapter around existing canvas.
- Modify `lib/src/chat/ui/app_destination.dart` and `lib/src/chat/ui/main_screen.dart`: remove Search bottom nav destination.
- Modify tests under `test/`: repository, notes screen, editor widgets, nav behavior, and chunk builder.

## Task 1: Document Block Model

- [ ] Add failing tests in `test/note_document_test.dart` for parsing legacy text/table/flowchart notes and serializing mixed block documents.
- [ ] Create `lib/src/notes/models/note_document.dart` with `NoteDocument`, `NoteBlock`, `NoteBlockType`, and helpers: `fromPayload`, `fromLegacy`, `toPayloadJson`, `plainText`, `preview`.
- [ ] Update `NoteItem` with `document`, `preview`, and `copyWithDocument` helpers while preserving old JSON fields.
- [ ] Run `flutter test test/note_document_test.dart`.

## Task 2: Repository API For Mixed Notes

- [ ] Add failing tests in `test/note_repository_test.dart` for `createDocumentNote`, updating a document, and legacy note readability.
- [ ] Extend `NoteRepository` with `createDocumentNote` and `updateNoteDocument`.
- [ ] Implement methods in memory and file repositories.
- [ ] Keep existing `createNote` API as a compatibility wrapper that creates a one-block document.
- [ ] Run `flutter test test/note_repository_test.dart`.

## Task 3: Note Chunk Builder

- [ ] Add failing tests in `test/note_chunk_builder_test.dart` for paragraph/list chunks, table chunks, flowchart chunks, and chunk groups.
- [ ] Create `lib/src/notes/data/note_chunk_builder.dart` returning inspectable `NoteChunkViewModel` values.
- [ ] Ensure table chunks include row text and flowchart chunks include node/edge summaries.
- [ ] Run `flutter test test/note_chunk_builder_test.dart`.

## Task 4: Notes Menu UI

- [ ] Update `test/notes_screen_test.dart` to expect compact note boxes, circular notes FAB, PDF-like folder bar, and no `Összes` pill when the note library is empty.
- [ ] Modify `NotesScreen` to render note boxes rather than type-driven chunk cards.
- [ ] Match the folder bar to the PDF `_FolderPillBar` styling and left alignment.
- [ ] Replace `FloatingActionButton.extended` with a normal circular FAB using a note creation icon.
- [ ] Run `flutter test test/notes_screen_test.dart`.

## Task 5: Slide-Up Note Create/Edit Card

- [ ] Update widget tests so the slide-up card shows name, folder, preview box, `Teljes editor`, and `Mentés`.
- [ ] Rework `NoteCreationSheet` into a note document entry card: no top-level text/table/flowchart type dropdown.
- [ ] Keep the preview box in the body and open the full editor from `Teljes editor`.
- [ ] Save the current document blocks through repository APIs.
- [ ] Run notes screen tests again.

## Task 6: Full-Screen Note Document Editor

- [ ] Add tests for opening the full editor, editing free text, adding list items, indenting/outdenting, and saving.
- [ ] Create `NoteDocumentEditorScreen` with title, freeform paragraph rows, list rows, heading controls, indent/outdent controls, add table, and add flowchart actions.
- [ ] Persist edited blocks back to `NoteCreationSheet` and then to repository.
- [ ] Run the editor tests.

## Task 7: Table Block Editor

- [ ] Add widget tests for editing a cell, adding row, adding column, and saving.
- [ ] Create `NoteTableEditorScreen` and call it from the document editor for table blocks.
- [ ] Update the parent note document block after save.
- [ ] Run table editor tests.

## Task 8: Flowchart Block Editor

- [ ] Add widget tests that a decision node keeps both `Igen` and `Nem` branch labels after save.
- [ ] Create `NoteFlowchartEditorScreen` as an adapter around existing `FlowchartEditorCanvas` and editable flowchart models.
- [ ] Support adding nodes, adding edges, editing edge labels, and saving back to the note block.
- [ ] Run flowchart editor tests.

## Task 9: Bottom Nav Cleanup

- [ ] Update nav tests or add `test/app_destination_test.dart` asserting four destinations and no `search` destination.
- [ ] Remove `AppDestinationId.search` and the `SearchScreen` branch from bottom navigation.
- [ ] Keep the search screen file untouched for possible future use, but unreachable from bottom nav.
- [ ] Run affected app shell tests.

## Task 10: Integration Verification

- [ ] Run focused tests: `flutter test test/note_document_test.dart test/note_repository_test.dart test/note_chunk_builder_test.dart test/notes_screen_test.dart test/graph_flowchart_editor_test.dart`.
- [ ] Run analyzer: `flutter analyze`.
- [ ] Commit implementation.
- [ ] Push branch and verify GitHub Actions build.

## Self-Review

- Spec coverage: universal mixed note document, slide-up preview, full-screen note/table/flowchart editors, notes-as-PDF-like menu, chunking, bottom nav cleanup, folder bar/FAB fixes, and legacy compatibility are covered.
- Placeholder scan: no implementation task is marked as optional or deferred.
- Type consistency: the plan consistently uses `NoteDocument`, `NoteBlock`, `createDocumentNote`, and `updateNoteDocument` as the new API surface while keeping `createNote` as compatibility.
