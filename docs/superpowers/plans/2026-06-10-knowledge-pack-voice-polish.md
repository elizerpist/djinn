# Knowledge Pack Voice Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the Tudastar, chunk package, voice, TTS, and citation UX so visible controls are functional and no placeholder menu items remain.

**Architecture:** Keep the working PDF chunking pipeline intact, but add a user-selectable chunking profile that only changes extraction instructions. Replace loose chunk JSON export/import with a ZIP-based `.djinnpack` package containing PDF bytes, chunk metadata, embeddings, and document metadata. Move voice mode choice into chat gestures, keep TTS voice selection in settings, and make assistant responses/citations actionable through callbacks.

**Tech Stack:** Flutter, Dart, ObjectBox, FilePicker, archive ZIP package, speech_to_text, flutter_tts, pdfrx, existing GitHub Actions APK workflow.

---

## Non-Negotiable Checklist

- [x] No visible disabled placeholder menu item remains.
- [x] Every visible button/menu item either performs its action or is removed.
- [x] No placeholder-only debug log remains behind a production menu action.
- [x] Folder pills are left-aligned on every screen width.
- [x] Tudastar no longer shows the green `Helyi ObjectBox tudastar` title.
- [x] PDF rows do not show a sync icon or any per-row action button.
- [x] Non-selected global menu has only working actions.
- [x] Selected-PDF menu has only working actions.
- [x] Selected-PDF menu no longer contains `Chunk csomag import`.
- [x] Global pack import works without a preselected PDF.
- [x] Global knowledge export writes a `.djinnpack` containing PDF + chunks.
- [x] Pack import writes/restores PDF into the app internal `knowledge_pdfs` directory.
- [x] If pack import sees the same PDF hash, the app asks whether to update the existing document or create a duplicate.
- [x] Duplicate import behavior follows user choice `3`: show a real update-existing / create-duplicate decision instead of silently choosing.
- [x] Pack export/import is a single `.djinnpack` bundle; users never need to manually match loose chunk JSON to a PDF.
- [x] Chunking mode exists in settings as `Kompakt`, `Normal`, `Reszletes`.
- [x] Chunking mode is persisted and used by Gemini/OpenAI extraction instructions.
- [x] Chat mic single tap starts conversation mode.
- [x] Chat mic long press starts one-shot push-to-talk.
- [x] Voice mode selector is removed from settings.
- [x] TTS locale/voice selection remains in settings as a dropdown.
- [x] Every assistant answer has a play button.
- [x] Citation/excerpt rows are tappable and open the referenced excerpt.
- [x] STT normalizes Android locale IDs, e.g. `hu-HU` to `hu_HU`.
- [x] If STT language is unsupported, it falls back to the platform/system locale and logs that fallback.
- [x] Existing working chunking behavior remains green.
- [ ] Commit and push branch.
- [ ] Run exactly one online debug APK build after all tests pass.

## Current Root Causes

- Folder pills appear centered because `_FolderPillBar` is a fixed-width child in a `Column` with default center cross-axis alignment. The fix is to make the pill bar fill width.
- `Chunk csomag import` and `Tudastar export` are disabled because no global action is implemented.
- Chunk export fails with `PathNotFoundException` because Android SAF-style `/document/primary:...` paths are treated as normal filesystem paths.
- PDF row sync button remains because `KnowledgeDocumentRow` still renders `_ProcessAction`.
- `error_language_not_supported` appears because STT uses `hu-HU`, while `speech_to_text` locale ids are often underscore-form or platform-provided ids.
- Assistant play/citation open actions are missing because `ChatBubble` receives no callbacks.

## Files

