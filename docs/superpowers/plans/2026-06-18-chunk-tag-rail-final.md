# Chunk Tag Rail Final Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for independent streams after the RED tests are written, or keep tightly coupled UI edits inline. Use TDD: every production change below starts with a failing test or a documented test update.

**Goal:** Implement the final chunk tag rail redesign, flowchart tag/edit behavior, flowchart preview fixes, RAG branch matching, and chat answer/source cleanup from `docs/superpowers/specs/2026-06-18-chunk-tag-rail-final-design.md`.

**Architecture:** Keep existing note/tag persistence where it can represent the final UX. Extend the model only where required for flowchart branch/port tags. Centralize selected-scope rail behavior and tag text rendering so text/list/table share one interaction contract. Keep flowchart canvas tag feedback separate from text/list/table: canvas uses outlines/line layers, edit cards use text highlight/underline.

**Tech Stack:** Flutter/Dart, existing notes and flowchart widgets, ObjectBox/local RAG services, existing widget/unit tests, GitHub Actions for APK build.

## Required Reference Read

- [ ] Read `.superpowers/brainstorm/12103-1781765637/content/text-chunk-two-row-rail-v6.html`
- [ ] Read `.superpowers/brainstorm/12103-1781765637/content/list-chunk-code-derived-rail-v2.html`
- [ ] Read `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-v2.html`
- [ ] Read `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-overflow-v1.html`
- [ ] Read `.superpowers/brainstorm/12103-1781765637/content/flowchart-canvas-tag-system-v4.html`

## Phase 1: Baseline Audit

- [ ] Inspect current tag model and UI entry points in `lib/src/notes/models/note_document.dart`, `note_tag_pills.dart`, `tag_manager_sheet.dart`, and all chunk editors.
- [ ] Inspect current flowchart connector, loop, and preview behavior in `note_flowchart_editor_screen.dart`, `mobile_flowchart_viewer.dart`, and `note_chunk_card.dart`.
- [ ] Inspect current RAG branch matching and answer/source formatting services.
- [ ] Record any model migration risk before changing production code.

## Phase 2: TDD - Shared Tag Rendering And Rail

- [ ] Add failing widget/unit tests for the two-row rail contract:
  - top action row remains visible when bottom pill row is collapsed;
  - bottom row shows `Nincs tag` when empty;
  - per-tag `x` exists;
  - horizontal overflow can scroll inside rows.
- [ ] Add failing tests for primary highlight plus secondary underline rendering:
  - first tag becomes text background;
  - secondary tags create separate underline metadata/layers;
  - no full component background is tag-colored.
- [ ] Implement shared tag text rendering helpers and rail widget.
- [ ] Run focused tests.

## Phase 3: TDD - Text Chunk

- [ ] Add failing tests in `test/note_text_chunk_editor_screen_test.dart`:
  - header title edits chunk name;
  - global tags render removable subheader capsules;
  - selecting tagged or untagged text opens inline two-row rail;
  - tapping highlighted text opens rail without focus border;
  - collapse button closes only bottom pill row;
  - next/previous jumps between tagged units;
  - bottom grey tip remains, but no duplicate tag buttons under content.
- [ ] Implement text selection state, local rail, selected tag removal, next/previous tagged unit navigation, and multi-tag rendering.
- [ ] Run focused text tests.

## Phase 4: TDD - List Chunk

- [ ] Add failing tests in `test/note_list_chunk_editor_screen_test.dart`:
  - no selector dot exists;
  - tap item non-text selects with border only;
  - tap text selects and edits;
  - Enter creates/focuses next item;
  - rail expands the selected list item downward and starts aligned with item text;
  - top row actions include open/close, tag, clear tags, prev, next, outdent, indent, delete;
  - bottom row pills have per-tag remove;
  - tag feedback colors only text;
  - long wrapped text stays in bounds;
  - multiple underlines expand item height and do not overlap wrapped lines;
  - layout mode dropdown switches checkbox/hierarchical mode;
  - hierarchical numbering cascades after indent/outdent/reorder.
- [ ] Implement list header controls, rail, Enter behavior, hierarchical numbering, and cleaned local tag display.
- [ ] Run focused list tests.

## Phase 5: TDD - Table Chunk

