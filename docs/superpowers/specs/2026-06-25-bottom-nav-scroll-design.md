# Bottom Navigation And Scroll Consistency Design

## Goal

Make bottom navigation switches feel immediate, keep the bottom navigation visible on PDF and note chunk-list screens, keep only chunk editor screens fullscreen, and centralize app-wide overscroll behavior so every scrollable menu matches the Knowledge PDF list feel.

## Root Cause

The main shell currently lazily creates destination bodies during the same `setState` that starts the destination FAB `AnimatedSwitcher`. On a cold tab switch, the app may build a whole Notes or Knowledge subtree while animating the FAB.

PDF chunk lists currently open with `Navigator.of(context).push(...)` from `KnowledgeBaseScreen`, and note chunk lists currently open as `NoteEditorRoute` from `NotesScreen`. Both are pushed above the entire main shell, so the bottom navigation is hidden.

The Knowledge PDF list uses the ambient Material scroll behavior. Several other menu/list screens override that with `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`, which allows a larger iOS-style rubber-band motion and makes overscroll inconsistent.

## Requirements Checklist

| ID | Source Instruction | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| NAV-01 | User: bottom navigation switch is not smooth/immediate and FAB animation janks on app entry | `lib/src/chat/ui/main_screen.dart` | Destination bodies/navigators are stable before first destination switch; switching tabs changes selected index/FAB state without constructing the destination body in the tap handler | Widget test for eager/stable destination shell plus targeted manual code inspection | DONE |
| NAV-02 | User: bottom nav should be visible inside PDF chunks list | `lib/src/chat/ui/main_screen.dart`, `lib/src/knowledge/ui/knowledge_base_screen.dart`, `lib/src/knowledge/ui/extracted_knowledge_screen.dart` | Opening a document's extracted PDF chunk list keeps the main `NavigationBar` visible and Knowledge selected | Widget test opening PDF chunks through the main shell | DONE |
| NAV-03 | User: bottom nav should be visible inside note chunks list | `lib/src/chat/ui/main_screen.dart`, `lib/src/notes/ui/notes_screen.dart`, `lib/src/notes/ui/note_editor_route.dart` | Opening a note's chunk list keeps the main `NavigationBar` visible and Notes selected | Widget test opening note chunks through the main shell | DONE |
| NAV-04 | User: only chunk editor menus should be fullscreen | `lib/src/notes/ui/note_editor_route.dart`, editor screen route calls | Opening an individual text/list/table/flowchart chunk editor uses the root navigator and covers the bottom navigation | Widget test from note chunk list to individual chunk editor | DONE |
| SCROLL-01 | User: all scrollable menus should use the same overscroll seen in the Knowledge PDF list, globally centralized | `lib/main.dart`, new shared UI scroll behavior file, list screens with explicit local physics | App-level scroll behavior owns default menu/list physics; menu/list screens no longer opt into local `BouncingScrollPhysics` unless they are specialized canvases/editors | Widget/source tests and `rg "BouncingScrollPhysics"` review | DONE |

## Architecture

`MainScreen` will own a stable shell with one nested `Navigator` per bottom destination. The outer `Scaffold` keeps the `NavigationBar` and destination FAB. Routes that should preserve the bottom navigation are pushed onto the active destination navigator. Routes that must be fullscreen are pushed onto the root navigator.

The Notes and Knowledge screens will receive callbacks for opening chunk-list screens inside their destination navigator. Their existing standalone behavior stays available for tests and direct usage by falling back to their current local push when no callback is provided.

Global scroll behavior will live in a shared UI file and be installed on `MaterialApp.scrollBehavior`. Ordinary menus/lists should rely on the ambient behavior or a shared helper instead of declaring `BouncingScrollPhysics` locally. Specialized editors/canvases can keep explicit physics only when needed for editing behavior.

## Testing Strategy

Use widget tests for the behavioral contract:

- Main shell keeps `NavigationBar` visible after opening PDF chunk lists.
- Main shell keeps `NavigationBar` visible after opening note chunk lists.
- Individual note chunk editor routes cover the bottom navigation.
- Main shell creates stable destination containers before navigation switches.
- App scroll behavior is installed globally and target menu/list screens no longer expose local `BouncingScrollPhysics`.

Run targeted Flutter tests and `flutter analyze` inside Ubuntu proot. APK builds are not run locally on Termux; the final branch push triggers GitHub Actions.

## Verification Notes

- `flutter analyze`: PASS.
- Targeted navigation/scroll tests: PASS for `test/main_screen_navigation_test.dart`, `test/notes_screen_test.dart`, `test/note_editor_route_test.dart`, `test/extracted_knowledge_screen_test.dart`, `test/widget_test.dart`, and `test/mobile_flowchart_viewer_test.dart`.
- Review-fix coverage: PASS for active-tab system back handling, destination FAB hiding on PDF/note chunk-list routes, and fullscreen text/list/table/flowchart note chunk editors.
- Source review: `rg "BouncingScrollPhysics" lib/src` returns no matches.
- Full `flutter test`: 446 passed, 8 skipped, 1 failed. The failure is the pre-existing dirty `test/knowledge_base_screen_test.dart` case `manual chunk sheet keeps its header pinned above the form`, which was already present in the worktree before this implementation and is not part of the bottom navigation or global scroll behavior changes.
