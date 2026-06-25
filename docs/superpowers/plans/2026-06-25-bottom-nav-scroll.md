# Bottom Navigation And Scroll Consistency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make bottom navigation switches immediate, keep bottom navigation visible on PDF/note chunk-list screens, keep chunk editors fullscreen, and centralize overscroll behavior.

**Architecture:** `MainScreen` owns stable per-destination nested navigators under one bottom navigation shell. Knowledge and Notes chunk-list opens are routed through destination-level callbacks, while editor routes use the root navigator. A shared scroll behavior installed on `MaterialApp` becomes the app-wide default for menu/list overscroll.

**Tech Stack:** Flutter, Material 3, widget tests, existing in-memory repositories, Ubuntu proot for Flutter commands.

## Global Constraints

- Do not run local Flutter APK builds on Termux/Android; APK builds run through GitHub Actions.
- Run Flutter tests and analysis through Ubuntu proot with `/home/flutteruser/flutter/bin/flutter`.
- Do not revert unrelated dirty worktree changes, including the existing `test/knowledge_base_screen_test.dart` change.
- Use `apply_patch` for manual file edits.
- Keep implementation scoped to navigation shell, chunk-list routing, and scroll behavior.

---

## File Structure

- Modify `lib/src/chat/ui/main_screen.dart`: stable destination navigators, root/fullscreen route boundary, callback wiring, eager destination shell setup.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: add optional extracted-chunk opener callback and use it for list-row/menu opens.
- Modify `lib/src/notes/ui/notes_screen.dart`: add optional note-chunk opener callback and use it for note opens/selection menu opens.
- Modify `lib/src/notes/ui/note_editor_route.dart`: add optional root navigator support for individual chunk editor screens and remove local menu-list bouncing physics.
- Create `lib/src/shared/ui/djinn_scroll_behavior.dart`: central scroll behavior and shared physics constants.
- Modify `lib/main.dart`: install `DjinnScrollBehavior` on `MaterialApp`.
- Modify targeted menu/list screens with local `BouncingScrollPhysics` only where needed to rely on the shared behavior.
- Modify tests in `test/main_screen_navigation_test.dart`, `test/notes_screen_test.dart`, `test/extracted_knowledge_screen_test.dart`, and add/update focused scroll behavior tests.

### Task 1: Main Shell Navigation Contract

**Files:**
- Modify: `test/main_screen_navigation_test.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`

**Interfaces:**
- Produces: destination-level route push helpers in `MainScreen`.
- Consumes: existing `NotesScreenController`, `KnowledgeBaseScreenController`, `appDestinations`.

- [ ] **Step 1: Write failing tests**

Add tests that pump `_mainScreenApp`, assert all four destination containers exist before tapping, open Notes and Knowledge without losing `NavigationBar`, and verify first switches do not create new destination body placeholders.

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/main_screen_navigation_test.dart'
```

Expected: FAIL because the current shell lazily populates `_destinationBodyCache` and chunk-list callbacks do not exist.

- [ ] **Step 3: Implement stable destination navigators**

Replace lazy body cache construction with stable destination entries created in `initState`/`didChangeDependencies`. Each entry has a `GlobalKey<NavigatorState>` and a body widget. The outer shell keeps the current `NavigationBar` and FAB.

- [ ] **Step 4: Run test to verify pass**

Run the same targeted test. Expected: PASS.

### Task 2: PDF Chunk Lists Stay Inside Knowledge Tab

**Files:**
- Modify: `test/main_screen_navigation_test.dart`
- Modify: `lib/src/knowledge/ui/knowledge_base_screen.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`

**Interfaces:**
- Add: `typedef KnowledgeExtractedChunkOpener = FutureOr<void> Function(KnowledgeDocument document);`
- Add: `KnowledgeBaseScreen.onOpenExtractedKnowledge`
- Consume: callback from `MainScreen` to push `ExtractedKnowledgeScreen` on the Knowledge destination navigator.

- [ ] **Step 1: Write failing test**

Create a knowledge document with one extracted item, open the Knowledge tab, tap the document row, and assert both the PDF chunk screen title and `NavigationBar` are visible.

- [ ] **Step 2: Run test to verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/main_screen_navigation_test.dart'
```

Expected: FAIL because `KnowledgeBaseScreen` pushes on the root navigator.

- [ ] **Step 3: Implement callback routing**

Add the optional callback to `KnowledgeBaseScreen`. `_openExtractedKnowledge` calls the callback when present; otherwise it keeps the existing local `Navigator.push` behavior. Wire the callback from `MainScreen` to the Knowledge destination navigator.

- [ ] **Step 4: Run test to verify pass**

Run the same targeted test. Expected: PASS.

### Task 3: Note Chunk Lists Stay Inside Notes Tab, Editors Stay Fullscreen

