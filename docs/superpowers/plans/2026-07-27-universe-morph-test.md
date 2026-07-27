# Universe Morph Test Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated, mock-data test screen that animates inline from a 3D Force Graph galaxy to a purple ThreeGlobe planet and then to a flat G6-style map.

**Architecture:** The first two levels share one `3d-force-graph` scene, camera, renderer, controls instance and one reusable `ThreeGlobe` object attached to the selected planet node's `THREE.Group`. The map is a separate, pre-mounted but inactive 2D layer in the same test-screen container; a DOM shared-element proxy bridges the selected yellow 3D planet node into its purple flat-map focus node. Pure mock-data, selection, gesture, projection and state-transition utilities live in a separate module so they can be tested without WebGL or a browser.

**Tech Stack:** Static HTML prototype, ES modules, Three.js, 3d-force-graph, vendored ThreeGlobe UMD build, G6, CSS, Node `assert` tests.

## Global Constraints

- Add only the development route `#universe-morph-test`; never route between GALAXY, PLANET and MAP levels.
- Use only deterministic mock data with `TEST_SEED = 42`: Galaxy 180 nodes/260 links/8 planets, Planet 140 nodes/210 links, Map 28 nodes/42 links.
- Do not change the Explore or Workspace bottom navigation, dropdown, breadcrumb, search, existing production graph view behaviour or production data.
- Galaxy and Planet share one 3d-force-graph `scene()`, `camera()`, `renderer()` and `controls()`; do not mount a standalone Globe.gl canvas.
- Exactly one reusable `ThreeGlobe` object may exist for the galaxy-to-planet transition.
- Transition progress runs in `requestAnimationFrame`; do not call React state or rebuild the force graph on every frame.
- Pointer taps require less than 8 px movement and at most 300 ms duration; drag and pinch must never select a node.
- The detailed Planet layer has 140 tappable yellow spherical nodes and 210 subtle surface-following links.
- The flat Map layer is mock-only, appears in the same container, and receives pointer events only in `MAP`.
- Maintain the approved acceptance checklist in `docs/superpowers/specs/2026-07-27-universe-morph-test-design.md`; do not mark an item DONE without evidence.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `prototypes/working-prototype/assets/universe-morph-model.js` | Deterministic PRNG/mock graph generation, Fibonacci sphere positions, tap classification, projection helpers, state transition validation, geometry-independent calculations. |
| `prototypes/working-prototype/assets/universe-morph-test.js` | Test-screen renderer lifecycle, Galaxy/Planet/Map layers, camera tweening, ThreeGlobe attachment, raycasting, morph proxy, Debug HUD, cleanup. |
| `prototypes/working-prototype/assets/universe-morph-test.css` | Fully namespaced `universe-morph-*` screen, canvas, overlay, transition and HUD styling. |
| `prototypes/working-prototype/screens/universe-morph-test.html` | Isolated test-screen shell and renderer mount points. |
| `prototypes/working-prototype/assets/app.js` | Minimal hash-route registration and lifecycle call to `initUniverseMorphTest`; no production view selector changes. |
| `prototypes/working-prototype/index.html` | Load the isolated CSS asset once alongside existing styles. |
| `prototypes/working-prototype/tests/universe-morph-model.test.mjs` | Deterministic unit tests for all pure graph, layout, gesture and state utilities. |

## Interfaces

```js
// assets/universe-morph-model.js
export const TEST_SEED = 42;
export const UNIVERSE_LEVEL = Object.freeze({
  GALAXY: 'GALAXY',
  GALAXY_TO_PLANET: 'GALAXY_TO_PLANET',
  PLANET: 'PLANET',
  PLANET_TO_MAP: 'PLANET_TO_MAP',
  MAP: 'MAP',
  MAP_TO_PLANET: 'MAP_TO_PLANET',
  PLANET_TO_GALAXY: 'PLANET_TO_GALAXY',
});

export function createUniverseMockData(seed = TEST_SEED);
// => { galaxy: { nodes, links, planetIds }, planet: { nodes, links }, map: { nodes, links } }

export function fibonacciSpherePoint(index, count, radius, altitude = 0);
// => { x, y, z, lat, lng }

export function classifyPointerTap(start, end, endedAt);
// start/end: { x, y, startedAt }, { x, y }; => boolean

export function projectPointToScreen(point, camera, width, height);
// point must expose clone().project(camera); => { x, y, ndcZ }

export function canTransition(level, targetLevel);
// => boolean

// assets/universe-morph-test.js
export function initUniverseMorphTest(root, helpers = {});
// => () => void
```

