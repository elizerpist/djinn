# Universal Notes Document Design

## Goal

The `Jegyzetek` area should behave like a user-owned document library, not like a list of separate chunk types. A note is one mixed document that can contain free text, headings, lists, tables, and flowcharts. The note can later be chunked and indexed just like an imported PDF.

## Current Problem

The current implementation models a note as `NoteItemType.text`, `NoteItemType.table`, or `NoteItemType.flowchart`. That is too narrow. It forces the user to choose a note type before writing, makes the list cards behave like chunk cards, and prevents one note from containing multiple content forms.

The requested behavior is different:

- the notes menu contains compact note boxes, visually and behaviorally close to PDF boxes;
- a slide-up card is used for create/edit entry work;
- inside that slide-up card, the user chooses a note name and sees a body preview box;
- the full editor is opened separately when real editing is needed;
- one note can contain mixed blocks;
- notes can be chunked, audited, indexed, searched, moved between folders, and deleted similarly to PDFs.

## Data Model

`NoteItem` remains the top-level library item for compatibility, but its meaning changes to "note document". The top-level `type` should no longer drive UX. New code should treat all notes as mixed documents. Legacy `type` is kept only for migration and backward compatibility.

Each note stores a block document in `payloadJson`:

```json
{
  "schemaVersion": 1,
  "type": "document",
  "blocks": [
    {"id":"b1","type":"heading","level":1,"text":"COPD kiváltó okok"},
    {"id":"b2","type":"paragraph","text":"Szabad szöveges bekezdés."},
    {"id":"b3","type":"listItem","level":0,"text":"Infekciók"},
    {"id":"b4","type":"listItem","level":1,"text":"Virális vagy bakteriális fertőzés"},
    {"id":"b5","type":"table","title":"Dózisok","rows":[["Elem","Érték"],["SpO2 cél","88-92%"]]},
    {"id":"b6","type":"flowchart","title":"Ellátási algoritmus","nodes":[],"edges":[]}
  ]
}
```

`plainText` remains a derived searchable preview/export field. It is generated from blocks and must include the meaningful text from paragraphs, headings, lists, table cells, and flowchart node/edge labels.

Legacy notes are migrated in memory on load:

- `text` notes become one paragraph block;
- `table` notes become a table block when rows can be parsed, otherwise a paragraph block;
- `flowchart` notes become a flowchart-like text block when structured graph data is not available.

## UI Model

The notes menu should show note boxes, not content-type cards. A note box contains:

- title;
- compact status chips;
- short derived preview;
- updated date / folder / indexing status where available;
- no inline full editor.

The create/edit slide-up card contains:

- name field;
- folder selector when folders exist;
- body preview box;
- actions: `Mégse`, `Teljes editor`, `Mentés`.

The slide-up body preview renders the current document summary. It is not the heavy editor.

## Full-Screen Editors

There is one full-screen note document editor. It is a free writing surface first, not a forced outline editor. It must support:

- normal paragraphs;
- headings;
- list items;
- indent/outdent for hierarchy;
- adding a table block;
- adding a flowchart block;
- opening a table block in a full-screen table editor;
- opening a flowchart block in the full-screen grid/canvas flowchart editor.

Table editing is full screen and supports at least:

- edit cell text;
- add row;
- add column;
- delete row or column where possible;
- save back into the parent note block.

Flowchart editing reuses the existing grid/canvas editor direction. It must preserve and edit both `Igen` and `Nem` branches for decision nodes. Flowchart editing should not be squeezed into a card.

## Chunking Notes

A note can be chunked like a PDF. The chunker reads blocks and emits local/manual note chunks:

- paragraph/heading/list sequences become text/list chunks;
- table blocks become table chunks and optionally row chunks;
- flowchart blocks become flowchart chunks with structured graph payload plus a plain text summary;
- chunk group metadata should keep related blocks together when they are logically part of one section.

The first implementation may keep the chunk output in the notes repository and visible in the note detail/editor rather than fully merging with every PDF chunk view, but it must not be a placeholder. It must produce inspectable chunks from a mixed note.

## Navigation And Folder Rules

Bottom navigation has four entries only:

- `Jegyzetek`;
- `Tudástár`;
- `Chat`;
- `Beáll.`.

`Keresés` is removed from the bottom nav.

The notes folder bar should visually match the PDF folder bar: horizontal, left aligned, white background, compact `ChoiceChip`s. The `Összes` pill is shown only when there is at least one note; an empty note library may still show user folders, but should not show a meaningless `Összes` pill.

The notes FAB should match the PDF import FAB size and style: a normal circular FAB, not an extended FAB.

## Acceptance Criteria

- Creating a note creates one mixed document, not a typed text/table/flowchart note.
- The create/edit slide-up card shows name, folder, preview box, and a full editor action.
- The full editor can save free text with list-like hierarchy.
- The same note can contain a table block and a flowchart block.
- Table blocks open in a full-screen table editor and persist changes.
- Flowchart blocks open in a full-screen grid/canvas editor and persist `Igen`/`Nem` edge labels.
- Notes can be chunked into inspectable chunks.
- Bottom nav has four destinations and no Search button.
- Notes folder bar matches the PDF folder bar styling and alignment.
- Notes FAB matches the PDF FAB size/style.
- Existing notes are still readable after the change.