- Modify `lib/src/settings/models/app_settings.dart`: add `ChunkingMode` constants and persisted `chunkingMode`.
- Modify `lib/src/settings/data/app_settings_repository.dart`: persist/load `chunkingMode`.
- Modify `lib/src/local_store/entities.dart`: add ObjectBox field for chunking mode.
- Regenerate `objectbox.g.dart` and `lib/objectbox-model.json`.
- Modify `lib/src/settings/ui/settings_screen.dart`: add chunking mode dropdown, add TTS locale dropdown, remove voice mode selector.
- Modify `lib/src/ai/ai_client.dart`: pass chunking mode to extraction.
- Modify `lib/src/openai/openai_http_client.dart`: adapt extraction instruction per chunking mode.
- Modify `lib/src/google/gemini_http_client.dart`: adapt extraction instruction per chunking mode.
- Modify `lib/src/knowledge/data/document_processing_service.dart`: pass settings chunking mode.
- Create `lib/src/knowledge/models/knowledge_pack.dart`: pack manifest model.
- Create `lib/src/knowledge/data/knowledge_pack_service.dart`: ZIP encode/decode `.djinnpack`.
- Modify `lib/src/knowledge/data/knowledge_document_repository.dart`: expose document lookup/import helpers for JSON tests.
- Modify `lib/src/knowledge/data/objectbox_knowledge_repository.dart`: pack export/import repository operations.
- Modify `lib/src/knowledge/data/objectbox_knowledge_document_repository.dart`: expose pack operations to UI.
- Modify `lib/src/knowledge/ui/knowledge_base_screen.dart`: working global import/export, duplicate dialog, no placeholders, no green title.
- Modify `lib/src/knowledge/ui/knowledge_document_row.dart`: remove sync/action area.
- Modify `lib/src/voice/speech_adapter.dart`: normalize/fallback locale handling.
- Modify `lib/src/voice/voice_controls.dart`: single tap conversation, long press push-to-talk.
- Modify `lib/src/chat/ui/message_composer.dart`: wire new voice gestures.
- Modify `lib/src/chat/ui/chat_screen.dart`: play callback and citation open callback.
- Modify `lib/src/chat/ui/chat_bubble.dart`: play button and tappable citation rows.
- Modify tests in `test/knowledge_base_screen_test.dart`, `test/knowledge_document_repository_test.dart`, `test/chunk_package_service_test.dart`, `test/settings_*`, `test/document_processing_service_test.dart`, `test/speech_adapter_test.dart`, `test/message_composer_test.dart`, `test/chat_bubble_test.dart`, `test/chat_screen_voice_test.dart`.

---

## Task 1: Settings and Chunking Profile

- [ ] Write failing settings model/repository tests proving default `chunkingMode == normal`, copyWith persists `compact/detailed`, and repository round-trips it.
- [ ] Write failing settings screen test proving `Chunkolasi mod` dropdown exists and autosaves `Reszletes`.
- [ ] Add `ChunkingModes.compact`, `normal`, `detailed` constants and `chunkingMode` to `AppSettings`.
- [ ] Add `chunkingMode` to `AppSettingsEntity`; regenerate ObjectBox model/code.
- [ ] Add dropdown in AI section under model selectors.
- [ ] Run targeted settings tests green.

## Task 2: Chunking Profile Reaches Extraction

- [ ] Write failing `document_processing_service_test` proving `settings.chunkingMode` is passed to `extractDocument`.
- [ ] Update `AiClient.extractDocument` signature with `chunkingMode`.
- [ ] Update fake clients and real clients.
- [ ] Change OpenAI/Gemini extraction instruction builder:
  - compact: fewer, larger chunks, keep sections intact.
  - normal: current balanced behavior.
  - detailed: smaller, more precise chunks, preserve list/table context.
- [ ] Run processing and AI client tests green.

## Task 3: Tudastar UI Cleanup and Menus

- [ ] Write failing UI tests:
  - no `Helyi ObjectBox tudastar` title;
  - folder pill bar starts near the left edge;
  - PDF rows have no sync icon/action button;
  - global menu has no disabled items;
  - selected menu has no disabled items;
  - selected menu does not show chunk import.
