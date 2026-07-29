import assert from 'node:assert/strict';
import {
  clearPlanetSelectionArcs,
  commitPlanetSelectionArcs,
} from '../assets/explore/planet-globe-arc-adapter.js';

const assigned = [];
const assignedPaths = [];
const globe = {
  arcsData(value) {
    if (arguments.length) assigned.splice(0, assigned.length, ...value);
    return assigned;
  },
  pathsData(value) {
    if (arguments.length) assignedPaths.splice(0, assignedPaths.length, ...value);
    return assignedPaths;
  },
};
const entries = [];
const trace = { record: (event, payload) => entries.push({ event, ...payload }) };
const selection = {
  selectedCityArcData: [
    {
      id: 'surface:a-b',
      renderer: 'surface-selection-arc',
      startLat: 12,
      startLng: 28,
      endLat: 18,
      endLng: 36,
      surfacePoints: [
        { lat: 12, lng: 28, altitude: .016 },
        { lat: 15, lng: 32, altitude: .016 },
        { lat: 18, lng: 36, altitude: .016 },
      ],
    },
    {
      id: 'bad-position',
      renderer: 'surface-selection-arc',
      startLat: Number.NaN,
      startLng: 28,
      endLat: 18,
      endLng: 36,
    },
    {
      id: 'wrong-renderer',
      renderer: 'other',
      startLat: 12,
      startLng: 28,
      endLat: 18,
      endLng: 36,
    },
  ],
};

const result = commitPlanetSelectionArcs({ globe, selection, trace });
assert.equal(result.assignedCount, 1);
assert.equal(result.verifiedCount, 1);
assert.equal(result.profile, 'surface-selection-arc');
assert.deepEqual(assigned, [], 'selection routes must not remain in the visually chord-like arcs layer');
assert.deepEqual(assignedPaths.map((arc) => arc.id), ['surface:a-b']);
assert.deepEqual(entries.map((entry) => entry.event), ['arc.payload', 'arc.commit', 'arc.verify']);
assert.deepEqual(entries[0].rejectedIds, ['bad-position', 'wrong-renderer']);
assert.deepEqual(entries[0].assignedArcs, [{
  id: 'surface:a-b',
  sourceCityId: undefined,
  targetCityId: undefined,
  startLat: 12,
  startLng: 28,
  endLat: 18,
  endLng: 36,
  surfacePointCount: 3,
}]);

const clearResult = clearPlanetSelectionArcs({ globe, trace, reason: 'repeat-tap' });
assert.equal(assigned.length, 0);
assert.equal(assignedPaths.length, 0);
assert.equal(clearResult.assignedCount, 0);
assert.equal(clearResult.verifiedCount, 0);
assert.equal(clearResult.profile, 'surface-selection-arc');
assert.deepEqual(entries.at(-1), { event: 'arc.clear', reason: 'repeat-tap', assignedCount: 0, verifiedCount: 0, profile: 'surface-selection-arc', renderLayer: 'paths' });
