import { contextCityIdsFor } from './universe4-globe-selection.js';

const stableStringify = (value) => {
  if (value === null || typeof value !== 'object') return JSON.stringify(value);
  if (Array.isArray(value)) return `[${value.map(stableStringify).join(',')}]`;
  return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(',')}}`;
};

const hash = (value) => {
  let state = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    state ^= value.charCodeAt(index);
    state = Math.imul(state, 16777619);
  }
  return (state >>> 0).toString(36);
};

const freeze = (value) => {
  if (!value || typeof value !== 'object' || Object.isFrozen(value)) return value;
  Object.values(value).forEach(freeze);
  return Object.freeze(value);
};

const cloneCity = (city) => ({
  id: city.id,
  title: city.title ?? city.name ?? city.id,
  subtitle: city.subtitle ?? '',
  lat: Number(city.lat),
  lng: Number(city.lng),
  color: city.color ?? null,
  communityId: city.communityId ?? city.v3Community ?? null,
});

const cloneEdge = (edge) => ({
  id: edge.id ?? `${edge.sourceCityId ?? edge.source}::${edge.targetCityId ?? edge.target}`,
  source: edge.sourceCityId ?? edge.source,
  target: edge.targetCityId ?? edge.target,
  sourceCityId: edge.sourceCityId ?? edge.source,
  targetCityId: edge.targetCityId ?? edge.target,
  weight: Number.isFinite(edge.weight) ? edge.weight : 1,
  type: edge.type ?? null,
});

/**
 * The immutable domain bridge between one V7 root/context selection and the
 * G6 Focused Map v2. It deliberately only contains selected direct context:
 * no new random layout, filtering, or relationship search occurs in G6.
 */
export function buildUniverse4FocusedMapSnapshot({
  sourcePlanetId,
  rootCityId,
  tappedContextCityId,
  selection,
  nodes = [],
  globePointOfView = null,
  cityAnchor = null,
} = {}) {
  if (typeof sourcePlanetId !== 'string' || !sourcePlanetId) throw new TypeError('sourcePlanetId is required');
  const resolvedRootCityId = rootCityId ?? selection?.selectedCityId;
  if (typeof resolvedRootCityId !== 'string' || !resolvedRootCityId) throw new TypeError('root city is required');
  const contextCityIds = contextCityIdsFor({ ...selection, selectedCityId: resolvedRootCityId });
  // A repeated tap on the selected root is also a valid focused-map entry.
  // The Globe policy deliberately treats it as `enter-map` so the user does
  // not have to hunt for one of the small context labels. Keep the strict
  // foreign-city guard while allowing either root or active context focus.
  const tappedRoot = tappedContextCityId === resolvedRootCityId;
  const tappedContext = contextCityIds.includes(tappedContextCityId);
  if (!tappedRoot && !tappedContext) throw new TypeError('tapped city must be the root or an active context city');

  const nodesById = new Map((Array.isArray(nodes) ? nodes : []).map((node) => [node?.id, node]));
  const orderedIds = [resolvedRootCityId, ...contextCityIds];
  const selectedNodes = orderedIds.map((id) => nodesById.get(id)).filter(Boolean).map(cloneCity);
  if (selectedNodes.length !== orderedIds.length) throw new TypeError('all root and context cities must exist in the V7 source snapshot');

  const selectedEdges = (Array.isArray(selection?.selectedCityArcData) ? selection.selectedCityArcData : [])
    .map(cloneEdge)
    .filter((edge) => orderedIds.includes(edge.source) && orderedIds.includes(edge.target));
  const payload = {
    sourcePlanetId,
    rootCityId: resolvedRootCityId,
    tappedContextCityId,
    focusCityId: tappedContextCityId,
    contextCityIds,
    nodes: selectedNodes,
    edges: selectedEdges,
    entryGlobePointOfView: globePointOfView && {
      lat: Number(globePointOfView.lat),
      lng: Number(globePointOfView.lng),
      altitude: Number(globePointOfView.altitude),
    },
    cityAnchor: cityAnchor && {
      x: Number(cityAnchor.x),
      y: Number(cityAnchor.y),
      width: Number(cityAnchor.width),
      height: Number(cityAnchor.height),
    },
  };
  return freeze({
    ...payload,
    snapshotId: `u4-map-${hash(stableStringify(payload))}`,
  });
}
