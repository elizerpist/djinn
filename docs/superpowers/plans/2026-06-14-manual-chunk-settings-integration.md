# Manual Chunk + Settings Submenus Implementation Plan

## Scope

- Fix the local chunking menu bug where AI-ready PDFs show `Lokális újrachunkolás` even when the user needs the first local chunking run.
- Add manual chunking as a first-class extraction pipeline that appends to existing AI/local chunks instead of replacing them.
- Add a user-facing manual chunk editor from the selected PDF menu.
- Show manual chunks separately in `Kinyert chunkok`, while keeping AI, local, and comparison views.
- Redesign `Beállítások` into tappable section cards that open section subpages.
- Add an `About / működési elv` card explaining chunking, OCR, embeddings, vector search, graph, audit, manual chunks, and the local ObjectBox architecture.

## Tests First

- Keep and complete the regression test that AI-ready PDFs still show `Lokális chunkolás`.
- Add repository coverage that manual chunks append without deleting AI or local chunks.
- Add UI coverage that the selected PDF menu exposes `Kézi chunkolás` and the editor saves a manual chunk.
- Update settings tests to navigate into submenu cards before interacting with controls.

## Implementation

- Extend `LocalExtractionPipeline` with `manual`.
- Add append-safe local chunk saving through `saveLocalChunks(..., replaceExisting: false)`.
- Add `ManualChunkEditorScreen` with type/source/page/title/content fields and real save behavior.
- Add a `Kézi chunkolás` selected-document menu action for single PDFs.
- Split extracted knowledge tabs into `AI`, `Lokális`, `Manuális`, and `Összehasonlítás`.
- Replace the flat settings body with `_SettingsMenuCard` entries and `_SettingsSectionPage` routes.
- Move the existing section controls into section builders, preserving autosave and keys.
- Add a long-form About page with concrete Hungarian explanations.

## Verification

- Run `git diff --check`.
- Run focused Dart/Flutter tests if the local environment allows it.
- If local Flutter tooling fails on Termux/ARM64, commit and push, then use GitHub Actions for the real build/test signal.
