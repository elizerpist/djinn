# Djinn RAG, Tags, And Chunk Editors Checklist

Date: 2026-06-17

## Retrieval And RAG Findings

- [ ] Answers are isolated per chat turn; an older citation set or previous answer cannot constrain a later unrelated question.
- [ ] Follow-up questions such as "mashol nem emliti?" carry the referenced entity from the previous turn and search every eligible chunk, not only the previous source.
- [ ] Exhaustive requests such as "mindent" or "extrahalj mindent" expand sibling list items, table rows, and same-block parts so one matched item does not hide the rest of the block.
- [ ] Multi-note retrieval keeps all relevant notes until query-specific reranking; it must not collapse to one note too early.
- [ ] A generic adjective such as "sulyos" cannot pull an unrelated note by itself when the domain head term is missing.
- [ ] "Sulyos legzesi elegtelenseg" should not return a future "Sulyos serult" note unless it also matches the respiratory-failure domain.
- [ ] "Sulyos serult legzesi elegtelensege" may return both topics if both are domain-relevant.
- [ ] Branch value matching respects polarity: an `igen` branch cannot match a `nem` sibling branch.
- [ ] Branch value matching respects local condition context: `sulyos=igen` can boost the severe branch, but not the non-severe oxygen branch.
- [ ] Definition and symbol expansion for DO2/VO2 is gated to definition/entity/symbol questions, not therapy/process questions.
- [ ] Therapy/facet queries such as "legzesi elegtelenseg terapiaja" prefer therapy tables or treatment chunks, not all definitions.
- [ ] Note title and inherited tags can boost/scope retrieval, but cannot alone satisfy local branch-value evidence.
- [ ] Logs show why a note/chunk was included or excluded with request id, query terms, note id, score, scope, and gate reason.

## Answer And Source UX

- [ ] Offline graph answers are sectioned and readable; they are not one long paragraph.
- [ ] Flowchart relations are verbalized as "Ha X, akkor Y" instead of raw arrows in chat answers.
- [ ] Sources are grouped by chunk, not listed as every individual node/edge/list item.
- [ ] A source row opens one fullscreen read-only preview of the real chunk design.
- [ ] Flowchart sources open a fullscreen scrollable preview.
- [ ] Source sections never become longer than the useful answer by default.

## Tag System

- [ ] Tag manager persists tag definitions and can recall existing tags.
- [ ] Every tag has a name and a unique color slot.
- [ ] Existing tag pills open the editor for rename/recolor/delete.
- [ ] Whole chunk tags and local scoped tags use the same tag editor sheet/card.
- [ ] Multi-tag is supported on one target.
- [ ] Local tag ranges/targets can be changed or removed.
- [ ] Tagged text shows the tag color as a background highlight.
- [ ] Whole chunk tags appear as full-opacity colored capsules in the editor subheader.
- [ ] Tag metadata is searchable but does not blindly make every tagged note relevant.

## Shared Chunk Editor Rules

- [ ] All chunk headers are editable and represent the chunk name.
- [ ] All chunk headers contain a global tag icon.
- [ ] All chunk headers contain a right-side three-dot menu.
- [ ] The three-dot menu contains selected part tagging, selected tag deletion, and chunk deletion.
- [ ] Selected tag deletion is disabled when the current selection has no tag.
- [ ] No standalone "Tag manager", "Tag/multitag", or bottom local-tag action buttons remain.
- [ ] A grey tip/instruction bar may remain below editor content.

## Text Chunk

- [ ] Header text is the editable chunk name.
- [ ] Header actions: global tag, paragraph indent, paragraph outdent, three-dot menu.
- [ ] Selected text is tagged through the three-dot menu.
- [ ] Local tags render as text highlight and local tag pills below the text.
- [ ] The bottom tip explains: write text, select text, then tag it from the dropdown.

## List Chunk

- [ ] Header text is the editable list title.
- [ ] Header actions: global tag, add row, three-dot menu.
- [ ] The old list-name box is removed from the subheader.
- [ ] The bottom add button is removed.
- [ ] List items stay draggable and keep indent/outdent controls.
- [ ] A list item can be selected.
- [ ] A selected list item can be tagged through the same three-dot menu.
- [ ] List item tags render below that item.

## Table Chunk

- [ ] Header text is the editable table title.
- [ ] Header actions: global tag, add row, add column, three-dot menu.
- [ ] Header add-row and add-column buttons work.
- [ ] Row, column, and cell selection is supported.
- [ ] Each column keeps plus and x controls.
- [ ] Column plus inserts a column to the right.
- [ ] Tag pills are not placed inside cells.
- [ ] Row tags use a left color rail.
- [ ] Column tags use a top color rail.
- [ ] Cell tags use a corner marker or stripe.
- [ ] Actual pills appear in a selected-element tag tray outside the table grid.

## Flowchart Chunk

- [ ] Header text is the editable flowchart title.
- [ ] Header actions: global tag and three-dot menu.
- [ ] Flowchart nodes and boxes are selectable.
- [ ] Local flowchart tags do not render as pills on the infinite canvas.
- [ ] Tagged flowchart elements use an outline/glow/corner marker.
- [ ] Actual pills appear in a selected-element tray outside the canvas.
- [ ] Three creation buttons are separate vertical FABs on the right side at FAB height.
- [ ] The three creation buttons are not horizontal and not inside one shared box.
- [ ] Zoom in/out controls replace the old top button location.
- [ ] Pan/drag performance is smooth enough on the target phone.
- [ ] Canvas behavior feels truly infinite for user work, not just a visibly bounded giant surface.

## Build And Release

- [ ] Local Flutter APK build is not attempted on Termux/Android.
- [ ] Unit/widget tests are run locally where available.
- [ ] GitHub Actions builds the APK after push.
- [ ] The final response includes commit SHA, branch, Actions URL, and APK URL.
