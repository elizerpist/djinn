# Universe 4 — Globe.gl → G6 Focused Map v2 depth transition

## Goal

Extend the existing isolated Universe 4 flow from `Universe V3 ForceGraph →
canonical Explore V7 Globe.gl` to a third, in-viewport depth level:

`ForceGraph galaxy → V7 Globe.gl planet → existing G6 Focused Map v2`.

The V7 Globe controller remains the rendering and interaction source of truth
for the planet. The G6 stage is an adapter over the existing Focused Map v2
domain/building blocks, not an Explore route or a duplicate graph model.

## Reference inputs

- `prototypes/working-prototype/assets/explore-galaxy-orb.js`: canonical V7
  city, arc, light, label, pointer and Globe.gl behaviour.
- `prototypes/working-prototype/assets/knowledge-map.js`: existing Focused
  Map v2 subgraph, LOD, position and card-style source.
- `prototypes/working-prototype/assets/universe4.js`: existing U3 → V7
  match-cut handoff; it is extended only at its V7 standalone boundary.

## Module ownership

- `assets/universe4/universe4-depth-controller.js`: generation-safe high
  level Universe depth state machine.
- `assets/universe4/universe4-globe-selection.js`: pure root/context/foreign
  tap resolution and two-tap foreign-city policy.
- `assets/universe4/universe4-focused-map-snapshot.js`: immutable bridge from
  V7 selection to the G6 Focused Map input snapshot.
- `assets/universe4/universe4-tangent-plane.js`: stable city-centred tangent
  projection and sphere-to-plane interpolation data.
- `assets/universe4/universe4-morph-patch.js`: temporary canvas patch for the
  visible sphere-surface → plane handoff.
- `assets/focused-g6-v2-stage.js`: reusable adapter over the existing G6 v2
  graph data/style primitives and the full canonical 700-node/1003-edge map
  domain after the entry handoff.
- `assets/focused-g6-v2-stage-state.js`: DOM-free center-card and zoom/LOD
  transition helpers; graph data is only rebound at a V2 LOD boundary.
- `assets/focused-g6-v2-stage-controls.js`: stage-local `− / + / ◎` controls
  for zoom-out, zoom-in and recentering the dynamic G6 center card.
- `assets/universe4/universe4-g6-focused-map-stage.js`: U4-specific G6
  lifecycle, Entry Layout and interaction ownership.
- `assets/universe4/universe4-input-ownership.js`: single source for Force,
  Globe, G6 and locked pointer ownership.

## Execution order

1. Add tests for the pure depth state, selection policy, snapshot and tangent
   projector; implement them without touching V7 runtime behaviour.
2. Extract/reuse the Focused Map v2 adapter as a new file and make a U4 G6
   stage that prewarms at zero opacity.
3. Add the V7 callback seam and stack the G6/morph stages in U4.
4. Connect context-city tap → camera lead-in → patch/G6 entry layout handoff.
5. Connect Map → Planet return while preserving the root context, then retain
   the existing Planet → Galaxy reset hierarchy.
6. Extend the U4 debug panel with depth/tap/morph/G6 signals; verify tests,
   syntax and an Android visual flow.
7. After the entry-layout handoff, promote the G6 stage to the full existing
   V2 map: node tap replaces the central card and native G6 zoom reveals the
   near/mid/far LOD rings without per-frame graph rebuilds.

## Explicit non-goals

- No route navigation to Explore while entering the map.
- No reimplementation of the V7 planet, V7 light rig, city layout, arc
  renderer or pointer router.
- No change to Universe V3's standalone behaviour.
- No unrestricted, long-lived triple renderer loop: the map and globe stages
  prewarm only briefly and suspend when hidden.
