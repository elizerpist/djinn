# Universe 4 Force → Globe Renderer Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an isolated Universe 4 mockup where a ForceGraph3D inline planet transitions without a visible jump into an independently rendered Globe.gl planet.

**Architecture:** Universe 4 owns two stacked live canvases. A Force stage handles the galaxy approach and its fade; a prewarmed Globe stage receives the same immutable planet snapshot and an explicitly mapped camera state. A pure handoff state machine gates a short crossfade on camera/landmark validation, then moves input ownership to Globe.gl. The reverse path maps the current Globe camera into the frozen Force planet frame.

**Tech Stack:** ES modules, Three.js, local 3d-force-graph and Globe.gl vendor bundles, DOM/CSS overlays, Node ESM regression tests.

## Global Constraints

- Universe 3 source/runtime/state machine must not be modified by Universe 4.
- Universe 4 owns distinct Force, Globe, transition, pointer and disposal state; only immutable model/math utilities may be shared.
- Both stages are live renderers; no screenshot/canvas-copy handoff.
- Handoff requires a deterministic `PlanetRenderSnapshot`, `animateIn: false`, equal CSS viewport, pixel-aligned camera mapping, and explicit input ownership.
- Pixel-match gates: center ≤2 CSS px, radius delta ≤1%, landmark delta ≤3 CSS px; failed validation remains inline.
- Crossfade lasts 160–280 ms (debug slow mode: 3000 ms); no transform/camera animation during fade.
- During handoff neither renderer accepts input; standalone Globe owns orbit/pinch/tap with pan disabled.
- Force simulation freezes before fade but its render loop pauses only after its opacity reaches zero.
- The return path is the symmetric handoff and restores the saved Force world/camera snapshot.
- Production must release Globe, Force listeners, animation frames, and canvases on route disposal.

## File Structure

- `screens/universe-morph-test-v4.html`: U4 route shell with two stacked stage mounts and debug panel.
- `assets/universe4/universe4-model.js`: immutable snapshots, state transition contract and pure snapshot construction.
- `assets/universe4/universe4-camera-mapper.js`: Force/local/Globe camera conversion and CSS screen projection helpers.
- `assets/universe4/universe4-pixel-match.js`: center/radius/landmark validator with explicit tolerances.
- `assets/universe4/universe4-force-stage.js`: isolated ForceGraph3D lifecycle, node/link fade and camera snapshot.
- `assets/universe4/universe4-globe-stage.js`: isolated Globe.gl lifecycle, snapshot layers, interaction ownership, camera positioning.
- `assets/universe4/universe4-transition-machine.js`: generation-safe finite-state handoff and reverse transition executor.
- `assets/universe4/universe4-debug-panel.js`: structured handoff diagnostics and proof modes.
- `assets/universe4/universe4.css`: shared viewport stacking, crossfade and debug styles.
- `assets/universe4.js`: U4 screen composition/disposal only.
- `assets/app.js`, `index.html`: route registration and cache invalidation only.
- `tests/universe4-model.test.mjs`, `tests/universe4-camera-mapper.test.mjs`, `tests/universe4-pixel-match.test.mjs`, `tests/universe4-transition-machine.test.mjs`, `tests/universe4-source-contract.test.mjs`: TDD and isolation contracts.

### Task 1: Pure Universe 4 model and transition contract

**Files:** Create `assets/universe4/universe4-model.js`, `assets/universe4/universe4-transition-machine.js`, `tests/universe4-model.test.mjs`, `tests/universe4-transition-machine.test.mjs`.

- [x] Write failing tests for the complete ordered state graph, generation invalidation, and deterministic planet snapshot values.
- [x] Run the two tests and confirm they fail because the U4 modules do not exist.
- [x] Implement `U4_STATE`, `canUniverse4Transition`, `createUniverse4Snapshot`, and `createUniverse4TransitionMachine` with a generation token.
- [x] Re-run the tests and confirm both pass.

### Task 2: Camera mapping and pixel validator

**Files:** Create `assets/universe4/universe4-camera-mapper.js`, `assets/universe4/universe4-pixel-match.js`, `tests/universe4-camera-mapper.test.mjs`, `tests/universe4-pixel-match.test.mjs`.

- [x] Write failing tests for Force-relative camera vector → local camera vector → Globe POV, CSS center/radius comparison, landmark threshold failure, and current Globe → Force return mapping.
- [x] Run the tests and confirm expected red failures.
- [x] Implement mapping without hard-coded Force-axis longitude assumptions; implement `validatePixelMatch` with ≤2 px / ≤1% / ≤3 px limits.
- [x] Re-run tests and confirm they pass.

### Task 3: Isolated renderer stages

**Files:** Create `assets/universe4/universe4-force-stage.js`, `assets/universe4/universe4-globe-stage.js`, `tests/universe4-source-contract.test.mjs`.

- [x] Write a failing source contract ensuring Force and Globe stages are separate, Globe uses `animateIn: false`, and neither imports U3 runtime.
- [x] Implement ForceGraph3D snapshot/approach/fade/freeze/resume APIs and Globe prewarm/snapshot/pointOfView/input/disposing APIs.
- [x] Ensure the Force stage holds simulation freeze separately from `pauseAnimation()` and Globe stage starts pointer-disabled.
- [x] Re-run the source test and stage syntax checks.

### Task 4: Handoff orchestrator, reverse path and debug proofs

**Files:** Create `assets/universe4/universe4-debug-panel.js`, `assets/universe4.js`, `assets/universe4/universe4.css`; extend `tests/universe4-transition-machine.test.mjs`, `tests/universe4-source-contract.test.mjs`.

- [x] Write failing tests for input ownership during every phase, failed-pixel-match inline fallback, and reverse transition progression.
- [x] Implement prewarm → align → validator → 220ms crossfade → Globe ownership; reverse it from current Globe POV.
- [x] Add split/overlay/landmark/camera/slow-motion/Force-only/Globe-only proof controls and the required metrics.
- [x] Run transition tests, source contracts, syntax checks and existing U3 suites.

### Task 5: Route, U4 screen and verification

**Files:** Create `screens/universe-morph-test-v4.html`; modify `assets/app.js`, `index.html`, `tests/djinn-menu.test.mjs`, `tests/query-menu.test.mjs`.

- [x] Write a failing route/cache test for `universe-morph-test-v4`.
- [x] Register the new route and tab without changing the V3 shell or initializer.
- [ ] Run all `tests/*.test.mjs`, `git diff --check`, and capture a fresh Android U4 screenshot for the pixel-match/crossfade proof. Tests and `git diff --check` are green; the Android visual proof remains required.

## Acceptance Checklist

| ID | Requirement | Verification |
| --- | --- | --- |
| U4-01 | U3 remains structurally and behaviorally untouched | source isolation test + original U3 tests |
| U4-02 | two stacked live renderers with independent lifecycles | DOM/source contract + debug panel |
| U4-03 | Force approach remains inline until handoff | Force stage smoke proof |
| U4-04 | shared deterministic snapshot | model test and debug snapshot ID |
| U4-05 | camera/offset/pixel landmark matching gates crossfade | mapper/validator tests + overlay proof |
| U4-06 | crossfade has exclusive input lock and proper Force pause timing | transition state test + debug trace |
| U4-07 | Globe standalone handles interaction, Force remains frozen | input-owner debug field + smoke test |
| U4-08 | return uses current Globe POV and restores Force snapshot | reverse transition test |
| U4-09 | failure/route dispose never leaks listeners/canvases or shows a jump | source contract + disposal test |
| U4-10 | Android visual proof shows no perceptible renderer jump | fresh screenshot/video evidence |
