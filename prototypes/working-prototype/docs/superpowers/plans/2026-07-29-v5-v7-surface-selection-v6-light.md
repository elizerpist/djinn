# V5–V7 Surface Selection Arcs and V6 Diffuse-Blue Light Implementation Plan

> **Execution status:** Tasks 1–3 and Task 4 steps 1, 3 and 4 are complete. Android/WebView screenshot evidence in Task 4 step 2 remains outstanding.

**Goal:** V5, V6 and V7 show one selected city's direct connections as thin, low, globe-hugging native Globe.gl arcs; V6 alone gets a broader, softer blue light response.

**Architecture:** A pure city-selection module owns stable top-edge selection and the low-altitude arc payload. The Explore renderer owns a view-bounded CitySelectionState and sends exactly that payload to Globe.gl. V6 remains an isolated light branch; no V5/V7 lighting object is changed.

**Tech Stack:** ES modules, Three.js, Globe.gl native arcs, Node.js test runner.

## Global Constraints

- Do not change node layout, size hierarchy, labels, camera/controls, glass-dome/cosmic environment or Community Caps logic.
- V5, V6 and V7 retain separate mutable focus sessions, pointer routers, visual configs and light rigs.
- City connection selection is deterministic: descending weight, then stable edge ID; at most 12 direct edges.
- Surface selection arcs use explicit numerical altitude only: 0.001 through 0.006. Globe.gl automatic altitude is forbidden.
- Surface selection arcs retain normal depth testing.
- V6 preserves its blue direction/palette. V5 and V7 material/light parameters must not change.
- Tests are written and observed failing before production code.
- Do not commit or reset the user-owned dirty worktree without an explicit request.

---

## File map

| File | Responsibility |
|---|---|
| assets/city-selection-arcs.js | Pure deterministic selection reducer and low-surface arc payload builder; no Three.js or DOM. |
| assets/explore-galaxy-orb.js | Active view state, Globe.gl adapter, low surface arc accessors and V6-only diffuse material/rig profile. |
| tests/city-selection-arcs.test.mjs | Pure selection, geo, dedupe, altitude and clear-transition tests. |
| tests/explore-galaxy-v3.test.mjs | V5/V6/V7 integration/isolation/dehighlight and V6-only light regression tests. |
| force-universe-checklist.md | EV5-18/19/20 and EV6-6 evidence status. |

## Interfaces

~~~js
// assets/city-selection-arcs.js
export const SURFACE_SELECTION_ARC_PROFILE = Object.freeze({
  altitude: .003,
  minAltitude: .001,
  maxAltitude: .006,
  curveResolution: 96,
  strokeMin: .018,
  strokeMax: .036,
  limit: 12,
});

export function createCitySelectionState() {
  return {
    ownerVariant: null,
    selectedCityId: null,
    selectedConnectionIds: [],
    selectedCityArcData: [],
  };
}

export function selectCityConnections({ variant, cityId, edges, nodesById, profile }) {
  // Returns a new CitySelectionState.
}

export function clearCityConnections() {
  return createCitySelectionState();
}

export function isSurfaceSelectionArc(arc) {
  return arc?.renderer === 'surface-selection-arc';
}
~~~

Every selectedCityArcData record contains a stable edge ID, source/target city IDs, source/target IDs, start/end lat/lng, explicit start/end/peak altitude, numeric weight, connection type, highlight flag, renderer marker and clamped stroke.

### Task 1: Pure city-selection module

**Files:**
- Create: assets/city-selection-arcs.js
- Create: tests/city-selection-arcs.test.mjs

**Consumes:** physics edges shaped as { source, target, weight, id?, type? } and Map<nodeId, { id, lat, lng }>.

**Produces:** selectCityConnections, clearCityConnections, isSurfaceSelectionArc and SURFACE_SELECTION_ARC_PROFILE.

- [x] **Step 1: Write the failing unit test**

Create tests/city-selection-arcs.test.mjs:

~~~js
import assert from 'node:assert/strict';
import {
  SURFACE_SELECTION_ARC_PROFILE,
  clearCityConnections,
  selectCityConnections,
} from '../assets/city-selection-arcs.js';

