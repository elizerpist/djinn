# Note Atom Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement note atom search from the 2026-06-21 spec so note retrieval returns precise atoms with audit reasons and bounded cascade instead of role/facet/definition search modes.

**Architecture:** Add explicit atom metadata to `SourceEvidence`, move note atomization into a focused indexer, then simplify `NoteAwareLocalRetriever` so it matches direct atoms first, determines a primary note scope, and only expands relationships inside that primary scope. Chat citations carry atom type and reasons so UI can render explainable source rows.

**Tech Stack:** Flutter/Dart, existing in-memory `NoteRepository`, `OfflineSearchService`, `LocalVectorSearchService`, existing chat citation UI, Ubuntu/proot for Flutter tests/analyze.

## Global Constraints

- No chunk categories or semantic role modes in the search/graph layer.
- `definicio`, `terapia`, `magyarazat`, `facet`, `<`, and `=` are literal/weak query tokens only.
- Chunk is an editing unit; atom is the search/display unit.
- Every displayed note atom must have at least one reason.
- Primary-note cascade may be deeper; external notes are direct-only by default.
- Full chunk context is opt-in; mixed chunks must not be shown wholesale by default.
- No `hidden_note_sentence` atom.
- Local Flutter APK builds are not expected on Termux; APK verification happens through GitHub Actions.

---

## File Structure

- Restore `docs/superpowers/specs/2026-06-21-note-atom-search-design.md`: approved design input recovered from commit `9ea3252`.
- Create `lib/src/rag/retrieval/note_atom_indexer.dart`: convert note chunks into typed atom `SourceEvidence` records with chunk metadata and table header search text.
- Modify `lib/src/rag/models/source_evidence.dart`: add atom type, reasons, chunk metadata, full chunk reference, and `copyWith`.
- Modify `lib/src/rag/retrieval/note_aware_local_retriever.dart`: use atom indexer, assign reasons, remove role/facet/definition scope behavior from the active note search path, and enforce bounded primary-note cascade.
- Modify `lib/src/chat/models/chat_citation.dart`: persist atom type and reasons.
- Modify `lib/src/chat/data/local_answer_service.dart`: map note atom metadata into citations without losing grouping.
- Modify `lib/src/chat/ui/chat_bubble.dart`: show compact atom type/reason chips in citation rows while preserving tap-to-preview.
- Test `test/note_atom_indexer_test.dart`: atomization and table header search text.
- Test `test/note_aware_local_retriever_atom_search_test.dart` or focused additions to `test/note_aware_local_retriever_test.dart`: spec acceptance scenarios.
- Test `test/local_answer_service_test.dart` and `test/chat_bubble_test.dart`: citation metadata and visible reason chips.

### Task 1: Restore Spec And Acceptance Tracking

**Files:**
- Create: `docs/superpowers/specs/2026-06-21-note-atom-search-design.md`
- Create: `docs/superpowers/checklists/2026-06-23-note-atom-search.md`
- Create: `docs/superpowers/plans/2026-06-23-note-atom-search.md`

**Interfaces:**
- Produces: stable source spec and checklist IDs `NAS-01` through `NAS-09`.

- [ ] Add the restored spec content from commit `9ea3252`.
- [ ] Add the checklist with all statuses initially `NOT DONE`.
- [ ] Keep implementation status honest by updating checklist rows only after tests or inspection verify them.

### Task 2: SourceEvidence Atom Metadata

**Files:**
- Modify: `lib/src/rag/models/source_evidence.dart`
- Test: existing citation/retriever tests continue compiling.

**Interfaces:**
- Produces: `NoteEvidenceAtomType`, `NoteEvidenceReason`, `SourceEvidence.copyWith`, optional fields `atomType`, `reasons`, `noteTitle`, `chunkId`, `chunkTitle`, `sourceStart`, `sourceEnd`, `fullChunkText`.

