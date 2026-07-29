export const PIXEL_MATCH_TOLERANCES = Object.freeze({
  // These limits describe the first user-visible Globe frame, not a loose
  // diagnostic comparison. If they are not met, U4 stays on the frozen
  // Force frame and never starts the reveal.
  centerPx: 1,
  radiusPercent: .75,
  landmarkRmsPx: 2,
  landmarkPx: 3,
});

const MINIMUM_LANDMARKS = 3;

const distance = (left, right) => Math.hypot(left.x - right.x, left.y - right.y);
const isPoint = (value) => Number.isFinite(value?.x) && Number.isFinite(value?.y);

const landmarkMap = (landmarks) => new Map(
  (Array.isArray(landmarks) ? landmarks : [])
    .filter((landmark) => typeof landmark?.id === 'string' && isPoint(landmark))
    .map((landmark) => [landmark.id, landmark]),
);

/**
 * Validates the visual handoff in CSS pixels. It is deliberately independent
 * from either renderer, so a failed match leaves the Force stage in control.
 */
export function validatePixelMatch({ inline, globe, tolerances = PIXEL_MATCH_TOLERANCES } = {}) {
  const failures = [];
  const inlineCenter = inline?.center;
  const globeCenter = globe?.center;
  const centerDeltaPx = isPoint(inlineCenter) && isPoint(globeCenter)
    ? distance(inlineCenter, globeCenter)
    : Infinity;
  if (centerDeltaPx > tolerances.centerPx) failures.push('center');

  const inlineRadius = inline?.radius;
  const globeRadius = globe?.radius;
  const radiusDeltaPercent = Number.isFinite(inlineRadius) && inlineRadius > 0 && Number.isFinite(globeRadius)
    ? (Math.abs(globeRadius - inlineRadius) / inlineRadius) * 100
    : Infinity;
  if (radiusDeltaPercent > tolerances.radiusPercent) failures.push('radius');

  const inlineLandmarks = landmarkMap(inline?.landmarks);
  const globeLandmarks = landmarkMap(globe?.landmarks);
  const landmarkDeltas = [];
  inlineLandmarks.forEach((inlineLandmark, id) => {
    const globeLandmark = globeLandmarks.get(id);
    const deltaPx = globeLandmark ? distance(inlineLandmark, globeLandmark) : Infinity;
    landmarkDeltas.push({ id, deltaPx });
    if (deltaPx > tolerances.landmarkPx) failures.push(`landmark:${id}`);
  });
  globeLandmarks.forEach((_, id) => {
    if (!inlineLandmarks.has(id)) failures.push(`landmark:${id}`);
  });
  if (inlineLandmarks.size < MINIMUM_LANDMARKS || globeLandmarks.size < MINIMUM_LANDMARKS) {
    failures.push('landmark-count');
  }

  const maxLandmarkDeltaPx = landmarkDeltas.length
    ? Math.max(...landmarkDeltas.map(({ deltaPx }) => deltaPx))
    : 0;
  const landmarkRmsDeltaPx = landmarkDeltas.length
    ? Math.sqrt(landmarkDeltas.reduce((sum, { deltaPx }) => sum + (deltaPx * deltaPx), 0) / landmarkDeltas.length)
    : Infinity;
  if (landmarkRmsDeltaPx > tolerances.landmarkRmsPx) failures.push('landmark-rms');

  return {
    valid: failures.length === 0,
    centerDeltaPx,
    radiusDeltaPercent,
    landmarkDeltas,
    maxLandmarkDeltaPx,
    landmarkRmsDeltaPx,
    failures,
  };
}
