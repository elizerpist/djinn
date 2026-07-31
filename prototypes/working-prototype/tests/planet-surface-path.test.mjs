import assert from 'node:assert/strict';
import { buildGreatCircleSurfacePath } from '../assets/universe4/globe/planet-surface-path.js';

const path = buildGreatCircleSurfacePath(
  { lat: 8, lng: 35 },
  { lat: -29, lng: -85 },
  { altitude: .016, minSegments: 16, maxSegments: 96, degreesPerSegment: 2 },
);

assert.ok(path.length >= 16, 'a long selection route needs multiple surface samples');
assert.deepEqual(path[0], { lat: 8, lng: 35, altitude: .016 });
assert.deepEqual(path.at(-1), { lat: -29, lng: -85, altitude: .016 });
assert.ok(path.every((point) => Number.isFinite(point.lat) && Number.isFinite(point.lng) && point.altitude === .016));
assert.notDeepEqual(path[1], path[0], 'the renderer must receive actual great-circle progress, not a chord endpoint pair');

console.log('planet great-circle surface path OK');
