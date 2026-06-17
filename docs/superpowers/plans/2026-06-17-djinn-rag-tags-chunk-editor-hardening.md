# Djinn RAG, Tags, And Chunk Editors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix retrieval precision, structured chat sources, persistent scoped tags, and unified tagging UX across text, list, table, and flowchart chunk editors.

**Architecture:** Split the work into retriever correctness, answer/citation presentation, tag persistence, shared editor controls, and per-editor selection/rendering. Retrieval changes must be test-first because the logged failures are subtle and regression-prone. UI changes should reuse shared tag/header widgets so the four editors behave consistently.

**Tech Stack:** Flutter/Dart, existing ObjectBox/local-vector retrievers, existing note document models, existing widget test suite, GitHub Actions for APK builds.

## Global Constraints

- Do not attempt a local Flutter APK build on Termux/Android.
- Use TDD for implementation tasks: write failing tests before production changes.
- Preserve existing user data shape with migration-compatible defaults.
- Do not hardcode respiratory-failure, severe-injury, DO2, VO2, or any other domain-specific medical rules.
- Do not render tag pills inside table cells.
- Do not render tag pills on the flowchart canvas.
- Whole chunk tag capsules are full-opacity colored pills in the subheader.
- Local table and flowchart tag pills render in a selected-element tray outside the dense/infinite content area.

---

## File Structure

- Modify `lib/src/rag/retrieval/note_aware_local_retriever.dart`: query intent, note retention, graph expansion gates.
- Modify `lib/src/chat/data/local_answer_service.dart`: structured answer sections and flowchart wording.
- Modify `lib/src/chat/ui/chat_bubble.dart`: grouped citation links and source preview trigger.
- Modify `lib/src/chat/ui/chat_screen.dart`: request-scoped citations and fullscreen preview route/sheet.
- Modify `lib/src/notes/models/note_document.dart`: tag definitions, scoped tag assignments, serialization.
- Modify `lib/src/notes/ui/tag_manager_sheet.dart`: persistent create/edit/delete, color slots, multi-select assignment.
- Create `lib/src/notes/ui/note_chunk_editor_header.dart`: shared editable title, global tag button, overflow menu.
- Create `lib/src/notes/ui/note_tag_pills.dart`: shared full-opacity tag capsules and local tag tray.
- Create `lib/src/notes/ui/note_tag_markers.dart`: row rail, column rail, cell marker, flowchart marker helpers.
- Modify `lib/src/notes/ui/note_text_chunk_editor_screen.dart`: text selection and range tag rendering.
- Modify `lib/src/notes/ui/note_list_chunk_editor_screen.dart`: list item selection and item tag rendering.
- Modify `lib/src/notes/ui/note_table_editor_screen.dart`: row/column/cell selection, working header add buttons, tag markers.
- Modify `lib/src/notes/ui/note_flowchart_editor_screen.dart`: selectable nodes, external tag tray, vertical FABs, pan/zoom smoothing.
- Test `test/note_aware_local_retriever_test.dart`: retrieval regression coverage.
- Test `test/local_answer_service_test.dart`: structured answer and flowchart wording.
- Test `test/note_document_test.dart`: tag serialization.
- Test `test/note_text_chunk_editor_screen_test.dart`: text range tags.
- Test `test/note_list_chunk_editor_screen_test.dart`: item tags.
- Test `test/note_table_editor_screen_test.dart`: table selection and markers.
- Test `test/note_flowchart_editor_screen_test.dart`: flowchart FABs and selected tag tray.
- Test `test/chat_bubble_test.dart` and `test/chat_screen_voice_test.dart`: grouped citations and fullscreen previews.

## Task 1: Retrieval Regression Tests

**Files:**
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Consumes: existing `NoteAwareLocalRetriever` test helpers.
- Produces: failing tests describing required retrieval behavior before implementation.

- [ ] **Step 1: Add branch polarity regression tests**

Add tests with two sibling edges, one `sulyos=igen` and one `sulyos=nem`. Assert that a severe query returns the positive edge/table row and does not cite the negative edge as supporting branch evidence.

