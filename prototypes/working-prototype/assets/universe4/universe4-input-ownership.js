import { U4_DEPTH_STATE } from './universe4-depth-controller.js';

/** One renderer owns an input cycle; all depth transitions are deliberately locked. */
export function universe4InputOwnershipForDepth(state) {
  if (state === U4_DEPTH_STATE.GALAXY) return 'FORCE';
  if ([U4_DEPTH_STATE.PLANET_IDLE, U4_DEPTH_STATE.PLANET_CONTEXT_ACTIVE, U4_DEPTH_STATE.PLANET_RETURNED].includes(state)) return 'GLOBE';
  if (state === U4_DEPTH_STATE.MAP_ACTIVE) return 'G6';
  return 'LOCKED';
}
