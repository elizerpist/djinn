import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

import { loadScreenMarkup, syncScreenTabs } from '../assets/screen-fragments.js';

const files = new Map([
  ['screens/demo.html', '<main><!-- include:partials/outer.html --></main>'],
  ['screens/partials/outer.html', '<section><!-- include:partials/inner.html --></section>'],
  ['screens/partials/inner.html', '<span data-fragment="inner">Betöltve</span>'],
]);

const fetchImpl = async (path) => ({
  ok: files.has(path),
  async text() {
    return files.get(path) ?? '';
  },
});

const resolved = await loadScreenMarkup('screens/demo.html', { fetchImpl });
assert.match(resolved, /data-fragment="inner"/);
assert.doesNotMatch(resolved, /include:/);

const realFetch = async (path) => {
  try {
    const text = await readFile(new URL(`../${path}`, import.meta.url), 'utf8');
    return { ok: true, async text() { return text; } };
  } catch {
    return { ok: false, async text() { return ''; } };
  }
};
const realExplore = await loadScreenMarkup('screens/explore.html', { fetchImpl: realFetch });
assert.match(realExplore, /data-explore-panel="overview"/);
assert.match(realExplore, /data-explore-panel="connections"/);
assert.doesNotMatch(realExplore, /include:/);

files.set('screens/cycle.html', '<!-- include:partials/cycle.html -->');
files.set('screens/partials/cycle.html', '<!-- include:partials/cycle.html -->');
await assert.rejects(
  loadScreenMarkup('screens/cycle.html', { fetchImpl }),
  /Körkörös képernyő-részlet hivatkozás/,
);

const buttons = ['workspace-topics', 'workspace-notes'].map((route) => ({
  dataset: { route },
  classList: { toggle(_className, active) { this.active = active; } },
}));
syncScreenTabs({
  querySelectorAll() {
    return [{ querySelectorAll() { return buttons; } }];
  },
}, 'workspace-notes');
assert.equal(buttons[0].classList.active, false);
assert.equal(buttons[1].classList.active, true);

console.log('screen fragment loader OK');