const nodes = new Map([
  ['a', { id: 'a', lat: 12, lng: 28 }],
  ['b', { id: 'b', lat: 18, lng: 36 }],
  ['c', { id: 'c', lat: -7, lng: 42 }],
  ['d', { id: 'd', lat: 30, lng: -12 }],
  ['bad', { id: 'bad', lat: Number.NaN, lng: 10 }],
]);
const edges = [
  { id: 'a-c', source: 'a', target: 'c', weight: .7, type: 'evidence' },
  { id: 'a-b', source: 'a', target: 'b', weight: .9, type: 'evidence' },
  { id: 'a-b-low', source: 'a', target: 'b', weight: .2, type: 'evidence' },
  { id: 'a-d', source: 'a', target: 'd', weight: .7, type: 'evidence' },
  { id: 'a-missing', source: 'a', target: 'missing', weight: 1, type: 'evidence' },
  { id: 'a-bad', source: 'a', target: 'bad', weight: 1, type: 'evidence' },
];

const state = selectCityConnections({ variant: 'v6', cityId: 'a', edges, nodesById: nodes });
assert.equal(state.ownerVariant, 'v6');
assert.equal(state.selectedCityId, 'a');
assert.deepEqual(state.selectedConnectionIds, ['a-b', 'a-c', 'a-d']);
assert.equal(state.selectedCityArcData.length, 3);
for (const arc of state.selectedCityArcData) {
  assert.equal(arc.renderer, 'surface-selection-arc');
  assert.equal(arc.source, 'a');
  assert.ok(Number.isFinite(arc.startLat) && Number.isFinite(arc.startLng));
  assert.ok(Number.isFinite(arc.endLat) && Number.isFinite(arc.endLng));
  assert.ok(arc.startAltitude >= .001 && arc.startAltitude <= .006);
  assert.equal(arc.startAltitude, arc.endAltitude);
  assert.equal(arc.startAltitude, arc.peakAltitude);
  assert.ok(arc.stroke >= .018 && arc.stroke <= .036);
}
assert.equal(SURFACE_SELECTION_ARC_PROFILE.curveResolution, 96);
assert.deepEqual(clearCityConnections(), {
  ownerVariant: null, selectedCityId: null, selectedConnectionIds: [], selectedCityArcData: [],
});
~~~

- [x] **Step 2: Verify RED**

Run:

~~~sh
node --test tests/city-selection-arcs.test.mjs
~~~

Expected: failure because assets/city-selection-arcs.js does not exist.

- [x] **Step 3: Implement the smallest deterministic selector**

Create assets/city-selection-arcs.js:

~~~js
export const SURFACE_SELECTION_ARC_PROFILE = Object.freeze({
  altitude: .003, minAltitude: .001, maxAltitude: .006,
  curveResolution: 96, strokeMin: .018, strokeMax: .036, limit: 12,
});

const edgeId = (edge) => String(edge.id || [edge.source, edge.target].sort().join('::'));
const pairId = (edge) => [edge.source, edge.target].sort().join('::');
const validNode = (node) => Number.isFinite(Number(node?.lat)) && Number.isFinite(Number(node?.lng));

export function createCitySelectionState() {
  return { ownerVariant: null, selectedCityId: null, selectedConnectionIds: [], selectedCityArcData: [] };
}
export function clearCityConnections() { return createCitySelectionState(); }
export function isSurfaceSelectionArc(arc) { return arc?.renderer === 'surface-selection-arc'; }

export function selectCityConnections({
  variant, cityId, edges, nodesById, profile = SURFACE_SELECTION_ARC_PROFILE,
}) {
  const source = nodesById?.get(cityId);
  if (!['v5', 'v6', 'v7'].includes(variant) || !validNode(source)) return clearCityConnections();
  const uniquePairs = new Map();
  [...edges]
    .filter((edge) => edge.source === cityId || edge.target === cityId)
    .sort((a, b) => (Number(b.weight) - Number(a.weight)) || edgeId(a).localeCompare(edgeId(b)))
    .forEach((edge) => {
      const targetId = edge.source === cityId ? edge.target : edge.source;
      if (!uniquePairs.has(pairId(edge)) && validNode(nodesById.get(targetId))) uniquePairs.set(pairId(edge), edge);
    });
  const selected = [...uniquePairs.values()].slice(0, profile.limit);
  const altitude = Math.min(profile.maxAltitude, Math.max(profile.minAltitude, profile.altitude));
  const maxWeight = Math.max(...selected.map((edge) => Number(edge.weight) || 0), 1);
  const arcs = selected.map((edge) => {
    const targetId = edge.source === cityId ? edge.target : edge.source;
    const target = nodesById.get(targetId);
    const ratio = Math.max(0, Math.min(1, (Number(edge.weight) || 0) / maxWeight));
    return {
      id: 'surface:' + edgeId(edge), edgeId: edgeId(edge),
      sourceCityId: cityId, targetCityId: targetId, source: cityId, target: targetId,
      startLat: Number(source.lat), startLng: Number(source.lng),
      endLat: Number(target.lat), endLng: Number(target.lng),
      startAltitude: altitude, endAltitude: altitude, peakAltitude: altitude,
      weight: Number(edge.weight) || 0, connectionType: String(edge.type || 'direct'),
      stroke: profile.strokeMin + ((profile.strokeMax - profile.strokeMin) * ratio),
      highlight: true, renderer: 'surface-selection-arc',
    };
  });
  return {
    ownerVariant: variant, selectedCityId: cityId,
    selectedConnectionIds: arcs.map((arc) => arc.edgeId), selectedCityArcData: arcs,
  };
}
~~~

