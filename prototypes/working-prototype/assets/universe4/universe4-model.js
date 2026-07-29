function hashString(value) {
  let hash = 0x811c9dc5;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 0x01000193);
  }
  return hash >>> 0;
}

function stableSerialize(value) {
  if (value === null) return 'null';
  if (value === undefined) return 'undefined';
  if (typeof value === 'number') {
    if (Number.isNaN(value)) return 'number:NaN';
    if (value === Infinity) return 'number:Infinity';
    if (value === -Infinity) return 'number:-Infinity';
    return `number:${value}`;
  }
  if (typeof value === 'string') return `string:${JSON.stringify(value)}`;
  if (typeof value === 'boolean') return `boolean:${value}`;
  if (Array.isArray(value)) return `[${value.map(stableSerialize).join(',')}]`;
  if (typeof value === 'object') {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableSerialize(value[key])}`).join(',')}}`;
  }
  return `${typeof value}:${String(value)}`;
}

function cloneFrozen(value) {
  if (Array.isArray(value)) return Object.freeze(value.map(cloneFrozen));
  if (value && typeof value === 'object') {
    const copy = {};
    for (const key of Object.keys(value).sort()) copy[key] = cloneFrozen(value[key]);
    return Object.freeze(copy);
  }
  return value;
}

function firstDefined(...values) {
  return values.find((value) => value !== undefined);
}

function snapshotSeed(source, planetId) {
  const candidate = firstDefined(source.seed, source.stableSeed, source.planet?.seed, source.planet?.stableSeed);
  return Number.isFinite(candidate) ? Number(candidate) : hashString(`universe4:${planetId}`);
}

/**
 * Produces the single immutable render contract shared by the isolated Force
 * and Globe stages. It intentionally contains only copied, deterministic data.
 */
export function createUniverse4Snapshot(source = {}) {
  const planetId = source.planetId ?? source.planet?.id;
  if (typeof planetId !== 'string' || !planetId) {
    throw new TypeError('Universe 4 snapshot requires a non-empty planetId');
  }

  const sourcePlanet = source.planet ?? {};
  const sourceGalaxy = source.galaxy ?? {};
  const seed = snapshotSeed(source, planetId);
  const snapshot = {
    planetId,
    seed,
    stableSeed: seed,
    galaxy: {
      nodes: firstDefined(sourceGalaxy.nodes, source.galaxyNodes, []),
      links: firstDefined(sourceGalaxy.links, source.galaxyLinks, []),
    },
    planet: {
      atoms: firstDefined(source.atoms, sourcePlanet.atoms, []),
      arcs: firstDefined(source.surfaceArcs, source.arcs, sourcePlanet.arcs, []),
      labels: firstDefined(source.labels, sourcePlanet.labels, []),
      selectedCityId: firstDefined(source.selectedCityId, sourcePlanet.selectedCityId, null),
      activeConnectionIds: firstDefined(source.activeConnectionIds, sourcePlanet.activeConnectionIds, []),
      material: firstDefined(source.globeMaterial, source.material, sourcePlanet.material, {}),
      lighting: firstDefined(source.lighting, sourcePlanet.lighting, {}),
      environment: firstDefined(source.environment, sourcePlanet.environment, {
        atmosphere: firstDefined(source.atmosphere, sourcePlanet.atmosphere, {}),
        cosmicEnvironment: firstDefined(source.cosmicEnvironment, sourcePlanet.cosmicEnvironment, {}),
      }),
      visualLod: firstDefined(source.visualLod, sourcePlanet.visualLod, 'default'),
      validation: firstDefined(source.validation, sourcePlanet.validation, {}),
      randomValues: firstDefined(source.randomValues, sourcePlanet.randomValues, {}),
    },
    landmarks: firstDefined(source.landmarks, sourcePlanet.landmarks, []),
  };
  const snapshotId = `u4:${planetId}:${seed}:${hashString(stableSerialize(snapshot)).toString(16)}`;
  return cloneFrozen({ snapshotId, ...snapshot });
}

// The target snapshot is intentionally derived from Explore V7's immutable
// layout. U4 must never regenerate its cities or choose a look-alike palette.
export function createUniverse4V7Snapshot({ planetId = 'explore-v7-knowledge-planet', galaxy } = {}) {
  const source = getV5PlanetVisualSnapshot();
  const landmarks = [source.atoms[8], source.atoms[47], source.atoms[103]]
    .filter(Boolean)
    .map(({ id, lat, lng, altitude }) => ({ id, lat, lng, altitude }));
  return createUniverse4Snapshot({
    planetId,
    stableSeed: 0x7A17,
    galaxy: galaxy || { nodes: [], links: [] },
    atoms: source.atoms,
    surfaceArcs: [],
    labels: source.atoms.map(({ id, label }) => ({ id, label })),
    globeMaterial: {
      color: DJINN_ORB_V7.planet,
      source: 'explore-v7',
    },
    lighting: { source: 'explore-v7-universe-v3-reference' },
    atmosphere: { source: 'explore-v7-no-native-atmosphere' },
    cosmicEnvironment: { source: 'explore-v7-cosmic-production' },
    landmarks,
  });
}
import { getV5PlanetVisualSnapshot } from '../explore/planet-data.js?rev=4';
import { DJINN_ORB_V7 } from '../explore/planet-visuals.js?rev=1';