### Task 1: Add deterministic model utilities and their test harness

**Files:**
- Create: `prototypes/working-prototype/assets/universe-morph-model.js`
- Create: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`

**Consumes:** no browser globals, only JavaScript built-ins.

**Produces:** deterministic three-level mock data and testable geometry/gesture/state helpers consumed by every renderer task.

- [x] **Step 1: Write the failing model test**

Create `tests/universe-morph-model.test.mjs` with these exact behavioural checks:

```js
import assert from 'node:assert/strict';
import {
  TEST_SEED,
  UNIVERSE_LEVEL,
  canTransition,
  classifyPointerTap,
  createUniverseMockData,
  fibonacciSpherePoint,
} from '../assets/universe-morph-model.js';

const first = createUniverseMockData(TEST_SEED);
const repeated = createUniverseMockData(TEST_SEED);

assert.equal(first.galaxy.nodes.length, 180);
assert.equal(first.galaxy.links.length, 260);
assert.equal(first.galaxy.planetIds.length, 8);
assert.equal(first.planet.nodes.length, 140);
assert.equal(first.planet.links.length, 210);
assert.equal(first.map.nodes.length, 28);
assert.equal(first.map.links.length, 42);
assert.deepEqual(first, repeated, 'the mock universe must be repeatable from one seed');
assert.equal(new Set(first.galaxy.nodes.map((node) => node.id)).size, 180);
assert.ok(first.galaxy.planetIds.every((id) => first.galaxy.nodes.find((node) => node.id === id)?.isPlanet));

const point = fibonacciSpherePoint(11, 140, 100, .02);
assert.ok(Math.abs(Math.hypot(point.x, point.y, point.z) - 102) < 1e-8);
assert.ok(point.lat >= -90 && point.lat <= 90);
assert.ok(point.lng >= -180 && point.lng <= 180);

assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 18, y: 17, endedAt: 390 }), true);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 23, y: 12, endedAt: 220 }), false);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 12, y: 12, endedAt: 401 }), false);

assert.equal(canTransition(UNIVERSE_LEVEL.GALAXY, UNIVERSE_LEVEL.GALAXY_TO_PLANET), true);
assert.equal(canTransition(UNIVERSE_LEVEL.PLANET, UNIVERSE_LEVEL.PLANET_TO_MAP), true);
assert.equal(canTransition(UNIVERSE_LEVEL.MAP, UNIVERSE_LEVEL.PLANET_TO_MAP), false);
```

- [x] **Step 2: Run the test to verify it fails because the module is absent**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: `ERR_MODULE_NOT_FOUND` for `assets/universe-morph-model.js`.

- [x] **Step 3: Implement the deterministic model module**

Create `assets/universe-morph-model.js` with a seeded Mulberry32 PRNG, fixed sequential IDs, no `Math.random()`, and these exact data invariants:

```js
export const TEST_SEED = 42;
export const TAP_MOVE_THRESHOLD_PX = 8;
export const TAP_DURATION_THRESHOLD_MS = 300;

export const UNIVERSE_LEVEL = Object.freeze({
  GALAXY: 'GALAXY', GALAXY_TO_PLANET: 'GALAXY_TO_PLANET',
  PLANET: 'PLANET', PLANET_TO_MAP: 'PLANET_TO_MAP', MAP: 'MAP',
  MAP_TO_PLANET: 'MAP_TO_PLANET', PLANET_TO_GALAXY: 'PLANET_TO_GALAXY',
});

export function fibonacciSpherePoint(index, count, radius, altitude = 0) {
  const phi = Math.acos(1 - (2 * (index + .5)) / count);
  const theta = Math.PI * (3 - Math.sqrt(5)) * index;
  const r = radius * (1 + altitude);
  const x = r * Math.sin(phi) * Math.cos(theta);
  const y = r * Math.cos(phi);
  const z = r * Math.sin(phi) * Math.sin(theta);
  return { x, y, z, lat: 90 - phi * 180 / Math.PI, lng: ((theta * 180 / Math.PI + 540) % 360) - 180 };
}

export function classifyPointerTap(start, end, endedAt) {
  return Math.hypot(end.x - start.x, end.y - start.y) <= TAP_MOVE_THRESHOLD_PX
    && endedAt - start.startedAt <= TAP_DURATION_THRESHOLD_MS;
}

