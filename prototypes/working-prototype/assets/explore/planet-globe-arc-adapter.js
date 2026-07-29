const PROFILE = 'surface-selection-arc';
const REQUIRED_COORDINATES = ['startLat', 'startLng', 'endLat', 'endLng'];

const record = (trace, event, payload) => {
  trace?.record?.(event, payload);
};

const rejectedId = (arc, index) => arc?.id ?? `index:${index}`;

const isValidSurfaceSelectionArc = (arc) => (
  arc?.renderer === PROFILE
  && REQUIRED_COORDINATES.every((field) => Number.isFinite(arc?.[field]))
  && Array.isArray(arc.surfacePoints)
  && arc.surfacePoints.length >= 2
  && arc.surfacePoints.every((point) => (
    Number.isFinite(point?.lat)
    && Number.isFinite(point?.lng)
    && Number.isFinite(point?.altitude)
  ))
);

const verifyAssignedArcs = (globe) => {
  if (typeof globe?.pathsData !== 'function') return 0;
  const current = globe.pathsData();
  return Array.isArray(current) ? current.length : 0;
};

const signalArc = (arc) => {
  const signal = {
    id: arc.id,
    sourceCityId: arc.sourceCityId,
    targetCityId: arc.targetCityId,
    startLat: arc.startLat,
    startLng: arc.startLng,
    endLat: arc.endLat,
    endLng: arc.endLng,
  };
  ['startAltitude', 'endAltitude', 'peakAltitude', 'stroke', 'highlight'].forEach((field) => {
    if (arc[field] !== undefined) signal[field] = arc[field];
  });
  signal.surfacePointCount = Array.isArray(arc.surfacePoints) ? arc.surfacePoints.length : 0;
  return signal;
};

/**
 * Commits only valid surface-selection routes to Globe.gl's Paths contract.
 * This intentionally owns no rendering profile, camera, DOM, or selection state.
 */
export function commitPlanetSelectionArcs({ globe, selection, trace } = {}) {
  const source = Array.isArray(selection?.selectedCityArcData)
    ? selection.selectedCityArcData
    : [];
  const payload = [];
  const rejectedIds = [];

  source.forEach((arc, index) => {
    if (isValidSurfaceSelectionArc(arc)) payload.push(arc);
    else rejectedIds.push(rejectedId(arc, index));
  });

  record(trace, 'arc.payload', {
    profile: PROFILE,
    candidateCount: source.length,
    assignedCount: payload.length,
    rejectedIds,
    assignedArcs: payload.map(signalArc),
  });

  if (typeof globe?.arcsData !== 'function' || typeof globe?.pathsData !== 'function') {
    throw new TypeError('globe.arcsData and globe.pathsData must be functions');
  }

  // Globe.gl Paths consume explicit great-circle samples. Clearing the old
  // Arc layer is intentional: low Arc Links were the visually straight/chord
  // renderer the selection layer replaces.
  globe.arcsData([]);
  globe.pathsData(payload);
  record(trace, 'arc.commit', {
    profile: PROFILE,
    renderLayer: 'paths',
    assignedCount: payload.length,
    rejectedIds,
  });

  const verifiedCount = verifyAssignedArcs(globe);
  record(trace, 'arc.verify', {
    profile: PROFILE,
    renderLayer: 'paths',
    assignedCount: payload.length,
    verifiedCount,
    rejectedIds,
  });

  return { assignedCount: payload.length, verifiedCount, profile: PROFILE };
}

/** Clears the adapter-owned selection arc payload without changing Globe settings. */
export function clearPlanetSelectionArcs({ globe, trace, reason } = {}) {
  if (typeof globe?.arcsData !== 'function' || typeof globe?.pathsData !== 'function') {
    throw new TypeError('globe.arcsData and globe.pathsData must be functions');
  }

  globe.arcsData([]);
  globe.pathsData([]);
  const verifiedCount = verifyAssignedArcs(globe);
  const result = { assignedCount: 0, verifiedCount, profile: PROFILE, renderLayer: 'paths' };
  record(trace, 'arc.clear', { reason, ...result });
  return result;
}
