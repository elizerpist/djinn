import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const adapter = await readFile(new URL('../assets/universe4/universe4-v7-source-stage.js', import.meta.url), 'utf8');
const canonical = await readFile(new URL('../assets/explore-galaxy-orb.js', import.meta.url), 'utf8');
const css = await readFile(new URL('../assets/universe4/universe4.css', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');

// U4 needs the identical V7 renderer, but not the entire Explore page chrome.
// Its destination must give the canonical controller a real measured viewport
// and request its bare-planet presentation mode.
assert.match(adapter, /embeddedViewport:\s*mount/);
assert.match(adapter, /embeddedBarePlanet:\s*true/);
assert.match(adapter, /embeddedDebugPortal:\s*debugPortal/);
assert.match(canonical, /embeddedViewport\s*=\s*null/);
assert.match(canonical, /embeddedBarePlanet\s*=\s*false/);
assert.match(canonical, /embeddedDebugPortal\s*=\s*null/);
assert.match(canonical, /if \(embeddedViewport\)/);
assert.match(canonical, /is-embedded-bare-planet/);
assert.match(canonical, /function syncEmbeddedViewportSize\(\)/, 'embedded V7 needs an eager WebGL canvas-size synchronizer');
assert.match(canonical, /applyOrbVariant\(\);\s*syncEmbeddedViewportSize\(\);/, 'the eager size synchronizer must run directly after Globe construction');
assert.match(canonical, /embeddedDebugPortal\.append\(v7LightTuning, planetSignalDebugHost\)/, 'U4 must portal the real V7 debug controls and copyable signal trace outside the hidden destination stage');
assert.match(canonical, /recordEmbeddedRenderDiagnostic\('u4\.globe\.prewarm'\)/, 'the V7 panel must be visible even when Globe construction fails before ready');
assert.match(canonical, /recordEmbeddedRenderDiagnostic\('u4\.globe\.ready'\)/, 'the copied V7 trace must expose the embedded renderer state');
assert.match(css, /is-embedded-bare-planet[\s\S]*galaxy-orb-controls/);
// U4 hides Explore navigation chrome, but it must retain the exact V7
// bottom light/debug and copyable signal panels while the embedded Globe is
// diagnosed on a real device.
assert.match(css, /universe4-v7-debug-portal \.galaxy-orb-v7-light-debug[\s\S]*display: flex !important;/);
assert.match(css, /universe4-v7-debug-portal \.planet-signal-debug-panel[\s\S]*display: grid !important;/);
assert.match(css, /universe4-v7-debug-portal/, 'the V7 debug portal must remain above both U4 render stages');
// Globe.gl can synchronously invoke `onGlobeReady` before its factory returns
// the stage object. U4 must defer its outer callback; otherwise updateDebug()
// reads `v7Stage` in its temporal-dead-zone and aborts the canonical V7 init.
assert.match(runtime, /onReady:\s*\(\)\s*=>\s*\{[\s\S]*?queueMicrotask\(/,
  'U4 must defer the V7-ready callback until v7Stage has been initialized');

console.log('universe4 bare V7 planet stage contract OK');