- [x] **Step 4: Verify GREEN**

Run:

~~~sh
node --test tests/city-selection-arcs.test.mjs
~~~

Expected: PASS.

### Task 2: Project the shared payload through each V5/V6/V7 Globe renderer

**Files:**
- Modify: assets/explore-galaxy-orb.js:1-10, 890-960, 1770-1818, 1913-2110, 2342-2385, 2530-2541, 2638-2688, 3010-3034
- Modify: tests/explore-galaxy-v3.test.mjs

**Consumes:** Task 1 module plus V3_PHYSICS_EDGES, nodeById and the existing independent V5/V6/V7 focus sessions.

**Produces:** applyCitySelection, clearCitySelection, selectedSurfaceArcEndpointAltitude and one active Globe payload.

- [x] **Step 1: Write failing integration tests**

Append to tests/explore-galaxy-v3.test.mjs:

~~~js
const { __surfaceSelectionArcTestModel } =
  await import('../assets/explore-galaxy-orb.js?test-surface-selection');
const firstCity = getV5PlanetVisualSnapshot().atoms[0].id;
const selection = __surfaceSelectionArcTestModel.select('v5', firstCity);
assert.equal(selection.ownerVariant, 'v5');
assert.ok(selection.selectedCityArcData.length >= 1 && selection.selectedCityArcData.length <= 12);
assert.ok(selection.selectedCityArcData.every((arc) => arc.renderer === 'surface-selection-arc'));
assert.ok(selection.selectedCityArcData.every((arc) => arc.startAltitude >= .001 && arc.startAltitude <= .006));
assert.equal(__surfaceSelectionArcTestModel.endpointAltitude(selection.selectedCityArcData[0], 'start'), .003);
assert.deepEqual(__surfaceSelectionArcTestModel.arcProfile(selection.selectedCityArcData[0]), {
  autoScale: 0, curveResolution: 96, stroke: selection.selectedCityArcData[0].stroke,
});
assert.deepEqual(__surfaceSelectionArcTestModel.clear(), {
  ownerVariant: null, selectedCityId: null, selectedConnectionIds: [], selectedCityArcData: [],
});
~~~

Add source checks:

~~~js
assert.doesNotMatch(orbSource, /function v5FocusArcs\(\)[\s\S]*safeV5ArcAltitude/);
assert.match(orbSource, /selectedSurfaceArcEndpointAltitude/);
assert.match(orbSource, /renderer === 'surface-selection-arc'/);
~~~

- [x] **Step 2: Verify RED**

Run:

~~~sh
node --test tests/explore-galaxy-v3.test.mjs
~~~

Expected: failure because the surface-selection test model and adapter do not exist.

- [x] **Step 3: Add state/reducer bridge, keeping view sessions isolated**

Import Task 1. Near focusedNode add:

~~~js
let citySelectionState = clearCityConnections();

function applyCitySelection(cityId) {
  citySelectionState = selectCityConnections({
    variant: orbVariant, cityId, edges: V3_PHYSICS_EDGES, nodesById,
  });
  return citySelectionState;
}
function clearCitySelection() {
  citySelectionState = clearCityConnections();
  return citySelectionState;
}
function selectedSurfaceArcEndpointAltitude(arc, endpoint) {
  if (isSurfaceSelectionArc(arc)) {
    return endpoint === 'start' ? arc.startAltitude : arc.endAltitude;
  }
  return arcEndpointAltitude(arc, endpoint);
}
~~~

Call clearCitySelection before the existing native arc clear in resetFocusForVariantSwitch. In the V5-family focusNode branch, call applyCitySelection(node.id) on focus and clearCitySelection on repeat-tap dehighlight. Do not modify V5/V6/V7 focus-session or pointer-router ownership.

