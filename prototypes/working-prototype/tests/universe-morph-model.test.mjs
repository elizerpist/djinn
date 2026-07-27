import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  TEST_SEED,
  UNIVERSE_LEVEL,
  canTransition,
  classifyPointerTap,
  createUniverseMockData,
  easeInOutCubic,
  fibonacciSpherePoint,
  focusCameraTarget,
  galaxyNodeRadius,
} from '../assets/universe-morph-model.js';

const first = createUniverseMockData(TEST_SEED);
const repeated = createUniverseMockData(TEST_SEED);

assert.equal(first.galaxy.nodes.length, 180);
assert.equal(first.galaxy.links.length, 260);
assert.equal(first.galaxy.planetIds.length, 8);
assert.equal(first.planet.nodes.length, 140);
assert.equal(first.planet.links.length, 210);
assert.equal(first.map.nodes.length, 28);
assert.equal(first.map.links.length, 42);
assert.deepEqual(first, repeated, 'the mock universe must be repeatable from one seed');
assert.equal(new Set(first.galaxy.nodes.map((node) => node.id)).size, 180);
assert.ok(first.galaxy.planetIds.every((id) => first.galaxy.nodes.find((node) => node.id === id)?.isPlanet));

const point = fibonacciSpherePoint(11, 140, 100, .02);
assert.ok(Math.abs(Math.hypot(point.x, point.y, point.z) - 102) < 1e-8);
assert.ok(point.lat >= -90 && point.lat <= 90);
assert.ok(point.lng >= -180 && point.lng <= 180);

assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 18, y: 17, endedAt: 390 }), true);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 23, y: 12, endedAt: 220 }), false);
assert.equal(classifyPointerTap({ x: 12, y: 12, startedAt: 100 }, { x: 12, y: 12, endedAt: 401 }), false);

assert.equal(canTransition(UNIVERSE_LEVEL.GALAXY, UNIVERSE_LEVEL.GALAXY_TO_PLANET), true);
assert.equal(canTransition(UNIVERSE_LEVEL.PLANET, UNIVERSE_LEVEL.PLANET_TO_MAP), true);
assert.equal(canTransition(UNIVERSE_LEVEL.MAP, UNIVERSE_LEVEL.PLANET_TO_MAP), false);

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

const appSource = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
assert.match(appSource, /'universe-morph-test': 'screens\/universe-morph-test\.html'/);
assert.match(appSource, /initUniverseMorphTest\(root, \{ showToast, navigate \}\)/);

const screenSource = await readFile(new URL('../screens/universe-morph-test.html', import.meta.url), 'utf8');
assert.match(screenSource, /data-universe-morph-test/);
assert.match(screenSource, /data-universe-galaxy/);
assert.match(screenSource, /data-universe-map/);

console.log('universe morph model OK');
