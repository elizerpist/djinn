import assert from 'node:assert/strict';
import { U4_STATE, canUniverse4Transition, createUniverse4TransitionMachine } from '../assets/universe4/universe4-transition-machine.js';

const orderedStates = [
  U4_STATE.GALAXY_IDLE,
  U4_STATE.INLINE_PLANET_ENTER,
  U4_STATE.INLINE_PLANET_FOCUS,
  U4_STATE.GLOBE_PREWARM,
  U4_STATE.HANDOFF_ALIGN,
  U4_STATE.HANDOFF_READY,
  U4_STATE.HANDOFF_CROSSFADE,
  U4_STATE.GLOBE_STANDALONE,
  U4_STATE.RETURN_PREPARE,
  U4_STATE.RETURN_ALIGN,
  U4_STATE.RETURN_CROSSFADE,
  U4_STATE.INLINE_PLANET_RETURN,
  U4_STATE.GALAXY_IDLE,
];

assert.deepEqual(Object.values(U4_STATE), [
  'GALAXY_IDLE',
  'INLINE_PLANET_ENTER',
  'INLINE_PLANET_FOCUS',
  'GLOBE_PREWARM',
  'HANDOFF_ALIGN',
  'HANDOFF_READY',
  'HANDOFF_CROSSFADE',
  'GLOBE_STANDALONE',
  'RETURN_PREPARE',
  'RETURN_ALIGN',
  'RETURN_CROSSFADE',
  'INLINE_PLANET_RETURN',
  'TRANSITION_ERROR',
  'DISPOSED',
]);

for (let index = 0; index < orderedStates.length - 1; index += 1) {
  assert.equal(
    canUniverse4Transition(orderedStates[index], orderedStates[index + 1]),
    true,
    `${orderedStates[index]} must lead to ${orderedStates[index + 1]}`,
  );
}
assert.equal(canUniverse4Transition(U4_STATE.GALAXY_IDLE, U4_STATE.GLOBE_STANDALONE), false);
assert.equal(canUniverse4Transition(U4_STATE.HANDOFF_READY, U4_STATE.GLOBE_PREWARM), false);
assert.equal(
  canUniverse4Transition(U4_STATE.RETURN_ALIGN, U4_STATE.GLOBE_STANDALONE),
  true,
  'return camera mapping failure must retain the working standalone Globe',
);
assert.equal(
  canUniverse4Transition(U4_STATE.RETURN_CROSSFADE, U4_STATE.GLOBE_STANDALONE),
  true,
  'a reverse failure during the fade must restore the working V7 standalone renderer',
);
assert.equal(canUniverse4Transition(U4_STATE.DISPOSED, U4_STATE.GALAXY_IDLE), false);
assert.equal(canUniverse4Transition(U4_STATE.GLOBE_PREWARM, U4_STATE.TRANSITION_ERROR), true);
assert.equal(canUniverse4Transition(U4_STATE.TRANSITION_ERROR, U4_STATE.GALAXY_IDLE), true);

const machine = createUniverse4TransitionMachine();
assert.equal(machine.state, U4_STATE.GALAXY_IDLE);
const generation = machine.begin(U4_STATE.INLINE_PLANET_ENTER);
assert.equal(generation, 1);
assert.equal(machine.state, U4_STATE.INLINE_PLANET_ENTER);
assert.equal(machine.advance(U4_STATE.INLINE_PLANET_FOCUS, generation), true);
assert.equal(machine.state, U4_STATE.INLINE_PLANET_FOCUS);

const replacementGeneration = machine.invalidate();
assert.equal(replacementGeneration, 2);
assert.equal(machine.advance(U4_STATE.GLOBE_PREWARM, generation), false, 'a stale async callback must not move the machine');
assert.equal(machine.state, U4_STATE.INLINE_PLANET_FOCUS);
assert.equal(machine.advance(U4_STATE.GLOBE_PREWARM, replacementGeneration), true);

for (const nextState of orderedStates.slice(4, -1)) {
  assert.equal(machine.advance(nextState, replacementGeneration), true);
}
assert.equal(machine.state, U4_STATE.INLINE_PLANET_RETURN);
assert.equal(machine.advance(U4_STATE.GALAXY_IDLE, replacementGeneration), true);
assert.equal(machine.state, U4_STATE.GALAXY_IDLE);
assert.equal(machine.history.length, 12);

const failingMachine = createUniverse4TransitionMachine();
const failingGeneration = failingMachine.begin(U4_STATE.INLINE_PLANET_ENTER);
assert.equal(failingMachine.fail(failingGeneration), true);
assert.equal(failingMachine.state, U4_STATE.TRANSITION_ERROR);
assert.equal(failingMachine.advance(U4_STATE.GALAXY_IDLE, failingGeneration), true);

const disposedGeneration = machine.dispose();
assert.equal(machine.state, U4_STATE.DISPOSED);
assert.equal(machine.advance(U4_STATE.GALAXY_IDLE, disposedGeneration), false);
assert.equal(machine.begin(U4_STATE.INLINE_PLANET_ENTER), null);

console.log('universe4 transition machine OK');
