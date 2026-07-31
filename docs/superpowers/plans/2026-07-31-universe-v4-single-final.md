# Universe V4 Single Final Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Universe V4 the only public Universe experience, migrate the V1/V2/V3 ForceGraph responsibilities that V4 still needs into V4-owned modules, remove the obsolete public versions and legacy imports, and preserve the working V4 handoff flow through Globe.gl city selection into the embedded Google Maps/G6 view.

**Architecture:** The app has one public route key, `universe`, backed by `screens/universe.html` and initialized only by `initUniverse4`. V4 owns the ForceGraph overview controller/model, the canonical Globe.gl V7 renderer boundary, and the focused G6 map adapter. The ForceGraph and Globe.gl implementations remain separate internal renderer stages because the existing handoff contract depends on their measured camera/material/light state, but no public route or UI exposes V1/V2/V3 choices. Shared gesture, transition, snapshot, and performance mechanisms remain in their existing neutral owners rather than being copied into a legacy sibling.

**Tech Stack:** Static HTML/CSS/ES modules, browser-native DOM events, Three.js/3d-force-graph, Globe.gl, G6, Node.js `.test.mjs` contract tests, local HTTP server on port 8082.

## Global Constraints

- Re-read `docs/superpowers/specs/2026-07-31-universe-v4-single-final-design.md` and keep its U4-01..U4-08 checklist authoritative throughout execution.
- The public navigation entry is exactly `universe`; V1, V2, V3, and `universe-morph-test*` are not valid routes, aliases, tabs, or screen links after migration.
- Do not delete Explore's internal V7 renderer variant. It is the canonical Globe.gl endpoint embedded by V4, not a second public Universe.
- Do not create a second ForceGraph, gesture classifier, transition machine, snapshot builder, or G6 renderer. Consolidate existing mechanisms in the V4 owner and preserve their public behavior.
- UI modules collect intent and render state; multi-step handoff, map preparation, camera matching, and renderer lifecycle remain behind V4 stage/controller adapters.
- Keep the existing lag fixes and debug trace semantics; remove only redundant work or obsolete version-specific UI.
- Use TDD for every behavior change: write or update a focused failing contract test, implement the smallest change, run the focused test, then run the relevant regression set.
- Use `apply_patch` for source edits and run `git diff --check` before every commit.

---

## Task 1: Lock the single public Universe route with failing contracts

**Files:**

- Modify `prototypes/working-prototype/tests/universe4-route.test.mjs`.
- Modify `prototypes/working-prototype/tests/universe-bottom-nav.test.mjs`.
- Modify `prototypes/working-prototype/tests/djinn-menu.test.mjs` and `prototypes/working-prototype/tests/explore-discovery.test.mjs` wherever they assert Universe route labels or links.
- Add `prototypes/working-prototype/tests/universe4-single-route.test.mjs` for the new public-route invariants.

- [ ] Replace the current V4-path assertions with assertions that `index.html` has one Universe button with `data-route="universe"`, `assets/app.js` maps `universe` to `screens/universe.html`, and the app imports only `initUniverse4` for that route.
- [ ] Assert that `app.js` contains no public route entries for `universe-morph-test`, `universe-morph-test-v2`, `universe-morph-test-v3`, or `universe-morph-test-v4`, and that `screens/universe.html` contains no version selector/tabs.
- [ ] Assert that child menus link to `universe` and render the label `Universe`, not a version-specific route.
- [ ] Run the new and updated tests first and verify they fail against the current implementation before editing runtime files.

**Acceptance:** U4-01 and U4-02 have executable failing contracts that distinguish one canonical route from the four current public routes.

## Task 2: Rebind the browser entrypoint and screen to V4

**Files:**

- Modify `prototypes/working-prototype/assets/app.js`.
- Modify `prototypes/working-prototype/index.html`.
- Add `prototypes/working-prototype/screens/universe.html` by reworking the approved V4 markup from `prototypes/working-prototype/screens/universe-morph-test-v4.html`.
- Modify every remaining prototype screen that contains a Universe link, found with `rg -l 'universe-morph-test|Universe v[1234]' prototypes/working-prototype/screens`.
- Modify `prototypes/working-prototype/assets/universe4/universe4.css` only for V4 screen class/name changes.

- [ ] Change `routes` and `activeNav` so `universe` is the sole Universe route and no route normalization can silently resurrect a deleted version.
- [ ] Make `render()` initialize `initUniverse4` only when `normalized === 'universe'`; remove the legacy `initUniverseMorphTest` import and all V1/V2/V3 initialization branches.
- [ ] Change the bottom navigation and all cross-screen links to `data-route="universe"`.
- [ ] Remove the legacy `universe-morph-test.css` stylesheet from `index.html` after its required rules are migrated in Task 4; keep the V4 stylesheet revision explicit.
- [ ] Rename the copied V4 screen's public title and controls to “Universe” while retaining the existing stage shell, reset, fullscreen, debug, Force background, Globe background, and G6 stage hooks.
- [ ] Keep the route screen's internal V4 stage attributes (`data-universe4-*`) unchanged unless the adapter contract requires a deliberate rename.

