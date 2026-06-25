# Manual PDF Chunk Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep manual PDF chunking in the viewer after save and make PDF chunk list cards/editors match note chunk behavior through shared UI.

**Architecture:** Extract a shared chunk card interaction widget used by both notes and PDF extracted chunks. Keep manual save inside the viewer by reloading source boxes instead of popping the route. Add focused repository/update adapters so fullscreen PDF chunk editors can persist edits without duplicating note editor layout code.

**Tech Stack:** Flutter, widget tests, existing `KnowledgeDocumentRepository`, existing note chunk editor screens, `pdfrx` PDF viewer, Ubuntu/proot Flutter test/analyze commands.

## Global Constraints

- Do not run local Flutter APK builds on Termux/Android.
- Run Flutter tests and `flutter analyze` via Ubuntu proot.
- Preserve unrelated dirty work, especially the existing unstaged `test/knowledge_base_screen_test.dart` changes unless this task intentionally updates that file.
- Use `apply_patch` for manual file edits.
- Every requirement in `docs/superpowers/specs/2026-06-25-manual-pdf-chunk-flow-design.md` must be `DONE` or explicitly deferred before claiming completion.

---

### Task 1: Manual Chunk Sheet And Save Flow

**Files:**
- Modify: `test/knowledge_base_screen_test.dart`
- Modify: `lib/src/knowledge/ui/manual_chunk_editor_screen.dart`
- Modify: `lib/src/shared/ui/inline_bottom_sheet_card.dart`

**Interfaces:**
- Consumes: existing `ManualChunkEditorScreen`, `InlineBottomSheetCard`, `SourceChunkBoxOverlay`.
- Produces: manual save remains in viewer, saved source box appears, page field removed.

- [ ] **Step 1: Write failing manual flow tests**

Add/adjust widget tests in `test/knowledge_base_screen_test.dart`:

```dart
testWidgets('manual chunk save sheet omits page field and can drag-dismiss', (tester) async {
  final repository = KnowledgeDocumentRepository();
  await _openManualChunkEditor(
    tester,
    repository,
    filename: 'manual-sheet-dismiss.pdf',
  );
  await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Szöveg').last);
  await tester.pumpAndSettle();
  await tester.drag(
    find.byKey(const Key('manual-chunk-selection-layer')),
    const Offset(260, 160),
  );
  await tester.pumpAndSettle();
  await _pumpUntilFound(tester, find.byKey(const Key('manual-chunk-title-field')));

  expect(find.byKey(const Key('manual-chunk-page-field')), findsNothing);

  await tester.drag(
    find.byKey(const ValueKey('inline-bottom-sheet-card')),
    const Offset(0, 180),
  );
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('manual-chunk-title-field')), findsNothing);
  expect(find.byKey(const Key('manual-chunk-new-selection')), findsOneWidget);
});

testWidgets('manual chunk save stays in viewer and prints saved source box', (tester) async {
  final repository = KnowledgeDocumentRepository();
  final document = await _openManualChunkEditor(
    tester,
    repository,
    filename: 'manual-print-box.pdf',
  );
  await tester.tap(find.byKey(const Key('manual-chunk-new-selection')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Szöveg').last);
  await tester.pumpAndSettle();
  await tester.drag(
    find.byKey(const Key('manual-chunk-selection-layer')),
    const Offset(260, 160),
  );
  await tester.pumpAndSettle();
  await _pumpUntilFound(tester, find.byKey(const Key('manual-chunk-title-field')));
  await tester.enterText(find.byKey(const Key('manual-chunk-title-field')), 'Kész szakasz');
  await tester.enterText(find.byKey(const Key('manual-chunk-content-field')), 'Mentett tartalom');
  await tester.tap(find.byKey(const Key('manual-chunk-save')));
  await tester.pumpAndSettle();

  final items = await repository.listExtractedKnowledgeItems(
    document.id,
    pipeline: LocalExtractionPipeline.manual,
  );
  expect(items, hasLength(1));
  expect(find.text('Kézi chunkolás'), findsOneWidget);
  expect(find.byKey(const Key('manual-chunk-title-field')), findsNothing);
  expect(find.byKey(ValueKey('source-chunk-box-${items.single.id}')), findsOneWidget);
  expect(find.byKey(const Key('manual-chunk-new-selection')), findsOneWidget);
});
```