- [ ] Make `_FolderPillBar` full width and left aligned.
- [ ] Remove green title block.
- [ ] Remove `_ProcessAction` from row and constructor.
- [ ] Keep sync only in selected header menu.
- [ ] Remove placeholder disabled selected-menu items until real features exist.
- [ ] Run `knowledge_base_screen_test.dart` green.

## Task 4: `.djinnpack` Export/Import

- [ ] Write failing pack service unit test: pack includes `manifest.json`, `document.pdf`, `chunks.json`; decode returns same PDF bytes and chunks.
- [ ] Write failing repository test: export ready document to pack; import pack as new document; imported doc is ready and has same chunks.
- [ ] Write failing UI test: global `Tudastar export` triggers pack export for visible documents.
- [ ] Write failing UI test: global `Chunk csomag import` imports a pack without selected PDF.
- [ ] Write failing UI test: duplicate hash asks update-or-duplicate and respects user choice.
- [ ] Implement `KnowledgePack` manifest and `KnowledgePackService` with ZIP via `archive`.
- [ ] Implement repository methods for export/import packs.
- [ ] Use `FilePicker.saveFile(bytes: ...)` for export and do not manually write SAF `/document/...` paths.
- [ ] Use `FilePicker.pickFiles(withData: true)` for import; decode bytes first.
- [ ] Import PDF bytes through `PdfImportService.copyPdfBytes` so PDF lands inside app internal storage.
- [ ] Active folder receives imported pack documents.
- [ ] Run pack and UI tests green.

## Task 5: Voice Input Behavior

- [ ] Write failing `speech_adapter_test` proving `hu-HU` is normalized to `hu_HU`.
- [ ] Write failing `speech_adapter_test` proving `error_language_not_supported` retries with system locale once.
- [ ] Write failing `message_composer_test`: mic tap sends conversation transcript and speaks response; long press sends one-shot push-to-talk without enabling auto reply.
- [ ] Extend speech engine abstraction with locale list/system locale if needed.
- [ ] Add locale normalization and one retry on unsupported locale.
- [ ] Replace voice reply toggle with mic gesture semantics:
  - tap: conversation.
  - long press: push-to-talk.
- [ ] Remove settings voice mode selector and stop persisting mode changes from settings.
- [ ] Run voice tests green.

## Task 6: TTS Settings and Assistant Play Button

- [ ] Write failing settings screen test proving TTS locale dropdown autosaves `hu-HU`/`en-US`.
- [ ] Write failing chat bubble test proving assistant message shows play button and user message does not.
- [ ] Write failing chat screen test proving tapping assistant play speaks that message.
- [ ] Add fixed TTS locale dropdown in settings.
- [ ] Add play callback to `ChatBubble`.
- [ ] Wire `_speakAssistant(message.text)` from `ChatScreen`.
- [ ] Run TTS/chat tests green.

## Task 7: Citation/Excerpt Open

- [ ] Write failing chat bubble test proving citation row is tappable.
- [ ] Write failing chat screen test proving tapping citation opens a source excerpt dialog.
- [ ] Add `onCitationTap` to `ChatBubble`.
- [ ] Show a bottom sheet/dialog with citation title, page, section, excerpt, and source id.
- [ ] If later PDF page navigation is available, replace dialog with PDF page jump; for this task excerpt open is the working behavior.
- [ ] Run citation tests green.

## Task 8: Full Verification, Commit, Push, Build

- [ ] Run `dart format` on touched Dart files.
- [ ] Run `flutter analyze` in proot Ubuntu.
- [ ] Run full `flutter test` in proot Ubuntu.
- [ ] Run `git diff --check`.
- [ ] Commit with a clear message.
- [ ] Push `feature/knowledge-ai-voice-upgrades`.
- [ ] Trigger exactly one `android-native-build.yml` workflow run.
- [ ] Verify GitHub Actions success and `debug-latest/djinn-debug.apk` asset.
