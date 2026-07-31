# Universe V4 — single final universe

## Goal

The prototype exposes exactly one public Universe experience: Universe V4.
The former V1, V2 and V3 public screens and routes are removed. Behaviour that
V4 still needs from those implementations is extracted into V4-owned modules;
V4 must not import the legacy `universe-morph-test` controller or model.

## Scope

Keep the working V4 vertical flow:

1. Galaxy overview owned by the V4 ForceGraph stage.
2. Focused planet handoff into the canonical Globe.gl stage.
3. Repeated city tap entering the focused G6 map.
4. Reset/back transitions returning to the V4 galaxy overview.

Move only the legacy responsibilities that are still part of that flow:

- ForceGraph galaxy layout, focused-planet transition and handoff frame capture;
- the required V3 reference lighting/cosmic maintenance;
- focused-planet input ownership and camera/gesture rules;
- immutable universe snapshot/model helpers used by those stages.

The V4 coordinator remains the only owner of depth state, stage ownership,
transition generations and map handoff. Renderer adapters stay in
`assets/universe4/` and do not own public navigation.

## Public surface

- Keep one canonical `Universe` navigation entry pointing to V4.
- Remove V1/V2/V3 route entries, screens, version tabs and legacy route aliases.
- V4's screen must not describe itself as a test or expose old version choices.
- Internal names such as `u3` or `v7` may remain temporarily where they describe
  a renderer boundary, but they must not be public product versions.

## Ownership and migration

| Responsibility | Final owner | Migration rule |
|---|---|---|
| Public route and screen | `app.js`, V4 screen | Keep only V4; remove old route wiring and screens |
| Galaxy ForceGraph | `assets/universe4/` Force stage/controller | Extract from `universe-morph-test.js`; no duplicate simplified engine |
| Universe data/model | V4 model module | Move the required immutable data/helpers from `universe-morph-model.js` |
| Globe.gl focus | `universe4-v7-source-stage.js` | Keep canonical Globe controller and V4 callback seam |
| G6 focused map | `universe4-g6-focused-map-stage.js` | Keep existing prewarm and map ownership |
| Depth/transition state | `universe4.js` + depth controller | One write path; legacy controllers cannot mutate it |
| Styles | `universe4.css` plus shared tokens only where needed | Remove legacy-only CSS after dependency scan |

The migration is an extraction, not a copy: each moved mechanism has one
implementation and one owner. Any shared data or geometry used by both the
Force and Globe adapters remains in a neutral V4 data module.

## Deletion rules

Delete only after the dependency scan and tests prove they are unused:

- V1/V2/V3 screen HTML files and route entries;
- the legacy public tabs and navigation aliases;
- legacy-only controller/model modules and CSS;
- tests whose sole contract is a deleted public version.

Do not delete vendor libraries or internal renderer adapters that V4 still
loads. Do not remove the internal ForceGraph or Globe stage merely because it
has an historical `u3`/`v7` name; rename or relocate it as part of extraction
when that improves ownership without changing its public behaviour.

## Acceptance checklist

| ID | Source | Code area | Acceptance condition | Verification | Status |
|---|---|---|---|---|---|
| U4-01 | User: one Universe, V4 final | `assets/app.js`, navigation | Only one public Universe route exists and it opens V4 | Route contract test + served entrypoint check | DONE |
| U4-02 | User: remove the others | `screens/`, `assets/app.js` | V1/V2/V3 screens, tabs and aliases are absent | `rg` dependency scan + route tests | DONE |
| U4-03 | User: move referenced code into V4 | `assets/universe4/` | V4 has its own ForceGraph/model/controller modules and imports no legacy public controller | Static import/ownership contract test | DONE |
| U4-04 | Existing V4 behaviour | `universe4.js` and stage adapters | Galaxy → focused planet → Globe handoff still completes | Universe4 transition/route tests | DONE |
| U4-05 | Existing V4 behaviour | Globe selection + G6 stage | Repeated root/context city tap enters the focused map and back/reset returns | Globe selection + focused map tests | DONE |
| U4-06 | Existing performance fix | Globe stage and diagnostics | Orbit interaction keeps throttled diagnostics and camera-only visual updates | Performance contract tests + source inspection | DONE |
| U4-07 | Architecture gate | `assets/universe4/` | No second copy of gesture, transition, or ownership mechanisms is introduced | Ownership review + targeted unit tests | DONE |
| U4-08 | Regression safety | `tests/` | Full JavaScript suite passes and no stale cache-buster imports remain | Full test loop + HTTP import-chain check | DONE |

## Verification evidence required before completion

- Full `tests/*.test.mjs` run;
- route/import scan proving no old public Universe path remains;
- HTTP-served import-chain check for the final V4 revisions;
- manual or automated interaction trace for handoff, repeated city tap, map,
  back and reset;
- `git diff --check` and staged diff review.

## Implementation evidence (2026-07-31)

- U4-01/U4-02: `universe4-route.test.mjs`, `universe4-single-route.test.mjs`,
  and the public-surface scan prove a single `universe` route and no legacy
  public screens/tabs.
- U4-03/U4-07: `universe4-force-stage.test.mjs`,
  `universe4-force-model.test.mjs`, and `universe4-source-contract.test.mjs`
  prove V4-owned Force/model/controller seams and no runtime legacy imports.
- U4-04/U4-05: transition, Globe selection, focused-map, and source-contract
  tests cover galaxy handoff, repeated city taps, map entry, and reset/back
  seams.
- U4-06: performance/debug contracts retain throttled diagnostics, camera-only
  refresh, paused hidden renderer behavior, and the existing ownership seams.
- U4-08: the complete prototype loop passed 42/42 Node contract tests; the
  served entrypoint and V4 module chain returned HTTP 200; `git diff --check`
  was clean.
- The runtime interaction path is covered by automated contracts in this
  Termux session; no separate manual browser screenshot trace was available.
