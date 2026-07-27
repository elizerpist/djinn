# Universe Bottom Navigation Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tegyük a Universe Morph tesztképernyőt elérhetővé egy külön `Universe` alsó navigációs menüpontból.

**Architecture:** A meglévő globális click-delegálás már minden `data-route` gombot a hash route-ra irányít, ezért az új belépési pont csak egy navigációs markup elem. Az aktív állapot a route nevének közvetlen egyezéséből működik; új route- vagy renderlogika nem kell.

**Tech Stack:** Statikus HTML, meglévő vanilla JavaScript hash router, Node alapú statikus teszt.

## Global Constraints

- A `Universe` új, hetedik elemként a `Workspace` és `Én` között jelenik meg.
- Felirat: `Universe`; ikon: `◉`; route: `universe-morph-test`.
- Nem módosul a Universe Morph renderkód, mock adata, WebGL ownership-e, Explore orb, Workspace dropdown, breadcrumb, kereső vagy más route.
- A meglévő `data-route` click delegationt kell újrahasználni; nem lesz külön event listener.
- Csak az érintett fájlok kerülhetnek commitba.

---

### Task 1: Bottom navigation Universe belépési pont

**Files:**
- Modify: `prototypes/working-prototype/index.html:30-37`
- Test: `prototypes/working-prototype/tests/universe-bottom-nav.test.mjs`

**Consumes:** az `app.js` meglévő `[data-route]` click-delegálása, valamint a már létező `universe-morph-test` hash route.

**Produces:** a Workspace és Én közötti, route-olható `Universe` navigációs gomb.

- [ ] **Step 1: Write the failing static navigation test**

Create `prototypes/working-prototype/tests/universe-bottom-nav.test.mjs`:

```js
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const nav = html.match(/<nav class="bottom-nav"[\s\S]*?<\/nav>/)?.[0] || '';

const workspaceIndex = nav.indexOf('data-route="workspace-topics"');
const universeIndex = nav.indexOf('data-route="universe-morph-test"');
const profileIndex = nav.indexOf('data-route="profile"');

assert.ok(universeIndex >= 0, 'Universe nav item must target universe-morph-test');
assert.ok(workspaceIndex < universeIndex && universeIndex < profileIndex, 'Universe must be between Workspace and Én');
assert.match(nav, /data-route="universe-morph-test"[^>]*>\s*<span class="nav-icon">◉<\/span><span>Universe<\/span>/);

console.log('universe bottom nav OK');
```

- [ ] **Step 2: Run the test to confirm it fails before the markup exists**

Run:

```sh
node prototypes/working-prototype/tests/universe-bottom-nav.test.mjs
```

Expected: assertion failure stating that the Universe nav item is missing.

- [ ] **Step 3: Add the minimal nav markup**

In `prototypes/working-prototype/index.html`, place this button directly after the existing Workspace button and before the profile button:

```html
<button class="nav-item" data-route="universe-morph-test"><span class="nav-icon">◉</span><span>Universe</span></button>
```

Do not change the other six buttons, the nav click handler, or the Universe screen route.

- [ ] **Step 4: Run the new test and the existing Universe model test**

Run:

```sh
node prototypes/working-prototype/tests/universe-bottom-nav.test.mjs
node prototypes/working-prototype/tests/universe-morph-model.test.mjs
git diff --check
```

Expected: both tests print their success messages and the diff check has no output.

- [ ] **Step 5: Manual mobile verification**

Open `http://127.0.0.1:8082/`, then verify:

1. The bottom nav shows `Universe` between Workspace and Én.
2. Tapping it opens `#universe-morph-test` and marks only Universe active.
3. Home, Explore, Djinn, Query, Workspace and Én continue to navigate normally.

Capture one screenshot and update `UNAV-01` through `UNAV-04` in `docs/superpowers/specs/2026-07-27-bottom-nav-universe-entry-design.md` truthfully.

- [ ] **Step 6: Commit and push only the scoped files**

Run:

```sh
git add \
  prototypes/working-prototype/index.html \
  prototypes/working-prototype/tests/universe-bottom-nav.test.mjs \
  docs/superpowers/specs/2026-07-27-bottom-nav-universe-entry-design.md \
  docs/superpowers/plans/2026-07-27-bottom-nav-universe-entry.md
git diff --cached --check
git commit -m "feat: add universe bottom navigation entry"
git push origin prototype
```

## Plan Self-Review

- **Spec coverage:** UNAV-01 through UNAV-04 map to Task 1; no production render, dropdown or WebGL code is in scope.
- **Consistency:** the test checks the exact `data-route`, icon, label and required ordering that Step 3 adds.
- **Scope:** one markup addition and a static regression test; no unrelated refactor.
- **Placeholders:** none.