- [ ] Add failing tests in `test/note_table_editor_screen_test.dart`:
  - grid has corner head, column heads, row heads, body cells;
  - row heads match cell heights;
  - cells and heads use rounded-square shape;
  - no tiny cell selector point or top-cell x/plus controls;
  - header add-row/add-column buttons work;
  - column head tap expands header area and pushes cells down;
  - row head tap expands that row;
  - cell tap expands that row;
  - sticky rail actions remain visible after horizontal scroll to far-right cell;
  - rail rows scroll internally with many actions/pills;
  - row/column poly-tagging applies feedback to every affected cell;
  - removing tag from cell affects only that cell;
  - removing row/column scope tag affects all cells in that scope;
  - row reorder and column reorder keep ghost/original behavior;
  - column resize from cell/header edge changes all cells in that column;
  - pinch zoom out does not exceed base max zoom-in.
- [ ] Implement Excel-style grid, sticky inline rail, poly-tagging behavior, reorder, resize, zoom out, and scoped tag remapping.
- [ ] Run focused table tests.

## Phase 6: TDD - Flowchart Editor And Preview

- [ ] Add failing tests in `test/note_flowchart_editor_screen_test.dart`:
  - no shape selector is present;
  - nodes render rounded boxes only;
  - create buttons are vertical separate FAB-height buttons;
  - zoom controls are in the old top control area;
  - edit card has node-name rail with type buttons;
  - branch cards have name input, separator, rail, side-position actions, and delete where allowed;
  - one plus button adds a new top branch;
  - binary yes/no branches cannot be renamed or deleted;
  - binary new ports are input-only;
  - input-used port cannot later become output;
  - node tags render as canvas outline layers;
  - edge/branch tags render as line layers while arrowhead remains normal;
  - only the last-created loop-closing edge is dashed orange.
- [ ] Add failing tests in `test/mobile_flowchart_viewer_test.dart` and `test/note_chunk_card_test.dart`:
  - preview uses rounded boxes only;
  - preview starts fit-to-view;
  - one-finger gesture leaves parent scroll usable;
  - two-finger gesture pans/zooms preview.
- [ ] Extend tag model if needed for flowchart branch/port scoped tags.
- [ ] Implement edit-card inline tag rails, branch rules, outline/line tag rendering, loop edge detection, preview gestures, and fit-to-view.
- [ ] Run focused flowchart tests.

## Phase 7: TDD - RAG And Chat Source Design

- [ ] Add failing unit tests for branch-value matching:
  - `sulyos=igen` does not match `sulyos ... nem`;
  - `javult=igen` does not match `javult ... nem`;
  - context-only branch match does not create branch-value link.
- [ ] Add failing retrieval tests:
  - `sulyos legzesi elegtelenseg` does not retrieve unrelated `sulyos serult` only by adjective;
  - `sulyos serult legzesi elegtelensege` can retrieve both relevant notes.
- [ ] Add failing answer/source tests:
  - flowchart answer emits `ha X, akkor Y` phrasing;
  - sources collapse to one link per chunk;
  - fullscreen source preview route is invoked by source tap.
- [ ] Implement strict branch-value matching, note-aware multi-note retrieval, structured answer formatting, chunk-level source citations, and fullscreen read-only chunk preview routes.
- [ ] Run focused RAG/chat tests.

## Phase 8: Verification, Commit, Push, Build

- [ ] Run available local non-APK verification commands only.
- [ ] Run Flutter tests locally if the SDK is usable; otherwise document that CI is the source of truth on Termux.
- [ ] Commit with a clear message after tests are green.
- [ ] Push `feature/knowledge-ocr-inspector`.
- [ ] Wait for GitHub Actions `Android native build` to finish.
- [ ] Provide the debug APK link: `https://github.com/<owner>/<repo>/releases/download/debug-latest/djinn-debug.apk`.

## Risk Notes

- Text paragraph-anchored rail may require a richer text editor than a single `TextField`; if so, implement the closest native equivalent and keep the reference behavior in tests.
- Table row/column reorder and resize are high-risk gesture changes; keep implementation scoped to the table editor and preserve tag remapping.
- Flowchart branch/port tags may require a backward-compatible model extension.
- GitHub Actions is mandatory for APK build because Termux/Android ARM64 is not expected to build Flutter APKs locally.