- [ ] **Step 2: Run RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/knowledge_base_screen_test.dart --plain-name "manual chunk save sheet omits page field and can drag-dismiss" --plain-name "manual chunk save stays in viewer and prints saved source box"'
```

Expected: FAIL because page field exists and save pops the route.

- [ ] **Step 3: Implement manual flow**

In `ManualChunkEditorScreen`:

- remove `TextField(key: Key('manual-chunk-page-field'))`.
- make `_save()` use `_pageNumber`.
- replace `Navigator.of(context).pop(true)` with reload/reset:

```dart
await _reloadSourceItems();
setState(() {
  _saving = false;
  _selectionKind = null;
  _selectionRect = null;
  _dragStart = null;
  _dragCurrent = null;
  _errorText = null;
  _boxMode = SourceChunkBoxMode.manual;
});
```

Add state for saved source items and render `SourceChunkBoxOverlay` in the viewer stack.

- [ ] **Step 4: Run GREEN**

Run the same targeted command. Expected: PASS.

### Task 2: Shared Chunk Card Contract

**Files:**
- Create or rewrite: `lib/src/shared/chunks/shared_chunk_card.dart`
- Modify: `lib/src/notes/ui/note_chunk_card.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/note_chunk_card_test.dart`
- Test: `test/extracted_knowledge_screen_test.dart`

**Interfaces:**
- Produces: `SharedChunkCard` with `viewModel`, `expanded`, `leading`, `onOpenEditor`, `onToggleExpanded`, `onEditTags`, action slots, and expanded body.
- Consumes: existing `NoteBlock` and `ExtractedKnowledgeItem` adapters.

- [ ] **Step 1: Write failing PDF card behavior tests**

In `test/extracted_knowledge_screen_test.dart`, add tests that:

- switch to manual chunks;
- tap the expand icon and verify the list scrolls;
- tap the card/icon and verify a fullscreen editor route opens and `NavigationBar` is absent when mounted under the main shell.

- [ ] **Step 2: Run RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/extracted_knowledge_screen_test.dart test/note_chunk_card_test.dart'
```

Expected: FAIL for PDF card editor/scroll behavior before shared card refactor.

- [ ] **Step 3: Implement shared card**

Move the common note-card layout into `SharedChunkCard` while preserving `ValueKey('note-chunk-card-<id>')` through an explicit key prefix. `NoteChunkCard` becomes an adapter that passes a `SharedChunkCardViewModel`. PDF extracted tiles use the same widget with `ValueKey('chunk-card-<id>')`.

- [ ] **Step 4: Run GREEN**

Run the same tests. Expected: PASS.

### Task 3: Fullscreen PDF Chunk Editors

**Files:**
- Create: `lib/src/knowledge/ui/pdf_chunk_editor_route.dart`
- Create: `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart`
- Modify: `lib/src/knowledge/data/knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_repository.dart`
- Modify: `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Test: `test/extracted_knowledge_screen_test.dart`
- Test: `test/main_screen_navigation_test.dart`

**Interfaces:**
- Produces: `PdfChunkEditorRoute` opens the existing note text/list/table/flowchart editor screens fullscreen.
- Produces: repository update method for local extracted chunks preserving source/page/rect.

- [ ] **Step 1: Write failing fullscreen editor tests**

Add tests for text/list/table/flowchart PDF manual chunks. Each taps the PDF chunk card and expects the corresponding note editor screen key:

- `note-text-chunk-editor`
- `note-list-chunk-editor`
- `note-table-zoomable-content`
- `note-flowchart-canvas-editor`

Also verify `NavigationBar` is absent when opened from `MainScreen`.

- [ ] **Step 2: Run RED**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/extracted_knowledge_screen_test.dart test/main_screen_navigation_test.dart'
```

Expected: FAIL because PDF chunks do not open fullscreen editors.

- [ ] **Step 3: Implement adapters and route**

Map `ExtractedKnowledgeItem` to `NoteBlock`:

- text -> paragraph block with `text`.
- list -> list block from lines.
- table -> table block from pipe/semicolon rows.
- flowchart -> flowchart block with a minimal node representation when full graph data is unavailable.

On editor changes, persist text/title/tags/audit state back to the local extracted chunk with the new repository update API.

- [ ] **Step 4: Run GREEN**

Run the same targeted tests. Expected: PASS.

### Task 4: Final Verification And Commit

**Files:**
- Modify: `docs/superpowers/specs/2026-06-25-manual-pdf-chunk-flow-design.md`

**Interfaces:**
- Produces: updated checklist statuses and verification notes.

- [ ] **Step 1: Update checklist statuses**

Mark each requirement `DONE` only after its verification command passes.

- [ ] **Step 2: Run targeted verification**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/knowledge_base_screen_test.dart test/extracted_knowledge_screen_test.dart test/note_chunk_card_test.dart test/main_screen_navigation_test.dart && /home/flutteruser/flutter/bin/flutter analyze'
```

Expected: all targeted tests pass and analyze reports no issues.

- [ ] **Step 3: Commit and push**

Stage only files belonging to this feature. Do not stage unrelated dirty changes.

```bash
git add docs/superpowers/specs/2026-06-25-manual-pdf-chunk-flow-design.md docs/superpowers/plans/2026-06-25-manual-pdf-chunk-flow.md lib/src test
git status --short
git commit -m "fix: align manual pdf chunk flow with notes"
git push origin feature/tag-sheet-registry-text-markers
```

- [ ] **Step 4: Verify GitHub Actions APK build**

Run:

```bash
gh run list --repo elizerpist/djinn --branch feature/tag-sheet-registry-text-markers --limit 5
gh run watch <run-id> --repo elizerpist/djinn --exit-status
gh release view debug-latest --repo elizerpist/djinn --json name,tagName,assets,url
```

Expected: run success and `debug-latest` contains a SHA-named APK for the final commit plus updated `djinn-debug.apk`.

