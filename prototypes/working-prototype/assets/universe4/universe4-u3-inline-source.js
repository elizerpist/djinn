// Universe 4 begins from Universe 3's existing ForceGraph data contract.
// This adapter is intentionally limited to the galaxy shell; V7 supplies the
// concrete planet contents at the handoff endpoint.
import { TEST_SEED, createUniverseMockData } from '../universe-morph-model.js?rev=5';

export function createUniverse4U3InlineSource() {
  const u3 = createUniverseMockData(TEST_SEED);
  return Object.freeze({
    galaxy: u3.galaxy,
    initialPlanetId: u3.galaxy.planetIds[0],
  });
}
