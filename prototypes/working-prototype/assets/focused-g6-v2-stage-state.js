// Small, DOM-free state helpers shared by the embedded G6 V2 runtime and its
// tests. Keeping these boundaries explicit prevents a zoom gesture from
// rebuilding the graph on every transform frame.
export const FOCUSED_G6_V2_STAGE_ZOOM = Object.freeze({ min: .35, max: 2.6, step: .22 });

const clamp = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, Number(value) || 0));

export function focusedG6V2NextStageZoom(currentZoom, direction, range = FOCUSED_G6_V2_STAGE_ZOOM) {
  const delta = direction === 'out' ? -range.step : range.step;
  return Number(clamp(Number(currentZoom) + delta, range.min, range.max).toFixed(2));
}

export function focusedG6V2ResolveStageFocus(candidateId, nodes = [], currentFocusId = null) {
  return (Array.isArray(nodes) && nodes.some((node) => node?.id === candidateId)) ? candidateId : currentFocusId;
}

export function focusedG6V2ShouldRefreshLod(previousLodKey, zoom, getLod) {
  if (typeof getLod !== 'function') throw new TypeError('getLod is required');
  return getLod(zoom).key !== previousLodKey;
}