export function canTransition(level, targetLevel) {
  return new Set([
    `${UNIVERSE_LEVEL.GALAXY}:${UNIVERSE_LEVEL.GALAXY_TO_PLANET}`,
    `${UNIVERSE_LEVEL.GALAXY_TO_PLANET}:${UNIVERSE_LEVEL.PLANET}`,
    `${UNIVERSE_LEVEL.PLANET}:${UNIVERSE_LEVEL.PLANET_TO_MAP}`,
    `${UNIVERSE_LEVEL.PLANET_TO_MAP}:${UNIVERSE_LEVEL.MAP}`,
    `${UNIVERSE_LEVEL.MAP}:${UNIVERSE_LEVEL.MAP_TO_PLANET}`,
    `${UNIVERSE_LEVEL.MAP_TO_PLANET}:${UNIVERSE_LEVEL.PLANET}`,
    `${UNIVERSE_LEVEL.PLANET}:${UNIVERSE_LEVEL.PLANET_TO_GALAXY}`,
    `${UNIVERSE_LEVEL.PLANET_TO_GALAXY}:${UNIVERSE_LEVEL.GALAXY}`,
  ]).has(`${level}:${targetLevel}`);
}
```

Use the PRNG to produce connected, duplicate-free link pairs; reserve `galaxy-000` through `galaxy-007` as planet IDs. Give every node the deterministic labels specified in the approved spec (`Bolygó 1`, `Fogalom 1`, `Kapcsolat 1`, and so on).

- [x] **Step 4: Run the model test and the existing focused-map regression test**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node prototypes/working-prototype/tests/focused-g6-map.test.mjs
```

Expected: the new test prints a success marker; the existing test remains successful.

- [x] **Step 5: Commit the model layer**

```sh
git add prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: add deterministic universe morph mock data"
```

### Task 2: Add the isolated screen shell, stylesheet and dev route

**Files:**
- Create: `prototypes/working-prototype/screens/universe-morph-test.html`
- Create: `prototypes/working-prototype/assets/universe-morph-test.css`
- Create: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/index.html`
- Modify: `prototypes/working-prototype/assets/app.js`

**Consumes:** no renderer yet; a temporary no-op `initUniverseMorphTest(root, helpers)` module keeps the route valid until Task 3.

**Produces:** an independently addressable `#universe-morph-test` route with an empty but styled test harness; no existing navigation or display mode is changed.

- [x] **Step 1: Write the failing route/source-contract checks**

Append these source checks to `tests/universe-morph-model.test.mjs`:

```js
import { readFile } from 'node:fs/promises';

const appSource = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const screenSource = await readFile(new URL('../screens/universe-morph-test.html', import.meta.url), 'utf8');
assert.match(appSource, /'universe-morph-test': 'screens\/universe-morph-test\.html'/);
assert.match(appSource, /initUniverseMorphTest\(root, \{ showToast, navigate \}\)/);
assert.match(screenSource, /data-universe-morph-test/);
assert.match(screenSource, /data-universe-galaxy/);
assert.match(screenSource, /data-universe-map/);
```

- [x] **Step 2: Run the test to verify it fails**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: assertion failure because the route and screen do not exist.

- [x] **Step 3: Add the markup, isolated CSS and minimal route wiring**

Create `screens/universe-morph-test.html` with a normal `.screen` and `.top-bar` so existing `createFixedScreenLayout()` works. The complete renderer shell must be:

```html
<section class="screen universe-morph-screen" aria-label="Universe morph teszt">
  <header class="top-bar compact">
    <button class="back-button" data-route="workspace-topic-connections" aria-label="Vissza">‹</button>
    <div><span class="eyebrow">DEVELOPER TEST</span><h2>Universe morph</h2></div>
  </header>
  <main class="universe-morph-test" data-universe-morph-test>
    <div class="universe-morph-stage" data-universe-stage>
      <div class="universe-morph-galaxy" data-universe-galaxy aria-label="3D Force Graph galaxis"></div>
      <div class="universe-morph-map" data-universe-map hidden aria-label="Lapos mock tudástérkép"></div>
      <div class="universe-morph-proxy" data-universe-proxy hidden></div>
      <aside class="universe-morph-debug" data-universe-debug></aside>
    </div>
  </main>
</section>
```

Create CSS entirely under `.universe-morph-*`. The stage must have `position: relative`, `min-height: 520px`, overflow hidden, deep-space violet background, and `touch-action: none`. The map layer must cover the stage with `position: absolute; inset: 0`, begin with `opacity: 0; pointer-events: none`, and only gain pointer events under `.is-map-active`. The proxy must be absolute with `transform: translate(-50%, -50%)`, 50% initial radius, and no pointer events.

