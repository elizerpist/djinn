# Djinn Tags, Search Scope, And Flowchart Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make offline note retrieval more specific as the query becomes more specific, add a visible typed tag system, and implement the 2026-06-17 flowchart visual semantics cleanup.

**Architecture:** Retrieval scope is derived from actual evidence roles instead of query length, so entity queries such as `bolognai` can expand local context while branch/state queries such as `sulyos` stay branch-scoped. Tags are persisted typed metadata on documents, blocks, and list items, then indexed as search metadata and shown in the notes UI. Flowchart editor and preview derive port/loop visual state from edge usage, while list and guide views render path steps without duplicate decision screens.

**Tech Stack:** Flutter/Dart, existing in-memory note repositories and widget tests, GitHub Actions for Flutter test/build/APK because Termux ARM64 does not support local Flutter APK builds.

## Global Constraints

- Do not rely on hard-coded medical or food terms; behavior must follow generic evidence type, query facet, state/branch, symbol, and tag signals.
- Tagless retrieval must still produce the best available result.
- Tags are typed scope/ranking metadata, not a command to blindly include every tagged item.
- More specific queries must produce more specific evidence.
- `terapia`/`therapy` facet queries should favor therapeutic table/rule evidence and not unrelated therapies from other topics.
- `sulyos` branch queries should include the severe branch and relevant therapy, but suppress DO2/VO2 definitions unless the query asks for definitions or symbols.
- `bolognai` topic/entity queries should include safe same-topic local context, but not respiratory DO2/VO2 content.
- Flowchart preview canvas must not show the square grid; the note flowchart editor canvas must keep its square grid.
- Flowchart normal process box design and normal non-loop line color stay unchanged.
- Loop-closing edges must be orange and dashed.
- Do not run local Flutter APK builds on Termux; push to GitHub and use Actions for test/build/APK.

---

## File Structure

- Modify `lib/src/rag/retrieval/note_aware_local_retriever.dart`: query scope classification, graph expansion filters, safe local context expansion, and tag-aware ranking.
- Modify `test/note_aware_local_retriever_test.dart`: failing tests for `bolognai`, `sulyos`, `sulyos legzesi elegtelenseg`, `legzesi elegtelenseg terapiaja`, and unrelated therapy isolation.
- Modify `lib/src/notes/models/note_document.dart`: typed tag model, document/block/list item tag serialization, inherited tag helpers, and indexing metadata.
- Modify `test/note_document_test.dart`: tag serialization and indexing tests.
- Modify `lib/src/notes/data/note_chunk_builder.dart`: include document/block/list item tag metadata in chunks.
- Modify `lib/src/notes/ui/note_document_editor_screen.dart`: typed block tag editor and visible direct/inherited tag chips.
- Modify `lib/src/notes/ui/note_list_chunk_editor_screen.dart`: per-list-item typed tag editor.
- Modify `lib/src/notes/ui/notes_screen.dart`: notes menu tag guide and selected-note tag assignment.
- Modify `test/note_document_editor_screen_test.dart`, `test/note_list_chunk_editor_screen_test.dart`, `test/notes_screen_test.dart`: visible tag UI tests.
- Modify `lib/src/notes/ui/note_flowchart_editor_screen.dart`: editor port visual state and loop edge style while keeping editor grid.
- Modify `lib/src/flowchart/ui/mobile_flowchart_viewer.dart`: preview port state, loop edge style, no preview grid, list cleanup, guide cleanup.
- Modify `test/note_flowchart_editor_screen_test.dart`, `test/mobile_flowchart_viewer_test.dart`: flowchart spec tests.
- Optionally modify `docs/superpowers/specs/2026-06-17-djinn-flowchart-visual-semantics-cleanup-design.md` only if implementation reveals a spec ambiguity; otherwise leave spec unchanged.

---

### Task 1: RED Tests For Search Scope Anomalies

**Files:**
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Consumes: existing `NoteAwareLocalRetriever.retrieveLocalVector`, `retrieveOffline`, `_respiratoryTherapyFixture`.
- Produces: failing tests that define generic query scope behavior.

