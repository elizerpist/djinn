# Djinn Mobile Flowchart Viewer Design

Date: 2026-06-16

## Goal

Design the final mobile flowchart reading experience for flowchart cards inside
PDF chunks and notes.

The flowchart viewer must support complex yes/no decision trees on a phone
without making deep nodes unreadably narrow. The final direction has three
user-selectable views over the same flowchart data:

1. `Lista`
2. `Canvas`
3. `Guide`

The default and primary view is `Lista`.

## Current Context

Djinn already treats flowcharts as extracted knowledge items and planned note or
PDF chunk cards. Earlier exploration showed that a classic side-by-side tree
breaks on phones:

- each yes/no decision doubles the number of columns;
- by four decision layers the user must reason about 16 terminal paths;
- deep boxes become too narrow for Hungarian clinical text;
- when scrolling vertically, a `Nem` box may appear far below its matching
  decision and lose context.

The final design avoids that failure by representing each branch as a list item:
the decision and selected answer are always in the same card.

Example:

- `Légzési elégtelen?` + `Igen`
- subprocess text
- child decision branch
- sibling branch divider
- `Légzési elégtelen?` + `Nem`

The same mother decision may appear multiple times, once per branch. This
duplication is intentional because it preserves context during vertical
scrolling.

## Design Principles

- The chart itself is clean content: decisions, answers, subprocesses, arrows,
  and terminal processes only.
- Validation, review state, trust state, and RAG eligibility must not appear
  inside the chart renderer.
- Every text-heavy card in `Lista` and `Guide` is screen-width. Hierarchy must
  not reduce text width.
- Arrows appear only between logically connected parent-child elements.
- Sibling transitions are not connected by arrows. They use a divider such as
  `Légzési elégtelen? · másik ág`.
- Closing a branch hides only that branch's descendants.
- The same flowchart can be read as a list, inspected as a canvas, or stepped
  through as a guide.

## Scope

In scope:

- Mobile UI behavior for flowchart cards.
- `Lista`, `Canvas`, and `Guide` view modes.
- Open/closed branch behavior for nested yes/no decision trees.
- PDF chunk and note card integration.
- Shared rendering model for decisions, answers, subprocesses, and terminal
  processes.
- Testing requirements for the viewer behavior.

Out of scope:

- Flowchart extraction quality.
- Node/edge validation UX.
- RAG eligibility state.
- Editing flowchart structure.
- Dragging nodes in the canvas.
- Local Flutter APK builds on Termux/Android.

## Shared Flowchart Model

The UI should render a normalized tree-like model.

Recommended conceptual structure:

- flowchart id;
- title;
- source summary, for example PDF filename and page;
- root decision;
- branch list per decision;
- branch answer: `Igen` or `Nem`;
- branch subprocess text;
- optional child decision;
- optional terminal process metadata;
- stable path id, for example `Y-N-Y`.

Each branch combines three concepts:

1. the mother decision question;
2. the selected answer;
3. the subprocess that follows that answer.

This means a decision with two branches is rendered as two separate cards:

- `Question? Igen`
- `Question? Nem`

The cards may be separated by many descendant items. The repeated question is
not duplication noise; it is the context anchor for scrolling.

## View Selector

Flowchart cards expose a compact segmented control:

- `Lista`
- `Canvas`
- `Guide`

The selected view persists while the user is viewing the flowchart card. A
later implementation may persist the user's last selected view globally, but
that is not required for the first version.

## Lista View

`Lista` is the primary mobile view.

### Ordering

The list uses depth-first ordering:

1. Render the mother decision's `Igen` branch card.
2. Render the subprocess below it.
3. If the branch has a child decision, render that child decision's `Igen`
   branch subtree first.
4. After the child `Igen` subtree completes, render the same child decision's
   `Nem` branch card.
5. Continue recursively.
6. When the mother `Igen` subtree is complete, show a sibling divider.
7. Render the mother decision's `Nem` branch card and subtree.

### Branch Card

Each branch card contains:

- the decision question;
- the selected answer chip: `Igen` or `Nem`;
- optional path indicator, for example `L3 · IIN`;
- open/close affordance.

Card color:

- `Igen`: restrained green;
- `Nem`: restrained red;
- neutral content cards: white;
- arrows: neutral gray.

### Process Card

The subprocess appears below the branch card.

Rules:

- it is screen-width;
- it does not inherit indentation from deep hierarchy;
- it supports long text without word-by-word wrapping;
- it may contain multiline clinical instructions.

### Arrows

Arrows are strict semantic connectors.

Use an arrow between:

- branch card -> subprocess;
- subprocess -> child decision branch card;
- subprocess -> terminal process, when terminal is shown separately.

Do not use an arrow between:

- the last item in an `Igen` subtree and the mother decision's `Nem` branch;
- sibling branch transitions;
- collapsed branch placeholders and unrelated following branches.

Sibling transitions use a divider:

`Shock jelek? · másik ág`

This divider means "the previous subtree is complete; now the same decision's
other branch starts."

### Open And Closed Behavior

Each branch card controls exactly its own subtree.

If `Légzési elégtelen? Igen` is closed:

- all subprocesses and child decisions under the `Igen` branch disappear;
- the card shrinks to its minimal branch-card height;
- the next visible logical unit is `Légzési elégtelen? Nem`;
- no arrow connects the collapsed `Igen` branch to the `Nem` branch.

If a deeper branch such as `Shock jelek? Nem` is closed:

