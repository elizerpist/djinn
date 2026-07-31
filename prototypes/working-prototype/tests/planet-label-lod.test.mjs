import assert from 'node:assert/strict';
import { getPlanetLabelLod } from '../assets/universe4/globe/planet-label-lod.js';

assert.deepEqual(
  getPlanetLabelLod({ distance: 3.39, focused: false }),
  { id: 'orbit', limit: 8 },
  'the screenshot-scale orbit must not be limited to only three city labels',
);
assert.deepEqual(
  getPlanetLabelLod({ distance: 4.1, focused: false }),
  { id: 'far', limit: 5 },
  'only a genuinely distant globe may use the sparse landmark budget',
);
assert.deepEqual(
  getPlanetLabelLod({ distance: 2.1, focused: false }),
  { id: 'medium', limit: 11 },
  'medium zoom must reveal more readable city labels',
);
assert.deepEqual(
  getPlanetLabelLod({ distance: 1.5, focused: false }),
  { id: 'near', limit: 15 },
  'near zoom must expose the full production landmark budget before collision filtering',
);
assert.deepEqual(
  getPlanetLabelLod({ distance: 1.5, focused: true }),
  { id: 'focus', limit: 9 },
  'focus keeps the selected city plus its nearby context readable',
);

console.log('planet label LOD OK');
