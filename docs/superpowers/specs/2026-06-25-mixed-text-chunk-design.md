# Mixed Text Chunk Design

## Goal

Create a new mixed text chunk that can hold normal paragraphs, lists, and tables inside one logical chunk. This fixes the current PDF text extraction/editor problem where a selected PDF paragraph becomes hard to read because every text fragment is joined with a newline and the text editor only supports a plain text surface with paragraph indentation.

The existing text, list, and table chunk model must remain readable and editable. This spec adds a new mixed chunk path first; it does not delete legacy chunk types or force-migrate existing content.

## Approval

The user approved this design direction on 2026-06-25 with "ok" after reviewing the proposed approach:

1. Fix PDF text fragment joining so extracted text is readable.
2. Add a new mixed text chunk model.
3. Keep legacy text/list/table chunks compatible.
4. Make list and table capabilities available inside the text chunk editor.
5. Keep selection/action rails above the keyboard, matching the text chunk rail pattern.

## Required References

- Extracted text screenshot: `/storage/emulated/0/Pictures/Screenshots/Screenshot_20260625-124832.png`.
- Raw PDF reference screenshot: `/storage/emulated/0/Pictures/Screenshots/Screenshot_20260625-124857.png`.
- Current text editor: `lib/src/notes/ui/note_text_chunk_editor_screen.dart`.
- Current list editor: `lib/src/notes/ui/note_list_chunk_editor_screen.dart`.
- Current table editor: `lib/src/notes/ui/note_table_editor_screen.dart`.
- Current note model: `lib/src/notes/models/note_document.dart`.
- Current PDF chunk adapter: `lib/src/knowledge/ui/pdf_chunk_note_block_adapter.dart`.
- Current manual PDF region text joiner: `lib/src/knowledge/ui/manual_pdf_region_text.dart`.

## Evidence And Root Cause

The extracted text screenshot shows content like:

```text
I.
Celok:
Az
eljarasrend
celja:
.
az
ellatas
soran
...
```

The raw PDF screenshot shows the same content as a readable document section:

- roman section heading;
- explanatory paragraph;
- bullet list with wrapped lines;
- following paragraph;
- later numbered nested list.

The immediate extraction root cause is `textFromFragmentsInPdfRect` in `manual_pdf_region_text.dart`: it trims each PDF text fragment and joins all fragments with `\n`. If `pdfrx` returns word-level fragments, the app writes one word per line.

The editor root cause is architectural: `NoteTextChunkEditorScreen` stores one plain `text` string plus range tags and paragraph indentation. `NoteListChunkEditorScreen` and `NoteTableEditorScreen` store separate `listItems`, `rows`, and scoped tags. `PdfChunkEditorRoute` converts PDF chunks into one of those legacy editor types, and `pdfChunkTextFromNoteBlock` flattens edits back to a string. That flattening cannot preserve a single logical chunk that contains paragraphs, list items, and tables together.

## Scope

In scope:

- Add a new mixed note block/chunk type that stores ordered content sections.
- Add mixed content section model types for paragraph, list, and table.
- Add a mixed text chunk editor route/screen.
- Reuse existing text, list, and table behavior where possible.
- Add conversion helpers from legacy text/list/table chunks into mixed sections.
- Save new manual/PDF text chunks as the mixed chunk type.
- Fix PDF selected-region text joining so normal lines and paragraphs are readable before they enter the editor.
- Keep old chunks readable and editable through current paths.

Out of scope for this first implementation:

- Deleting `NoteBlockType.listItem` or `NoteBlockType.table`.
- Global migration of existing documents.
- Flowchart integration into the mixed chunk.
- Rich text styling beyond current tags, paragraph indent, list hierarchy, and table controls.
- Pixel-perfect PDF layout reproduction. The target is a logically structured, readable editor layout, not exact PDF typography.

## Requirements Checklist

