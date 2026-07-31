import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const controller = await readFile(new URL('../assets/universe4/universe4-force-controller.js', import.meta.url), 'utf8');
const model = await readFile(new URL('../assets/universe4/universe4-force-model.js', import.meta.url), 'utf8');
const adapter = await readFile(new URL('../assets/universe4/universe4-u3-stage.js', import.meta.url), 'utf8');

assert.match(controller, /export function initUniverse4ForceController/);
assert.match(controller, /captureFocusedPlanetHandoffFrame/);
assert.match(controller, /captureFocusedPlanetRenderProfile/);
assert.match(controller, /pauseUniverseRenderRuntime/);
assert.match(controller, /resumeUniverseRenderRuntime/);
assert.match(controller, /dispose\.resetToGalaxyOverview/);
assert.doesNotMatch(controller, /from ['"].*universe-morph-model/);
assert.doesNotMatch(controller, /initUniverseMorphTest/);
assert.match(model, /export function createUniverseMockData/);
assert.match(adapter, /from '\.\/universe4-force-controller\.js\?rev=2'/);
assert.match(adapter, /suppressInlineCityLabels: true/);
assert.match(adapter, /pauseAnimation/);
assert.match(adapter, /resumeAnimation/);
assert.match(adapter, /captureHandoffFrame/);
assert.match(adapter, /captureRenderProfile/);
assert.match(adapter, /resetToGalaxyOverview/);

console.log('universe4 Force owner contract OK');
