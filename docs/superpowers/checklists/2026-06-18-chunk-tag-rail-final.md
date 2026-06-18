# Chunk Tag Rail Final Checklist

Date: 2026-06-18

## Spec And References

- [x] Write final spec from the accepted design conversation.
- [x] Reference approved text HTML.
- [x] Reference approved list HTML.
- [x] Reference approved table sticky rail HTML.
- [x] Reference approved table overflow HTML.
- [x] Reference approved flowchart HTML.
- [ ] Re-read all approved HTML references immediately before production implementation.

## Shared Tag System

- [ ] Tags have name and unique color.
- [ ] Tag manager slide-up sheet saves and reuses tags.
- [ ] Tag menu is available at notes root and inside each note dropdown.
- [ ] Whole-chunk tag button exists in every chunk header.
- [ ] Global tag capsules render in one horizontal subheader row with per-pill remove.
- [ ] Shared two-row rail exists for text/list/table.
- [ ] Rail top row has open/close, tag, clear all tags, previous, next.
- [ ] Rail bottom row has tag pills with per-tag remove or `Nincs tag`.
- [ ] Bottom row collapse does not close the rail.
- [ ] Next/previous moves between tagged units and scrolls/focuses the target.
- [ ] Primary/secondary multi-tag rendering is implemented.

## Text Chunk

- [ ] Header title edits chunk name.
- [ ] Header has global tag, paragraph indent/outdent, and three-dot menu.
- [ ] Three-dot menu has selected range tag, selected tag delete, chunk delete.
- [ ] Selected text opens inline rail under the text/paragraph, not screen bottom.
- [ ] Tagged text opens rail on tap without focus border.
- [ ] Bottom area has only the instruction/tip bar.

## List Chunk

- [ ] Header title edits list name.
- [ ] Header has global tag, add item, and three-dot menu.
- [ ] Bottom add button and duplicate list-name subheader field are removed.
- [ ] Checkbox remains beside drag handle.
- [ ] No selector dot exists.
- [ ] Tap non-text selects with border only.
- [ ] Tap text selects and edits.
- [ ] Enter creates/focuses a new list item.
- [ ] Selected item expands downward with the final rail design.
- [ ] Local tag feedback colors text only.
- [ ] Long text wraps and expands item height.
- [ ] Multiple underline lines do not overlap wrapped text.
- [ ] Checkbox and hierarchical numbering modes exist.
- [ ] Hierarchical numbering cascades after indent/outdent/reorder.

## Table Chunk

- [ ] Excel-like grid replaces split layout.
- [ ] Corner head, column heads, row heads, body cells exist.
- [ ] Row heads match row cell height.
- [ ] Cells use rounded-square design.
- [ ] Header add-row/add-column buttons work.
- [ ] No tiny selector point or top-cell x/plus controls remain.
- [ ] Column head tap expands header area and pushes cells down.
- [ ] Row head tap expands selected row.
- [ ] Cell tap expands selected row.
- [ ] Sticky rail content remains visible at far-right horizontal scroll.
- [ ] Rail rows scroll internally with many buttons/pills.
- [ ] Row and column poly-tagging apply feedback to affected cells.
- [ ] Removing a cell tag affects only that cell.
- [ ] Removing row/column tag affects all cells in scope.
- [ ] Row reorder via row head works with identical ghost.
- [ ] Column reorder via column head works with identical ghost.
- [ ] Column resize from cell/header edge works.
- [ ] Table zoom-out works with current scale as max zoom-in.

## Flowchart Chunk

- [ ] No tag pills or rails render on canvas.
- [ ] Flowchart edit card owns node/branch tagging.
- [ ] Shape selector is removed.
- [ ] All nodes render as rounded boxes in editor and previews.
- [ ] Three create buttons are vertical separate FAB-height buttons.
- [ ] Zoom controls are in the old top control area.
- [ ] Node-name rail includes type buttons.
- [ ] Branch rails include side-position actions.
- [ ] One plus button adds top branch by default.
- [ ] Binary yes/no branches cannot be renamed or deleted.
- [ ] Binary yes/no ports are output-only.
- [ ] New binary ports are input-only.
- [ ] Input-used ports cannot later become outputs.
- [ ] Node tags render as canvas outline layers.
- [ ] Edge tags render as edge line layers; arrowheads remain normal.
- [ ] Only the last-created loop-closing edge is dashed orange.
- [ ] Preview starts fit-to-view.
- [ ] Preview uses one finger for parent scroll and two fingers for preview pan/zoom.

## RAG And Chat

- [ ] Branch-value matching requires key, value, and polarity match.
- [ ] `igen` no longer matches `nem` branches.
- [ ] Context-only branch candidates do not create branch-value links.
- [ ] Single adjective `sulyos` does not pull unrelated notes when phrase context is missing.
- [ ] Combined topics can retrieve multiple relevant notes.
- [ ] Offline graph answer is sectioned and readable.
- [ ] Flowchart relationships are written as `ha X, akkor Y`.
- [ ] Sources collapse to one link per chunk.
- [ ] Source tap opens fullscreen read-only chunk preview.
- [ ] Flowchart source opens fullscreen scrollable/fit preview.

## Verification And Delivery

- [ ] Add failing tests before production code.
- [ ] Make focused tests green.
- [ ] Run available verification.
- [ ] Commit changes.
- [ ] Push branch.
- [ ] GitHub Actions debug APK build completes.
- [ ] APK download link is provided.