In `index.html`, add a separate stylesheet link immediately after `assets/styles.css`. In `app.js`, add the new import, route value, and only this route-specific initializer:

```js
if (normalized === 'universe-morph-test') {
  destroyScreen = initUniverseMorphTest(root, { showToast, navigate });
}
```

Do not edit `activeNav`, the bottom-nav markup, `initKnowledgeMap`, or any view-dropdown code.

Create the first, deliberately no-op `assets/universe-morph-test.js` so the imported route is runnable before the renderer task:

```js
export function initUniverseMorphTest(root) {
  const mount = root.querySelector('[data-universe-morph-test]');
  if (!mount) return () => {};
  return () => {};
}
```

- [x] **Step 4: Run source contracts and syntax checks**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node --check prototypes/working-prototype/assets/app.js
git diff --check
```

Expected: all commands exit zero; the test still has no renderer dependency.

- [x] **Step 5: Commit the isolated shell**

```sh
git add prototypes/working-prototype/screens/universe-morph-test.html \
  prototypes/working-prototype/assets/universe-morph-test.css \
  prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/index.html \
  prototypes/working-prototype/assets/app.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: add universe morph test screen shell"
```

### Task 3: Implement GalaxyForceLayer with stable large planet-node selection

**Files:**
- Modify: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-model.js`
- Modify: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`

**Consumes:** `createUniverseMockData`, `classifyPointerTap`, `UNIVERSE_LEVEL`; global `window.ForceGraph3D` and vendored Three.js module.

**Produces:** `initUniverseMorphTest(root, helpers)` that creates the galaxy render and returns an idempotent cleanup callback.

- [x] **Step 1: Add failing pure-selection tests**

Export and test a pure degree/radius helper:

```js
import { galaxyNodeRadius } from '../assets/universe-morph-model.js';

assert.ok(galaxyNodeRadius(0, 0, 12) < galaxyNodeRadius(4, 0, 12));
assert.ok(galaxyNodeRadius(4, 0, 12) < galaxyNodeRadius(12, 0, 12));
assert.ok(galaxyNodeRadius(12, 0, 12) <= 6.4);
```

- [x] **Step 2: Run the test to verify it fails**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: missing `galaxyNodeRadius` export error.

- [x] **Step 3: Implement the galaxy render with one node root group per node**

In `universe-morph-model.js`, implement a square-root bounded radius function:

```js
export function galaxyNodeRadius(degree, minDegree, maxDegree) {
  if (maxDegree <= minDegree) return 1.5;
  const normalized = Math.max(0, Math.min(1, (degree - minDegree) / (maxDegree - minDegree)));
  return 1.5 + Math.sqrt(normalized) * 4.7;
}
```

In `universe-morph-test.js`, import `THREE` from `./vendor/three.module.min.js?rev=92`, set `window.THREE = THREE` before requesting ThreeGlobe, and create the Galaxy layer through `new window.ForceGraph3D(galaxyMount, { controlType: 'orbit' })`.

Configure it with:

```js
graph
  .graphData(mock.galaxy)
  .backgroundColor('#0b0a17')
  .nodeThreeObject(createGalaxyNodeRoot)
  .nodeLabel(() => '')
  .linkColor(() => 'rgba(201,196,255,.28)')
  .linkOpacity(.34)
  .linkWidth(.42)
  .cooldownTicks(90)
  .cooldownTime(900);
```

`createGalaxyNodeRoot(node)` must create a `THREE.Group` containing:

```js
const proxySphere = new THREE.Mesh(sharedSphereGeometry, createPlanetMaterial(node));
const glow = new THREE.Mesh(sharedSphereGeometry, new THREE.MeshBasicMaterial({
  color: 0x8f6bff, transparent: true, opacity: node.isPlanet ? .16 : .06,
  depthWrite: false, side: THREE.BackSide,
}));
const ring = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.22, .09, 8, 30), selectedRingMaterial);
```

Store `{ root, proxySphere, glow, ring, radius }` in `planetViews` keyed by node ID. Only `node.isPlanet` nodes receive raycast selection; unrelated small nodes remain visual context. Add one point light, one ambient light, and ensure the renderer remains the one owned by 3d-force-graph.

Install pointerdown/pointerup on the force container; use `classifyPointerTap`. On a valid tap, convert client coordinates to NDC, call a `THREE.Raycaster` against only the large planet root objects, choose the closest hit, and call `requestPlanetEntry(node.id)`. Do not use `onNodeClick` because the explicit tap gate must reject a drag.

Implement cleanup that removes pointer and controls listeners, cancels requestAnimationFrame, calls `graph._destructor?.()`, clears the mount, and disposes materials owned by this screen.

- [x] **Step 4: Run tests and syntax checks**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node --check prototypes/working-prototype/assets/universe-morph-test.js
git diff --check
```

