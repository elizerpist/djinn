import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../assets/universe4/globe/planet-debug-panel.js', import.meta.url), 'utf8');
const styleSource = await readFile(new URL('../assets/styles.css', import.meta.url), 'utf8');

assert.match(source, /data-planet-signal-log/);
assert.match(source, /data-planet-signal-copy/);
assert.match(source, /Mind másolása/);
assert.match(styleSource, /max-height:\s*100px/);
