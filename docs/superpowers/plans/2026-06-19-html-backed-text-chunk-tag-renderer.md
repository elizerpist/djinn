# HTML-Backed Text Chunk And Shared Tag Renderer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the broken Flutter overlay text chunk rail with the approved HTML/contenteditable behavior, and make text/list/table tag coloring use primary background plus one underline per secondary tag.

**Architecture:** Text chunk editing moves to an Android WebView that loads a generated local HTML document based on `.superpowers/brainstorm/12103-1781765637/content/text-chunk-two-row-rail-v6.html`. List and table remain Flutter-native but share one tag visual contract so first tag paints the text background and every secondary tag paints its own underline without moving the baseline upward.

**Tech Stack:** Flutter 3.41.4, Dart 3.11.1, `webview_flutter` 4.14.x, existing `NoteBlock` / `NoteTextRangeTag` / `NoteKnowledgeTag` model, Flutter widget tests through Ubuntu.

## Global Constraints

- Do not run local Flutter APK builds on Termux/Android.
- Flutter tests and analyze must run through `proot-distro login ubuntu`.
- Only push after tests pass.
- The approved text reference is `.superpowers/brainstorm/12103-1781765637/content/text-chunk-two-row-rail-v6.html`.
- Text chunk rail must be inserted below the selected line/range inside the editable content, not floated and not painted as a Flutter overlay.
- Native Android text selection toolbar must remain visible above selected text.
- Tapping a tagged text unit opens the rail without extra focus border; tapping non-tagged collapsed text does not open the rail.
- First tag is primary background; every later tag is a separate underline line with that tag color.
- Secondary underline lines must create downward clearance so following content is not overpainted.

---

## Files

- Modify: `pubspec.yaml` to add `webview_flutter`.
- Create: `lib/src/notes/ui/text_chunk_web_editor_html.dart` to generate the approved HTML document from a `NoteBlock`.
- Create: `lib/src/notes/ui/note_text_chunk_web_editor.dart` to host the WebView and bridge JSON changes.
- Modify: `lib/src/notes/ui/note_text_chunk_editor_screen.dart` to use the WebView editor on Android and keep only a non-Android test fallback.
- Create: `lib/src/notes/ui/tagged_text_visual.dart` for reusable primary-background plus stacked-secondary-underline rendering helpers.
- Modify: `lib/src/notes/ui/note_list_chunk_editor_screen.dart` to use the shared tag visual contract and remove list focus border styling if it only indicates selection.
- Modify: `lib/src/notes/ui/note_table_editor_screen.dart` to use the shared tag visual contract for cells and fix remaining resize/scroll regressions after the renderer change.
- Modify: `test/note_text_chunk_editor_screen_test.dart`, `test/note_list_chunk_editor_screen_test.dart`, and `test/note_table_editor_screen_test.dart`.
- Create: `test/text_chunk_web_editor_html_test.dart`.

## Task 1: HTML Generator Contract

- [ ] Write failing tests in `test/text_chunk_web_editor_html_test.dart`:
  - generated HTML contains `contenteditable="true"`;
  - generated HTML contains `line.after(rail)` or equivalent insertion logic;
  - generated HTML encodes a three-tag range as one primary color plus two secondary underline colors;
  - generated JS posts `textChanged` and `rangeTagsChanged` messages through `NoteBridge.postMessage`.
- [ ] Run:
  `proot-distro login ubuntu -- sh -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_web_editor_html_test.dart'`
  Expected: fail because the generator does not exist.
- [ ] Implement `text_chunk_web_editor_html.dart` by adapting the approved HTML reference into a generated body-only editor document.
- [ ] Re-run the same test until it passes.

## Task 2: WebView Text Chunk Host

- [ ] Add `webview_flutter: ^4.14.0` and run `flutter pub get` in Ubuntu.
- [ ] Write failing widget tests that verify `NoteTextChunkEditorScreen` no longer builds `note-text-visual-selection-layout` and exposes a keyed web editor host on Android paths.
- [ ] Implement `note_text_chunk_web_editor.dart` with:
  - `WebViewController`;
  - unrestricted JavaScript;
  - `NoteBridge` JavaScript channel;
  - `loadHtmlString(buildTextChunkWebEditorHtml(...))`;
  - JSON message handling for text/range tag updates and tag sheet requests.
- [ ] Route Android text chunks through the WebView widget. Keep a limited non-Android test fallback so Ubuntu widget tests do not instantiate a platform view.
- [ ] Re-run text chunk tests through Ubuntu.

## Task 3: Shared Tag Visual Contract

- [ ] Write failing tests for a new `TaggedTextVisual` helper:
  - one tag renders primary background only;
  - three tags render two secondary underline layers;
  - underline layers add bottom clearance while keeping text baseline stable.
- [ ] Implement `tagged_text_visual.dart` with deterministic keys for primary highlight and secondary underline layers.
- [ ] Replace list/table `_tagged...TextStyle` helpers with the shared contract where possible.
- [ ] Re-run list/table focused tests through Ubuntu.

## Task 4: List And Table Integration Fixes

- [ ] Update list tests so item tag rendering expects primary background plus N secondary underline layers, not `TextDecorationStyle.double`.
- [ ] Ensure Enter in list items creates a new row and moves focus into it.
- [ ] Update table tests so cell rendering expects primary background plus N secondary underline layers.
- [ ] Keep table horizontal rail independent from table scroll and keep row/column resize tests green.
- [ ] Re-run:
  `proot-distro login ubuntu -- sh -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/note_list_chunk_editor_screen_test.dart test/note_table_editor_screen_test.dart'`

## Task 5: Verification And Push

- [ ] Run focused tests:
  `proot-distro login ubuntu -- sh -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter test test/text_chunk_web_editor_html_test.dart test/note_text_chunk_editor_screen_test.dart test/note_list_chunk_editor_screen_test.dart test/note_table_editor_screen_test.dart'`
- [ ] Run full analyze:
  `proot-distro login ubuntu -- sh -lc 'cd /data/data/com.termux/files/home/djinn-knowledge-ocr-inspector && /home/flutteruser/flutter/bin/flutter analyze'`
- [ ] If focused tests and analyze are green, commit.
- [ ] Push the branch only after tests pass.