| ID | Source Instruction | Intended Code Area | Acceptance Condition | Verification Method | Status |
| --- | --- | --- | --- | --- | --- |
| OCR-01 | User: extracted text is unreadable because OCR/PDF text breaks every word onto a new line | `lib/src/knowledge/ui/manual_pdf_region_text.dart` | Selected PDF text joins fragments into readable lines and paragraphs instead of one word per line. | Unit tests with word fragments on same line, bullet lines, and paragraph gaps. | NOT DONE |
| OCR-02 | User expected the first PDF paragraph/list structure from raw PDF | `manual_pdf_region_text.dart`, mixed parser helpers | Bullet markers and numbered markers remain visible and are not separated from their text. | Unit tests from representative first-section fixture text. | NOT DONE |
| MIX-01 | User: "kozos chunk modell az appba" | `lib/src/notes/models/note_document.dart` | A new mixed block type serializes/deserializes paragraph, list, and table sections in order. | `note_document_test.dart` model round-trip tests. | NOT DONE |
| MIX-02 | User: "egyelore uj elem legyen, ne torold a korabbi chunk modellt" | note model, adapters, editors | Existing text/list/table/flowchart blocks still parse, render, edit, index, and export through legacy paths. | Existing regression tests plus targeted compatibility tests. | NOT DONE |
| MIX-03 | User: textchunk should accept lists | mixed editor | Mixed editor can add, edit, delete, indent/outdent, reorder, and tag list items inside the chunk. | Mixed editor widget tests based on current list editor tests. | NOT DONE |
| MIX-04 | User: list behavior must match listchunk | mixed editor list section | List items have draggable cards, dynamic bullets/checkbox/hierarchy behavior, and list hierarchy controls. | Widget tests for drag reorder and hierarchy markers. | NOT DONE |
| MIX-05 | User: tables should integrate into textchunk | mixed editor table section | Mixed editor can add table sections and use current row/column/cell edit, resize, reorder, and scoped tag behavior. | Mixed table widget tests adapted from current table editor tests. | NOT DONE |
| MIX-06 | User: text with explanatory sentences, list, and table should be one logical unit | mixed editor, model plain text | Mixed chunk plain text and indexing preserve the ordered paragraph/list/table content as one chunk. | Model tests for `plainText`, `displayTextForIndexing`, and search metadata. | NOT DONE |
| UX-01 | User: rail should not be inline, it should be above keyboard like textchunk | mixed editor rail | Text, list, and table selection actions in the mixed editor use a keyboard-top rail, not inline action rails inside list/table cards. | Widget tests with `viewInsets.bottom` and selected text/list/table targets. | NOT DONE |
| UX-02 | User: editor layout should satisfy text layout criteria and resemble PDF structure | mixed editor | Mixed editor uses full-width readable content, paragraph spacing, bullet/list indentation, and table blocks without forcing all text into a narrow column. | Widget tests for field/card widths; manual screenshot review. | NOT DONE |
| PDF-01 | User: new behavior should apply after manual PDF text chunk extraction | `manual_chunk_editor_screen.dart`, PDF chunk adapter/repository | Manual PDF text chunks are created as mixed chunks with structured content when possible. | Widget/repository tests that saved manual chunks retain mixed section JSON. | NOT DONE |
| PDF-02 | User wants only 3 effective chunk types going forward | add chunk UI, shared cards | New add/manual creation treats text as the container for paragraphs/lists/tables; legacy list/table creation is no longer primary for new chunks. | Widget tests for FAB/manual sheet options and shared card labels. | NOT DONE |
| COMPAT-01 | Existing PDF chunks store only `text` and `chunkKind` | `pdf_chunk_note_block_adapter.dart`, repository model | Legacy PDF list/table/text chunks can be opened and optionally converted to mixed without data loss. | Adapter tests for text/list/table to mixed conversion. | NOT DONE |
| COMPAT-02 | Existing ObjectBox rows store string text | local storage/repository | Mixed structure is persisted without breaking older string-only chunks. | ObjectBox/in-memory repository tests. | NOT DONE |
| EXPORT-01 | Existing note PDF export supports text/list/table separately | `note_pdf_document_builder.dart` | Mixed chunks export paragraphs, lists, and tables in their stored order. | PDF builder tests for mixed block output. | NOT DONE |
| SEARCH-01 | Existing local retrieval indexes note blocks | note indexing/retrieval | Mixed chunks contribute searchable paragraph/list/table text and metadata. | Retrieval/indexing tests for mixed block content. | NOT DONE |