**Files:**
- Modify: `test/main_screen_navigation_test.dart`
- Modify: `test/notes_screen_test.dart`
- Modify: `test/note_editor_route_test.dart`
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`

**Interfaces:**
- Add: `typedef NoteChunkListOpener = FutureOr<void> Function(NoteItem note);`
- Add: `NotesScreen.onOpenChunkList`
- Add: `NoteEditorRoute.useRootNavigatorForChunkEditors`

- [ ] **Step 1: Write failing tests**

Add a main-shell test where tapping a note opens `NoteEditorRoute` while `NavigationBar` remains visible. Add a note editor test where tapping an individual chunk editor opens a fullscreen editor and the main shell bottom navigation is absent from the top route.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/main_screen_navigation_test.dart test/notes_screen_test.dart test/note_editor_route_test.dart'
```

Expected: FAIL because note chunk lists currently push on the root navigator and chunk editors do not distinguish root versus nested navigator.

- [ ] **Step 3: Implement note routing boundary**

Add `NotesScreen.onOpenChunkList`. `_openEditor(note:)` calls the callback for existing notes when provided. New note FAB creation can still create a note first, then open the chunk list through the same callback. In `MainScreen`, push `NoteEditorRoute` onto the Notes destination navigator and pass `useRootNavigatorForChunkEditors: true`. In `NoteEditorRoute._openBlockEditor`, choose `Navigator.of(context, rootNavigator: true)` when that flag is true.

- [ ] **Step 4: Run tests to verify pass**

Run the same targeted tests. Expected: PASS.

### Task 4: Centralize Scroll Behavior

**Files:**
- Create: `lib/src/shared/ui/djinn_scroll_behavior.dart`
- Modify: `lib/main.dart`
- Modify: `lib/src/chat/ui/main_screen.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Modify: `lib/src/knowledge/ui/extracted_knowledge_screen.dart`
- Modify: `lib/src/notes/ui/notes_screen.dart`
- Modify: `lib/src/notes/ui/note_editor_route.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Modify other ordinary menu/list screens with local `BouncingScrollPhysics` after source review.
- Test: targeted widget/source tests for scroll behavior.

**Interfaces:**
- Add: `class DjinnScrollBehavior extends MaterialScrollBehavior`
- Add: `static const ScrollPhysics menuPhysics = ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`

- [ ] **Step 1: Write failing tests**

Add a test that `MaterialApp` uses `DjinnScrollBehavior`, and targeted widget checks that extracted knowledge and note list scrollables do not expose `BouncingScrollPhysics`.

- [ ] **Step 2: Run tests to verify failure**

Run:

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/main_screen_navigation_test.dart test/extracted_knowledge_screen_test.dart test/notes_screen_test.dart'
```

Expected: FAIL because `DjinnScrollBehavior` does not exist and several screens set local bouncing physics.

- [ ] **Step 3: Implement shared behavior**

Create `DjinnScrollBehavior`, install it in `MaterialApp(scrollBehavior: const DjinnScrollBehavior())`, and remove local `BouncingScrollPhysics` from ordinary menus/lists so the global behavior applies. Keep explicit editor/canvas physics only when the screen needs custom editing gestures.

- [ ] **Step 4: Run tests and source review**

Run the targeted tests and:

```bash
rg "BouncingScrollPhysics" lib/src
```

Expected: remaining matches are only specialized editors/canvases or intentionally documented exceptions.

### Task 5: Final Verification, Checklist Update, Commit, Push

**Files:**
- Modify: `docs/superpowers/specs/2026-06-25-bottom-nav-scroll-design.md`

**Interfaces:**
- Consumes: all previous task outputs.
- Produces: committed branch pushed to GitHub for Actions APK build.

- [ ] **Step 1: Run targeted tests**

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/main_screen_navigation_test.dart test/notes_screen_test.dart test/note_editor_route_test.dart test/extracted_knowledge_screen_test.dart'
```

- [ ] **Step 2: Run analyze**

```bash
proot-distro login ubuntu -- bash -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter analyze'
```

- [ ] **Step 3: Update acceptance checklist**

Mark each implemented requirement `DONE` only after the corresponding test/source verification passes.

- [ ] **Step 4: Commit only relevant files**

Use `git status --short`, avoid unrelated dirty files unless intentionally touched for this feature, then commit with:

```bash
git commit -m "fix: keep chunk lists inside bottom navigation"
```

- [ ] **Step 5: Push branch**

```bash
git push origin feature/tag-sheet-registry-text-markers
```

Expected: GitHub Actions starts a new build for the pushed commit.

## Self-Review

- NAV-01 is covered by Task 1.
- NAV-02 is covered by Task 2.
- NAV-03 and NAV-04 are covered by Task 3.
- SCROLL-01 is covered by Task 4.
- Build/push verification is covered by Task 5.
- No plan step requires local APK builds.
