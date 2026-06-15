# Flowchart Popup Editor And Edge Routing Design

Date: 2026-06-15

## Purpose

The note flowchart editor should become simpler to use and more expressive. The current palette exposes many visual flowchart symbols even when they store the same graph logic. The editor should instead expose a small set of logical elements, let the user configure connection ports from a popup editor, and draw connections in a way that makes loops and back-edges readable.

This design applies to the full-screen note flowchart editor.

## Goals

- Reduce the palette to a small logical element set.
- Make node configuration explicit through a popup editor.
- Let ports exist on any side of an element.
- Do not hard-code a port as input or output.
- Support loops, lateral flows, return paths, and parallel branches.
- Draw back-edges as visible side-routed loops, not hidden lines behind cards.
- Keep inline text editing separate from node configuration.
- Keep graph storage clean and independent from visual routing details.

## Non-Goals

- Do not restore the large classic flowchart-symbol palette as separate graph types.
- Do not force all charts into a top-to-bottom layout.
- Do not make edge routing manually editable in the first implementation.
- Do not store generated auto-routing waypoints unless the user later edits an edge route manually.

## Element Model

The editor should use three logical element types:

1. Universal element
   - Represents start, end, or process-like content.
   - Visual role can be normal, start, or end.
   - Shape can be rectangular or oval as a visual property.
   - Ports can be placed on any side.

2. Binary decision
   - Represents an `Igen/Nem` decision.
   - Has configurable ports and branch labels.
   - The user can choose which port is `Igen` and which port is `Nem`.
   - Multiple incoming ports are allowed.

3. Multi-branch decision
   - Represents a decision with arbitrary named outcomes.
   - Example branch labels: `95 felett`, `90-95`, `80-90`, `80 alatt`.
   - Branches can be placed on any side and multiple branches may share one side.

Classic symbols such as subprocess, input/output, data store, and connector are not distinct graph types in the first redesign. They can later be added as visual styles if needed, but they should not create separate storage logic when their topology is the same.

## Storage Model

The flowchart graph should move toward a port-based model.

```text
FlowNode
- id
- label
- kind: universal | binaryDecision | multiDecision
- role: normal | start | end
- visualShape: rectangle | oval | diamond
- x, y, width, height
- ports[]

FlowPort
- id
- side: top | right | bottom | left
- positionIndex
- label
- semantic: normal | yes | no | custom

FlowEdge
- id
- fromNodeId
- fromPortId
- toNodeId
- toPortId
- label
- routingMode: auto | manual
- manualWaypoints?: []
```

Port direction is determined by the connection gesture:

- The first tapped port is the edge source.
- The second tapped port is the edge target.
- The same physical port can receive multiple incoming edges.
- The same node can have multiple source ports on different sides.

This avoids fixed top-input and bottom-output assumptions and supports loops, side branches, and return paths.

## Popup Editor

The popup editor configures the selected node. It is not used for normal text editing.

Open behavior:

- Tapping node text starts inline text editing.
- Tapping the non-text body of a node opens the popup editor.
- Dragging a node must not open the popup.
- Movement above a small threshold is treated as drag, not tap.
- Tapping a port starts or completes edge connection mode.

Presentation:

- On phones, the popup appears as a compact bottom sheet or anchored inspector.
- It should not take over the entire screen.
- It saves changes live.
- It closes by outside tap, close button, or swipe down.

Popup sections:

1. Logical type
   - Universal element
   - Binary decision
   - Multi-branch decision

2. Role and visual style
   - Role: normal, start, end
   - Shape: rectangle, oval, diamond when compatible

3. Ports
   - Four side lanes: top, right, bottom, left.
   - Each side can contain zero or more ports.
   - Add port, rename port, delete port.
   - Binary decision ports can be marked as `Igen` or `Nem`.
   - Multi-branch decision ports can have arbitrary labels.

The popup should show a small live preview of the node with ports around it, so the user understands where connection handles will appear on the canvas.

