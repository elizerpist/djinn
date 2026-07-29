# Explore Module Split and Signal Debug Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the V5–V7 Explore interaction path into small ESM modules while fixing repeat highlight/dehighlight, native Globe arc commits, and adding a copyable on-screen signal trace.

**Architecture:** Pure variant state, trace, and Globe arc payload code live outside the UI. `explore-galaxy-orb.js` owns the single Globe instance and wires independent V5/V6/V7 controller instances to it. The debug panel renders only a bounded trace snapshot.

**Tech Stack:** Browser ESM, Three.js, Globe.gl, Node `assert` tests.

## Implementation status — 2026-07-29

- Signal trace, isolated V5/V6/V7 selection controllers, native Globe arc
  adapter, gesture router and the copyable on-screen panel are implemented.
- Their focused tests, syntax checks and the complete JavaScript test suite
  pass. The release checklist keeps visual/mobile acceptance as `PARTIAL`
  until a V5→V6→V7 device tap/dehighlight/arc proof is captured.

## Global Constraints

- Keep a single Globe.gl scene, camera, renderer, controls instance and render loop.
- Do not modify atom positions, community membership, camera behavior, label behavior, glass effect, or lighting profiles.
- V5, V6 and V7 keep separate mutable controller instances.
- Do not write production code before its focused test has failed.

---

### Task 1: Signal Trace Core

**Files:**
- Create: `assets/explore/planet-signal-trace.js`
- Test: `tests/planet-signal-trace.test.mjs`

**Interfaces:**
- Produces `createPlanetSignalTrace({ limit, now })` with `record(event, payload)`, `entries()`, `clear()` and `serialize()`.
- `entries()` returns frozen copies ordered by sequence; `serialize()` emits newline-delimited JSON.

- [ ] **Step 1: Write the failing test**

```js
const trace = createPlanetSignalTrace({ limit: 2, now: () => 10 });
trace.record('pointer.tap', { variant: 'v5', cityId: 'pao2' });
trace.record('focus', { action: 'focus' });
trace.record('arc.commit', { assigned: 3 });
assert.deepEqual(trace.entries().map((entry) => entry.event), ['focus', 'arc.commit']);
assert.match(trace.serialize(), /"event":"arc.commit"/);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/planet-signal-trace.test.mjs`

