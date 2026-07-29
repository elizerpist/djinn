import assert from 'node:assert/strict';
import { U4_STATE } from '../assets/universe4/universe4-transition-machine.js';
import { getUniverse4PointerOwner } from '../assets/universe4.js';

assert.equal(getUniverse4PointerOwner(U4_STATE.GALAXY_IDLE), 'FORCE');
assert.equal(getUniverse4PointerOwner(U4_STATE.HANDOFF_ALIGN), 'LOCKED');
assert.equal(getUniverse4PointerOwner(U4_STATE.HANDOFF_CROSSFADE), 'LOCKED');
assert.equal(getUniverse4PointerOwner(U4_STATE.RETURN_CROSSFADE), 'LOCKED');
assert.equal(getUniverse4PointerOwner(U4_STATE.GLOBE_STANDALONE), 'GLOBE');

console.log('universe4 runtime ownership OK');
