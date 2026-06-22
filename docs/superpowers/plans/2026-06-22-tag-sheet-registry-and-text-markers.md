# Tag Sheet Registry And Text Markers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace text chunk secondary underline tag feedback with highlight plus count markers, and implement the approved 2026-06-21 global tag sheet backed by a reusable local tag registry.

**Architecture:** Keep note text editing native by leaving controller text and line metrics untouched by tag count. Add a notes tag registry repository with memory and ObjectBox implementations, then rewrite the tag manager bottom sheet to read/write that registry and immediately apply selected tags to every note/chunk target.

**Tech Stack:** Flutter, Material 3, ObjectBox, existing `NoteRepository`, existing note chunk editor widgets, existing widget tests.

## Global Constraints

- Existing note JSON must remain readable.
- New scoped assignments should store stable tag ids plus fallback label/color metadata.
- The tag sheet has no user-facing type/category dropdown; internal default type is `custom`.
- The tag sheet has no `Mentés` button; updates are immediate.
- Text chunk tag visuals are highlight background plus selected count marker mode; no secondary underlines and no underline-triggered line-height growth.
- The 2026-06-21 spec's underline wording is superseded. Other chunk types may receive badge visuals later, but this plan does not roll out chunk-specific badge UI beyond text chunks.
- Local Flutter APK builds are not expected on Termux; APK verification happens through GitHub Actions.

---

## File Structure

- Modify `lib/src/notes/ui/tagged_text_visual.dart`: remove underline-producing APIs while preserving highlight and count marker APIs.
- Modify `lib/src/notes/ui/note_text_chunk_editor_screen.dart`: remove underline layer, strut expansion, and underline debug fields.
- Modify `lib/src/notes/ui/note_list_chunk_editor_screen.dart` and `lib/src/notes/ui/note_table_editor_screen.dart`: remove calls to the deleted shared secondary underline widget without adding badge UI there yet.
- Modify `lib/src/notes/models/note_document.dart`: extend `NoteKnowledgeTag` with registry id, color slot id, and folder id while preserving old JSON.
- Create `lib/src/notes/models/note_tag_registry.dart`: registry tag/folder value objects and normalization helpers.
- Create `lib/src/notes/data/tag_repository.dart`: `TagRepository`, `MemoryTagRepository`, and helper methods for embedded tag compatibility.
- Create `lib/src/notes/data/objectbox_tag_repository.dart`: ObjectBox-backed repository.
- Modify `lib/src/local_store/entities.dart`: add ObjectBox tag and tag folder entities.
- Modify `lib/main.dart`, `lib/src/chat/ui/main_screen.dart`, `lib/src/notes/ui/notes_screen.dart`, `lib/src/notes/ui/note_editor_route.dart`, and note chunk editor constructors: pass `TagRepository`.
- Rewrite `lib/src/notes/ui/tag_manager_sheet.dart`: fixed header/folder/editor regions, one scrollable pill area, immediate updates, no save/type UI.
- Update tests in `test/tagged_text_visual_test.dart`, `test/note_text_chunk_editor_screen_test.dart`, `test/note_list_chunk_editor_screen_test.dart`, `test/note_table_editor_screen_test.dart`, `test/note_flowchart_editor_screen_test.dart`, `test/note_editor_route_test.dart`, `test/notes_screen_test.dart`, `test/note_document_test.dart`, and add `test/tag_repository_test.dart`.

### Task 1: Remove Secondary Underlines

**Files:**
- Modify: `lib/src/notes/ui/tagged_text_visual.dart`
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Test: `test/tagged_text_visual_test.dart`
- Test: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: existing `NoteTextRangeTag.resolvedTags`.
- Produces: `noteTaggedTextVisualStyle()` with only `primaryBackground`; count marker helpers remain the only multi-tag visual API for text chunks.

- [ ] Write/update tests proving extra tags do not produce underline colors, underline runs, underline widgets, or text strut expansion.
- [ ] Run `flutter test test/tagged_text_visual_test.dart test/note_text_chunk_editor_screen_test.dart` and confirm the changed tests fail before implementation.
- [ ] Remove underline generation and textchunk underline layer/strut wiring.
- [ ] Run the same tests and confirm they pass.

### Task 2: Add Registry Tag Model And Repositories

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Create: `lib/src/notes/models/note_tag_registry.dart`
- Create: `lib/src/notes/data/tag_repository.dart`
- Create: `lib/src/notes/data/objectbox_tag_repository.dart`
- Modify: `lib/src/local_store/entities.dart`
- Test: `test/note_document_test.dart`
- Test: `test/tag_repository_test.dart`

**Interfaces:**
- Produces: `NoteTagDefinition`, `NoteTagFolder`, `TagRepository`, `MemoryTagRepository`, `ObjectBoxTagRepository`.
- Produces: `NoteKnowledgeTag.copyWith(...)` carrying `id`, `colorSlotId`, `folderId`.

- [ ] Write serialization tests for old `NoteKnowledgeTag` JSON and new registry fields.
- [ ] Write repository tests for upsert, duplicate-label reuse, folder creation, folder clearing, and embedded tag seeding.
- [ ] Implement value objects, note tag JSON compatibility, memory repository, ObjectBox entities, and ObjectBox repository.
- [ ] Run `flutter test test/note_document_test.dart test/tag_repository_test.dart`.

### Task 3: Rewrite The Tag Manager Sheet

**Files:**
- Rewrite: `lib/src/notes/ui/tag_manager_sheet.dart`
- Test: `test/notes_screen_test.dart`
- Test: `test/note_editor_route_test.dart`
- Test: chunk editor tag tests.

**Interfaces:**
- Consumes: `TagRepository`.
- Produces: `showTagManagerSheet(context, initialTags, tagRepository, onChanged, availableTags, singleSelection, title)`.

- [ ] Write widget tests asserting there is no `tag-manager-type` and no `tag-manager-save`.
- [ ] Write widget tests for one scrollable tag area, fixed folder bar, fixed editor, full-color pills, edit/delete controls, duplicate label reuse, and immediate target updates.
- [ ] Implement the new sheet with header, folder bar, pill area, and fixed editor.
- [ ] Run sheet and call-site tests.

### Task 4: Wire Registry Through The App

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Modify: text/list/table/flowchart chunk editor constructors and sheet calls.

**Interfaces:**
- Consumes: `TagRepository` from app dependencies.
- Produces: all note tag entry points use the same repository and immediate `onChanged` callback.

- [ ] Add `tagRepository` to dependency objects and constructors.
- [ ] Pass memory repository in test-friendly paths and ObjectBox repository in production path.
- [ ] Update all `showTagManagerSheet` callers to immediate apply.
- [ ] Run all note editor tests.

### Task 5: Verification, Checklist, Commit, Push

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-22-tag-sheet-registry-and-text-markers.md`

- [ ] Re-read the checklist and update every status honestly.
- [ ] Run targeted Flutter tests.
- [ ] Run `flutter analyze` if local toolchain allows; otherwise note why and rely on GitHub Actions.
- [ ] Commit the changes.
- [ ] Push branch and watch GitHub Actions.
