import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const sourceStage = await readFile(new URL('../assets/universe4/universe4-v7-source-stage.js', import.meta.url), 'utf8');
const u3Stage = await readFile(new URL('../assets/universe4/universe4-u3-stage.js', import.meta.url), 'utf8');
const runtime = await readFile(new URL('../assets/universe4.js', import.meta.url), 'utf8');
const exploreController = await readFile(new URL('../assets/explore-galaxy-orb.js', import.meta.url), 'utf8');
const u3Controller = await readFile(new URL('../assets/universe-morph-test.js', import.meta.url), 'utf8');
const lightRig = await readFile(new URL('../assets/virtual-galaxy-light-rig.js', import.meta.url), 'utf8');

// U4 must mount the exact V7 controller, not a hand-copied approximation.
assert.match(sourceStage, /initExpandableGalaxyOrb/);
assert.match(sourceStage, /initialVariant:\s*'v7'/);
assert.match(sourceStage, /setRoute\('explore'\)/);
assert.match(sourceStage, /export function createUniverse4V7SourceStage/);
assert.match(exploreController, /onGlobeReady/,
  'the canonical Explore controller must expose a lifecycle signal to U4');
assert.match(exploreController, /initialVariant/,
  'the canonical Explore controller must accept the V7 initial variant directly');

// U4 must run the existing U3 flow rather than another ForceGraph copy.
assert.match(u3Stage, /initUniverseMorphTest/);
assert.match(u3Stage, /onPlanetReady/);
assert.match(u3Controller, /helpers\.onPlanetReady/,
  'the real U3 controller must provide the handoff boundary after its own morph');
assert.match(runtime, /createUniverse4U3Stage/);
assert.match(runtime, /createUniverse4V7SourceStage/);
assert.doesNotMatch(runtime, /createUniverse4ForceStage/);
assert.doesNotMatch(runtime, /createUniverse4V7GlobeStage/);
assert.doesNotMatch(runtime, /navigate\([^)]*explore/i);

// The requested U3-reference visual profile is shared, not approximated
// separately at the ForceGraph and Globe.gl sides of the U4 handoff.
assert.match(lightRig, /export const UNIVERSE_V3_REFERENCE_LIGHTING/);
assert.match(exploreController, /let v7LightMode = 'universe-v3-reference'/);
assert.match(exploreController, /v7LightMode = 'universe-v3-reference'/);
assert.match(u3Controller, /UNIVERSE_V3_REFERENCE_LIGHTING/);
assert.match(u3Controller, /new THREE\.AmbientLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.ambientColor, UNIVERSE_V3_REFERENCE_LIGHTING\.ambientIntensity\)/);
assert.match(u3Controller, /new THREE\.HemisphereLight\(\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillColor,\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillGroundColor,\s*UNIVERSE_V3_REFERENCE_LIGHTING\.fillIntensity/s);
assert.match(u3Controller, /new THREE\.DirectionalLight\(UNIVERSE_V3_REFERENCE_LIGHTING\.keyColor, UNIVERSE_V3_REFERENCE_LIGHTING\.keyIntensity\)/);
const inlineDetailGlobe = u3Controller.match(/function configureDetailGlobe\(ThreeGlobe, view\) \{[\s\S]*?\n  \}/)?.[0] || '';
assert.match(inlineDetailGlobe, /new THREE\.MeshPhongMaterial\(/,
  'the inline body must use the same Phong response as the canonical Globe.gl body');
assert.match(inlineDetailGlobe, /color: UNIVERSE_V3_REFERENCE_LIGHTING\.color/);
assert.match(inlineDetailGlobe, /emissive: UNIVERSE_V3_REFERENCE_LIGHTING\.emissive/);
assert.match(u3Controller, /function stripForceGraphDefaultLights\(scene\)/,
  'the inline U3 scene must not retain extra ForceGraph default lights that V7 does not have');

console.log('universe4 V7 source-of-truth contract OK');
