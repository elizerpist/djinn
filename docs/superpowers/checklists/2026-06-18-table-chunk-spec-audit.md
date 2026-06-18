# Table Chunk Spec Audit

Source spec: `docs/superpowers/specs/2026-06-18-chunk-tag-rail-final-design.md`

Approved HTML references that must be re-read before table implementation:

- `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-v2.html`
- `.superpowers/brainstorm/12103-1781765637/content/table-sticky-inline-rail-overflow-v1.html`

Current implementation file:

- `lib/src/notes/ui/note_table_editor_screen.dart`

Current tests:

- `test/note_table_editor_screen_test.dart`

## Acceptance Matrix

| ID | Requirement | Status | Evidence / gap |
| --- | --- | --- | --- |
| TABLE-001 | Excel-like grid with corner head, column heads, row heads, body cells | DONE | `note-table-corner-head`, `note-table-column-head-*`, `note-table-row-head-*`, `note-table-cell-*`. |
| TABLE-002 | Rounded-square heads and cells | DONE | `_HeadCell` and `_CellField` use 8px radius. |
| TABLE-003 | Row head height matches row cell height | DONE | Body/header rows use `IntrinsicHeight` + stretch; regression test covers wrapped cell height. |
| TABLE-004 | Cell height is content-driven and text wraps inside boundary | DONE | Text fields are multiline and row heads now stretch with wrapped cells. |
| TABLE-005 | Tap column head selects column and expands header area downward | DONE | `_buildHeader` renders `note-table-column-head-expansion-*`. |
| TABLE-006 | Tap row head selects row and expands selected row downward | DONE | `_buildRow` renders `note-table-row-head-expansion-*`. |
| TABLE-007 | Tap cell selects/edits cell and expands selected row downward | DONE | `_CellField` tap plus `note-table-cell-expansion-*`. |
| TABLE-008 | No tiny selector point or top-cell x/plus controls remain | DONE | Legacy selector keys are absent in tests. |
| TABLE-009 | Header add-row/add-column buttons work | DONE | `note-table-appbar-add-row`, `note-table-appbar-add-column`. |
| TABLE-010 | Rail action content remains visible for far-right selection | DONE | `_stickyRail` tracks horizontal scroll offset. |
| TABLE-011 | Rail action/pill rows scroll internally | DONE | `NoteSelectionActionRail` uses horizontal `SingleChildScrollView` for both rows. |
| TABLE-012 | Row/column heads are poly-tagging scopes and write affected cell targets | DONE | `_targetsToWriteForSelection` writes table-cell targets for row/column. |
| TABLE-013 | Row/column rail lists all tags present in affected cells | DONE | `_tagsForSelection` aggregates affected cell targets. |
| TABLE-014 | Removing a cell tag affects only that cell | DONE | Cell selection affected target is only the selected cell. |
| TABLE-015 | Removing row/column scope tag affects all cells in that scope | DONE | Row/column selection affected targets include all affected cell targets. |
| TABLE-016 | Direct cell tag has primary color priority over row/column inherited tags | PARTIAL | Primary direct color works, but secondary inherited tags are currently not rendered as underline layers. |
| TABLE-017 | Rail includes relevant insert/delete operations for row/column/cell scope | DONE | Column insert/delete, row insert/delete exist in the rail. |
| TABLE-018 | Scoped tags remap on row/column insertion/deletion/reorder | PARTIAL | Column insert/delete, row insert, and row delete remap exist; reorder is not implemented. |
| TABLE-019 | Long-tap row head vertical reorder with identical ghost | NOT DONE | No row reorder gesture implementation exists. |
| TABLE-020 | Long-tap column head horizontal reorder with identical ghost | NOT DONE | No column reorder gesture implementation exists. |
| TABLE-021 | Long-tap drag on cell/header edge resizes entire column | NOT DONE | No resize gesture or column-width state exists. |
| TABLE-022 | Pinch zoom out with base scale as max zoom-in | NOT DONE | Table has nested scroll views, no scale controller. |

## Current Short Bugfix Scope

- Fixed `TABLE-003` and `TABLE-004` by making row heads stretch to the wrapped row height.
- Fixed `TABLE-017` and the row-insert part of `TABLE-018` by adding a row insert rail action and row-insert tag remap.
- `TABLE-018` remains `PARTIAL` only because reorder remapping depends on the missing reorder feature.
- Leave `TABLE-019` through `TABLE-022` as `NOT DONE`; they require a larger gesture/state implementation pass.
