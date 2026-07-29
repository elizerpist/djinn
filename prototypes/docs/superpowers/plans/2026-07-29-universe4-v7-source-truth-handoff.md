# Universe 4: V7 source-of-truth handoff

## Acceptance checklist

| ID | Requirement source | Code area | Acceptance condition | Verification | Status |
|---|---|---|---|---|---|
| U4-ST-01 | User correction: V7 is source of truth | `assets/universe4/universe4-v7-globe-stage.js` | U4 final renderer consumes V7's `getV5PlanetVisualSnapshot`, `V3_PHYSICS_EDGES`, V7 visual tokens, V7 light rig and cosmic environment; it does not create mock atoms or navigate to Explore. | Green source-contract test plus direct import inspection | PARTIAL — all canonical source contracts are wired; Android V7-to-U4 visual comparison is outstanding. |
| U4-ST-02 | User correction: exact concrete V7 interactions | V7 standalone stage | The embedded U4 globe owns the 700 city node objects, label LOD, custom ray-pick, first-tap focus, second-tap dehighlight and V7 gold surface Paths. | Controller/input/path unit tests; Android tap proof | PARTIAL — same V7 data, selection controller, input router, label LOD and Paths adapter are wired and regression tests are green; physical tap proof is outstanding. |
| U4-ST-03 | User correction: U3 is the ForceGraph entry reference | `universe4-force-stage.js` | The inline U4 planet is built from U3's actual V5 visual snapshot/ThreeGlobe data rather than generic Fibonacci mock atoms. | Green source-contract test; U3/U4 Android split screenshot | PARTIAL — the inline target is now a ThreeGlobe populated from the exact V5/V7 snapshot; visual U3/U4 parity proof is outstanding. |
| U4-ST-04 | User correction: functional embedded handoff | `universe4.js`, stage modules | The crossfade remains in the U4 screen and transfers input to the embedded Globe.gl runtime. No route/navigation to Explore V7 occurs. | Green transition/source tests; Android handoff interaction proof | PARTIAL — two live stages, input ownership and no-route handoff are in code and tests; device proof remains required. |
| U4-ST-05 | Prior U4 UI requirement | `screens/universe-morph-test-v4.html`, U4 CSS | Fullscreen retains the bottom controls/debug panel and both live render stages resize correctly. | Existing route/source tests; Android fullscreen proof | PARTIAL |

## Implementation sequence

1. Add a failing source-contract test for the canonical V7 runtime imports and forbid generic mock-stage imports in U4.
2. Create a dedicated, embedded V7 Globe.gl stage by copying the V7 rendering contracts into a lifecycle-controlled module: concrete snapshot, node factory, labels, selection/path adapter, input router, V7 lighting and cosmic scene.
3. Replace U4's generic Globe stage with that runtime and feed camera mapping/crossfade state into it.
4. Replace the fabricated U4 inline atom payload with the U3 V5 snapshot and preserve the ForceGraph portion only as the handoff entry stage.
5. Run targeted source/runtime tests, then inspect Android U3, U4 and Explore V7 screenshots and update this checklist honestly.