- [ ] **Step 1: Add a bolognai entity-context regression test**

Add a test that creates a mixed note with bolognai sentences and respiratory definition content. Assert that query `bolognai` returns the bolognai preparation context, and does not return `DO2`, `VO2`, or `legzesi elegtelenseg akkor all fenn`.

Expected assertions:

```dart
expect(joined, contains('Bolognai spagetti'));
expect(joined, contains('ragu'));
expect(joined, contains('paradicsomos alap'));
expect(joined, isNot(contains('DO2')));
expect(joined, isNot(contains('VO2')));
expect(joined, isNot(contains('légzési elégtelenség akkor áll fenn')));
```

- [ ] **Step 2: Add a severe branch regression test**

Use `_respiratoryTherapyFixture()` and query `súlyos?`. Assert branch and therapy evidence is present, while DO2/VO2 definitions are absent.

Expected assertions:

```dart
expect(joined, contains('Súlyos? -> Oxygén [Igen]'));
expect(joined, contains('súlyos légzési elégtelenség'));
expect(joined, contains('magas áramlású oxygén'));
expect(joined, contains('enyhe légzési elégtelenség'));
expect(joined, contains('célzott oxygénterápia'));
expect(joined, isNot(contains('DO2')));
expect(joined, isNot(contains('VO2')));
```

- [ ] **Step 3: Add a specific therapy-facet test**

Create a respiratory therapy table and a hypoglycaemia therapy table. Query `légzési elégtelenség terápiája`. Assert only respiratory therapy rows are returned.

Expected assertions:

```dart
expect(joined, contains('magas áramlású oxygén'));
expect(joined, contains('célzott oxygénterápia'));
expect(joined, isNot(contains('hypoglycaemia')));
expect(joined, isNot(contains('glükóz')));
expect(joined, isNot(contains('DO2 < VO2')));
```

- [ ] **Step 4: Verify RED**

Run:

```bash
flutter test test/note_aware_local_retriever_test.dart
```

Expected: FAIL. If `flutter` is unavailable locally, commit and push the test-only change, then verify the failing run in GitHub Actions before production edits.

---

### Task 2: GREEN Search Scope Implementation

**Files:**
- Modify: `lib/src/rag/retrieval/note_aware_local_retriever.dart`
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Consumes: `_QueryScope.from(query)`, `SourceEvidence`, `_keywordMatches`, `_localVectorSearch.search`, `LocalKnowledgeGraphExpander.expand`.
- Produces: evidence-aware scope filtering that no longer treats every single-word query as a narrow state.

- [ ] **Step 1: Replace single-word state detection**

Change `_QueryScope.from` so `terms.length == 1` is not sufficient for `isNarrowState`. Keep explicit yes/no branch terms as narrow. Add fields such as `hasBranchIntent` or create a resolver method that upgrades scope after seeing evidence.

Core rule:

```dart
final isNarrowState =
    terms.any((term) => const {'igen', 'nem', 'yes', 'no'}.contains(term));
```

- [ ] **Step 2: Add evidence role detection**

Add private helpers that inspect matched evidence:

```dart
bool _looksLikeBranchOrStateEvidence(SourceEvidence evidence, Set<String> terms)
bool _looksLikeTopicEntityEvidence(SourceEvidence evidence, Set<String> terms)
bool _sameDocumentBlockGroup(SourceEvidence a, SourceEvidence b)
```

Branch/state evidence should include flowchart node/edge matches and table rows where the query term is a condition/state value. Topic/entity evidence should include ordinary text/list matches without branch-like source type.

- [ ] **Step 3: Gate definition and symbol expansion by resolved scope**

Use the resolved evidence role before graph expansion:

- branch/state query: allow branch_value links, table companions, and direct flowchart neighbors; suppress definition/symbol expansion unless the query has definition or symbol intent.
- topic/entity query: allow same-block or same-list local context, but suppress unrelated definition/symbol expansion when the symbol was not queried.
- facet query: require facet evidence plus topic coverage.

- [ ] **Step 4: Preserve broad definition behavior**