- [ ] Add enum wire names matching the spec: `text_sentence`, `list_item`, `table_cell`, `table_row`, `flowchart_node`, `flowchart_edge`.
- [ ] Add reason wire names matching the spec: `direct_query`, `note_scope`, `chunk_title`, `list_item_match`, `table_column`, `table_cell`, `flowchart_branch`, `process_link`, `external_direct`.
- [ ] Add optional fields with defaults so existing `SourceEvidence(...)` call sites do not break.
- [ ] Add `copyWith` for score and reason enrichment.

### Task 3: Note Atom Indexer

**Files:**
- Create: `lib/src/rag/retrieval/note_atom_indexer.dart`
- Test: `test/note_atom_indexer_test.dart`

**Interfaces:**
- Produces: `NoteAtomIndexer.buildEvidence(NoteDocument note, {required String noteId, required String noteTitle}) -> List<SourceEvidence>`.
- Consumes: existing `NoteChunkBuilder`, `NoteDocument`, `NoteContentBlock`, `NoteKnowledgeTag`.

- [ ] Write tests that a mixed paragraph creates multiple `text_sentence` atoms with source offsets and no hidden-note atom type.
- [ ] Write tests that list items become one `list_item` atom per item.
- [ ] Write tests that a table cell atom search text contains chunk title, row header, column header, and value.
- [ ] Write tests that flowchart nodes and edges become typed atoms.
- [ ] Implement the indexer with no definition/facet/therapy classification helpers.

### Task 4: Atom Retrieval And Bounded Cascade

**Files:**
- Modify: `lib/src/rag/retrieval/note_aware_local_retriever.dart`
- Test: `test/note_aware_local_retriever_atom_search_test.dart`

**Interfaces:**
- Consumes: `NoteAtomIndexer.buildEvidence`.
- Produces: note retrieval that returns atom-level `SourceEvidence` with nonempty reasons.

- [ ] Write `bolognai` test proving only bolognai atoms are returned from a mixed chunk.
- [ ] Write `legzesi elegtelenseg` multi-note test proving external notes are direct-only.
- [ ] Write `legzesi elegtelenseg definicio` test proving `definicio` is not a role filter and DO2/VO2 only enter through primary-note cascade.
- [ ] Write `sulyos` test proving no automatic deep cascade.
- [ ] Write `sulyos legzesi elegtelenseg` test proving internal flowchart/table atoms can appear but external oxygen-only atoms do not.
- [ ] Replace active role/facet scope filtering with direct atom matching plus primary-note bounded expansion.
- [ ] Assign reason lists to every returned note atom.

### Task 5: Chat Citation Metadata And UI Chips

**Files:**
- Modify: `lib/src/chat/models/chat_citation.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Test: `test/local_answer_service_test.dart`
- Test: `test/chat_bubble_test.dart`

**Interfaces:**
- Consumes: `SourceEvidence.atomType`, `SourceEvidence.reasons`.
- Produces: `ChatCitation.atomType`, `ChatCitation.reasons` serialized to JSON and shown in citation rows.

- [ ] Add citation serialization tests for atom type and reasons.
- [ ] Add chat bubble widget test that reason chips render for a citation.
- [ ] Map atom metadata from evidence to citations and preserve it during grouping.
- [ ] Render compact chips below/inside citation rows without changing the tap target.

### Task 6: Verification, Checklist, Commit, Push

**Files:**
- Modify: `docs/superpowers/checklists/2026-06-23-note-atom-search.md`

- [ ] Re-read the spec and checklist.
- [ ] Run targeted tests in Ubuntu/proot:
  `proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_atom_indexer_test.dart test/note_aware_local_retriever_atom_search_test.dart test/local_answer_service_test.dart test/chat_bubble_test.dart'`
- [ ] Run broader relevant tests in Ubuntu/proot:
  `proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter test test/note_aware_local_retriever_test.dart test/local_answer_service_test.dart test/chat_bubble_test.dart'`
- [ ] Run analyze in Ubuntu/proot:
  `proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && flutter analyze'`
- [ ] Update checklist statuses to `DONE`, `PARTIAL`, or `BLOCKED` based on evidence.
- [ ] Commit and push this branch so GitHub Actions can build APK.
