# Djinn Notes And Chunk Validation Redesign

Date: 2026-06-14

## Goal

Redesign Djinn's bottom navigation and source-review workflow around two
principles:

- User-created notes are first-class knowledge items.
- Chunk validation belongs in the chunk's source context, not in a separate
  audit or validation menu.

The separate `Audit`, `Flow`, or `Validálás` bottom navigation destination
should be removed. Validation remains available, but it is reached from PDF and
note chunk cards through a deliberate long-tap interaction.

## Required Bottom Navigation Direction

The bottom navigation should not expose a standalone audit/validation module.
The target top-level destinations are:

1. `Jegyzetek`
2. `Tudástár`
3. `Chat`
4. `Keresés`
5. `Beállítások`

`Jegyzetek` replaces the earlier `Esetek`, `Forrás`, or `Audit` direction. It
is the place where the user creates and manages manual knowledge items:

- text chunks;
- tables;
- flowcharts.

Manual notes are not attached to PDFs from the creation menu. They are their own
knowledge items.

## Current Context

The current Flutter source still has a drawer-based `MainScreen`, a
`KnowledgeBaseScreen` with PDF rows, and a separate `FlowchartValidationScreen`.
The existing flowchart validation screen lists flowcharts needing review, then
opens an editor where node and edge validation is handled separately.

This redesign changes the product model:

- validation should not require a separate bottom menu;
- flowchart validation should be reachable from the flowchart or chunk card that
  needs review;
- PDF chunks and manual note chunks should use the same card language;
- the user should always understand which source item is being validated.

## User-Visible Success Criteria

1. The bottom navigation no longer has `Audit`, `Flow`, or `Validálás` as a
   separate destination.
2. `Jegyzetek` is the leftmost bottom navigation destination.
3. The `Jegyzetek` screen behaves like the `Tudástár` screen: it has a header,
   top-right three-dot menu, optional folder subheader bar, sorting, selection,
   export, and import actions.
4. The `Jegyzetek` header three-dot menu can show or hide the folder subheader
   bar.
5. The `Jegyzetek` folder subheader is a horizontal bar below the header, not a
   chip group inside note cards.
6. Note cards do not contain folder chips.
7. Note cards use the same chunk-card visual language as PDF chunk cards:
   consistent icons, metadata line, short content preview, status badges, and
   item overflow menu.
8. The `Jegyzetek` FAB always opens the same bottom sheet.
9. The FAB sheet has a top dropdown for selecting what the user wants to create.
10. Changing the dropdown changes the sheet content for text chunk, table, or
    flowchart creation.
11. Manual note creation does not include a `PDF-hez csatolás` action.
12. In PDF and note chunk lists, validation is opened by long-tapping a chunk
    card.
13. Long-tap selects the chunk card and slides up a validation card from the
    bottom.
14. The validation card includes the chunk content itself, editable in place.
15. The validation card includes a note/rejection reason field.
16. The validation card uses a status selector such as `Review`, `Elfogad`,
    `Elutasít` rather than a four-button action grid.
17. Saving validation state controls whether the chunk can be used by RAG and
    citations.

## Scope

In scope:

- Product and UI design for `Jegyzetek`.
- Product and UI design for PDF/manual chunk cards.
- Product and UI design for long-tap validation.
- Definition of validation state semantics.
- Data-model direction for notes, folders, note types, and validation metadata.
- Migration direction away from a standalone audit/validation bottom menu.

Out of scope for this design spec:

- Implementing the Flutter UI.
- Changing ObjectBox schema in code.
- Migrating existing user data.
- Changing the AI extraction pipeline.
- Changing retrieval ranking.
- Building APKs locally on Termux/Android.

## Notes Menu Design

`Jegyzetek` is a library, not a loose creation screen. Its structure mirrors the
knowledge/PDF library so users do not need to learn a second management model.

### Header

The header contains:

- title: `Jegyzetek`;
- search action;
- top-right three-dot overflow action.

The three-dot menu contains:

- `Mappasáv mutatása / elrejtése`;
- `Új mappa`;
- `Rendezés`;
- `Kijelölés`;
- `Export`;
- `Import`.

### Folder Subheader

