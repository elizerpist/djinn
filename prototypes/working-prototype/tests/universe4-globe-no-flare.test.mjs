import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const source = await readFile(new URL('../assets/universe4/universe4-globe-stage.js', import.meta.url), 'utf8');

function section(start, end) {
  const startIndex = source.indexOf(start);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.ok(startIndex >= 0 && endIndex > startIndex, `missing source section: ${start}`);
  return source.slice(startIndex, endIndex);
}

const v6Apply = section('function applyVariantLightRig()', 'function createLightDirectionProof()');
const v7Apply = section('function applyV7LightRig()', 'function suspendV7LightRig()');
const v7FrameHook = section('function ensureV7LightRig()', 'function ensureV7CosmicEnvironment()');
const v6Cosmic = section('function ensureV6CosmicEnvironment()', 'function applyV6CosmicEnvironment()');
const v7Cosmic = section('function ensureV7CosmicEnvironment()', 'function applyV7CosmicEnvironment()');

assert.doesNotMatch(v6Apply, /applyV6LensFlare/, 'V6 production must not activate a lens flare');
assert.doesNotMatch(v7Apply, /applyV7LensFlare/, 'V7 production must not activate a lens flare');
assert.doesNotMatch(v7FrameHook, /v7LensFlare\?\.updateFrame/, 'V7 frame updates must not render a lens flare');
assert.match(v6Cosmic, /getLensFlareController:\s*\(\)\s*=>\s*null/, 'V6 cosmic sun and stars must run without a flare controller');
assert.match(v7Cosmic, /getLensFlareController:\s*\(\)\s*=>\s*null/, 'V7 cosmic sun and stars must run without a flare controller');

console.log('Universe V6/V7 no-flare production wiring OK');