Expected: pure tests pass and the module parses without starting WebGL.

- [x] **Step 5: Commit the galaxy layer**

```sh
git add prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: render tappable universe morph galaxy"
```

### Task 4: Add camera snapshots and the Galaxy → Planet scene morph

**Files:**
- Modify: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-model.js`
- Modify: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`

**Consumes:** Galaxy `planetViews`, force graph `camera()`/`controls()`/`scene()`/`renderer()`, `UNIVERSE_LEVEL`.

**Produces:** `requestPlanetEntry(planetId)` and a reusable, single scene-attached purple `ThreeGlobe` detailed planet.

- [x] **Step 1: Add failing state/camera helper tests**

Add and test these pure utilities:

```js
import { easeInOutCubic, focusCameraTarget } from '../assets/universe-morph-model.js';

assert.equal(easeInOutCubic(0), 0);
assert.equal(easeInOutCubic(1), 1);
assert.ok(easeInOutCubic(.5) > .49 && easeInOutCubic(.5) < .51);
assert.deepEqual(
  focusCameraTarget({ x: 4, y: 5, z: 6 }, { x: 0, y: 0, z: 20 }, { x: 0, y: 0, z: 0 }, 12),
  { x: 4, y: 5, z: 18 },
);
```

- [x] **Step 2: Run the test to verify it fails**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: missing helper export assertion failure.

- [x] **Step 3: Implement camera tween and reusable detail planet**

Implement the helpers exactly as pure Vector-like object operations. `focusCameraTarget(node, camera, previousTarget, distance)` must normalize `(camera - previousTarget)` and add `distance` along that direction to the node.

In the renderer module, add:

```js
const state = {
  level: UNIVERSE_LEVEL.GALAXY,
  selectedGalaxyNodeId: null,
  selectedPlanetNodeId: null,
  transitionProgress: 0,
  interactionLocked: false,
  savedGalaxyCamera: null,
  savedPlanetCamera: null,
};
```

`requestPlanetEntry(planetId)` must reject if `state.level !== UNIVERSE_LEVEL.GALAXY` or locked. It must snapshot:

```js
{
  position: graph.camera().position.clone(),
  target: graph.controls().target.clone(),
}
```

Then set the selected ring/glow, reduce nonselected node material opacity to `.16`, reduce graph link opacity to `.07`, and animate camera position plus controls target for 560 ms. The end camera position uses the selected node world position and `view.radius * 6`; update `controls.target` and call `controls.update()` every tween frame.

Load ThreeGlobe only once with a Promise that resolves `window.ThreeGlobe`. Create the object once:

```js
detailGlobe = new window.ThreeGlobe({ animateIn: false, waitForGlobeReady: false })
  .showGlobe(true)
  .showAtmosphere(true)
  .atmosphereColor('#8f6bff')
  .atmosphereAltitude(.12)
  .globeImageUrl(null);
detailGlobe.globeMaterial(new THREE.MeshStandardMaterial({
  color: 0x6337d5, roughness: .72, metalness: .04,
  emissive: 0x25104e, emissiveIntensity: .18,
}));
```

Attach this same object to the selected root group, use `detailGlobe.getGlobeRadius()` to scale it to `view.radius`, and never instantiate a second `ThreeGlobe`. Run the morph for 520 ms: proxy sphere opacity 1→0, detail globe opacity 0→1, detail globe local scale `.92→1`, other galaxy nodes `.16→.10`, links `.07→.03`. Add the selected root to `scene()` only through the force graph node group; do not create any new renderer or `Globe()` object.

The detail globe remains `visible = true` and `state.level = PLANET` at completion; re-enable controls and update the HUD.

- [ ] **Step 4: Run tests, syntax checks and manually inspect the first stable transition**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node --check prototypes/working-prototype/assets/universe-morph-test.js
```

Manual: open `#universe-morph-test`, tap one large planet, wait for the camera focus and verify that the same force-graph canvas contains the lila ThreeGlobe object without a blank frame.