For broad queries like `mi a légzési elégtelenség?`, keep definition expansion so DO2 and VO2 definitions still appear.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
flutter test test/note_aware_local_retriever_test.dart
```

Expected: PASS. If local Flutter is unavailable, push and verify the workflow.

---

### Task 3: RED/GREEN Typed Tag Model And Indexing

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Modify: `lib/src/notes/data/note_chunk_builder.dart`
- Modify: `test/note_document_test.dart`
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Produces: `NoteKnowledgeTag`, `NoteKnowledgeTagTypes`, `tags` on `NoteDocument`, `NoteBlock`, and `NoteListItem`.
- Consumes: existing `searchMetadataText`, `plainTextForIndexing`, `NoteChunkBuilder.build`.

- [ ] **Step 1: Write failing model tests**

Add tests asserting typed tags serialize and index without polluting display text:

```dart
const tag = NoteKnowledgeTag(type: NoteKnowledgeTagTypes.topic, label: 'légzési elégtelenség');
const block = NoteBlock(
  id: 'b1',
  type: NoteBlockType.paragraph,
  text: 'Súlyos esetben high flow oxygen.',
  tags: [tag],
);
final parsed = NoteBlock.fromJson(block.toJson());
expect(parsed.tags.single.type, NoteKnowledgeTagTypes.topic);
expect(parsed.searchMetadataText, contains('topic:légzési elégtelenség'));
expect(parsed.plainText, isNot(contains('topic:')));
```

Add a list item test:

```dart
const item = NoteListItem(
  id: 'i1',
  text: 'magas áramlású oxygén',
  tags: [NoteKnowledgeTag(type: NoteKnowledgeTagTypes.state, label: 'súlyos')],
);
expect(NoteListItem.fromJson(item.toJson()).tags.single.label, 'súlyos');
```

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/note_document_test.dart
```

Expected: FAIL because tag model fields do not exist.

- [ ] **Step 3: Implement the tag model**

Add:

```dart
class NoteKnowledgeTagTypes {
  static const topic = 'topic';
  static const type = 'type';
  static const state = 'state';
  static const symbol = 'symbol';
  static const node = 'node';
  static const branch = 'branch';
  static const custom = 'custom';
}

class NoteKnowledgeTag {
  const NoteKnowledgeTag({required this.type, required this.label});
  final String type;
  final String label;
}
```

Normalize empty or unknown types to `custom`, trim labels, and serialize tags as JSON objects with `type` and `label`.

- [ ] **Step 4: Add tag fields and indexing text**

Add `tags` to `NoteDocument`, `NoteBlock`, and `NoteListItem`. Include direct tags in metadata as both `type:label` and the raw label. For list items, include item-level tag metadata in granular evidence `searchText`.

- [ ] **Step 5: Verify GREEN**

Run:

```bash
flutter test test/note_document_test.dart test/note_aware_local_retriever_test.dart
```

Expected: PASS for model/indexing behavior.

---

### Task 4: RED/GREEN Visible Tag UI

