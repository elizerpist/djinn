import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const index = await readFile(new URL('../index.html', import.meta.url), 'utf8');
const app = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
const screen = await readFile(new URL('../screens/universe-morph-test-v4.html', import.meta.url), 'utf8');
const css = await readFile(new URL('../assets/universe4/universe4.css', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');
const universeChildScreens = await Promise.all([
  'universe-morph-test.html',
  'universe-morph-test-v2.html',
  'universe-morph-test-v3.html',
].map((file) => readFile(new URL(`../screens/${file}`, import.meta.url), 'utf8')));

assert.match(index, /assets\/universe4\/universe4\.css\?rev=16/);
assert.match(index, /assets\/app\.js\?rev=271/);
assert.match(app, /initUniverse4 \} from '\.\/universe4\.js\?rev=54';/);
assert.match(app, /'universe-morph-test-v4': 'screens\/universe-morph-test-v4\.html'/);
assert.match(app, /normalized === 'universe-morph-test-v4'[\s\S]*initUniverse4\(root,/);
assert.match(screen, /data-universe4-force-stage/);
assert.match(screen, /data-universe4-globe-stage/);
assert.match(screen, /data-universe4-v7-debug-portal/, 'U4 must surface the real V7 debug controls and renderer trace on its own screen');
assert.match(screen, /data-universe4-stage-shell/, 'fullscreen must include both the render viewport and its control panel');
assert.match(screen, /data-universe4-fullscreen/, 'U4 needs the same stage-local fullscreen control as the other Universe screens');
assert.match(screen, /data-universe4-reset/, 'U4 needs a stage-level Reset action while V7 owns the view');
assert.match(screen, /data-universe4-force-background/, 'U4 needs an independent ForceGraph background selector');
assert.match(screen, /data-universe4-globe-background/, 'U4 needs an independent Globe background selector');
assert.ok(
  screen.indexOf('data-universe4-debug') > screen.indexOf('</section>'),
  'U4 diagnostic panel must live below the render viewport instead of covering it',
);
assert.match(css, /\.universe4-stage-shell:fullscreen[\s\S]*\.is-universe4-fullscreen-fallback/,
  'U4 fullscreen target needs native and Android-WebView fallback styling');
assert.match(css, /\.universe4-debug\s*\{[^}]*position:\s*static/s,
  'U4 diagnostic panel must use normal document flow');
assert.match(css, /is-u4-match-diagnostics[\s\S]*\.universe4-debug/,
  'a failed hidden match must surface measured diagnostics without polluting the successful bare-V7 endpoint');
assert.match(css, /\.universe4-v7-source-root \.galaxy-orb-label-layer\s*\{[^}]*pointer-events:\s*none/,
  'the transparent V7 label layer must pass background gestures through to Globe.gl');
assert.match(css, /\.universe4-v7-source-root \.galaxy-orb-label\s*\{[^}]*pointer-events:\s*auto/,
  'individual V7 city labels must remain tappable above the Globe canvas');
assert.match(runtime, /data-universe4-fullscreen/);
assert.match(runtime, /data-universe4-stage-shell/);
assert.match(runtime, /requestFullscreen/);
for (const childScreen of universeChildScreens) {
  assert.match(childScreen, /data-route="universe-morph-test-v4"[^>]*>Universe v4<\//,
    'Universe v4 must be reachable from every existing Universe child menu');
}

console.log('universe4 route OK');
