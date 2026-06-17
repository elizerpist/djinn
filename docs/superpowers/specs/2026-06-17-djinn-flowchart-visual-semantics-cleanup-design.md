# Djinn Flowchart Visual Semantics And Viewer Cleanup Design

Date: 2026-06-17

## Goal

Define the final visual semantics for flowchart connection points, loop edges,
editor canvas styling, and the cleaned mobile flowchart viewer output.

This spec extends the mobile flowchart viewer design from 2026-06-16. It covers
two surfaces:

1. the flowchart editor canvas, where users create and connect nodes;
2. the collapsed or expanded flowchart box preview, where users read the chart
   inside notes and PDF chunks.

The editor may show extra construction hints. The preview must stay clean.

## Accepted Decisions

- A visible node point may act as input, output, or both.
- Input and output roles use different colors.
- If the same visible point is used as both input and output, it gets a clear
  outer circular outline so the double role is intentional, not a visual bug.
- Current process box design remains unchanged.
- Current non-loop line color remains unchanged.
- Only the edge that closes a loop changes style: it becomes dashed and orange
  instead of the current purple line.
- The flowchart box preview canvas must not show a square grid.
- The square grid belongs only in the editor canvas.
- The flowchart list view must remove duplicated question-only steps.
- The guide view must show choices directly under the current question or
  process, not repeat the same question as a separate intermediate step.

## Scope

In scope:

- Node-point visual states in the flowchart editor.
- Edge styling for normal connections and loop-closing connections.
- Canvas background rules for editor versus preview.
- List-view text cleanup in the flowchart box.
- Guide-view interaction cleanup in the flowchart box.
- Model and rendering rules needed to implement these UI changes.
- Widget and behavior tests for these states.

Out of scope:

- Changing the shape, typography, spacing, or visual style of process boxes.
- Changing the current color of normal non-loop lines.
- Replacing the editor interaction model.
- Adding validation banners or quality state inside the chart.
- Local Flutter APK builds on Termux/Android.

## Editor Node-Point Semantics

The app must not treat a visible node point as permanently "input only" or
"output only." A visible point is an anchor. Each edge assigns the anchor role
for that specific connection.

Recommended conceptual model:

```text
Edge.source = nodeId + pointId + role: output
Edge.target = nodeId + pointId + role: input
```

The same `nodeId + pointId` can therefore appear in both source and target
positions across different edges.

### Port States

Each visible point has one of these derived visual states:

| State | Meaning | Visual |
| --- | --- | --- |
| `inputOnly` | At least one edge targets this point, and no edge starts from it. | Input color only |
| `outputOnly` | At least one edge starts from this point, and no edge targets it. | Output color only |
| `inputAndOutput` | At least one edge targets this point and at least one edge starts from it. | Output/input color plus an outer circular outline |
| `unused` | No edge uses this point. | Current neutral point style |

Use the current editor connection palette with fixed role meanings:

- input: the current green/teal port color;
- output: the current purple output accent;
- input and output: both role colors remain readable, plus a visible outer
  circular outline around the point.

The outer circular outline should be high contrast against the node body and
must sit outside the normal point radius, so it reads as an intentional
additional state instead of a larger ordinary port.

The double-role state should be readable at normal phone zoom. It must not rely
only on a tiny icon, because the editor is used on a touch screen.

### Double-Role Port Rendering

When a point is both input and output, render it as one shared anchor with two
visible layers:

1. the normal point body;
2. an outer circular outline around it.

The outer outline is the important part of the decision. It tells the user:

> this is not an accidental overlap; this point is intentionally both an input
> and an output.

The user should still drag from or connect to the same visible point. The UI
must not force two nearly overlapping handles, because that would be hard to use
on mobile.

## Editor Edge Semantics

Normal existing line styling remains unchanged. In the current editor this means
normal connections keep the current purple line style.

Only loop-closing edges receive special styling.

### Loop-Closing Edge

A loop-closing edge is an edge that completes a cycle in the graph. In practice
this is usually the line from a lower node back to an earlier or higher node,
but implementation should prefer graph semantics over only comparing screen
positions.

Recommended detection:

1. When adding or rendering edge `A -> B`, check whether `B` already has a path
   back to `A` through existing flowchart edges.
2. If yes, `A -> B` closes a loop.
3. Mark that edge as `loopClosing`.

Fallback for early implementation:

- if the target node is visually above the source node and the connection is a
  return/back connection, style it as a loop-closing edge.

### Loop Edge Visual Style

Loop-closing edges must be:

- orange;
- dashed;
- otherwise consistent with current edge geometry and arrow behavior.

Do not recolor all upward or sideways lines by default. Only the edge that
semantically closes the loop gets the orange dashed treatment.

## Editor Canvas Background

The editor canvas keeps the square grid.

The grid is useful in the editor because users position nodes, align edges, and
understand spatial structure while editing. This spec does not change the editor
grid.

## Flowchart Box Preview Canvas

