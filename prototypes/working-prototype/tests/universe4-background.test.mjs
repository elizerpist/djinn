import assert from 'node:assert/strict';

import {
  U4_BACKGROUND_PROFILES,
  resolveUniverse4Background,
} from '../assets/universe4/universe4-background.js';

assert.deepEqual(U4_BACKGROUND_PROFILES.force, {
  id: 'force',
  label: 'ForceGraph · világosabb',
  color: '#0B0A17',
});

assert.deepEqual(U4_BACKGROUND_PROFILES.globe, {
  id: 'globe',
  label: 'Globe.gl · sötétebb',
  color: '#03091D',
});

assert.equal(resolveUniverse4Background('force').color, '#0B0A17');
assert.equal(resolveUniverse4Background('globe').color, '#03091D');
assert.equal(resolveUniverse4Background('unknown').id, 'force',
  'an invalid select value must fall back to the lighter ForceGraph background');

console.log('universe4 background profiles OK');