**Files:**
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify: `lib/src/notes/ui/note_document_editor_screen.dart`
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`
- Modify: `test/notes_screen_test.dart`
- Modify: `test/note_document_editor_screen_test.dart`
- Modify: `test/note_list_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NoteKnowledgeTag` from Task 3.
- Produces: visible tag entry points in Notes menu, block editor, and list item editor.

- [ ] **Step 1: Write failing Notes menu tests**

Add tests that open the notes header menu and selected-note menu and expect `Tagek` to be visible. For one selected note, tapping `Tagek` should open a dialog/sheet keyed `notes-tag-dialog`.

Expected assertions:

```dart
expect(find.text('Tagek'), findsOneWidget);
await tester.tap(find.text('Tagek'));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('notes-tag-dialog')), findsOneWidget);
```

- [ ] **Step 2: Write failing block tag editor tests**

In `note_document_editor_screen_test.dart`, expect a typed tag input keyed `note-block-tag-label-block-1`, a type selector keyed `note-block-tag-type-block-1`, and chips such as `Tag: topic légzési elégtelenség`.

- [ ] **Step 3: Write failing list item tag tests**

In `note_list_chunk_editor_screen_test.dart`, add a test that enters `súlyos` into `note-list-item-tags-item-1` and asserts `latest!.listItems.first.tags.single.label == 'súlyos'`.

- [ ] **Step 4: Verify RED**

Run:

```bash
flutter test test/notes_screen_test.dart test/note_document_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart
```

Expected: FAIL because tag UI does not exist.

- [ ] **Step 5: Implement UI**

Implement:

- `NotesScreen` header menu item `Tagek` opens a tag guide/overview explaining direct and inherited tags.
- selected-note menu item `Tagek` opens a note-level tag dialog for the selected document.
- `NoteDocumentEditorScreen` shows typed block tag controls and direct/inherited chips.
- `NoteListChunkEditorScreen` shows a compact tag field per list item.

Use existing Material controls and keep labels concise.

- [ ] **Step 6: Verify GREEN**

Run:

```bash
flutter test test/notes_screen_test.dart test/note_document_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart
```

Expected: PASS.

---

### Task 5: RED/GREEN Flowchart Visual Semantics

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Modify: `lib/src/flowchart/ui/mobile_flowchart_viewer.dart`
- Modify: `test/note_flowchart_editor_screen_test.dart`
- Modify: `test/mobile_flowchart_viewer_test.dart`

**Interfaces:**
- Consumes: existing `NoteFlowchartEdge.fromPortId/toPortId`, `MobileFlowchartEdge.fromPortId/toPortId`, and route helpers.
- Produces: derived port state, orange dashed loop edges, no preview grid, cleaned list/guide views.

- [ ] **Step 1: Write failing editor port state tests**

Add tests for:

- input-only connector uses a teal state key such as `note-flowchart-connector-state-b-in-inputOnly`;
- output-only connector uses an output state key such as `note-flowchart-connector-state-a-out-outputOnly`;
- input+output connector renders an outer outline key `note-flowchart-connector-outer-loop-shared`.

- [ ] **Step 2: Write failing loop style tests**

Add an editor test with edges `A -> B`, `B -> A`. Assert a loop edge anchor/key exists, for example `note-flowchart-loop-edge-edge-back`, and normal edge key remains non-loop.

- [ ] **Step 3: Write failing preview tests**

In `mobile_flowchart_viewer_test.dart`, assert:

```dart
expect(find.byKey(const ValueKey('mobile-flowchart-canvas-grid')), findsNothing);
expect(find.byKey(const ValueKey('mobile-flowchart-loop-edge-edge-back')), findsOneWidget);
```

Add list cleanup and guide cleanup assertions:

```dart
expect(find.text('Start'), findsOneWidget);
expect(find.text('Légzési elégtelen? Igen'), findsOneWidget);
expect(find.text('Légzési elégtelen?'), findsNothing);
expect(find.byKey(const ValueKey('mobile-flowchart-guide-next')), findsNothing);
expect(find.byKey(const ValueKey('mobile-flowchart-guide-answer-igen')), findsOneWidget);
expect(find.byKey(const ValueKey('mobile-flowchart-guide-answer-nem')), findsOneWidget);
```

- [ ] **Step 4: Verify RED**

Run:

```bash
flutter test test/note_flowchart_editor_screen_test.dart test/mobile_flowchart_viewer_test.dart
```

Expected: FAIL.

- [ ] **Step 5: Implement derived port state**

Add helper types/functions in editor and viewer:

```dart
enum _PortUsageState { unused, inputOnly, outputOnly, inputAndOutput }
```

Derive state from actual edges:

```dart
hasIncoming = edges.any((edge) => edge.toNodeId == node.id && edge.toPortId == port.id);
hasOutgoing = edges.any((edge) => edge.fromNodeId == node.id && edge.fromPortId == port.id);
```

Use teal for input-only, purple for output-only, and outer circle for input+output.

- [ ] **Step 6: Implement loop-closing edge detection**

Add graph helper `_edgeClosesLoop(edge, edges)` that checks whether `edge.toNodeId` already has a path back to `edge.fromNodeId` through other edges. Render that edge orange and dashed in editor and preview. Keep normal edge color unchanged.

- [ ] **Step 7: Remove preview grid only**

Remove `_GridPainter` from `_FlowchartCanvasView`. Keep `note-flowchart-grid` and `_FlowchartGridPainter` in `NoteFlowchartEditorScreen`.

- [ ] **Step 8: Clean list and guide views**

Change list view to render path step rows:

- start row: `Start`;
- answered decision row: `Question? Answer`;
- process row only when it is meaningful content, not the same decision being answered next;
- loop reference row for cycles.

Change guide view so branch buttons appear directly under the current question, and after an answer the next decision and its branch buttons appear without a mandatory next button.

- [ ] **Step 9: Verify GREEN**

Run:

```bash
flutter test test/note_flowchart_editor_screen_test.dart test/mobile_flowchart_viewer_test.dart
```

Expected: PASS.

---

### Task 6: Integration Verification, Commit, Push, APK

**Files:**
- Modify only files touched by previous tasks.

**Interfaces:**
- Consumes: all changes from Tasks 1-5.
- Produces: pushed branch, green GitHub Actions run, debug APK link.

- [ ] **Step 1: Format and analyze**

Run:

```bash
dart format lib/src/rag/retrieval/note_aware_local_retriever.dart lib/src/notes/models/note_document.dart lib/src/notes/data/note_chunk_builder.dart lib/src/notes/ui/note_document_editor_screen.dart lib/src/notes/ui/note_list_chunk_editor_screen.dart lib/src/notes/ui/notes_screen.dart lib/src/notes/ui/note_flowchart_editor_screen.dart lib/src/flowchart/ui/mobile_flowchart_viewer.dart test/note_aware_local_retriever_test.dart test/note_document_test.dart test/note_document_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart test/notes_screen_test.dart test/note_flowchart_editor_screen_test.dart test/mobile_flowchart_viewer_test.dart
```

If local Dart is unavailable, rely on GitHub Actions formatting/analyze/test output and fix failures there.

- [ ] **Step 2: Run focused tests**

Run locally if available:

```bash
flutter test test/note_aware_local_retriever_test.dart test/note_document_test.dart test/note_document_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart test/notes_screen_test.dart test/note_flowchart_editor_screen_test.dart test/mobile_flowchart_viewer_test.dart
```

- [ ] **Step 3: Run full tests**

Run locally if available:

```bash
flutter test
```

- [ ] **Step 4: Commit**

Use concise commits:

```bash
git add docs/superpowers/plans/2026-06-17-djinn-tags-search-flowchart-plan.md
git commit -m "docs: plan tags search and flowchart implementation"
git add test/note_aware_local_retriever_test.dart test/note_document_test.dart test/note_document_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart test/notes_screen_test.dart test/note_flowchart_editor_screen_test.dart test/mobile_flowchart_viewer_test.dart
git commit -m "test: cover scoped tags and flowchart semantics"
git add lib/src test
git commit -m "feat: add scoped tags search and flowchart semantics"
```

- [ ] **Step 5: Push and monitor CI**

Run:

```bash
git push origin feature/knowledge-ocr-inspector
```

Then monitor GitHub Actions until the branch run completes.

- [ ] **Step 6: Report APK link**

After CI publishes the debug APK, report:

```text
https://github.com/elizerpist/djinn/releases/download/debug-latest/djinn-debug.apk
```

Only report the APK link after verifying the latest workflow run uses the final commit SHA.

---

## Self-Review

- Spec coverage: retrieval specificity, tagless quality, typed tags, visible UI, flowchart point states, loop styling, preview grid removal, list cleanup, guide cleanup, tests, push/build/APK are covered by Tasks 1-6.
- Placeholder scan: no TBD/TODO/later placeholders remain.
- Type consistency: `NoteKnowledgeTag`, `NoteKnowledgeTagTypes`, `_PortUsageState`, and loop helpers are introduced before later tasks rely on them.