```dart
test('does not match opposite branch polarity siblings', () async {
  final result = await retrieveFor('sulyos legzesi elegtelenseg oxygen');

  expect(result.evidence.map((e) => e.sourceId), contains('edge-sulyos-igen'));
  expect(
    result.evidence.where((e) => e.linkType == 'branch_value').map((e) => e.sourceId),
    isNot(contains('edge-sulyos-nem')),
  );
});
```

- [ ] **Step 2: Add cross-note specificity tests**

Create one note named `Legzesi elegtelenseg` and one named `Sulyos serult`. Assert `sulyos legzesi elegtelenseg` prefers the respiratory note, while `sulyos serult legzesi elegtelensege` can include both.

- [ ] **Step 3: Add follow-up and exhaustive tests**

Cover `DO2` followed by `mashol nem emliti?`, and a list query with `mindent` where item 4 must be included after item 1 matches.

- [ ] **Step 4: Run the targeted tests and confirm failure**

Run: `flutter test test/note_aware_local_retriever_test.dart`

Expected before implementation: at least one new test fails because graph expansion or note gating is too broad or too narrow.

## Task 2: Retrieval Gates And Scope

**Files:**
- Modify: `lib/src/rag/retrieval/note_aware_local_retriever.dart`
- Modify: `test/note_aware_local_retriever_test.dart`

**Interfaces:**
- Produces: request-scoped retrieval result where evidence has note id, chunk id, local score, graph score, link type, and gate reason.

- [ ] **Step 1: Add query intent classification**

Implement a small internal classifier that identifies `isFollowUp`, `isExhaustive`, `isDefinitionIntent`, and `domainHeadTerms`. Keep it generic and term-based.

```dart
class RetrievalQueryIntent {
  const RetrievalQueryIntent({
    required this.isFollowUp,
    required this.isExhaustive,
    required this.isDefinitionIntent,
    required this.domainHeadTerms,
  });

  final bool isFollowUp;
  final bool isExhaustive;
  final bool isDefinitionIntent;
  final Set<String> domainHeadTerms;
}
```

- [ ] **Step 2: Gate branch-value links**

Require key, value, polarity, and local condition context compatibility before `branch_value` evidence is emitted. Opposite-value sibling edges may remain `flowchart` context only.

- [ ] **Step 3: Gate symbol expansion**

Only expand DO2/VO2-style symbols into definitions when `isDefinitionIntent` is true or the query explicitly asks what the symbol means.

- [ ] **Step 4: Keep multi-note candidates longer**

Do not reduce to one note before graph expansion when multiple notes have strong local evidence. Apply note title/tag boosts after local evidence scoring, not as replacement evidence.

- [ ] **Step 5: Run retrieval tests**

Run: `flutter test test/note_aware_local_retriever_test.dart`

Expected: all retrieval regression tests pass.

## Task 3: Structured Answers And Grouped Sources

**Files:**
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/chat/ui/chat_bubble.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `test/local_answer_service_test.dart`
- Modify: `test/chat_bubble_test.dart`

**Interfaces:**
- Produces: grouped citation model keyed by chunk id.
- Produces: answer text sections with flowchart wording in "Ha X, akkor Y" style.

- [ ] **Step 1: Write answer formatting tests**

```dart
test('formats flowchart evidence as conditional sentences', () {
  final answer = service.composeOfflineAnswer([severeFlowchartEvidence]);
  expect(answer.body, contains('Ha'));
  expect(answer.body, contains('akkor'));
  expect(answer.body, isNot(contains('->')));
});
```

- [ ] **Step 2: Write grouped citation UI test**

Render a chat bubble with three flowchart evidence items from the same chunk. Assert one source row is visible, not three.

- [ ] **Step 3: Implement citation grouping**

Group by note id + chunk id + chunk kind. Keep item-level evidence inside the preview payload.

- [ ] **Step 4: Implement fullscreen read-only source preview**

Use the existing chunk renderers where possible. For flowcharts, open a fullscreen scrollable/pannable preview.

- [ ] **Step 5: Run chat tests**

Run: `flutter test test/local_answer_service_test.dart test/chat_bubble_test.dart`

Expected: structured answer and citation grouping tests pass.

## Task 4: Tag Model Persistence

**Files:**
- Modify: `lib/src/notes/models/note_document.dart`
- Modify: `test/note_document_test.dart`