**Acceptance:** Browser navigation reaches exactly one Universe screen and that screen always starts the V4 runtime.

## Task 3: Consolidate the legacy model/helpers under V4 ownership

**Files:**

- Modify `prototypes/working-prototype/assets/universe4/universe4-model.js`.
- Add `prototypes/working-prototype/assets/universe4/universe4-force-model.js` only if the existing model cannot own the ForceGraph-specific pure helpers without mixing renderer concerns.
- Modify `prototypes/working-prototype/assets/universe4/universe4-u3-inline-source.js`.
- Modify `prototypes/working-prototype/assets/universe4/universe4-force-stage.js` if its existing snapshot/ForceGraph helpers are the correct consolidation point.
- Modify `prototypes/working-prototype/tests/universe4-model.test.mjs`.
- Add `prototypes/working-prototype/tests/universe4-force-model.test.mjs` only when a separate pure module is required.

- [ ] Inventory the imports from `assets/universe-morph-model.js` used by the V4 U3 path (seed/data construction, focus distance/target math, orbit clamping, pointer classification, easing, projection, and surface arc generation).
- [ ] Move those pure responsibilities into the V4 model owner, preserving function names/behavior at the V4 boundary and keeping deterministic snapshots frozen and immutable.
- [ ] Update `universe4-u3-inline-source.js` and the consolidated Force stage to import only the V4-owned model; do not leave a compatibility import from `../universe-morph-model.js`.
- [ ] Add tests for deterministic model output, focus-camera math, pointer classification thresholds, and surface-arc sampling. Make the tests fail before the extraction and pass after it.
- [ ] Do not move Explore V5/V7 data or the canonical Globe selection policy into the Force model; those remain in their existing Explore/U4 owners.

**Acceptance:** U4-03 and U4-07 are satisfied for pure model behavior: V4 owns the required helpers once, with no legacy-model import.

## Task 4: Extract the required ForceGraph controller into the V4 stage

**Files:**

- Modify `prototypes/working-prototype/assets/universe4/universe4-force-stage.js` (consolidate the existing file rather than creating a sibling renderer).
- Modify `prototypes/working-prototype/assets/universe4/universe4-u3-stage.js`.
- Migrate only the required rendering styles from `prototypes/working-prototype/assets/universe-morph-test.css` into `prototypes/working-prototype/assets/universe4/universe4.css`.
- Add or modify `prototypes/working-prototype/tests/universe4-force-stage.test.mjs`.
- Modify `prototypes/working-prototype/tests/universe4-source-contract.test.mjs` to enforce ownership.

- [ ] Extract the V4-needed portions of `assets/universe-morph-test.js` into the V4 Force owner: ForceGraph creation, galaxy node rendering, selected-planet focus/morph, V3-reference lighting/material setup, handoff frame/render-profile capture, reset, input enable/disable, pause/resume, background color, and disposal.
- [ ] Preserve the adapter surface consumed by `createUniverse4U3Stage`: `setOpacity`, `setInputEnabled`, `pauseAnimation`, `resumeAnimation`, `resetToGalaxyOverview`, `setBackgroundColor`, `resumeInlineInteraction`, `captureHandoffFrame`, `captureRenderProfile`, `applyHandoffCamera`, and `dispose`, plus `onPlanetReady`/helper callbacks.
- [ ] Keep one ForceGraph animation loop and stop its vendor loop, HUD RAF, and cosmic environment whenever Globe.gl is active; resume them only for reset/return-to-planet.
- [ ] Replace `initUniverseMorphTest` in `universe4-u3-stage.js` with the V4 Force owner and V4-specific root/class names. Preserve the handoff matcher’s measured CSS center/radius and landmark data.
- [ ] Add source-contract assertions that `universe4-u3-stage.js` has no `initUniverseMorphTest` import, the V4 Force owner exports the adapter seams, and no runtime file imports `universe-morph-test.js`.
- [ ] Run focused Force/U4 handoff tests before broad tests; inspect the browser trace for the existing `u4.u3.inline.complete` and `u4.handoff.complete` events.

**Acceptance:** U4-03, U4-04, U4-06, and U4-07 hold for the migrated Force stage without duplicating the old controller.

## Task 5: Remove obsolete public screens, controllers, and stylesheet dependencies

**Files:**

