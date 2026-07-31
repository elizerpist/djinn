import assert from 'node:assert/strict';
import { createPlanetVariantController } from '../assets/universe4/globe/planet-variant-controller.js';
import {
  V3_PHYSICS_EDGES,
  buildV3Layout,
  createV5NodePositionRegistry,
  syncV5NodePositionRegistry,
} from '../assets/universe4/globe/planet-data.js';

const nodesById = new Map([
  ['pao2', { id: 'pao2', lat: 47.5, lng: 19.0 }],
  ['bud1', { id: 'bud1', lat: 47.49, lng: 19.04 }],
  ['deb2', { id: 'deb2', lat: 47.53, lng: 21.63 }],
]);
const edges = [
  { id: 'pao2-bud1', source: 'pao2', target: 'bud1', weight: .9 },
  { id: 'pao2-deb2', source: 'pao2', target: 'deb2', weight: .6 },
];

const v5Events = [];
const v5 = createPlanetVariantController({
  variant: 'v5', edges, nodesById, trace: (event) => v5Events.push(event),
});
const v6 = createPlanetVariantController({ variant: 'v6', edges, nodesById });

assert.equal(v5.tap('pao2').action, 'focus');
assert.equal(v5.state().selectedCityId, 'pao2');
assert.equal(v5.state().ownerVariant, 'v5');
assert.equal(v5.tap('pao2').action, 'dehighlight');
assert.equal(v5.state().selectedCityId, null);
assert.equal(v6.state().selectedCityId, null);
assert.deepEqual(v5Events.map((event) => event.type), [
  'selection.focus',
  'selection.dehighlight',
]);

assert.equal(v5.tap('pao2').action, 'focus');
assert.equal(v5.tap('bud1').action, 'replace');
assert.equal(v5.state().selectedCityId, 'bud1');
assert.equal(v5Events.at(-1).type, 'selection.replace');

assert.equal(v5.clear('variant-hidden').action, 'clear');
assert.equal(v5.state().selectedCityId, null);
assert.deepEqual(v5Events.at(-1), {
  type: 'selection.clear',
  variant: 'v5',
  cityId: 'bud1',
  reason: 'variant-hidden',
});

// Regression: V5–V7 must receive the frozen 700-city Community Caps
// positions, not the small legacy ORB_POINTS coordinates. This is the exact
// position source used by the live Globe.gl arc adapter after layout creation.
const finalLayout = buildV3Layout('community-overkill');
const finalRegistry = createV5NodePositionRegistry();
syncV5NodePositionRegistry(finalRegistry, finalLayout.atoms);
const [finalEdge] = V3_PHYSICS_EDGES;

for (const variant of ['v5', 'v6', 'v7']) {
  const controller = createPlanetVariantController({
    variant,
    edges: V3_PHYSICS_EDGES,
    nodesById: finalRegistry,
  });
  const firstTap = controller.tap(finalEdge.source);
  const source = finalRegistry.get(finalEdge.source);
  assert.equal(firstTap.action, 'focus');
  assert.ok(firstTap.selection.selectedCityArcData.length > 0);
  assert.ok(firstTap.selection.selectedCityArcData.every((arc) => (
    arc.startLat === source.lat && arc.startLng === source.lng
  )), `${variant} selection arcs must begin at the frozen final layout position`);
  assert.equal(controller.tap(finalEdge.source).action, 'dehighlight',
    `${variant} repeat tap must clear the exact same local controller state`);
  assert.equal(controller.state().selectedCityArcData.length, 0);
}