- only that branch's subprocesses and descendants disappear;
- ancestor cards remain open;
- the visible list becomes shorter but not minimal at the root level;
- sibling branches remain visible according to their own open/closed state.

The user should be able to:

- tap a branch card to open or close it;
- use `Nyit mind`;
- use a convenience action such as `Mély ágak zárása`.

## Canvas View

`Canvas` is a read-only visual overview.

It is an embedded canvas-like surface inside the flowchart card or flowchart
detail. It is not an editor.

Required behavior:

- scrollable horizontally and vertically;
- pinch zoom on touch devices;
- wheel/trackpad zoom when supported;
- optional `+` and `-` zoom buttons;
- no node dragging;
- no edge editing;
- no text editing;
- no structural modification.

Purpose:

- inspect the full structure spatially;
- understand rough branch density;
- provide a familiar flowchart overview before switching back to `Lista` or
  `Guide`.

The canvas may use a wider internal surface than the phone screen. Unlike
`Lista`, horizontal movement is acceptable in this view because the view's
purpose is spatial inspection, not primary reading.

## Guide View

`Guide` is an interactive step-through reader.

It shows one decision or subprocess at a time.

Interaction:

1. Show a decision question.
2. Show two buttons: `Igen` and `Nem`.
3. User taps one answer.
4. The selected subprocess slides in.
5. If the selected branch has a child decision, show
   `Tovább a következő döntéshez`.
6. User can tap `Vissza` to return to the previous decision or answer state.
7. At a terminal branch, show an `Ág vége` state.

Guide mode should preserve a short path summary, for example:

`Igen -> Igen -> Nem`

Purpose:

- help users follow one clinical route without seeing the whole tree;
- make long subprocess text readable;
- support decision-by-decision reading on small screens.

## PDF Chunk Integration

Flowchart chunks appear among PDF chunks using the same card language as text
and table chunks.

Collapsed flowchart chunk card shows:

- type: `Flowchart`;
- source, for example `12. oldal`;
- title or root decision;
- small summary such as `1 -> 16 út`;
- selected view entry point.

Expanded flowchart chunk shows the view selector and the selected view.

The flowchart renderer does not show validation or trust state inside the chart.
Any source-level metadata belongs to the surrounding chunk card shell, not to
the chart content.

The same viewer can be reused in `Jegyzetek` flowchart note cards.

## Accessibility And Text Rules

- Branch cards must be buttons with clear expanded/collapsed state.
- `Igen` and `Nem` answer chips must not rely on color alone.
- Long Hungarian text must wrap by words, not into one word per line.
- Tap targets should be at least standard mobile button height.
- `Guide` mode should announce state changes through normal screen-reader
  focus order.
- Canvas mode must remain optional because it is less accessible than list and
  guide reading.

## Edge Cases

### Very Deep Trees

For trees deeper than four levels, `Lista` still uses the same DFS branch-card
model. Rendering should be lazy or virtualized if performance becomes a
problem.

### Missing Child Decision

If a branch has no child decision, its subprocess is terminal and `Guide` shows
`Ág vége`.

### Non-Binary Extraction

The primary UI is optimized for `Igen`/`Nem`. If extraction produces another
branch label, the branch card can still render it as a neutral answer chip, but
the extraction pipeline should prefer normalized yes/no branches for clinical
decision algorithms.

### Shared Or Reused Nodes

If a source flowchart is a graph rather than a strict tree, the mobile renderer
may duplicate a referenced node in list and guide views. The canvas may show the
graph relationship visually. The list must prioritize local readability over
graph purity.

## Testing Requirements

Widget tests should cover:

1. `Lista` renders each branch as question plus answer in the same card.
2. A root `Igen` branch closes all of its descendants while leaving the root
   `Nem` branch visible below it.
3. A deep branch such as `Shock jelek? Nem` closes only its own descendants.
4. Arrows render only for parent-child links.
5. No arrow renders between the final item of a subtree and the mother
   decision's sibling branch.
6. Sibling dividers render before duplicated mother decisions.
7. `Canvas` view is selectable and does not expose editing controls.
8. `Canvas` supports zoom controls.
9. `Guide` starts at the root decision with `Igen` and `Nem` buttons.
10. In `Guide`, tapping an answer shows the subprocess before advancing to the
    next decision.
11. `Guide` `Vissza` returns to the previous decision or answer state.
12. Terminal guide branches show an end state.

Manual QA should include:

- a four-level tree with 16 terminal subprocesses;
- long subprocess text in the deepest branch;
- opening and closing root and deep branches;
- switching between `Lista`, `Canvas`, and `Guide`;
- viewing the same flowchart inside a PDF chunk card.

## Acceptance Criteria

The feature is ready when:

1. Flowchart chunks offer `Lista`, `Canvas`, and `Guide` views.
2. `Lista` is the default view.
3. `Lista` uses duplicated question+answer cards for sibling branches.
4. Closing a branch hides only that branch's descendants.
5. Sibling branch transitions use dividers, not arrows.
6. Arrows only show true logical parent-child relationships.
7. `Canvas` is read-only, scrollable, and zoomable.
8. `Guide` shows one decision/subprocess flow at a time with `Igen`, `Nem`,
   `Tovább a következő döntéshez`, and `Vissza`.
9. Long text remains screen-width in `Lista` and `Guide`.
10. No chart-internal validation, review, or RAG status appears in any view.