- [x] **Step 5: Commit the inline first morph**

```sh
git add prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: morph selected galaxy planet inline"
```

### Task 5: Add yellow spherical node objects and surface-following planet edges

**Files:**
- Modify: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-model.js`
- Modify: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`

**Consumes:** reusable ThreeGlobe, `mock.planet`, `fibonacciSpherePoint`, selected force-node root group.

**Produces:** 140 hit-testable yellow surface spheres, 210 low-altitude spherical surface links, and `requestMapEntry(planetNodeId)`.

- [x] **Step 1: Add failing sphere-link tests**

Export `surfaceArcPoints` and test that every sampled point remains above the planet surface:

```js
import { surfaceArcPoints } from '../assets/universe-morph-model.js';

const arc = surfaceArcPoints({ x: 100, y: 0, z: 0 }, { x: 0, y: 100, z: 0 }, 100, 8, .045);
assert.equal(arc.length, 9);
assert.ok(arc.every((point) => Math.hypot(point.x, point.y, point.z) >= 104.5));
assert.ok(Math.hypot(arc[4].x, arc[4].y, arc[4].z) > 104.5, 'the middle of a long surface arc must rise above its endpoints');
```

- [x] **Step 2: Run the test to verify it fails**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: missing `surfaceArcPoints` export error.

- [x] **Step 3: Implement planet content inside the detail globe root**

Implement `surfaceArcPoints(start, end, baseRadius, segments, lift)` with spherical linear interpolation of normalized start/end directions and a midpoint altitude raised by `lift`. It must return `segments + 1` Cartesian points and never run through the planet interior.

In `configurePlanetContent()`, create exactly one `THREE.Group` called `planetContentGroup` as a child of `detailGlobe`. Do not use Globe.gl `objectsData()`; this keeps the surface spheres and their edges in the same existing scene.

For all 140 mock planet nodes:

```js
const point = fibonacciSpherePoint(index, 140, detailRadius, .025);
const nodeRoot = new THREE.Group();
const visibleSphere = new THREE.Mesh(sharedPlanetNodeGeometry, yellowMaterial);
const hitSphere = new THREE.Mesh(hitGeometry, invisibleHitMaterial);
nodeRoot.position.set(point.x, point.y, point.z);
nodeRoot.add(visibleSphere, hitSphere);
```

Use `yellowMaterial = new THREE.MeshStandardMaterial({ color: 0xf6d76b, roughness: .5, metalness: .06 })`; create a larger invisible hit sphere with `material.visible = false`. Store `{ id, root, visibleSphere, hitSphere, normal }` in `planetNodeViews`.

For every one of the 210 links, use `surfaceArcPoints` to build `THREE.CatmullRomCurve3` and a shared low-segment `THREE.TubeGeometry` or a `THREE.Line` with points. Use a transparent lavender-white material at opacity `.24`; the arc sits 2.5–8% above surface depending on angular distance. Add only this planet content group to `detailGlobe`; it remains hidden until the first morph is near completion.

Install a pointer tap handler that runs only in `PLANET`, raycasts only the 140 hit spheres, and calls `requestMapEntry(closestPlanetNode.id)`. Explicitly reject pointer movement above threshold or a locked state. During selection, selected yellow node glow grows, direct links use `.8` opacity, unrelated yellow spheres use `.28` opacity.

- [ ] **Step 4: Run unit tests and do the planet manual acceptance check**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node --check prototypes/working-prototype/assets/universe-morph-test.js
```

Manual: after Galaxy→Planet, rotate and pinch the purple planet. Confirm that yellow objects rotate with it, the selected node is tapable, links remain outside the sphere and a drag does not select a yellow node.

- [x] **Step 5: Commit the detailed planet layer**

```sh
git add prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: add tappable planet surface graph"
```

### Task 6: Add the yellow-node camera focus and shared-element proxy morph to the flat map

**Files:**
- Modify: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-model.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-test.css`
- Modify: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`

**Consumes:** `projectPointToScreen`, `planetNodeViews`, active camera/controls, `mock.map`.

**Produces:** screen-stable yellow-circle → purple map-node morph and a gradually visible mock G6 map layer.

- [x] **Step 1: Add failing screen-projection tests**

Test the projection helper with a minimal clone/project fake:

```js
import { projectPointToScreen } from '../assets/universe-morph-model.js';

