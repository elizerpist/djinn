# Scoped Offline RAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make offline note graph retrieval narrower as queries become more specific, and surface the requested tag/metadata controls in the note editor.

**Architecture:** Keep the existing note metadata model. Add query-scope gates in the local graph expander so branch/facet queries cannot widen into root definitions or unrelated topic therapy tables. Expose context, role, and aliases as visible chips in the editor.

**Tech Stack:** Flutter, Dart, GitHub Actions Android debug APK build.

## Global Constraints

- Termux/Android cannot run a local Flutter APK build; use GitHub Actions for Flutter tests and APK generation.
- Use TDD: the retrieval regression tests must fail before production code changes and pass after.
- Do not hardcode medical terms such as `súlyos`, `DO2`, or `légzési elégtelenség`; rules must be based on query scope, metadata, source type, and graph link type.
- Preserve broad queries: a root topic query may still bring definitions, flowchart, and therapy for the same topic.
- Preserve specific queries: a branch/state or topic+facet query must stay in the relevant branch/facet context.

---

### Task 1: Retrieval Regression Tests

**Files:**
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Consumes: `NoteAwareLocalRetriever.retrieveLocalVector`, `NoteAwareLocalRetriever.retrieveHybrid`
- Produces: failing tests for branch-specific and topic+facet retrieval scope

- [x] **Step 1: Write failing tests**

Add tests that verify `súlyos` excludes `DO2/VO2` definitions while keeping severe/mild oxygen therapy, and `légzési elégtelenség terápiája` intersects respiratory topic plus therapy without pulling hypoglycaemia therapy.

- [x] **Step 2: Run test to verify it fails**

Run through GitHub Actions because local Flutter is unavailable.
Expected: Flutter test job fails in `note_aware_local_retriever_test.dart`.

- [ ] **Step 3: Keep tests unchanged while fixing production code**

Do not weaken assertions unless the RED failure is a test bug.

### Task 2: Scoped Graph Retrieval

**Files:**
- Modify: `lib/src/rag/retrieval/note_aware_local_retriever.dart`

**Interfaces:**
- Consumes: `SourceEvidence.searchableText`, `EvidenceSourceType`, `LocalKnowledgeGraphExpander.expand`
- Produces: query-scope-aware graph links and final evidence pruning

- [ ] **Step 1: Split query terms from seed terms**

Use a seed's own text/search metadata for seed expansion, and keep original query terms only as query-scope constraints.

- [ ] **Step 2: Add query-scope helpers**

Classify symbol, definition, table/facet, and narrow branch/state queries from normalized query text and evidence metadata.

- [ ] **Step 3: Gate graph links**

Allow branch/table/flowchart links for narrow branch queries, but suppress symbol and root definition jumps unless the query explicitly asks for symbols or definitions.

- [ ] **Step 4: Prune final evidence**

For topic+facet queries, keep evidence that matches the topic and facet metadata/content; remove unrelated same-facet evidence from other topics and root definitions.

- [ ] **Step 5: Run tests in CI**

Expected: all `note_aware_local_retriever_test.dart` tests pass, including older symbol and bolognai regressions.

### Task 3: Visible Tag And Metadata UI

**Files:**
- Modify: `lib/src/notes/ui/note_document_editor_screen.dart`
- Modify: `test/note_document_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NoteBlock.searchContext`, `NoteBlock.searchRole`, `NoteBlock.searchAliases`
- Produces: visible chip-style tag summary without a data migration

- [ ] **Step 1: Write widget test**

Assert that the editor shows a `Keresési metadata / tagek` section and visible chips for context, role, and aliases.

- [ ] **Step 2: Implement UI chips**

Render context, role, and aliases above/below the existing fields; rename alias field to `Tagek / aliasok / szimbólumok`.

- [ ] **Step 3: Preserve save behavior**

Existing metadata save test must still pass.

### Task 4: Build, Commit, Push, APK Link

**Files:**
- No production files beyond Tasks 2-3

**Interfaces:**
- Consumes: GitHub Actions workflow and `debug-latest` release
- Produces: pushed branch, passing CI, downloadable APK URL

- [ ] **Step 1: Run local static checks available in Termux**

Run `git diff --check`. Record that local Flutter is unavailable if still true.

- [ ] **Step 2: Commit and push**

Commit production changes after tests are in place, then push `feature/knowledge-ocr-inspector`.

- [ ] **Step 3: Watch GitHub Actions**

Run `gh run watch --exit-status` for the pushed commit.

- [ ] **Step 4: Return APK link**

Use the `debug-latest` release asset URL after the workflow publishes it.
