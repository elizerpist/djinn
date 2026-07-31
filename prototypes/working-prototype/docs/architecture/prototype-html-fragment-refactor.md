# Prototype HTML fragment architecture card

Source: `structuring-apps` skill and its `architecture-checklist.md` reference.

| ID | Requirement | Code area | Acceptance condition | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| HTML-01 | Route rendering has one screen-markup loader | `assets/app.js`, `assets/screen-fragments.js` | `app.js` owns routes/lifecycle; the fragment loader only resolves markup and detects cycles | `tests/screen-fragments.test.mjs`, source inspection | DONE |
| HTML-02 | Repeated Workspace and topic navigation markup is shared | `screens/partials/workspace-tabs.html`, `screens/partials/topic-tabs.html` | Every affected screen includes the shared partial instead of copying its tab buttons | `rg` include audit, full test suite | DONE |
| HTML-03 | Explore content is split by responsibility | `screens/partials/explore-*.html`, `screens/explore.html` | Explore shell owns composition; overview, concepts, connections and tabs are independently replaceable | `tests/explore-discovery.test.mjs`, fragment-loader test | DONE |
| HTML-04 | Universe diagnostics are isolated from render-stage markup | `screens/partials/universe-debug.html`, `screens/universe.html` | Debug controls remain below the viewport and are expanded before Universe initialization | `tests/universe4-route.test.mjs`, real Explore fragment expansion test | DONE |
| HTML-05 | Existing route behavior remains intact | `assets/app.js`, all `screens/*.html` | All existing contracts pass with the new fragment composition | Node test loop (`44` tests) | DONE |
