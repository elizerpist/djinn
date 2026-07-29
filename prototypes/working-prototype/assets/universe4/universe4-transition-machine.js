export const U4_STATE = Object.freeze({
  GALAXY_IDLE: 'GALAXY_IDLE',
  INLINE_PLANET_ENTER: 'INLINE_PLANET_ENTER',
  INLINE_PLANET_FOCUS: 'INLINE_PLANET_FOCUS',
  GLOBE_PREWARM: 'GLOBE_PREWARM',
  HANDOFF_ALIGN: 'HANDOFF_ALIGN',
  HANDOFF_READY: 'HANDOFF_READY',
  HANDOFF_CROSSFADE: 'HANDOFF_CROSSFADE',
  GLOBE_STANDALONE: 'GLOBE_STANDALONE',
  RETURN_PREPARE: 'RETURN_PREPARE',
  RETURN_ALIGN: 'RETURN_ALIGN',
  RETURN_CROSSFADE: 'RETURN_CROSSFADE',
  INLINE_PLANET_RETURN: 'INLINE_PLANET_RETURN',
  TRANSITION_ERROR: 'TRANSITION_ERROR',
  DISPOSED: 'DISPOSED',
});

const ORDERED_EDGES = Object.freeze({
  [U4_STATE.GALAXY_IDLE]: Object.freeze([U4_STATE.INLINE_PLANET_ENTER]),
  [U4_STATE.INLINE_PLANET_ENTER]: Object.freeze([U4_STATE.INLINE_PLANET_FOCUS]),
  [U4_STATE.INLINE_PLANET_FOCUS]: Object.freeze([U4_STATE.GLOBE_PREWARM]),
  [U4_STATE.GLOBE_PREWARM]: Object.freeze([U4_STATE.HANDOFF_ALIGN]),
  [U4_STATE.HANDOFF_ALIGN]: Object.freeze([U4_STATE.HANDOFF_READY]),
  [U4_STATE.HANDOFF_READY]: Object.freeze([U4_STATE.HANDOFF_CROSSFADE]),
  [U4_STATE.HANDOFF_CROSSFADE]: Object.freeze([U4_STATE.GLOBE_STANDALONE]),
  [U4_STATE.GLOBE_STANDALONE]: Object.freeze([U4_STATE.RETURN_PREPARE]),
  [U4_STATE.RETURN_PREPARE]: Object.freeze([U4_STATE.RETURN_ALIGN]),
  // Mapping can fail after a user has orbited the standalone Globe. In that
  // case retain the already valid Globe instead of flashing or falling back to
  // a stale Force camera.
  [U4_STATE.RETURN_ALIGN]: Object.freeze([U4_STATE.RETURN_CROSSFADE, U4_STATE.GLOBE_STANDALONE]),
  [U4_STATE.RETURN_CROSSFADE]: Object.freeze([U4_STATE.INLINE_PLANET_RETURN, U4_STATE.GLOBE_STANDALONE]),
  [U4_STATE.INLINE_PLANET_RETURN]: Object.freeze([U4_STATE.GALAXY_IDLE]),
  [U4_STATE.TRANSITION_ERROR]: Object.freeze([U4_STATE.GALAXY_IDLE]),
  [U4_STATE.DISPOSED]: Object.freeze([]),
});

export function canUniverse4Transition(from, to) {
  if (!Object.values(U4_STATE).includes(from) || !Object.values(U4_STATE).includes(to)) return false;
  if (from === U4_STATE.DISPOSED) return false;
  if (to === U4_STATE.DISPOSED || to === U4_STATE.TRANSITION_ERROR) return true;
  return ORDERED_EDGES[from].includes(to);
}

/**
 * State mutations require the current generation token. Async callbacks retain
 * their creation token, so a stale prewarm/renderer callback cannot revive an
 * old planet transition after a selection, route, or disposal change.
 */
export function createUniverse4TransitionMachine(initialState = U4_STATE.GALAXY_IDLE) {
  if (!Object.values(U4_STATE).includes(initialState)) {
    throw new TypeError(`Unknown Universe 4 state: ${initialState}`);
  }

  let state = initialState;
  let generation = 0;
  const history = [];

  const move = (nextState) => {
    if (!canUniverse4Transition(state, nextState)) return false;
    const previousState = state;
    state = nextState;
    history.push(Object.freeze({ generation, from: previousState, to: nextState }));
    return true;
  };

  const machine = {
    begin(nextState = U4_STATE.INLINE_PLANET_ENTER) {
      if (state === U4_STATE.DISPOSED || !canUniverse4Transition(state, nextState)) return null;
      generation += 1;
      return move(nextState) ? generation : null;
    },
    advance(nextState, expectedGeneration = generation) {
      if (state === U4_STATE.DISPOSED || expectedGeneration !== generation) return false;
      return move(nextState);
    },
    invalidate() {
      generation += 1;
      return generation;
    },
    isCurrentGeneration(token) {
      return state !== U4_STATE.DISPOSED && token === generation;
    },
    fail(expectedGeneration = generation) {
      if (state === U4_STATE.DISPOSED || expectedGeneration !== generation) return false;
      return move(U4_STATE.TRANSITION_ERROR);
    },
    dispose() {
      generation += 1;
      if (state !== U4_STATE.DISPOSED) move(U4_STATE.DISPOSED);
      return generation;
    },
  };

  Object.defineProperties(machine, {
    state: { enumerable: true, get: () => state },
    generation: { enumerable: true, get: () => generation },
    history: { enumerable: true, get: () => Object.freeze([...history]) },
  });
  return Object.freeze(machine);
}