The folder subheader is a horizontal bar below the header. It is controlled from
the header three-dot menu.

Example folder items:

- `Összes`;
- `Stroke`;
- `Gyógyszer`;
- `Oktatás`;
- user-created folders.

The folder subheader filters the visible note list. It should behave like a
library-level folder selector, not like per-card metadata.

### Note Cards

Note cards must be visually consistent with PDF chunk cards.

Each card shows:

- type icon;
- title;
- metadata line;
- optional content preview;
- status badges;
- three-dot item menu.

Allowed type icons should match the PDF chunk card language:

- text chunk: paragraph/text icon;
- table: table/grid icon;
- flowchart: flowchart/diamond/tree icon.

Note cards must not contain folder chips. Folder belongs to the subheader and
metadata, not the card's primary controls.

## Note Type Isolation

Folders are the primary organizational unit. Types are metadata on note items.

This means:

- folder = topic or workspace;
- type = text, table, or flowchart;
- validation = item status.

Example:

- folder: `Stroke`;
- item 1: text chunk;
- item 2: contraindication table;
- item 3: patient-path flowchart.

The folder may contain mixed types. Type isolation is handled with list tools,
not separate folder trees.

Recommended list tools inside a folder:

- a compact type filter when needed: `Mind`, `Szöveg`, `Táblázat`, `Flow`;
- a sort/group option in the three-dot menu: `Csoportosítás típus szerint`.

The type filter is a list-level control. It should not appear inside note cards.

## Unified FAB Creation Sheet

The `Jegyzetek` FAB always opens the same creation sheet. The sheet changes
internally based on a dropdown at the top.

Top control:

- label: `Mit szeretnél létrehozni?`;
- values:
  - `Szöveges chunk`;
  - `Táblázat`;
  - `Flowchart`.

Common fields:

- title;
- folder;
- validation initial status, defaulting to `Review`;
- optional notes/source comment.

Type-specific content:

- `Szöveges chunk`: multiline text editor.
- `Táblázat`: table editor with rows, columns, and cell content.
- `Flowchart`: flowchart starter with nodes and edges.

The creation sheet must not include `PDF-hez csatolás`. Manual notes are created
as independent knowledge items. Any future relationship between a manual note
and a PDF should be modeled as a separate linking workflow, not as part of the
basic create menu.

## PDF Chunk Card Design

PDF detail should expose chunks in a source-local view. The standalone
validation menu is removed because review belongs inside the source.

Recommended PDF detail structure:

- `PDF`;
- `Chunkok`;
- `Flow`;
- `Keresés`.

The `Chunkok` and `Flow` views use the same card language as `Jegyzetek`.

PDF chunk cards show:

- type icon;
- type and source position, for example `Szöveg · 12. oldal`;
- metadata, for example `AI extraction · módosítva ma`;
- content preview;
- status badges;
- item overflow menu.

Flowchart cards may show aggregate state:

- `Review kell`;
- `Részleges`;
- `Elfogadva`;
- `Elutasítva`;
- node/edge review counts.

## Long-Tap Validation Interaction

Validation is opened by long-tapping a chunk card in either PDF or `Jegyzetek`
contexts.

Interaction:

1. User long-taps a chunk card.
2. The card enters selected state.
3. A validation card slides up from the bottom.
4. The underlying list remains visible behind it so the user keeps source
   context.
5. User edits content and validation metadata in the card.
6. User taps `Mentés` or `Mégse`.

The validation card is not a simple action sheet. It contains the card content
and lets the user edit the content before saving a validation state.

Validation card content:

- item type and source summary;
- editable chunk content;
- note/rejection reason field;
- status selector:
  - `Review`;
  - `Elfogad`;
  - `Elutasít`;
- `Mégse`;
- `Mentés`.

The validation card should not use a four-button action grid. It should not
require a separate `Szerkesztés` button to reveal the content editor.

## Validation State Semantics

Validation controls RAG and citation eligibility.

### Review

`Review` means the item exists but has not been accepted or rejected.

Behavior:

- visible in lists;
- may show `Review kell` badge;
- should not be treated as fully trusted;
- RAG eligibility is disabled by default;
- citation eligibility is disabled by default.