Expected: FAIL because `planet-signal-trace.js` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```js
export function createPlanetSignalTrace({ limit = 200, now = () => Date.now() } = {}) {
  const events = [];
  let sequence = 0;
  return {
    record(event, payload = {}) { events.push(Object.freeze({ sequence: ++sequence, at: now(), event, ...payload })); while (events.length > limit) events.shift(); },
    entries: () => events.map((entry) => ({ ...entry })),
    clear: () => { events.length = 0; },
    serialize: () => events.map((entry) => JSON.stringify(entry)).join('\n'),
  };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `node tests/planet-signal-trace.test.mjs`

Expected: PASS.

### Task 2: Isolated Variant Focus Controller

**Files:**
- Create: `assets/explore/planet-variant-controller.js`
- Test: `tests/planet-variant-controller.test.mjs`

**Interfaces:**
- Consumes `selectCityConnections` and `clearCityConnections`.
- Produces `createPlanetVariantController({ variant, edges, nodesById, trace })` with `tap(cityId)`, `clear(reason)`, `state()`.

- [ ] **Step 1: Write the failing test**

```js
const v5 = createPlanetVariantController({ variant: 'v5', edges, nodesById });
const v6 = createPlanetVariantController({ variant: 'v6', edges, nodesById });
assert.equal(v5.tap('pao2').action, 'focus');
assert.equal(v5.tap('pao2').action, 'dehighlight');
assert.equal(v6.state().selectedCityId, null);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/planet-variant-controller.test.mjs`

Expected: FAIL because the controller module does not exist.

- [ ] **Step 3: Implement the controller**

The controller must call `clearCityConnections()` for an equal repeat tap and `selectCityConnections({ variant, cityId, edges, nodesById })` otherwise. It records `selection.focus`, `selection.replace`, `selection.dehighlight`, and `selection.clear` events but never touches Globe or DOM objects.

- [ ] **Step 4: Run the test to verify it passes**

Run: `node tests/planet-variant-controller.test.mjs`

Expected: PASS.

### Task 3: Globe Arc Adapter

**Files:**
- Create: `assets/explore/planet-globe-arc-adapter.js`
- Test: `tests/planet-globe-arc-adapter.test.mjs`

**Interfaces:**
- Produces `commitPlanetSelectionArcs({ globe, selection, trace })` and `clearPlanetSelectionArcs({ globe, trace, reason })`.
- Returns `{ assignedCount, verifiedCount, profile }` and records `arc.payload`, `arc.commit`, `arc.verify`, or `arc.clear`.

- [ ] **Step 1: Write the failing fake-Globe test**

```js
const assigned = [];
const globe = { arcsData(value) { if (value) assigned.splice(0, assigned.length, ...value); return assigned; } };
const result = commitPlanetSelectionArcs({ globe, selection, trace });
assert.equal(result.assignedCount, selection.selectedCityArcData.length);
assert.equal(result.verifiedCount, selection.selectedCityArcData.length);
clearPlanetSelectionArcs({ globe, trace, reason: 'repeat-tap' });
assert.equal(assigned.length, 0);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/planet-globe-arc-adapter.test.mjs`

Expected: FAIL because the adapter does not exist.

- [ ] **Step 3: Implement the adapter**

Reject malformed `startLat/startLng/endLat/endLng` or non-surface-selection arcs before commit, record the rejected IDs, commit once with the remaining payload, then read `globe.arcsData()` when supported. The adapter must not change Globe profile settings or selection state.

- [ ] **Step 4: Run test to verify it passes**

Run: `node tests/planet-globe-arc-adapter.test.mjs`

Expected: PASS.

### Task 4: On-screen Signal Debug Panel

**Files:**
- Create: `assets/explore/planet-debug-panel.js`
- Modify: `assets/styles.css`
- Test: `tests/planet-debug-panel.test.mjs`

**Interfaces:**
- Produces `mountPlanetSignalDebugPanel({ host, trace, clipboard })` with `render()` and `dispose()`.
- The DOM has `[data-planet-signal-log]` and `[data-planet-signal-copy]`.

- [ ] **Step 1: Write the failing DOM-contract source test**

```js
assert.match(source, /data-planet-signal-log/);
assert.match(source, /data-planet-signal-copy/);
assert.match(styleSource, /max-height:\s*100px/);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/planet-debug-panel.test.mjs`

Expected: FAIL because the panel module and CSS contract do not exist.

- [ ] **Step 3: Implement the panel**

Render the latest trace lines into a semantic `pre`/`output` inside a scrollable 100px band. The copy button uses `navigator.clipboard.writeText(trace.serialize())`; on failure it displays a copy error in the same trace and never throws into the interaction path.

- [ ] **Step 4: Run the test to verify it passes**

Run: `node tests/planet-debug-panel.test.mjs`

Expected: PASS.

### Task 5: Integrate V5–V7 Without Shared Mutable State

**Files:**
- Modify: `assets/explore-galaxy-orb.js`
- Modify: `tests/explore-galaxy-v3.test.mjs`

**Interfaces:**
- Consumes the controller, arc adapter and panel from Tasks 1–4.
- Re-exports existing `__v3TestModel`, `__v5VariantInteractionTestModel`, `__surfaceSelectionArcTestModel`, and `getV5PlanetVisualSnapshot` unchanged.

- [ ] **Step 1: Write the failing integration assertions**

```js
assert.match(orbSource, /createPlanetVariantController/);
assert.match(orbSource, /commitPlanetSelectionArcs/);
assert.match(orbSource, /mountPlanetSignalDebugPanel/);
assert.doesNotMatch(orbSource, /let citySelectionState =/);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/explore-galaxy-v3.test.mjs`

Expected: FAIL because the main file still owns shared selection state.

- [ ] **Step 3: Integrate minimally**

Create exactly one controller per V5-family variant. At the current `onV5PointerUp` → `focusNode` boundary, record gesture/pick data, dispatch to that variant controller, commit or clear via the adapter, then refresh visuals. `refreshEdges` must consume the active controller state only; it must never calculate or mutate selection independently.

- [ ] **Step 4: Run targeted and complete JS tests**

Run: `node tests/planet-signal-trace.test.mjs && node tests/planet-variant-controller.test.mjs && node tests/planet-globe-arc-adapter.test.mjs && node tests/planet-debug-panel.test.mjs && node tests/explore-galaxy-v3.test.mjs && for test in tests/*.test.mjs; do node "$test"; done`

Expected: all PASS.

### Task 6: Extract Explore Model and V5-family Visuals

**Files:**
- Create: `assets/explore/planet-data.js`
- Create: `assets/explore/planet-visuals.js`
- Modify: `assets/explore-galaxy-orb.js`
- Test: `tests/explore-galaxy-v3.test.mjs`

**Interfaces:**
- `planet-data.js` exports V3 layout, weighted-size, V5 snapshot and selection test seams.
- `planet-visuals.js` exports immutable V5/V6/V7 visual profiles and `contextVisualState(variant, state)`.

- [ ] **Step 1: Add source/import contract assertions**

Assert that main imports both modules and still re-exports the legacy model APIs. Assert the pure V5/V6/V7 transition and size tests remain unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `node tests/explore-galaxy-v3.test.mjs`

Expected: FAIL because exports still live in the monolithic file.

- [ ] **Step 3: Move only pure code**

Move constants and pure helpers without altering behavior. Keep Three/Globe lifecycle code in the main file. Re-export existing test seams from the main module to preserve current callers.

- [ ] **Step 4: Run full suite and syntax checks**

Run: `node --check assets/explore-galaxy-orb.js && for test in tests/*.test.mjs; do node "$test"; done`

Expected: all PASS.

## Plan self-review

- Covers the user’s four requested outcomes: smaller files, V5–V7 isolation, working highlight/arcs, and copyable on-screen debug.
- Keeps the single Globe renderer and avoids unrelated lighting/layout changes.
- Uses a focused RED→GREEN cycle before every production module.
- Universe and knowledge-map refactors are deliberately separate packages to avoid mixing a confirmed interaction bugfix with unrelated migration risk.