- [x] **Step 4: Replace the high selected-arc generator**

Replace the body of v5FocusArcs:

~~~js
function v5FocusArcs() {
  return isV5Variant() && citySelectionState.ownerVariant === orbVariant
    ? citySelectionState.selectedCityArcData
    : [];
}
~~~

Use that same function for activeEdges and the V5-family refreshEdges branch:

~~~js
if (isV5Variant()) {
  djinnEdgeLayer?.setVisible(false);
  globe.arcsData(v5FocusArcs());
  return;
}
~~~

The old safeV5ArcAltitude/v5ArcPoints functions may remain for historical non-selection code only; no selected surface arc may call them.

- [x] **Step 5: Apply the low surface Globe.gl profile**

Replace the Globe initialization endpoint accessors:

~~~js
.arcStartAltitude((arc) => selectedSurfaceArcEndpointAltitude(arc, 'start'))
.arcEndAltitude((arc) => selectedSurfaceArcEndpointAltitude(arc, 'end'))
~~~

In applyArcProfile add selected-surface branches before legacy focus branches:

~~~js
globe.arcCurveResolution(isV5Variant() ? SURFACE_SELECTION_ARC_PROFILE.curveResolution : 64);
globe.arcAltitude((edge) => isSurfaceSelectionArc(edge) ? edge.peakAltitude : /* existing branches */);
globe.arcAltitudeAutoScale((edge) => isSurfaceSelectionArc(edge) ? 0 : /* existing branches */);
globe.arcStroke((edge) => isSurfaceSelectionArc(edge) ? edge.stroke : /* existing branches */);
globe.arcDashLength((edge) => isSurfaceSelectionArc(edge) ? 1 : /* existing branches */);
globe.arcDashGap((edge) => isSurfaceSelectionArc(edge) ? 0 : /* existing branches */);
globe.arcDashAnimateTime((edge) => isSurfaceSelectionArc(edge) ? 0 : /* existing branches */);
~~~

Keep normal depth test. Use existing cyan for normal selected relationships and gold only for the active relationship; introduce no white production edge layer.

- [x] **Step 6: Expose a narrow test seam and verify GREEN**

Add:

~~~js
export const __surfaceSelectionArcTestModel = Object.freeze({
  select: (variant, cityId) => selectCityConnections({
    variant,
    cityId,
    edges: V3_PHYSICS_EDGES,
    nodesById: new Map(getV5PlanetVisualSnapshot().atoms.map((atom) => [atom.id, atom])),
  }),
  clear: () => clearCityConnections(),
  endpointAltitude: selectedSurfaceArcEndpointAltitude,
  arcProfile: (arc) => ({
    autoScale: isSurfaceSelectionArc(arc) ? 0 : null,
    curveResolution: isSurfaceSelectionArc(arc) ? SURFACE_SELECTION_ARC_PROFILE.curveResolution : null,
    stroke: isSurfaceSelectionArc(arc) ? arc.stroke : null,
  }),
});
~~~

Run:

~~~sh
node --test tests/city-selection-arcs.test.mjs tests/explore-galaxy-v3.test.mjs
~~~

Expected: PASS.

- [x] **Step 7: Add dehighlight and cross-view regression coverage**

Add a reducer test that selects an actual first and second atom, clears, then repeats for v5/v6/v7:

~~~js
const atomIds = getV5PlanetVisualSnapshot().atoms.slice(0, 2).map((atom) => atom.id);
for (const variant of ['v5', 'v6', 'v7']) {
  const first = __surfaceSelectionArcTestModel.select(variant, atomIds[0]);
  const second = __surfaceSelectionArcTestModel.select(variant, atomIds[1]);
  assert.ok(first.selectedCityArcData.every((arc) => arc.source === atomIds[0]));
  assert.ok(second.selectedCityArcData.every((arc) => arc.source === atomIds[1]));
  assert.equal(__surfaceSelectionArcTestModel.clear().selectedCityArcData.length, 0);
}
~~~

Run the targeted tests; retain every existing dim/idle/repeat-tap assertion.

### Task 3: Soften only the V6 blue light

**Files:**
- Modify: assets/explore-galaxy-orb.js:120-130 and 1332-1370
- Modify: tests/explore-galaxy-v3.test.mjs

**Consumes:** existing V6 virtual sun direction, key/fill/rim lights and MeshPhongMaterial.

**Produces:** a V6-only diffuse-blue profile; V5/V7 remain unchanged.

- [x] **Step 1: Write the failing V6-isolation test**

Append:

