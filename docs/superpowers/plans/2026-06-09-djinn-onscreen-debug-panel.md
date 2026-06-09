# Djinn Onscreen Debug Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an onscreen debug console for OpenAI login, AI document training, vector retrieval, and flowchart validation, then publish exactly one debug APK through GitHub Releases.

**Architecture:** Follow the existing Exptv2 pattern with a global in-memory `DebugConsole`, a floating terminal button, and a modal log viewer. Keep logs metadata-only: never log API keys, full PDF text, full prompts, or full answer context. Instrument the existing service boundaries where OpenAI, document processing, retrieval, and flowchart validation already happen.

**Tech Stack:** Flutter/Dart, `flutter_test`, ObjectBox-backed Djinn local mode, GitHub Actions, GitHub Releases.

---

### Task 1: Debug Console Surface

**Files:**
- Create: `lib/src/debug/debug_console.dart`
- Create: `lib/src/debug/debug_floating_button.dart`
- Test: `test/debug_console_test.dart`
- Test: `test/debug_floating_button_test.dart`

- [ ] Add tests that `DebugConsole.log()` stores timestamped bounded entries and that the floating button opens a dialog showing the log.
- [ ] Implement a 500-entry in-memory console with `ValueNotifier`, copy, clear, and scrollable read-only output.
- [ ] Add a floating terminal button that opens the dialog.

### Task 2: Wire Debug Surface Into App Shell

**Files:**
- Modify: `lib/main.dart`
- Test: `test/widget_test.dart`

- [ ] Add a test that the app shell contains a debug floating button.
- [ ] Wrap `MainScreen` in a `Stack` and place `DebugFloatingButton` above the app UI.

### Task 3: Add Targeted Runtime Logs

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Modify: `lib/src/knowledge/data/document_processing_service.dart`
- Modify: `lib/src/rag/retrieval/local_retriever.dart`
- Modify: `lib/src/chat/data/local_answer_service.dart`
- Modify: `lib/src/flowchart/data/flowchart_validation_repository.dart`
- Modify: `lib/src/flowchart/ui/flowchart_validation_screen.dart`
- Test: existing focused Flutter tests.

- [ ] Log OpenAI key save/delete/test start/success/failure without logging the key.
- [ ] Log document processing start, extraction chunk count, embedding model/dimensions, saved chunks, and failures.
- [ ] Log local answer guardrails and retrieval/citation outcomes.
- [ ] Log vector retrieval start, limit, result count, source type, score, and rejected flowchart filtering.
- [ ] Log flowchart list loading, opening, node validation, and edge validation.

### Task 4: Single Debug APK Release Workflow

**Files:**
- Modify: `.github/workflows/android-native-build.yml`

- [ ] Keep backend tests, Flutter pub get, analyze, and Flutter tests.
- [ ] Remove release APK build and artifact uploads.
- [ ] Build only `app-debug.apk`.
- [ ] Publish `djinn-debug.apk` to the `debug-latest` GitHub Release using `contents: write`.
- [ ] Echo the direct APK URL: `https://github.com/elizerpist/djinn/releases/download/debug-latest/djinn-debug.apk`.

### Task 5: Verification, Commit, Push, Online Build

**Files:**
- All changed files.

- [ ] Run focused debug tests.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Confirm no local APK build was run.
- [ ] Commit changes.
- [ ] Push `feature/onscreen-debug-panel`.
- [ ] Trigger the GitHub Actions workflow for the pushed branch.
- [ ] Watch the workflow until it succeeds.
- [ ] Verify the `debug-latest` release contains `djinn-debug.apk`.
- [ ] Report the direct APK link.
