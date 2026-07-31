# Prototype HTML fragment architecture card

Source: `structuring-apps` skill and its `architecture-checklist.md` reference.

| ID | Requirement | Code area | Acceptance condition | Verification | Status |
| --- | --- | --- | --- | --- | --- |
| HTML-01 | Route rendering has one screen-markup loader | `assets/app.js`, `assets/screen-fragments.js` | `app.js` owns routes/lifecycle; the fragment loader only resolves markup and detects cycles | `tests/screen-fragments.test.mjs`, source inspection | DONE |
| HTML-02 | Repeated Workspace and topic navigation markup is shared | `screens/partials/workspace-tabs.html`, `screens/partials/topic-tabs.html` | Every affected screen includes the shared partial instead of copying its tab buttons | `rg` include audit, full test suite | DONE |
| HTML-03 | Explore content is split by responsibility | `screens/partials/explore-*.html`, `screens/explore.html` | Explore shell owns composition; overview, concepts, connections and tabs are independently replaceable | `tests/explore-discovery.test.mjs`, fragment-loader test | DONE |
| HTML-04 | Universe diagnostics are isolated from render-stage markup | `screens/partials/universe-debug.html`, `screens/universe.html` | Debug controls remain below the viewport and are expanded before Universe initialization | `tests/universe4-route.test.mjs`, real Explore fragment expansion test | DONE |
| HTML-05 | Existing route behavior remains intact | `assets/app.js`, all `screens/*.html` | All existing contracts pass with the new fragment composition | Node test loop (`45` tests) | DONE |
| HTML-06 | The prototype status bar must not consume app space | `index.html`, `assets/styles.css` | No status-bar markup or CSS remains; `.app-shell` uses the full phone height | `tests/djinn-menu.test.mjs`, direct source inspection | DONE |
| HTML-07 | All app cards share one size/style primitive | `assets/styles.css`, `assets/explore-discovery.css`, card markup | Every semantic card carries `.card`; global card variables control padding, radius and spacing; Explore “Mai felfedezés” remains a legend | `tests/card-style-contract.test.mjs`, full test suite | DONE |
| HTML-08 | All app cards are 10% taller | `assets/styles.css`, `assets/explore-discovery.css`, `tests/card-style-contract.test.mjs` | `--card-height-scale` is `1.1`; shared vertical padding and fixed card min-heights use the scale; Explore “Mai felfedezés” remains unchanged as a legend | `tests/card-style-contract.test.mjs`, full test suite | DONE |