**Interfaces:**
- Produces: `NoteTagDefinition`, `NoteTagAssignment`, and target scope serialization.

- [ ] **Step 1: Write serialization tests**

Test whole chunk, text range, list item, table row, table column, table cell, flowchart node, and flowchart edge tag assignments round-trip through JSON.

```dart
test('round-trips scoped tag assignments', () {
  final document = sampleDocumentWithScopedTags();
  final restored = NoteDocument.fromJson(document.toJson());
  expect(restored.tags.definitions.single.name, 'Sulyos');
  expect(restored.tags.assignments.map((a) => a.target.kind), contains(NoteTagTargetKind.tableCell));
});
```

- [ ] **Step 2: Add model types with defaults**

Add nullable/backward-compatible parsing so existing notes without tags load as empty tag collections.

- [ ] **Step 3: Add helper methods**

Add helpers for assign, unassign, rename, recolor, and selected-target lookup.

- [ ] **Step 4: Run model tests**

Run: `flutter test test/note_document_test.dart`

Expected: old documents and new scoped tag documents both pass.

## Task 5: Shared Tag UI Components

**Files:**
- Create: `lib/src/notes/ui/note_chunk_editor_header.dart`
- Create: `lib/src/notes/ui/note_tag_pills.dart`
- Create: `lib/src/notes/ui/note_tag_markers.dart`
- Modify: `lib/src/notes/ui/tag_manager_sheet.dart`
- Test: existing editor widget tests plus any new focused widget tests near `test/`

**Interfaces:**
- Produces: shared header with editable title, global tag action, optional secondary actions, overflow menu.
- Produces: shared tag pills and selected-element tag tray.

- [ ] **Step 1: Add widget tests for shared header behavior**

Assert the title can enter edit mode, global tag action fires, overflow menu contains selected tagging, selected tag deletion, and chunk deletion.

- [ ] **Step 2: Implement `NoteChunkEditorHeader`**

Expose callbacks:

```dart
typedef NoteChunkTitleChanged = void Function(String value);

class NoteChunkEditorHeader extends StatelessWidget {
  const NoteChunkEditorHeader({
    super.key,
    required this.title,
    required this.onTitleChanged,
    required this.onTagChunk,
    required this.onTagSelection,
    required this.onDeleteSelectedTag,
    required this.onDeleteChunk,
    this.canDeleteSelectedTag = false,
    this.trailingActions = const [],
  });
}
```

- [ ] **Step 3: Implement persistent tag sheet actions**

The tag sheet must create, edit, delete, recall existing tags, and assign multiple selected tags to the provided target.

- [ ] **Step 4: Run shared UI tests**

Run the focused tests for the new widgets.

Expected: header/menu/tag sheet tests pass.

## Task 6: Text Chunk Tagging

**Files:**
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`
- Modify: `test/note_text_chunk_editor_screen_test.dart`

**Interfaces:**
- Consumes: `NoteChunkEditorHeader`, `NoteTagPills`, tag model helpers.
- Produces: text range target assignments and highlighted spans.

- [ ] **Step 1: Test selected text tagging**

Select text in the editor, open overflow menu, tag the selection, and assert the text range is highlighted.

- [ ] **Step 2: Replace local header controls with shared header**

Use editable title, global tag, indent/outdent, and overflow menu in the required order.

- [ ] **Step 3: Render local tag highlights**

Build `TextSpan` or equivalent rich text spans with background color for tagged ranges.

- [ ] **Step 4: Remove redundant bottom tag controls**

Keep only the grey instruction/tip bar below the editor content.

- [ ] **Step 5: Run text editor tests**

Run: `flutter test test/note_text_chunk_editor_screen_test.dart`

Expected: text tagging, title edit, and removed-controls assertions pass.

## Task 7: List Chunk Tagging

**Files:**
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`
- Modify: `test/note_list_chunk_editor_screen_test.dart`

**Interfaces:**
- Produces: selectable list item target and item-level tag pills below selected/tagged items.

- [ ] **Step 1: Test header add-row and selected item tagging**

Assert the header plus button adds an item, a list item can be selected, and overflow tagging adds a pill below that item.

