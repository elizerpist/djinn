import assert from 'node:assert/strict';
import { createUniverse4Snapshot, createUniverse4V7Snapshot } from '../assets/universe4/universe4-model.js';
import { getV5PlanetVisualSnapshot } from '../assets/universe4/globe/planet-data.js';

const source = {
  planetId: 'respiratory-planet',
  stableSeed: 8128,
  atoms: [
    { id: 'pneumonia', lat: 8.01, lng: 35.11, color: '#56f2ef', size: 1.2, communityId: 'respiratory' },
    { id: 'ards', lat: 52.08, lng: 149.32, color: '#56f2ef', size: .9, communityId: 'respiratory' },
  ],
  surfaceArcs: [{ id: 'pneumonia:ards', sourceCityId: 'pneumonia', targetCityId: 'ards' }],
  selectedCityId: 'pneumonia',
  activeConnectionIds: ['pneumonia:ards'],
  labels: [{ atomId: 'pneumonia', priority: 10 }],
  landmarks: ['pneumonia', 'ards'],
  globeMaterial: { color: '#2a1a57', shininess: 9 },
  lighting: { mode: 'universe-v3-reference', keyIntensity: 1.4 },
  atmosphere: { color: '#7d75ff', altitude: .12 },
  cosmicEnvironment: { seed: 44, reducedEffects: false },
  visualLod: 'near',
  validation: { source: 'universe4' },
  randomValues: { labelOrder: [0.9, 0.4] },
};

const first = createUniverse4Snapshot(source);
const repeated = createUniverse4Snapshot(source);

assert.equal(first.planetId, 'respiratory-planet');
assert.equal(first.seed, 8128);
assert.equal(first.stableSeed, 8128);
assert.equal(first.planet.selectedCityId, 'pneumonia');
assert.equal(first.planet.atoms.length, 2);
assert.equal(first.planet.arcs.length, 1);
assert.equal(first.snapshotId, repeated.snapshotId, 'the same input must produce the same visual snapshot identity');
assert.deepEqual(first, repeated, 'the snapshot must be deterministic');
assert.ok(Object.isFrozen(first));
assert.ok(Object.isFrozen(first.planet));
assert.ok(Object.isFrozen(first.planet.atoms));
assert.ok(Object.isFrozen(first.planet.atoms[0]));
assert.ok(Object.isFrozen(first.planet.material));

source.atoms[0].lat = 90;
source.globeMaterial.color = '#ffffff';
assert.equal(first.planet.atoms[0].lat, 8.01, 'snapshot data must not share mutable atom references with its source');
assert.equal(first.planet.material.color, '#2a1a57', 'snapshot data must not share mutable visual state with its source');
assert.throws(() => { first.planet.atoms[0].lat = 90; }, TypeError);

const derivedSeed = createUniverse4Snapshot({ planetId: 'same-planet' });
assert.equal(derivedSeed.seed, createUniverse4Snapshot({ planetId: 'same-planet' }).seed);

const canonicalV7 = getV5PlanetVisualSnapshot();
const u4V7 = createUniverse4V7Snapshot({
  planetId: 'galaxy-planet-001',
  galaxy: { nodes: [{ id: 'galaxy-planet-001', isPlanet: true }], links: [] },
});
assert.equal(u4V7.planet.atoms.length, canonicalV7.atoms.length, 'U4 target must keep the full concrete V7 city count');
assert.deepEqual(u4V7.planet.atoms[0], canonicalV7.atoms[0], 'U4 target must preserve V7 geographic city coordinates and visual tokens');
assert.equal(u4V7.planet.material.source, 'universe-v7');
assert.equal(u4V7.planet.lighting.source, 'universe-v7-universe-v3-reference');

console.log('universe4 model OK');