## Connection Interaction

Connection mode should work the same for every element type:

1. User taps a port.
2. That port grows with an animation and becomes the selected source.
3. Other node cards dim slightly.
4. Available ports remain at full opacity.
5. User taps a target port.
6. The editor creates a directed edge from source port to target port.

There is no separate input/output button. The connection gesture defines the direction.

Decision edge labels:

- Binary decision edges inherit `Igen` or `Nem` from the selected source port when available.
- Multi-branch decision edges inherit the selected source port label.
- The user can later edit an edge label.

## Edge Deletion And Editing

All edges should be selectable, not only yes/no edges.

Edge tap behavior:

- Tap edge: select it and show lightweight controls.
- Delete action removes the edge.
- Label action edits the edge label.

Edge deletion must work for universal, binary, and multi-branch edges.

## Auto Edge Routing

Edges should be drawn with orthogonal, obstacle-aware routing. A direct straight line is allowed only when it does not hide behind node cards and does not make the relationship ambiguous.

The renderer should treat node cards as obstacles with padding.

Default route style:

```text
source port -> short exit segment -> horizontal/vertical middle segments
-> short entry segment -> target port
```

Back-edge rule:

- If the target node is visually above the source node, the edge is a back-edge.
- Back-edges must not be drawn behind cards.
- The route should exit sideways, travel upward in an outer side lane, and then enter the target port.

Example:

```text
lower node port
  -> side exit
  -> vertical rise outside the node stack
  -> horizontal return
  -> upper node port
```

Lane selection:

- Prefer the side with more free horizontal space.
- Use a minimum lane distance of about 24-40 px from nearby node bounds.
- Apply at least 16 px obstacle padding around node cards.
- If both sides are crowded, choose the shorter route that intersects the fewest node bounding boxes.

This makes loops visible and conventional: the user can see that a lower step returns to an earlier step.

## Routing Storage

Auto-routing is a rendering concern.

For normal edges, store only:

- source node and port;
- target node and port;
- label;
- routing mode.

Generated auto-route waypoints should not be stored because they become stale when nodes move.

If a later feature lets the user manually drag edge bends, then switch that edge to `routingMode: manual` and store `manualWaypoints`.

## Canvas Requirements

The canvas should use world coordinates, not a fixed screen-sized coordinate system.

- Nodes can exist at negative coordinates.
- Pan and zoom are viewport transforms only.
- Grid is drawn from the visible viewport.
- Large charts should be possible without resizing a giant widget.
- Lazy rendering/culling can be added when node counts become large.

## Migration

Existing notes should remain readable.

Initial migration rules:

- `startEnd` becomes universal with role `start` or `end` based on label.
- `process`, `subprocess`, `inputOutput`, `dataStore`, and `connector` become universal nodes.
- `decision` becomes binary decision with default `Igen` and `Nem` output ports.
- Existing edge labels remain unchanged.
- Existing edges without port ids can map to default generated ports.

## Debug Logging

The editor should continue logging enough detail to debug interaction problems.

Add or keep logs for:

- popup open/close and reason;
- port add/delete/rename;
- connection source selection;
- connection completion;
- edge delete/edit;
- auto-route classification: direct, side-route, back-edge;
- route lane selected: left or right;
- number of obstacle intersections avoided.

## Acceptance Criteria

- The palette exposes only universal, binary decision, and multi-branch decision elements.
- Tapping node text edits the text inline.
- Tapping node body opens the popup editor.
- The popup can configure type, role, visual shape, and ports.
- Ports can exist on any side of a node.
- The first tapped port becomes edge source; the second tapped port becomes edge target.
- Binary decisions can place `Igen` and `Nem` on configurable ports.
- Multi-branch decisions can define arbitrary branch labels.
- All edges can be selected and deleted.
- Back-edges are visibly routed around the side of the graph instead of behind node cards.
- Moving nodes recomputes auto-routes without corrupting stored graph data.
- Existing flowchart notes still load.