- [ ] **Step 2: Move add action to header**

Remove the bottom add button and the subheader list-name input. The editable header title is the list name.

- [ ] **Step 3: Preserve item drag and indent controls**

Keep existing drag handle and indent/outdent behavior while adding tap selection.

- [ ] **Step 4: Run list editor tests**

Run: `flutter test test/note_list_chunk_editor_screen_test.dart`

Expected: drag controls still exist and item tags render below list items.

## Task 8: Table Selection And Tag Markers

**Files:**
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart`
- Modify: `test/note_table_editor_screen_test.dart`

**Interfaces:**
- Produces: table row, column, and cell selection targets.
- Produces: row rail, column rail, cell marker, and external selected-tag tray.

- [ ] **Step 1: Test header add-row/add-column actions**

Tap header add-row and add-column buttons. Assert row and column counts change.

- [ ] **Step 2: Test row/column/cell selection**

Tap row selector, column selector, and a cell. Assert the selected target kind changes correctly.

- [ ] **Step 3: Test tag marker rendering**

Assign row, column, and cell tags. Assert rails/markers render and no tag pill is inside a cell.

- [ ] **Step 4: Implement selection and marker rendering**

Use color rails/markers in the grid and the shared selected-element tag tray outside the table.

- [ ] **Step 5: Run table editor tests**

Run: `flutter test test/note_table_editor_screen_test.dart`

Expected: header actions, selection, and markers pass.

## Task 9: Flowchart Selection, Tags, And Smoothness

**Files:**
- Modify: `lib/src/notes/ui/note_flowchart_editor_screen.dart`
- Modify: `test/note_flowchart_editor_screen_test.dart`

**Interfaces:**
- Produces: flowchart node/edge selection target and external tag tray.
- Produces: three independent vertical creation FABs.

- [ ] **Step 1: Test vertical FAB layout**

Assert three creation buttons have distinct vertical positions on the right side and are not wrapped by one shared box.

- [ ] **Step 2: Test selected node tag tray**

Select a flowchart box, assign a tag, assert a marker appears on the selected element and the tag pill appears outside the canvas.

- [ ] **Step 3: Move creation actions to vertical FABs**

Place the three create buttons as separate FAB-sized controls on the right.

- [ ] **Step 4: Keep tag pills off canvas**

Render only outline/glow/corner markers on canvas elements. Render pills in the selected-element tray.

- [ ] **Step 5: Reduce pan/drag lag**

Audit pointer handling, repaint boundaries, state updates during drag, and expensive rebuilds. Limit state writes during pointer move to the minimum required visual state.

- [ ] **Step 6: Run flowchart tests**

Run: `flutter test test/note_flowchart_editor_screen_test.dart`

Expected: FAB placement and tag tray tests pass.

## Task 10: Full Regression And Build Handoff

**Files:**
- Modify only if failures reveal missing test coverage.

**Interfaces:**
- Produces: verified branch pushed to GitHub Actions.

- [ ] **Step 1: Run local test suite where available**

Run: `flutter test`

Expected: all tests pass locally if Flutter is available. If Flutter is unavailable in Termux, record the exact failure and rely on GitHub Actions for the build.

- [ ] **Step 2: Check formatting and static issues**

Run: `dart format lib test`

Run: `flutter analyze`

Expected: no new analyzer errors.

- [ ] **Step 3: Commit implementation**

```bash
git add lib test docs/superpowers
git commit -m "feat: harden note retrieval and scoped tag editors"
```

- [ ] **Step 4: Push and watch GitHub Actions**

```bash
git push origin feature/knowledge-ocr-inspector
gh run list --branch feature/knowledge-ocr-inspector --limit 5
gh run watch <run-id> --exit-status
```

Expected: GitHub Actions succeeds and publishes the debug APK.

- [ ] **Step 5: Final report**

Report commit SHA, branch, Actions URL, APK URL, and any tests that could not be run locally.

## Self-Review

- Spec coverage: every checklist section maps to a task above.
- Placeholder scan: no task uses unresolved placeholders.
- Type consistency: shared tag/header components are introduced before editor-specific tasks consume them.
- Execution recommendation: use subagent-driven development by subsystem after this documentation commit is accepted.