## Architecture

### New Mixed Content Model

Add a new block type rather than changing the meaning of existing types:

```dart
enum NoteBlockType {
  paragraph,
  heading,
  listItem,
  table,
  flowchart,
  mixed,
}
```

Add an ordered `mixedSections` field to `NoteBlock`. Each section has a stable id, a type, optional title, and type-specific payload.

Recommended model shape:

```dart
enum NoteMixedSectionType {
  paragraph,
  list,
  table,
}

class NoteMixedSection {
  final String id;
  final NoteMixedSectionType type;
  final String? title;
  final String text;
  final List<NoteTextRangeTag> rangeTags;
  final List<NoteTextParagraphStyle> paragraphStyles;
  final List<NoteListItem> listItems;
  final NoteListLayoutMode listLayoutMode;
  final List<List<String>> rows;
  final List<double> tableColumnWidths;
  final List<double> tableRowHeights;
  final List<NoteScopedTagAssignment> scopedTags;
}
```

This deliberately mirrors the existing fields instead of inventing a second list/table model. That keeps legacy conversion straightforward and avoids losing current capabilities.

`NoteBlock` keeps block-level `tags`, `searchContext`, `searchRole`, and `searchAliases`. Section-level range/list/table scoped tags stay inside sections.

### Persistence

For notes, `NoteBlock.toJson()` stores `type: "mixed"` and `mixedSections`.

For PDF/manual chunks, the repository currently stores the display text and chunk kind. Add a structured payload field in the local chunk path. Preferred first step:

- add `structuredContentJson` to `LocalChunk`, `ExtractedKnowledgeItem`, and `DocumentChunkEntity`;
- keep `text` as the flattened display/indexing fallback;
- set `chunkKind` to a new `mixed` kind or keep it as `text` while `structuredContentJson` marks the mixed payload.

Because the user wants only three effective types going forward, the UI should present this as "Szoveg" with embedded list/table tools. The storage can still use a clear wire value such as `mixed_text` to distinguish new structured text from legacy plain text.

### Mixed Editor

Create `NoteMixedTextChunkEditorScreen` instead of enlarging the already-large text/list/table editor files directly.

The mixed editor owns:

- section order;
- active section id;
- active selection target;
- keyboard-top rail state;
- block-level title/tags.

It renders ordered section widgets:

- paragraph section: based on current text editor text field/range tag behavior;
- list section: based on current list item row/card behavior;
- table section: based on current table grid behavior.

The current list/table editor files should not be copied wholesale into the mixed editor. Extract reusable widgets/controllers only where needed:

- list section row widget and list operations;
- table section model operations and table grid widget;
- shared keyboard rail action model.

The mixed editor must support table sections inside the same editor surface. A separate table route is acceptable only for legacy `NoteBlockType.table` chunks, not for new mixed chunks.

### Keyboard-Top Rail Contract

The text editor already positions `_TextKeyboardRail` above the keyboard using `MediaQuery.viewInsets.bottom`. Mixed editor must reuse that placement model:

- no inline rail inside selected list cards;
- no inline rail inside selected table cells;
- selecting text/list item/table cell changes the action set in the bottom rail;
- the content area gets bottom padding equal to keyboard inset plus rail height.

Actions by target:

- text selection: tag, clear tags, previous/next tag, indent/outdent;
- list item: tag, clear tags, previous/next tagged item, indent/outdent, add/delete item;
- table cell/row/column: tag, clear tags, insert/delete row/column, resize/reorder controls where practical.

### PDF Text Region Joining

Replace the current simple `join('\n')` behavior with layout-aware joining.

Input: selected structured PDF text fragments with bounds.

Algorithm:

1. Filter fragments by overlap with selected PDF rect.
2. Sort by reading order if the source order is not already stable: top-to-bottom, then left-to-right in PDF/page coordinate terms.
3. Group fragments into lines when their vertical centers overlap within a tolerance.
4. Within a line, join fragments with a space unless punctuation rules indicate no leading space.
5. Insert a newline between lines.
6. Insert a blank line when vertical line gap exceeds paragraph threshold.
7. Keep bullet markers (`•`, `-`) and numbered markers (`1.`, `I.`, `II.`) attached to following text.

