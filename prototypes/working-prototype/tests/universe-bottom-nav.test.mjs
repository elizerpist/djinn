import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const html = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const css = await readFile(new URL('../assets/styles.css', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const nav = html.match(/<nav class="bottom-nav"[\s\S]*?<\/nav>/)?.[0] || '';

const workspaceIndex = nav.indexOf('data-route="workspace-topics"');
const universeIndex = nav.indexOf('data-route="universe-morph-test"');
const profileIndex = nav.indexOf('data-route="profile"');

assert.ok(universeIndex >= 0, 'Universe nav item must target universe-morph-test');
assert.ok(workspaceIndex < universeIndex && universeIndex < profileIndex, 'Universe must be between Workspace and Én');
assert.match(nav, /data-route="universe-morph-test"[^>]*>\s*<span class="nav-icon">◉<\/span><span>Universe<\/span>/);
assert.match(css, /\.bottom-nav\s*\{[^}]*grid-template-columns:\s*repeat\(7,\s*1fr\)/s, 'bottom nav must allocate seven equal columns');
assert.match(app, /const navKey = button\.dataset\.nav \|\| button\.dataset\.route;\s*button\.classList\.toggle\('is-active', navKey === activeNav\(normalized\)\);/s, 'active navigation must fall back to data-route');

console.log('universe bottom nav OK');
