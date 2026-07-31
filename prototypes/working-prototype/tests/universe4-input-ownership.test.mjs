import assert from 'node:assert/strict';
import { U4_DEPTH_STATE } from '../assets/universe4/universe4-depth-controller.js';
import { universe4InputOwnershipForDepth } from '../assets/universe4/universe4-input-ownership.js';

assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.GALAXY), 'FORCE');
assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.PLANET_IDLE), 'GLOBE');
assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE), 'GLOBE');
assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.PLANET_TO_MAP_MORPH), 'LOCKED');
assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.MAP_ACTIVE), 'G6');
assert.equal(universe4InputOwnershipForDepth(U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE), 'LOCKED');

console.log('universe4 input ownership OK');
