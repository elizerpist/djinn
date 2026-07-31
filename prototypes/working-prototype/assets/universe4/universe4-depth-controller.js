// High-level navigation ownership for the three Universe depths.  The older
// match-cut machine remains the low-level Force → Globe renderer contract;
// this controller owns user-visible depth, cancellation and Map lifecycle.
export const U4_DEPTH_STATE = Object.freeze({
  GALAXY: 'GALAXY',
  GALAXY_TO_PLANET: 'GALAXY_TO_PLANET',
  PLANET_IDLE: 'PLANET_IDLE',
  PLANET_CONTEXT_ACTIVE: 'PLANET_CONTEXT_ACTIVE',
  PLANET_TO_MAP_PREPARE: 'PLANET_TO_MAP_PREPARE',
  PLANET_TO_MAP_MORPH: 'PLANET_TO_MAP_MORPH',
  MAP_ACTIVE: 'MAP_ACTIVE',
  MAP_TO_PLANET_PREPARE: 'MAP_TO_PLANET_PREPARE',
  MAP_TO_PLANET_MORPH: 'MAP_TO_PLANET_MORPH',
  PLANET_RETURNED: 'PLANET_RETURNED',
  TRANSITION_ERROR: 'TRANSITION_ERROR',
});

const EDGES = Object.freeze({
  [U4_DEPTH_STATE.GALAXY]: Object.freeze([U4_DEPTH_STATE.GALAXY_TO_PLANET]),
  [U4_DEPTH_STATE.GALAXY_TO_PLANET]: Object.freeze([U4_DEPTH_STATE.PLANET_IDLE]),
  [U4_DEPTH_STATE.PLANET_IDLE]: Object.freeze([
    U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
    U4_DEPTH_STATE.GALAXY,
  ]),
  [U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE]: Object.freeze([
    U4_DEPTH_STATE.PLANET_IDLE,
    U4_DEPTH_STATE.PLANET_TO_MAP_PREPARE,
    U4_DEPTH_STATE.GALAXY,
  ]),
  [U4_DEPTH_STATE.PLANET_TO_MAP_PREPARE]: Object.freeze([U4_DEPTH_STATE.PLANET_TO_MAP_MORPH]),
  [U4_DEPTH_STATE.PLANET_TO_MAP_MORPH]: Object.freeze([U4_DEPTH_STATE.MAP_ACTIVE]),
  [U4_DEPTH_STATE.MAP_ACTIVE]: Object.freeze([U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE]),
  [U4_DEPTH_STATE.MAP_TO_PLANET_PREPARE]: Object.freeze([U4_DEPTH_STATE.MAP_TO_PLANET_MORPH]),
  [U4_DEPTH_STATE.MAP_TO_PLANET_MORPH]: Object.freeze([U4_DEPTH_STATE.PLANET_RETURNED]),
  [U4_DEPTH_STATE.PLANET_RETURNED]: Object.freeze([U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE]),
  [U4_DEPTH_STATE.TRANSITION_ERROR]: Object.freeze([
    U4_DEPTH_STATE.GALAXY,
    U4_DEPTH_STATE.PLANET_IDLE,
    U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE,
    U4_DEPTH_STATE.MAP_ACTIVE,
  ]),
});

export function canUniverse4DepthTransition(from, to) {
  if (!Object.values(U4_DEPTH_STATE).includes(from) || !Object.values(U4_DEPTH_STATE).includes(to)) return false;
  if (to === U4_DEPTH_STATE.TRANSITION_ERROR) return true;
  return EDGES[from].includes(to);
}

export function createUniverse4DepthController(initialState = U4_DEPTH_STATE.GALAXY) {
  if (!Object.values(U4_DEPTH_STATE).includes(initialState)) throw new TypeError(`Unknown U4 depth state: ${initialState}`);
  let state = initialState;
  let generation = 0;
  const history = [];

  const move = (nextState) => {
    if (!canUniverse4DepthTransition(state, nextState)) return false;
    const from = state;
    state = nextState;
    history.push(Object.freeze({ generation, from, to: nextState }));
    return true;
  };

  const controller = {
    begin(nextState) {
      if (!canUniverse4DepthTransition(state, nextState)) return null;
      generation += 1;
      return move(nextState) ? generation : null;
    },
    advance(nextState, expectedGeneration = generation) {
      if (expectedGeneration !== generation) return false;
      return move(nextState);
    },
    invalidate() {
      generation += 1;
      return generation;
    },
    isCurrentGeneration(expectedGeneration) {
      return expectedGeneration === generation;
    },
    fail(expectedGeneration = generation) {
      if (expectedGeneration !== generation) return false;
      return move(U4_DEPTH_STATE.TRANSITION_ERROR);
    },
  };

  Object.defineProperties(controller, {
    state: { enumerable: true, get: () => state },
    generation: { enumerable: true, get: () => generation },
    history: { enumerable: true, get: () => Object.freeze([...history]) },
  });
  return Object.freeze(controller);
}
