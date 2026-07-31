import assert from 'node:assert/strict';
import {
  U4_DEPTH_STATE,
  canUniverse4DepthTransition,
  createUniverse4DepthController,
} from '../assets/universe4/universe4-depth-controller.js';

const path = [
  U4_DEPTH_STATE.GALAXY,
  U4_DEPTH_STATE.GALAXY_TO_PLANET,
  U4_DEPTH_STATE.PLANET_IDLE,
  U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
  U4_DEPTH_STATE.PLANET_TO_MAP_PREPARE,
  U4_DEPTH_STATE.PLANET_TO_MAP_MORPH,
  U4_DEPTH_STATE.MAP_ACTIVE,
  U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE,
  U4_DEPTH_STATE.MAP_TO_PLANET_MORPH,
  U4_DEPTH_STATE.PLANET_RETURNED,
  U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
];

for (let index = 0; index < path.length - 1; index += 1) {
  assert.equal(canUniverse4DepthTransition(path[index], path[index + 1]), true, `${path[index]} → ${path[index + 1]}`);
}
assert.equal(canUniverse4DepthTransition(U4_DEPTH_STATE.MAP_ACTIVE, U4_DEPTH_STATE.GALAXY), false);
assert.equal(canUniverse4DepthTransition(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE, U4_DEPTH_STATE.GALAXY), true, 'Only Planet can explicitly reset back to Galaxy.');

const controller = createUniverse4DepthController();
const galaxyGeneration = controller.begin(U4_DEPTH_STATE.GALAXY_TO_PLANET);
assert.equal(galaxyGeneration, 1);
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_IDLE, galaxyGeneration), true);
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE, galaxyGeneration), true);
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_TO_MAP_PREPARE, galaxyGeneration), true);

const stale = galaxyGeneration;
const mapGeneration = controller.invalidate();
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_TO_MAP_MORPH, stale), false, 'stale callbacks must never revive a cancelled morph');
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_TO_MAP_MORPH, mapGeneration), true);
assert.equal(controller.advance(U4_DEPTH_STATE.MAP_ACTIVE, mapGeneration), true);
assert.equal(controller.state, U4_DEPTH_STATE.MAP_ACTIVE);

assert.equal(controller.begin(U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE), mapGeneration + 1);
assert.equal(controller.advance(U4_DEPTH_STATE.MAP_TO_PLANET_MORPH), true);
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_RETURNED), true);
assert.equal(controller.advance(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE), true);

console.log('universe4 depth controller OK');