- Delete `prototypes/working-prototype/screens/universe-morph-test.html`.
- Delete `prototypes/working-prototype/screens/universe-morph-test-v2.html`.
- Delete `prototypes/working-prototype/screens/universe-morph-test-v3.html`.
- Delete `prototypes/working-prototype/assets/universe-morph-test.js` after all imports and tests are migrated.
- Delete `prototypes/working-prototype/assets/universe-morph-model.js` after Task 3 leaves no imports.
- Modify or delete `prototypes/working-prototype/assets/universe-morph-test.css` only after its rules are migrated and no HTML imports it.
- Inspect `prototypes/working-prototype/assets/universe4/universe4-v7-globe-stage.js` and `prototypes/working-prototype/assets/universe4/universe4-u3-inline-source.js`; delete either only if `rg` proves it is unused after consolidation.
- Remove/update `prototypes/working-prototype/tests/universe-morph-model.test.mjs` and any tests whose only purpose is a deleted public version; retain shared behavior coverage in the U4 tests.

- [ ] Run `rg -n "universe-morph-test|universe-morph-model|Universe v[123]" prototypes/working-prototype/assets prototypes/working-prototype/screens prototypes/working-prototype/tests` and classify every match as a required migration, an allowed historical test fixture, or a removable stale reference.
- [ ] Remove all public route/screen/import references; no deleted file may remain reachable through `app.js`, `index.html`, a screen link, or a dynamic import.
- [ ] Remove version tabs and stale labels from the copied canonical screen without touching the internal V7 Explore variant.
- [ ] Confirm the source tree has exactly one public Universe screen and one V4 Force/Globe/G6 composition.

**Acceptance:** U4-02 and U4-03 are complete; legacy public versions are deleted and no dead imports remain.

## Task 6: Update cache-busters and migrate regression contracts

**Files:**

- Modify revision query strings in `prototypes/working-prototype/index.html`, `prototypes/working-prototype/assets/app.js`, `prototypes/working-prototype/assets/universe4.js`, `prototypes/working-prototype/assets/universe4/universe4-u3-stage.js`, and any changed V4-owned module imports.
- Modify all affected tests under `prototypes/working-prototype/tests/` that assert exact revision strings or old screen paths.
- Modify `docs/superpowers/specs/2026-07-31-universe-v4-single-final-design.md` status fields as each acceptance item becomes verified.

- [ ] Increment every browser cache-buster for a changed module and update exact-revision contract tests in the same change.
- [ ] Keep the existing performance/debug contracts (throttled U4 diagnostics, camera-only visual refresh, reused labels, paused hidden renderer) green.
- [ ] Verify repeated root-city and context-city taps still follow the current U4 policy: first foreign/context tap clears or focuses as defined, repeated tap enters the embedded map, and map reset/back returns to the planet without a second renderer.

**Acceptance:** U4-05 and U4-06 remain true after the route and ownership migration.

## Task 7: Full verification and honest checklist closeout

**Files:**

- Update `docs/superpowers/specs/2026-07-31-universe-v4-single-final-design.md` with final evidence and statuses.
- No source edits are allowed in this task except fixes required by verification failures.

- [ ] Run every prototype Node contract test from the prototype directory:
  ```sh
  cd /data/data/com.termux/files/home/ubuntu/flutteruser/flutterapps/djinn/prototypes/working-prototype
  for f in tests/*.test.mjs; do node "$f" || exit 1; done
  ```
- [ ] Run `git diff --check` and `git status --short`.
- [ ] Run the dependency/public-surface scan:
  ```sh
  rg -n "universe-morph-test|universe-morph-model|Universe v[123]" assets screens index.html tests
  rg -n "data-route=\"universe\"|screens/universe\.html|initUniverse4" assets/app.js index.html screens
  ```
  The first scan must contain no public route/import/screen references; any retained match must be explicitly documented as an internal test fixture or renderer-boundary comment.
- [ ] Start/use the local HTTP server on port 8082 and verify `GET /index.html`, `GET /screens/universe.html`, and the V4 module tree return 200 responses.
- [ ] Exercise the browser flow with the existing debug trace: overview -> focused planet -> Globe.gl -> repeated city tap -> embedded G6/Google Maps view -> reset/back. Confirm no uncaught `map.error`, `pointer.tap.reject` on a deliberate stationary city tap, or runaway controls/RAF logs.
- [ ] Mark U4-01..U4-08 `DONE` only when the corresponding evidence is present; otherwise leave the item `PARTIAL`/`BLOCKED` and report it before commit.

**Acceptance:** The repository contains one public V4 Universe, the full regression suite passes, and the checklist records evidence rather than inferred completion.

## Commit and handoff

- [ ] Commit the implementation as a focused migration commit after verification, using a message such as `refactor: make Universe V4 the single public universe`.
- [ ] Push only when explicitly requested by the user; report the commit hash, branch, test command, and any remaining untracked files (including `.codex/` metadata) without hiding them.