### Elfogad

`Elfogad` means the user accepts the chunk's content as usable knowledge.

Behavior:

- status becomes accepted/validated;
- RAG eligibility is enabled;
- citation eligibility is enabled;
- embedding refresh is allowed when needed;
- the item can appear in chat evidence.

### Elutasít

`Elutasít` means the user rejects the chunk.

Behavior:

- status becomes rejected;
- RAG eligibility is disabled;
- citation eligibility is disabled;
- rejection reason should be stored when available;
- rejected item remains visible as audit/history unless hidden by filters;
- rejected item can be edited later and returned to `Review`.

### Flowchart Validation

Flowcharts are composite items. Node and edge validation can remain separate,
but the UI entry point should be the flowchart card inside the PDF or
`Jegyzetek` context.

Rules:

- a flowchart is fully accepted only when required nodes and edges are accepted;
- a flowchart is partial when some nodes or edges still need review or are
  rejected;
- only accepted nodes/edges are eligible for trusted RAG/citation use;
- rejected nodes/edges remain in the editor with reason/history.

## Data Model Direction

This section describes intent, not implementation code.

Core concepts:

- note folder;
- note item;
- note item type;
- chunk content;
- validation status;
- validation reason/comment;
- RAG eligibility;
- citation eligibility.

Suggested note item fields:

- public id;
- folder id;
- type: text, table, flowchart;
- title;
- content payload;
- validation status;
- validation reason/comment;
- RAG enabled flag or derived RAG eligibility;
- created timestamp;
- updated timestamp.

Suggested folder fields:

- public id;
- title;
- sort order;
- created timestamp;
- updated timestamp.

The implementation may store type-specific payloads as structured JSON or as
separate type-specific entities, but the UI should treat them through one common
note/chunk card interface.

## Migration From Audit/Validation Menu

The existing audit/validation builder should move into `Jegyzetek`.

Migration direction:

- remove the standalone audit/validation bottom menu from the navigation model;
- expose manual creation through the `Jegyzetek` FAB sheet;
- expose PDF extraction review through PDF chunk cards;
- expose flowchart review through flowchart cards inside PDF or `Jegyzetek`;
- keep debug/audit trail as metadata and history, not as a primary navigation
  destination.

## Error Handling

- Failed note load shows a local error state in `Jegyzetek`.
- Failed note save keeps the creation/validation card open and shows an inline
  error.
- Failed validation save keeps the bottom validation card open and does not
  change badges optimistically unless the save succeeds.
- Unknown note type renders as a generic chunk card with a warning badge.
- Unknown validation status falls back to `Review`.
- Folder deletion should not silently delete note items unless the user chooses
  an explicit destructive delete operation.

## Testing Requirements

Future implementation should include tests for:

- `Jegyzetek` appears as the leftmost bottom navigation item.
- Audit/Flow validation is not rendered as a separate bottom navigation item.
- The `Jegyzetek` three-dot menu can show and hide the folder subheader.
- Folder filtering changes the visible notes.
- Note cards use the common chunk card component or equivalent shared card
  contract.
- The FAB opens one unified creation sheet.
- Changing the creation dropdown changes the sheet content.
- The creation sheet has no `PDF-hez csatolás` action.
- Long-tap on a PDF chunk opens the bottom validation card.
- Long-tap on a manual note chunk opens the same validation card pattern.
- The validation card contains editable content without requiring a separate
  edit action.
- Saving `Elfogad` enables RAG/citation eligibility.
- Saving `Elutasít` disables RAG/citation eligibility and stores a reason when
  provided.
- Flowchart partial state is shown when only some nodes/edges are accepted.

## Implementation Boundaries

When this design is implemented, keep work split by ownership:

- navigation shell;
- `Jegyzetek` library screen;
- note folders and note repository;
- shared chunk card component;
- unified creation sheet;
- bottom validation card;
- PDF chunk integration;
- flowchart validation integration.

Do not combine this work with unrelated AI provider settings, voice settings,
chat bubble redesign, or retrieval ranking changes.

No Flutter APK build should be attempted locally on Termux/Android. APK builds
must run online, for example through GitHub Actions.
