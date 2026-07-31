import assert from 'node:assert/strict';
import { buildUniverse4FocusedMapSnapshot } from '../assets/universe4/universe4-focused-map-snapshot.js';

const nodes = [
  { id: 'root', title: 'Root', lat: 5, lng: 6, color: '#cfeeff' },
  { id: 'context', title: 'Context', lat: 7, lng: 8, color: '#ffd45a' },
  { id: 'sibling', title: 'Sibling', lat: 9, lng: 10, color: '#ffd45a' },
  { id: 'foreign', title: 'Foreign', lat: 15, lng: 16, color: '#56f2ef' },
];
const selection = {
  selectedCityId: 'root',
  selectedCityArcData: [
    { id: 'root-context', sourceCityId: 'root', targetCityId: 'context', weight: .9 },
    { id: 'root-sibling', sourceCityId: 'sibling', targetCityId: 'root', weight: .7 },
  ],
};

const source = {
  sourcePlanetId: 'respiratory',
  rootCityId: 'root',
  tappedContextCityId: 'context',
  selection,
  nodes,
  globePointOfView: { lat: 12, lng: 28, altitude: 1.1 },
  cityAnchor: { x: 180, y: 255, width: 30, height: 30 },
};

const first = buildUniverse4FocusedMapSnapshot(source);
const repeat = buildUniverse4FocusedMapSnapshot(source);
const rootFocus = buildUniverse4FocusedMapSnapshot({ ...source, tappedContextCityId: 'root' });
assert.equal(first.sourcePlanetId, 'respiratory');
assert.equal(first.rootCityId, 'root');
assert.equal(first.tappedContextCityId, 'context');
assert.equal(first.focusCityId, 'context');
assert.equal(rootFocus.focusCityId, 'root', 'a repeated root tap must enter the map focused on the root city');
assert.deepEqual(first.contextCityIds, ['context', 'sibling']);
assert.deepEqual(first.nodes.map((node) => node.id), ['root', 'context', 'sibling']);
assert.equal(first.edges.length, 2);
assert.equal(first.snapshotId, repeat.snapshotId, 'same selection must lead to a deterministic reusable map snapshot');
assert.deepEqual(first, repeat);
assert.ok(Object.isFrozen(first));
assert.ok(Object.isFrozen(first.nodes));
assert.ok(Object.isFrozen(first.nodes[0]));

nodes[0].title = 'mutated';
assert.equal(first.nodes[0].title, 'Root');
assert.throws(() => buildUniverse4FocusedMapSnapshot({ ...source, tappedContextCityId: 'foreign' }), /root or an active context city/);

console.log('universe4 focused map snapshot OK');