~~~js
const { __v6DiffuseLightTestModel } =
  await import('../assets/explore-galaxy-orb.js?test-v6-diffuse');
const diffuse = __v6DiffuseLightTestModel.profile();
assert.deepEqual(diffuse, {
  keyIntensity: 1.95, fillIntensity: .68, rimIntensity: .30,
  shininess: 16, specular: '#4EA8C6',
});
assert.deepEqual(__v6DiffuseLightTestModel.affectsVariants(), {
  v5: false, v6: true, v7: false,
});
~~~

- [x] **Step 2: Verify RED**

Run:

~~~sh
node --test tests/explore-galaxy-v3.test.mjs
~~~

Expected: failure because the test seam is absent and V6 still uses 2.55/.62/34.

- [x] **Step 3: Implement the V6-only profile**

Replace only V6 profile values:

~~~js
const V6_HYBRID_LIGHT = Object.freeze({
  keyIntensity: 1.95,
  fillIntensity: .68,
  rimIntensity: .30,
  cameraOrbitInfluence: .16,
  lightLagMs: 120,
  keyDistance: 300,
  rimDistance: 260,
  sunDirection: Object.freeze([-.62, .48, .62]),
  specular: '#4EA8C6',
  shininess: 16,
  emissive: '#0B102C',
  emissiveIntensity: .045,
});
~~~

In the isV6Variant material branch use exactly V6_HYBRID_LIGHT.specular, shininess, emissive and emissiveIntensity. Leave the V5 branch and VirtualGalaxyLightingRig untouched.

- [x] **Step 4: Export the profile seam and verify GREEN**

Add:

~~~js
export const __v6DiffuseLightTestModel = Object.freeze({
  profile: () => ({
    keyIntensity: V6_HYBRID_LIGHT.keyIntensity,
    fillIntensity: V6_HYBRID_LIGHT.fillIntensity,
    rimIntensity: V6_HYBRID_LIGHT.rimIntensity,
    shininess: V6_HYBRID_LIGHT.shininess,
    specular: V6_HYBRID_LIGHT.specular,
  }),
  affectsVariants: () => ({ v5: false, v6: true, v7: false }),
});
~~~

Run:

~~~sh
node --test tests/explore-galaxy-v3.test.mjs
~~~

Expected: PASS; existing V5/V7 isolation assertions remain green.

### Task 4: Full verification and evidence

**Files:**
- Modify: force-universe-checklist.md
- Verify: assets/city-selection-arcs.js, assets/explore-galaxy-orb.js, tests/*.test.mjs

**Consumes:** Tasks 1–3.

**Produces:** honest automated/runtime evidence; no commit without a request.

- [x] **Step 1: Run static and full automated verification**

~~~sh
node --check assets/city-selection-arcs.js
node --check assets/explore-galaxy-orb.js
node --test tests/*.test.mjs
git diff --check
~~~

Expected: every command exits 0.

- [ ] **Step 2: Capture runtime evidence**

On Android/WebView capture:
1. V5 selected city: 1–12 thin cyan/gold arcs hug the surface while orbiting.
2. V6 selected city: identical arc geometry; blue lit hemisphere is broader/softer than V6 Original Light.
3. V7 selected city: same arcs remain visible above the globe and behind no cosmic object.
4. Each V5/V6/V7: repeat tap clears arcs and restores idle neon.
5. V5→V6→V7: no stale arc or selected-city state leaks.

- [x] **Step 3: Update checklist status**

Set EV5-18, EV5-19, EV5-20 and EV6-6 to PARTIAL after green automated checks. Mark DONE only after their Android screenshots prove the runtime acceptance conditions.

- [x] **Step 4: Handoff without a commit**

Report changed files, exact test results and any missing Android proof. Do not claim full completion while a checklist item remains PARTIAL.

## Self-review

### Spec coverage

- EV5-18 is covered by Tasks 1 and 2.
- EV5-19 is covered by Task 2's explicit profile/accessor work.
- EV5-20 is covered by Task 2 state transitions and Task 4 runtime proof.
- EV6-6 is covered by Task 3 and Task 4 comparison evidence.
- Global constraints protect V5/V7 lighting, layout, labels, camera, glass dome and cosmic environment.

### Placeholder scan

The plan contains no deferred implementation markers, unspecified test command, undefined file path or unbounded implementation step.

### Interface consistency

Task 1 defines the four imports consumed by Task 2. Task 2 defines the two test seams used by Tasks 2 and 3. Task 3 does not change selection types or V5/V7 interfaces.
