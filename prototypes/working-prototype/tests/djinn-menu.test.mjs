import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const screen = fs.readFileSync(path.join(root, 'screens/djinn.html'), 'utf8');
const app = fs.readFileSync(path.join(root, 'assets/app.js'), 'utf8');
const styles = fs.readFileSync(path.join(root, 'assets/styles.css'), 'utf8');
const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

assert.match(screen, /djinn-command-screen/);
assert.match(screen, /Miben segítsek itt\?/);
assert.match(screen, /AKTUÁLIS KONTEXTUS/);
assert.match(screen, /data-route="query"/);
assert.match(screen, /data-route="universe"/);
assert.match(screen, /data-route="workspace-note-editor"/);
assert.match(screen, /data-route="workspace-library"/);
assert.match(screen, /data-djinn-form/);
assert.match(screen, /Megnyitás Kérdezzben/);
assert.doesNotMatch(screen, /Javasolt kérdések/);
assert.doesNotMatch(screen, /Kérdezz a tudásodból/);
assert.match(app, /const djinnForm = event\.target\.closest\('\[data-djinn-form\]'\)/);
assert.match(app, /state\.question = djinnForm\.querySelector\('input'\)/);
assert.match(styles, /\.djinn-command-sheet/);
assert.match(styles, /\.djinn-command-grid/);
assert.match(styles, /\.djinn-context-card/);
assert.doesNotMatch(index, /class="status-bar"/, 'the prototype status bar must not consume app viewport height');
assert.doesNotMatch(styles, /\.status-bar\s*\{/, 'status bar styles must be removed with the markup');
assert.match(styles, /\.app-shell\s*\{[^}]*height:\s*100%/, 'the app shell must reclaim the removed status-bar height');
// The production entry points are explicitly versioned so a device cannot
// retain stale renderer/state modules after a Universe update.
assert.match(index, /assets\/styles\.css\?rev=147/);
assert.match(index, /assets\/app\.js\?rev=280/);

console.log('djinn command menu OK');
