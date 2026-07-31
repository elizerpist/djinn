import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const app = await readFile(new URL('assets/app.js', root), 'utf8');
const index = await readFile(new URL('index.html', root), 'utf8');
const screen = await readFile(new URL('screens/universe.html', root), 'utf8');

assert.equal((index.match(/data-route="universe"/g) || []).length, 1,
  'the shell must expose exactly one public Universe navigation entry');
assert.match(app, /const routes = \{[\s\S]*(?:'universe'|universe): 'screens\/universe\.html'/);
assert.match(app, /normalized === 'universe'[\s\S]*initUniverse4\(root,/);
assert.doesNotMatch(app, /initUniverseMorphTest/);
assert.doesNotMatch(app, /universe-morph-test(?:-v[234])?/);
assert.doesNotMatch(screen, /Universe v[1234]|data-route="universe-morph-test/);
assert.match(screen, /data-universe4-force-stage/);
assert.match(screen, /data-universe4-globe-stage/);
assert.match(screen, /data-universe4-g6-stage/);

for (const file of [
  'screens/universe-morph-test.html',
  'screens/universe-morph-test-v2.html',
  'screens/universe-morph-test-v3.html',
  'screens/universe-morph-test-v4.html',
]) {
  await assert.rejects(access(new URL(file, root)), undefined, `${file} must not remain public`);
}

console.log('single public Universe route contract OK');
