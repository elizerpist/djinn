import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const query = fs.readFileSync(path.join(root, 'screens/query.html'), 'utf8');
const answer = fs.readFileSync(path.join(root, 'screens/query-answer.html'), 'utf8');
const app = fs.readFileSync(path.join(root, 'assets/app.js'), 'utf8');
const styles = fs.readFileSync(path.join(root, 'assets/styles.css'), 'utf8');
const index = fs.readFileSync(path.join(root, 'index.html'), 'utf8');

assert.match(query, /data-query-screen/);
assert.match(query, /data-query-scope-toggle/);
assert.match(query, /data-query-scope-menu/);
assert.match(query, /data-query-form/);
assert.match(query, /data-query-voice/);
assert.match(query, /query-shortcut-grid/);
assert.match(query, /data-query-fill/);
assert.doesNotMatch(query, /Search|Keresés gomb/);

assert.match(answer, /data-route="query-evidence"/);
assert.match(answer, /data-route="query-related"/);
assert.match(answer, /data-route="query-sources"/);
assert.match(answer, /data-route="query-process"/);

assert.match(app, /'query-evidence': 'screens\/query-evidence\.html'/);
assert.match(app, /'query-related': 'screens\/query-related\.html'/);
assert.match(app, /'query-sources': 'screens\/query-sources\.html'/);
assert.match(app, /'query-process': 'screens\/query-process\.html'/);
assert.match(app, /data-query-scope-option/);
assert.match(app, /data-query-fill/);
assert.match(index, /assets\/styles\.css\?rev=147/);
assert.match(index, /assets\/app\.js\?rev=280/);
assert.match(styles, /\.query-scope-menu/);
assert.match(styles, /\.query-answer-actions/);
assert.match(styles, /\.query-related-map/);
assert.match(styles, /\.query-source-compare/);
assert.match(styles, /\.query-process-flow/);

console.log('query menu flow OK');