The flowchart box preview is a reading surface, not an editing surface.

Rules:

- no square grid behind the chart;
- no editor construction background;
- no validation state inside the chart;
- preserve the flowchart content, node shapes, and connection geometry;
- loop-closing edges may still use the orange dashed style, because that is
  semantic chart information, not editor chrome.

The preview canvas should read like a clean diagram embedded in a note or PDF
chunk card.

## Flowchart Box List View Cleanup

The list view currently repeats question labels as separate steps and then
again as answer cards. That produces duplication.

Current problematic form:

```text
Kezdés
Légzési elégtelen?
Légzési elégtelen? Igen
Súlyos?
Súlyos? Igen
```

Required cleaned form:

```text
Start
Légzési elégtelen? Igen
Súlyos? Igen
```

The question and selected answer belong in the same list item. A question-only
item should not appear immediately before its own answer item.

### List Item Rules

Render these item types:

- start item: `Start`;
- answered decision item: `Question? Answer`;
- process item, when the source chart has meaningful process text;
- loop reference item, when an edge returns to an earlier node;
- terminal item, when the branch ends.

Do not render:

- a standalone decision question immediately followed by `same question +
  selected answer`;
- duplicate mother-question breadcrumbs as normal list items;
- editor-only connection labels as content steps.

Answer color remains semantic:

- `Igen`: green;
- `Nem`: red;
- other branch labels: use neutral or configured branch color.

## Flowchart Box Guide View Cleanup

The guide view must behave like an interactive decision walkthrough.

Current problematic form:

```text
Légzési elégtelen?
Tovább a következő lépéshez
Légzési elégtelen?
Súlyos?
Igen / Nem buttons
```

Required form:

```text
Start
Légzési elégtelen?
[Igen] [Nem]
```

After the user taps `Igen`:

```text
Start > Légzési elégtelen? Igen
Súlyos?
[Igen] [Nem]
```

The next decision appears directly after the selected process path. The guide
must not repeat the same question as an intermediate "next step" screen.

### Guide Choice Rules

If the current node has two branches, show both answer buttons directly under
the current question:

- `Igen`;
- `Nem`.

If the current node has more than two possible branches, show every branch as a
button under the current process or question.

Examples:

```text
Ellátási út?
[Otthon] [Sürgősségi] [Intenzív]
```

The guide must support non-binary branch sets without changing the interaction
model.

### Guide Process Rules

When a selected answer has process text:

1. show the selected path context;
2. show the process content;
3. show the next decision and all its branch buttons below it.

Do not require a separate `Tovább a következő lépéshez` tap unless the process
content is long enough to need a deliberate pause. For the default flow, the
next available choice should be visible immediately.

## Loop Handling In List And Guide Views

Loop-closing edges must not recursively expand earlier content forever.

In list view:

- render a loop reference item;
- show the target decision or target step label;
- do not inline the target subtree again.

In guide view:

- show a loop reference after the process that creates the loop;
- provide a jump/back action to the target step;
- do not duplicate the full target path as new content unless the user follows
  the loop.

Loop visual style in preview canvas:

- orange dashed line.

Loop visual style in list and guide:

- explicit loop/reference row or compact badge;
- no editor grid or editor handles.

## Data Model Implications

The renderer needs stable IDs for:

- nodes;
- visible node points;
- edges;
- edge source role;
- edge target role;
- branch labels;
- loop-closing edge state.

The renderer should derive point visual state from actual edge usage:

```text
hasIncoming = any edge target uses nodeId + pointId
hasOutgoing = any edge source uses nodeId + pointId

if hasIncoming && hasOutgoing => inputAndOutput
if hasIncoming => inputOnly
if hasOutgoing => outputOnly
otherwise => unused
```

This avoids storing stale visual state on the point itself.

## Testing Requirements

Add or update tests for:

- a point used only as input renders input color;
- a point used only as output renders output color;
- a point used as both input and output renders the outer circular outline;
- normal edges keep the existing line color;
- loop-closing edges render dashed orange;
- editor canvas shows the square grid;
- flowchart box preview canvas does not show the square grid;
- list view renders `Start > Légzési elégtelen? Igen > Súlyos? Igen` without
  duplicate standalone question items;
- guide view shows answer buttons directly under `Légzési elégtelen?`;
- guide view supports more than two branch buttons under a process or question;
- loop references do not recursively expand forever in list or guide mode.

## Acceptance Criteria

The feature is complete when:

- shared input/output node points are visually understandable on a phone;
- shared points do not require two nearly overlapping touch targets;
- normal line and process box styling remains visually unchanged;
- loop-closing lines are dashed orange;
- only the editor canvas has the square grid;
- flowchart preview cards have a clean canvas background;
- list view no longer duplicates decision questions before answer cards;
- guide view no longer repeats the same decision before showing child choices;
- multi-branch decisions render all branch choices as buttons;
- automated tests cover the new rendering rules.
