import assert from 'node:assert/strict';
import {
  CORRIDOR_MOCK,
  TEST_SEED,
  UNIVERSE_FOCUS_STATE,
  UNIVERSE_LEVEL,
  canTransition,
  clampOrbitDistance,
  classifyPointerTap,
  createUniverseMockData,
  easeInOutCubic,
  fibonacciSpherePoint,
  focusDistanceForBoundingRadius,
  focusCameraTarget,
  focusTargetDelta,
  galaxyNodeRadius,
  projectPointToScreen,
  reverseTransition,
  surfaceArcPoints,
} from '../assets/universe4/universe4-force-model.js';

const first = createUniverseMockData(TEST_SEED);
const repeated = createUniverseMockData(TEST_SEED);

assert.equal(first.galaxy.nodes.length, 180);
assert.equal(first.galaxy.links.length, 260);
assert.equal(first.galaxy.planetIds.length, 8);
assert.deepEqual(
  first.galaxy.planetIds.map((id) => first.galaxy.nodes.find((node) => node.id === id)?.atomCount),
  [8, 28, 48, 68, 88, 108, 128, 148],
);
assert.equal(first.planet.nodes.length, 140);
assert.equal(first.planet.links.length, 210);
assert.equal(first.map.nodes.length, 28);
assert.equal(first.map.links.length, 42);
assert.equal(UNIVERSE_LEVEL.CORRIDOR, 'CORRIDOR');
assert.equal(UNIVERSE_FOCUS_STATE.GALAXY_OVERVIEW, 'GALAXY_OVERVIEW');
assert.equal(UNIVERSE_FOCUS_STATE.PLANET_FOCUS, 'PLANET_FOCUS');
assert.equal(CORRIDOR_MOCK.connectionCount, 18);
assert.equal(CORRIDOR_MOCK.sourceCount, 7);
assert.equal(CORRIDOR_MOCK.bridges.length, 3);
assert.deepEqual(first, repeated, 'the V4 Force model must be repeatable from one seed');

const point = fibonacciSpherePoint(11, 140, 100, .02);
assert.ok(Math.abs(Math.hypot(point.x, point.y, point.z) - 102) < 1e-8);
assert.ok(point.lat >= -90 && point.lat <= 90);
assert.ok(point.lng >= -180 && point.lng <= 180);

assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 18, y: 17, endedAt: 390 }), true);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 23, y: 12, endedAt: 220 }), false);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 12, y: 12, endedAt: 401 }), false);

assert.equal(canTransition(UNIVERSE_LEVEL.GALAXY, UNIVERSE_LEVEL.GALAXY_TO_PLANET), true);
assert.equal(canTransition(UNIVERSE_LEVEL.GALAXY, UNIVERSE_LEVEL.CORRIDOR), true);
assert.equal(canTransition(UNIVERSE_LEVEL.CORRIDOR, UNIVERSE_LEVEL.GALAXY), true);
assert.equal(canTransition(UNIVERSE_LEVEL.PLANET, UNIVERSE_LEVEL.PLANET_TO_MAP), true);
assert.equal(canTransition(UNIVERSE_LEVEL.MAP, UNIVERSE_LEVEL.PLANET_TO_MAP), false);
assert.equal(reverseTransition(UNIVERSE_LEVEL.MAP), UNIVERSE_LEVEL.MAP_TO_PLANET);
assert.equal(reverseTransition(UNIVERSE_LEVEL.PLANET), UNIVERSE_LEVEL.PLANET_TO_GALAXY);
assert.equal(reverseTransition(UNIVERSE_LEVEL.CORRIDOR), UNIVERSE_LEVEL.GALAXY);
assert.equal(reverseTransition(UNIVERSE_LEVEL.GALAXY), null);

assert.ok(galaxyNodeRadius(0, 0, 12) < galaxyNodeRadius(4, 0, 12));
assert.ok(galaxyNodeRadius(4, 0, 12) < galaxyNodeRadius(12, 0, 12));
assert.ok(galaxyNodeRadius(12, 0, 12) <= 6.4);
assert.equal(easeInOutCubic(0), 0);
assert.equal(easeInOutCubic(1), 1);
assert.ok(easeInOutCubic(.5) > .49 && easeInOutCubic(.5) < .51);
assert.deepEqual(
  focusCameraTarget({ x: 4, y: 5, z: 6 }, { x: 0, y: 0, z: 20 }, { x: 0, y: 0, z: 0 }, 12),
  { x: 4, y: 5, z: 18 },
);

const squareFocusDistance = focusDistanceForBoundingRadius(10, 50, 1, .4);
const narrowFocusDistance = focusDistanceForBoundingRadius(10, 50, .55, .4);
assert.ok(squareFocusDistance > 10);
assert.ok(narrowFocusDistance > squareFocusDistance);
assert.deepEqual(
  clampOrbitDistance({ x: 0, y: 0, z: 100 }, { x: 0, y: 0, z: 0 }, 20, 60),
  { x: 0, y: 0, z: 60, distance: 60 },
);
assert.deepEqual(
  clampOrbitDistance({ x: 0, y: 0, z: 5 }, { x: 0, y: 0, z: 0 }, 20, 60),
  { x: 0, y: 0, z: 20, distance: 20 },
);
assert.equal(focusTargetDelta({ x: 3, y: 4, z: 5 }, { x: 3, y: 4, z: 5 }), 0);
assert.equal(focusTargetDelta({ x: 3, y: 4, z: 5 }, { x: 6, y: 8, z: 5 }), 5);

const arc = surfaceArcPoints({ x: 100, y: 0, z: 0 }, { x: 0, y: 100, z: 0 }, 100, 8, .045);
assert.equal(arc.length, 9);
assert.ok(arc.every((entry) => Math.hypot(entry.x, entry.y, entry.z) >= 104.5));
assert.ok(Math.hypot(arc[4].x, arc[4].y, arc[4].z) > 104.5);

const fakePoint = { clone: () => ({ project: () => ({ x: 0, y: 0, z: .2 }) }) };
assert.deepEqual(projectPointToScreen(fakePoint, {}, 390, 560), { x: 195, y: 280, ndcZ: .2 });

console.log('universe4 Force model OK');
