import assert from 'node:assert/strict';
import {
  SURFACE_SELECTION_ARC_PROFILE,
  clearCityConnections,
  selectCityConnections,
} from '../assets/city-selection-arcs.js';

const nodes = new Map([
  ['a', { id: 'a', lat: 12, lng: 28 }],
  ['b', { id: 'b', lat: 18, lng: 36 }],
  ['c', { id: 'c', lat: -7, lng: 42 }],
  ['d', { id: 'd', lat: 30, lng: -12 }],
  ['bad', { id: 'bad', lat: Number.NaN, lng: 10 }],
]);
const edges = [
  { id: 'a-c', source: 'a', target: 'c', weight: .7, type: 'evidence' },
  { id: 'a-b', source: 'a', target: 'b', weight: .9, type: 'evidence' },
  { id: 'a-b-low', source: 'a', target: 'b', weight: .2, type: 'evidence' },
  { id: 'a-d', source: 'a', target: 'd', weight: .7, type: 'evidence' },
  { id: 'a-missing', source: 'a', target: 'missing', weight: 1, type: 'evidence' },
  { id: 'a-bad', source: 'a', target: 'bad', weight: 1, type: 'evidence' },
];

const state = selectCityConnections({ variant: 'v6', cityId: 'a', edges, nodesById: nodes });
assert.equal(state.ownerVariant, 'v6');
assert.equal(state.selectedCityId, 'a');
assert.deepEqual(state.selectedConnectionIds, ['a-b', 'a-c', 'a-d']);
assert.equal(state.selectedCityArcData.length, 3);
for (const arc of state.selectedCityArcData) {
  assert.equal(arc.renderer, 'surface-selection-arc');
  assert.equal(arc.source, 'a');
  assert.ok(Number.isFinite(arc.startLat) && Number.isFinite(arc.startLng));
  assert.ok(Number.isFinite(arc.endLat) && Number.isFinite(arc.endLng));
  assert.ok(arc.startAltitude >= .014 && arc.startAltitude <= .016);
  assert.equal(arc.startAltitude, arc.endAltitude);
  assert.equal(arc.startAltitude, arc.peakAltitude);
  assert.ok(arc.stroke >= .440 && arc.stroke <= .720,
    'selected gold surface routes must remain visibly readable on a mobile globe');
  assert.equal(arc.highlight, true, 'every selected city connection must use the gold highlight treatment');
  assert.ok(Array.isArray(arc.surfacePoints) && arc.surfacePoints.length >= 2,
    'each selected connection must carry an explicit Globe.gl surface path');
  assert.deepEqual(arc.surfacePoints[0], {
    lat: arc.startLat,
    lng: arc.startLng,
    altitude: arc.surfacePoints[0].altitude,
  });
  assert.deepEqual(arc.surfacePoints.at(-1), {
    lat: arc.endLat,
    lng: arc.endLng,
    altitude: arc.surfacePoints.at(-1).altitude,
  });
}
assert.equal(SURFACE_SELECTION_ARC_PROFILE.altitude, .015, 'the surface path must sit just above the rendered node shell');
assert.equal(SURFACE_SELECTION_ARC_PROFILE.pathResolution, .5, 'the native Globe path must stay smooth on long routes');
assert.equal(SURFACE_SELECTION_ARC_PROFILE.strokeMin, .440,
  'the lightest selected route must remain visibly thicker than the prior hairline treatment');
assert.equal(SURFACE_SELECTION_ARC_PROFILE.strokeMax, .720,
  'the heaviest selected route must preserve hierarchy without becoming a tube');
assert.deepEqual(clearCityConnections(), {
  ownerVariant: null,
  selectedCityId: null,
  selectedConnectionIds: [],
  selectedCityArcData: [],
});

const manyEdges = Array.from({ length: 16 }, (_, index) => ({
  id: `a-many-${index}`,
  source: 'a',
  target: 'b',
  weight: 16 - index,
  type: 'evidence',
}));
const capped = selectCityConnections({ variant: 'v5', cityId: 'a', edges: manyEdges, nodesById: nodes });
assert.equal(capped.selectedCityArcData.length, 1, 'duplicate city pairs must collapse before the cap');