const fakePoint = { clone: () => ({ project: () => ({ x: 0, y: 0, z: .2 }) }) };
assert.deepEqual(projectPointToScreen(fakePoint, {}, 390, 560), { x: 195, y: 280, ndcZ: .2 });
```

- [x] **Step 2: Run the test to verify it fails**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: missing `projectPointToScreen` export error.

- [x] **Step 3: Implement the second camera focus and proxy transition**

`requestMapEntry(id)` must only run from `PLANET`, snapshot the planet camera, set `state.level = PLANET_TO_MAP`, and lock controls. Rotate the selected `detailGlobe` parent/root via quaternion tween so the selected node's normal aligns with the current camera-facing direction. Then move the camera closer over 420 ms while retaining the selected node within a small center tolerance.

At the end of camera focus, calculate:

```js
const screen = projectPointToScreen(selectedView.root.getWorldPosition(new THREE.Vector3()), camera, stage.clientWidth, stage.clientHeight);
```

Set the proxy element to the selected yellow node screen diameter:

```js
proxy.style.left = `${screen.x}px`;
proxy.style.top = `${screen.y}px`;
proxy.style.width = `${diameter}px`;
proxy.style.height = `${diameter}px`;
proxy.style.borderRadius = '50%';
proxy.style.background = 'radial-gradient(circle at 32% 28%, #fff4a8, #e2b93a 68%, #a66e12)';
```

In the 560 ms proxy tween:

- 0–35%: make proxy visible, fade selected 3D yellow sphere to zero;
- 30–60%: map background and direct edges fade in;
- 45–75%: first-ring mock map nodes fade/scale in;
- 65–100%: remaining map nodes and labels appear;
- 100%: proxy changes to `hidden`, its pointer events remain disabled, state becomes `MAP`, and the map layer is `.is-map-active`.

The final proxy geometry is `width: 148px`, `height: 56px`, `borderRadius: '16px'`, with purple `linear-gradient(135deg, #8b65fa, #5b31cc)`. Never resize the map canvas in the proxy rAF loop.

Build the map with G6 only once when the first map transition begins. Remove `hidden` before its first opacity animation, then configure the 28/42 deterministic mock data with the selected node ID as the central purple node:

```js
mapMount.hidden = false;
mapGraph ??= new window.G6.Graph({
  container: mapMount,
  width: stage.clientWidth,
  height: stage.clientHeight,
  data: toMapG6Data(mock.map, state.selectedPlanetNodeId),
  animation: { duration: 0 },
  behaviors: [{ type: 'drag-canvas' }, { type: 'zoom-canvas', enableOptimize: true }],
  layout: { type: 'force', preventOverlap: true, nodeSize: 42, linkDistance: 105 },
});
mapGraph.render();
```

`toMapG6Data` must return `{ nodes, edges }` with the selected ID as `style.fill: '#8b65fa'`, `style.stroke: '#d9ccff'`, and all other nodes in the deep-space violet palette. The G6 mount remains in the stage; inactive state has `hidden` and no pointer events. Do not modify `knowledge-map.js` or reuse its live production G6 instance.

- [ ] **Step 4: Run tests and manually verify the second morph**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node --check prototypes/working-prototype/assets/universe-morph-test.js
git diff --check
```

Manual: select a yellow node after entering Planet. Confirm camera focus, a yellow proxy originates at the selected screen position, transforms into the map’s purple central node, and the map appears in progressive layers without white/black flash.

- [x] **Step 5: Commit the Planet → Map transition**

```sh
git add prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/assets/universe-morph-test.css \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs
git commit -m "feat: morph planet node into flat map"
```

### Task 7: Implement reverse morphs, Debug HUD and lifecycle safety

**Files:**
- Modify: `prototypes/working-prototype/assets/universe-morph-test.js`
- Modify: `prototypes/working-prototype/assets/universe-morph-test.css`
- Modify: `prototypes/working-prototype/tests/universe-morph-model.test.mjs`
- Modify: `docs/superpowers/specs/2026-07-27-universe-morph-test-design.md`

**Consumes:** completed forward transitions, saved galaxy/planet snapshots, G6 instance, screen cleanup callback.

**Produces:** reverse/replay controls, telemetry HUD, full cleanup, and honest verification statuses in the approved checklist.

- [x] **Step 1: Add failing reverse-transition tests**

Add the missing reverse-target decision helper to the state utility test:

```js
assert.equal(reverseTransition(UNIVERSE_LEVEL.MAP), UNIVERSE_LEVEL.MAP_TO_PLANET);
assert.equal(reverseTransition(UNIVERSE_LEVEL.PLANET), UNIVERSE_LEVEL.PLANET_TO_GALAXY);
assert.equal(reverseTransition(UNIVERSE_LEVEL.GALAXY), null);
```

- [x] **Step 2: Run the test to verify the transition utility or test is incomplete**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
```

Expected: missing `reverseTransition` export error.

- [x] **Step 3: Implement the reverse controls and HUD**

Populate `[data-universe-debug]` with exactly these controls and live fields:

```html
<output data-universe-level></output>
<output data-universe-progress></output>
<output data-universe-selection></output>
<output data-universe-camera></output>
<output data-universe-fps></output>
<div class="universe-morph-debug-actions">
  <button type="button" data-universe-action="galaxy">Galaxy</button>
  <button type="button" data-universe-action="planet">Planet</button>
  <button type="button" data-universe-action="map">Map</button>
  <button type="button" data-universe-action="reverse">Reverse</button>
  <button type="button" data-universe-action="replay">Replay</button>
</div>
```

`reverse()` chooses `requestPlanetReturn()` for `MAP`, and `requestGalaxyReturn()` for `PLANET`. Map return runs the proxy backwards from central purple map-node to yellow circular proxy while map nodes/edges fade out; restore the selected yellow 3D sphere before re-enabling planet pointer handling. Planet return fades yellow planet content/atmosphere/detail globe out, restores proxy sphere/galaxy material/link opacities, then tween-restores `savedGalaxyCamera`. No route call may occur.

`replay` executes Galaxy→Planet→Map only after first returning to GALAXY. The `Galaxy`, `Planet`, and `Map` debug controls use the same request functions as normal interaction; they do not directly set layer visibility.

FPS uses a single frame counter sampled once per second. HUD update is throttled to 10 Hz; transition rAF only mutates Three.js/CSS properties. On cleanup: cancel all rAF/timers, remove all DOM and controls listeners, dispose G6, dispose screen-owned Three geometries/materials/textures, remove `detailGlobe` from its parent, call the force graph destructor, and clear the stage.

- [x] **Step 4: Run the full automated suite**

Run:

```sh
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
node prototypes/working-prototype/tests/focused-g6-map.test.mjs
node --check prototypes/working-prototype/assets/universe-morph-model.js
node --check prototypes/working-prototype/assets/universe-morph-test.js
node --check prototypes/working-prototype/assets/app.js
git diff --check
```

Expected: every command exits zero.

- [ ] **Step 5: Perform the required visual verification and update the acceptance checklist honestly**

Manual test on the Android prototype page:

1. Open `http://127.0.0.1:8082/#universe-morph-test`.
2. Capture GALAXY, PLANET and MAP stable screenshots plus a Galaxy→Planet and a Planet→Map midpoint screenshot.
3. Tap a large galaxy sphere; verify auto-focus, zoom, in-place detailed purple planet and no second canvas flash.
4. Drag and pinch; verify neither gesture selects a node.
5. Tap a yellow planet sphere; verify purple map reveal from its screen position.
6. Run `Reverse` twice; verify each prior camera snapshot is restored.
7. Run `Replay` without reload and ensure the debug HUD reflects all level changes.
8. Return to `#workspace-topic-connections`; verify the original view dropdown and bottom navigation look and work unchanged.

For each UM-01 through UM-13 row in `docs/superpowers/specs/2026-07-27-universe-morph-test-design.md`, set status to `DONE`, `PARTIAL`, or `BLOCKED` based on this evidence. Do not mark any item DONE solely because a syntax test passed.

- [x] **Step 6: Commit the complete test-screen feature**

```sh
git add prototypes/working-prototype/assets/universe-morph-test.js \
  prototypes/working-prototype/assets/universe-morph-test.css \
  prototypes/working-prototype/assets/universe-morph-model.js \
  prototypes/working-prototype/tests/universe-morph-model.test.mjs \
  docs/superpowers/specs/2026-07-27-universe-morph-test-design.md
git commit -m "feat: complete universe morph interaction test"
```

## Final Review Gate

Before reporting completion, re-read `docs/superpowers/specs/2026-07-27-universe-morph-test-design.md` and verify that every UM row is `DONE` or explicitly explained to the user as `PARTIAL`/`BLOCKED`. Provide the exact test commands and screenshot paths used as evidence. Do not include unrelated pre-existing worktree changes in any commit.