This produces readable plain text before the mixed parser runs.

### Mixed Parser From Plain Text

For manual PDF text chunks, parse normalized text into initial mixed sections:

- consecutive normal lines become paragraph sections;
- bullet lines become list sections with `NoteListItem`s;
- numbered lines can become hierarchy list items when the pattern is clear;
- simple pipe/semicolon table text can become table sections;
- ambiguous text remains paragraph text.

The parser must be conservative. It should preserve content even if structure detection is imperfect.

### Shared Chunk Type Display

Add a shared kind for mixed text or map it to the existing text visual kind:

- display label: `Szoveg`;
- icon: text icon;
- preview: flattened mixed text;
- details: optional status chip such as `vegyes` if useful, but do not create a fourth primary user-facing creation type.

Flowchart remains a separate chunk type. The effective new creation set is:

- text/mixed;
- flowchart;
- existing image/visual/manual modes where already present.

Legacy list/table rows may still display with their legacy icon until they are edited/converted. New creation should favor mixed text.

## Data Flow

### Manual PDF Text Selection

1. User selects a PDF region and chooses text.
2. Structured PDF text fragments are filtered to the selected rect.
3. Fragment text is joined into readable text.
4. The mixed parser creates initial sections.
5. The save sheet/editor stores:
   - flattened text in `text`;
   - structured mixed JSON in `structuredContentJson`;
   - source rect JSON unchanged from the page-anchored design.
6. PDF chunk list shows the item as text/mixed.
7. Opening the editor loads the mixed structure if present; otherwise it converts legacy text/list/table to mixed on edit.

### Notes

1. New text chunk creation creates a `NoteBlockType.mixed` block by default.
2. Existing `paragraph`, `listItem`, and `table` blocks keep their current editor routes.
3. A conversion action may later convert legacy chunks to mixed, but this first implementation should not mutate old blocks silently.

### Indexing And Export

Mixed block `plainText` walks sections in order:

- paragraph text;
- list title/items with indentation;
- table title/rows as pipe-separated text.

PDF export walks the same section order and delegates rendering to paragraph/list/table builders.

## Error Handling

- If `structuredContentJson` is invalid, fall back to legacy `text` as one paragraph section.
- If mixed section parsing fails, preserve raw text in one paragraph section and log a debug message.
- If table section data is ragged, normalize rows with existing table normalization rules.
- If list item ids are missing or duplicated, regenerate stable ids during parse.
- If selection text is empty, keep the current OCR fallback path.

## Testing Strategy

Unit tests:

- PDF fragment line joining with word fragments on one line.
- Bullet and numbered marker preservation.
- Mixed section JSON round-trip.
- Legacy text/list/table to mixed conversion.
- Mixed `plainText`, `displayTextForIndexing`, `knownTags`, and `contentHash`.

Widget tests:

- Mixed editor renders paragraph, list, and table sections in order.
- List section supports add/delete/indent/outdent/reorder.
- Table section supports row/column/cell editing and scoped tags.
- Keyboard-top rail appears for selected text/list/table targets with `viewInsets.bottom`.
- New text chunk creation opens mixed editor.
- Manual PDF text save stores mixed structure.

Regression tests:

- Current text editor tests remain green.
- Current list editor tests remain green.
- Current table editor tests remain green.
- Current PDF chunk list/editor tests remain green.
- `flutter analyze` in Ubuntu proot passes.

## Implementation Notes

- Keep implementation staged behind tests. The mixed model and parser should land before editor wiring.
- Avoid copying the full table editor into the mixed editor. Extract operations and widgets where doing so reduces duplication.
- Keep legacy editor routes in `PdfChunkEditorRoute` until mixed structure exists for the item.
- Do not remove legacy `LocalChunkKind.list` or `LocalChunkKind.table`.
- Do not run local Android APK builds in Termux; use GitHub Actions after implementation.

## Open Decisions Resolved

- New content should be mixed text by default.
- Legacy chunks stay intact.
- Flowcharts remain separate.
- The rail belongs above the keyboard, not inline in cards.
- Exact PDF typography is not required; logical structure and readable layout are required.
