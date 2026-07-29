// Pure selection data for the V5/V6/V7 city-context renderer. This module
// intentionally knows nothing about Globe.gl, Three.js, the camera or view
// state: all variants receive the same deterministic connection payload.
import { buildGreatCircleSurfacePath } from './explore/planet-surface-path.js?rev=1';

export const SURFACE_SELECTION_ARC_PROFILE = Object.freeze({
  // Nodes are centered at .012. A three-thousandth shell offset leaves the
  // line visibly above the opaque globe without making an air bridge.
  altitude: .015,
  minAltitude: .014,
  maxAltitude: .016,
  minSegments: 16,
  maxSegments: 96,
  degreesPerSegment: 2,
  pathResolution: .5,
  // The old .018–.036 range was a hairline on mobile against the dark globe.
  // Keep the same weight hierarchy, but make the selected gold context routes
  // legible without changing their surface geometry or height.
  strokeMin: .440,
  strokeMax: .720,
  limit: 12,
});

const stableEdgeId = (edge) => String(edge?.id || [edge?.source, edge?.target].sort().join('::'));
const stablePairId = (edge) => [edge?.source, edge?.target].sort().join('::');
const hasGeoPosition = (node) => Number.isFinite(Number(node?.lat)) && Number.isFinite(Number(node?.lng));

export function createCitySelectionState() {
  return {
    ownerVariant: null,
    selectedCityId: null,
    selectedConnectionIds: [],
    selectedCityArcData: [],
  };
}

export function clearCityConnections() {
  return createCitySelectionState();
}

export function isSurfaceSelectionArc(arc) {
  return arc?.renderer === 'surface-selection-arc';
}

export function selectCityConnections({
  variant,
  cityId,
  edges = [],
  nodesById,
  profile = SURFACE_SELECTION_ARC_PROFILE,
} = {}) {
  const source = nodesById?.get?.(cityId);
  if (!['v5', 'v6', 'v7'].includes(variant) || !cityId || !hasGeoPosition(source)) {
    return clearCityConnections();
  }

  const uniquePairs = new Map();
  [...edges]
    .filter((edge) => edge?.source === cityId || edge?.target === cityId)
    .sort((left, right) => (
      (Number(right?.weight) || 0) - (Number(left?.weight) || 0)
    ) || stableEdgeId(left).localeCompare(stableEdgeId(right)))
    .forEach((edge) => {
      const targetId = edge.source === cityId ? edge.target : edge.source;
      if (uniquePairs.has(stablePairId(edge)) || !hasGeoPosition(nodesById.get(targetId))) return;
      uniquePairs.set(stablePairId(edge), edge);
    });

  const selectedEdges = [...uniquePairs.values()].slice(0, Math.max(0, Number(profile.limit) || 0));
  const altitude = Math.min(
    Number(profile.maxAltitude),
    Math.max(Number(profile.minAltitude), Number(profile.altitude)),
  );
  const maxWeight = Math.max(...selectedEdges.map((edge) => Number(edge.weight) || 0), 1);
  const selectedCityArcData = selectedEdges.map((edge, index) => {
    const targetId = edge.source === cityId ? edge.target : edge.source;
    const target = nodesById.get(targetId);
    const weightRatio = Math.max(0, Math.min(1, (Number(edge.weight) || 0) / maxWeight));
    return {
      id: `surface:${stableEdgeId(edge)}`,
      edgeId: stableEdgeId(edge),
      sourceCityId: cityId,
      targetCityId: targetId,
      source: cityId,
      target: targetId,
      startLat: Number(source.lat),
      startLng: Number(source.lng),
      endLat: Number(target.lat),
      endLng: Number(target.lng),
      startAltitude: altitude,
      endAltitude: altitude,
      peakAltitude: altitude,
      weight: Number(edge.weight) || 0,
      connectionType: String(edge.type || 'direct'),
      surfacePoints: buildGreatCircleSurfacePath(source, target, {
        altitude,
        minSegments: profile.minSegments,
        maxSegments: profile.maxSegments,
        degreesPerSegment: profile.degreesPerSegment,
      }),
      stroke: Number(profile.strokeMin) + ((Number(profile.strokeMax) - Number(profile.strokeMin)) * weightRatio),
      // A city focus is one visual context: every direct connection is gold.
      // Reserving gold for only the top edge made the remaining selection
      // layer read as the unrelated blue network.
      highlight: true,
      renderer: 'surface-selection-arc',
    };
  });

  return {
    ownerVariant: variant,
    selectedCityId: cityId,
    selectedConnectionIds: selectedCityArcData.map((arc) => arc.edgeId),
    selectedCityArcData,
  };
}
