import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
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
} from '../assets/universe-morph-model.js';

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
assert.ok(narrowFocusDistance > squareFocusDistance, 'a keskeny viewportnak távolabbi fókuszkamera kell');
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
assert.ok(arc.every((point) => Math.hypot(point.x, point.y, point.z) >= 104.5));
assert.ok(Math.hypot(arc[4].x, arc[4].y, arc[4].z) > 104.5, 'the middle of a long surface arc must rise above its endpoints');

const fakePoint = { clone: () => ({ project: () => ({ x: 0, y: 0, z: .2 }) }) };
assert.deepEqual(projectPointToScreen(fakePoint, {}, 390, 560), { x: 195, y: 280, ndcZ: .2 });

const appSource = await readFile(new URL('../assets/app.js', import.meta.url), 'utf8');
assert.match(appSource, /'universe-morph-test': 'screens\/universe-morph-test\.html'/);
assert.match(appSource, /'universe-morph-test-v2': 'screens\/universe-morph-test-v2\.html'/);
assert.match(appSource, /'universe-morph-test-v3': 'screens\/universe-morph-test-v3\.html'/);
assert.match(appSource, /normalized === 'universe-morph-test' \|\| normalized === 'universe-morph-test-v2' \|\| normalized === 'universe-morph-test-v3'/);
assert.match(appSource, /initUniverseMorphTest\(root, \{ showToast, navigate \}\)/);

const screenSource = await readFile(new URL('../screens/universe-morph-test.html', import.meta.url), 'utf8');
assert.match(screenSource, /data-universe-morph-test/);
assert.match(screenSource, /data-universe-galaxy/);
assert.match(screenSource, /data-universe-map/);
assert.match(screenSource, /data-universe-corridor/);
assert.match(screenSource, /data-universe-corridor-close/);
assert.match(screenSource, /Universe v3/);

const v2ScreenSource = await readFile(new URL('../screens/universe-morph-test-v2.html', import.meta.url), 'utf8');
assert.match(v2ScreenSource, /universe-morph-v2-screen/);
assert.match(v2ScreenSource, /Universe v1/);
assert.match(v2ScreenSource, /Universe v2/);
assert.match(v2ScreenSource, /Universe v3/);

const v3ScreenSource = await readFile(new URL('../screens/universe-morph-test-v3.html', import.meta.url), 'utf8');
assert.match(v3ScreenSource, /universe-morph-v3-screen/);
assert.match(v3ScreenSource, /Universe v1/);
assert.match(v3ScreenSource, /Universe v2/);
assert.match(v3ScreenSource, /Universe v3/);

const universeSource = await readFile(new URL('../assets/universe-morph-test.js', import.meta.url), 'utf8');
assert.match(universeSource, /requestPlanetCorridor/);
assert.match(universeSource, /positionCorridorLayer/);
assert.match(universeSource, /corridorTargetView/);
assert.doesNotMatch(universeSource, /strongestPlanetNeighborId/);
assert.doesNotMatch(universeSource, /onEngineStop\(/);
assert.match(universeSource, /planetRadiusFromAtomCount/);
assert.match(universeSource, /node\.isPlanet \? baseRadius \* \(isFocusV3 \? 3 : 1\.5\) : baseRadius \* \.76/);
assert.match(universeSource, /DJINN_V2/);
assert.match(universeSource, /universe-morph-v3-screen/);
assert.match(universeSource, /new ThreeGlobe\(/);
assert.match(universeSource, /planetFocusAnchor/);
assert.match(universeSource, /freezeGalaxyLayout/);
assert.match(universeSource, /controls\.enablePan = false/);
assert.match(universeSource, /clampOrbitDistance/);
assert.match(universeSource, /setPointOfView/);
assert.match(universeSource, /restoreControls/);
assert.match(universeSource, /getV5PlanetVisualSnapshot/);
assert.match(universeSource, /configureV5PlanetContent/);
assert.match(universeSource, /refreshUniverseV5PlanetVisuals/);
assert.match(universeSource, /toggleUniverseFullscreen/);
assert.match(universeSource, /requestFullscreen/);
assert.match(universeSource, /refreshUniverseV5Labels/);
assert.match(universeSource, /createUniverseV5LabelSprite/);
assert.match(universeSource, /CanvasTexture/);
assert.match(universeSource, /labelAnchor/);
assert.match(universeSource, /refreshUniverseV5LabelSprites/);
assert.match(universeSource, /UNIVERSE_V5_LABEL_POOL_LIMIT = 15/);
assert.match(universeSource, /universeV5LabelTextureCache/);
assert.doesNotMatch(universeSource, /planetLabelLayer/);
assert.doesNotMatch(universeSource, /scheduleUniverseV5LabelProjection/);
assert.match(universeSource, /selectUniverseV5City/);
assert.match(universeSource, /refreshUniverseV5CityContext/);
assert.match(universeSource, /refreshUniverseV5PlanetShell/);
assert.match(universeSource, /radius \* \.28/);
assert.match(universeSource, /nodeThreeObjectExtend\(false\)/);
assert.match(universeSource, /detailMount/);
assert.match(universeSource, /hideFocusedOverviewVisual/);
assert.match(universeSource, /view\.detailMount\.add\(detailGlobe\)/);
assert.match(universeSource, /scheduleV3ControlRefresh/);
assert.match(universeSource, /controls\.enableDamping = true/);
assert.match(universeSource, /targetProof: false/);
assert.match(universeSource, /distanceInRadii - 1\.8/);
assert.match(universeSource, /state\.selectedPlanetNodeId\s*\?\s*0/);
assert.match(universeSource, /if \(nodeId\) \{\s*selectUniverseV5City\(nodeId\);/);
assert.match(universeSource, /PLANET_INTERACTION/);
assert.match(universeSource, /applyUniverseInteractionPolicy/);
assert.match(universeSource, /graph\.enableNodeDrag\(false\)/);
assert.match(universeSource, /graph\.enablePointerInteraction\(false\)/);
assert.match(universeSource, /graph\.enableNavigationControls\(true\)/);
assert.match(universeSource, /CAMERA_PINCH/);
assert.match(universeSource, /pointercancel/);
assert.match(universeSource, /isFrontFacingPlanetNode/);
assert.match(universeSource, /distanceSqToPoint/);
assert.match(universeSource, /worldUnitsForPlanetHitPixels/);
assert.match(universeSource, /selectedPlanetFocusEdgeAt/);
assert.match(universeSource, /selectUniverseV5Edge/);
assert.match(universeSource, /linkWidth\(isFocusV3 \? \.14 : \.42\)/);
assert.equal((universeSource.match(/new window\.ForceGraph3D/g) || []).length, 1, 'Universe v3 must share the existing single ForceGraph renderer');

assert.match(v3ScreenSource, /data-universe-fullscreen/);
assert.doesNotMatch(v3ScreenSource, /data-universe-planet-label-layer/);
assert.match(v3ScreenSource, /data-universe-city-context/);

const universeCss = await readFile(new URL('../assets/universe-morph-test.css', import.meta.url), 'utf8');
assert.match(universeCss, /\.universe-morph-stage:fullscreen/);
assert.match(universeCss, /\.universe-morph-debug\s*\{[\s\S]*bottom:/);
assert.doesNotMatch(universeCss, /\.universe-planet-label-layer/);

console.log('universe morph model OK');
