// This policy has no renderer or DOM dependency. The V7 controller asks it
// whether a city tap belongs to U4 before applying its normal selection logic.
export const GLOBE_CITY_ROLE = Object.freeze({
  ROOT: 'root',
  CONTEXT: 'context',
  FOREIGN: 'foreign',
  BACKGROUND: 'background',
});

export function contextCityIdsFor(selection = {}) {
  const rootCityId = typeof selection.selectedCityId === 'string' ? selection.selectedCityId : null;
  if (!rootCityId) return [];
  const seen = new Set();
  const ids = [];
  (Array.isArray(selection.selectedCityArcData) ? selection.selectedCityArcData : []).forEach((arc) => {
    const otherId = arc?.sourceCityId === rootCityId
      ? arc?.targetCityId
      : (arc?.targetCityId === rootCityId ? arc?.sourceCityId : null);
    if (typeof otherId !== 'string' || otherId === rootCityId || seen.has(otherId)) return;
    seen.add(otherId);
    ids.push(otherId);
  });
  return ids;
}

export function resolveUniverse4GlobeTap({ cityId = null, selection = {} } = {}) {
  const rootCityId = typeof selection.selectedCityId === 'string' ? selection.selectedCityId : null;
  const contextCityIds = contextCityIdsFor(selection);
  if (!cityId) {
    return rootCityId
      ? { action: 'clear-context', role: GLOBE_CITY_ROLE.BACKGROUND, cityId: null, rootCityId, contextCityIds, consume: true }
      : { action: 'ignore', role: GLOBE_CITY_ROLE.BACKGROUND, cityId: null, rootCityId: null, contextCityIds: [] };
  }
  if (!rootCityId) {
    return { action: 'select-root', role: GLOBE_CITY_ROLE.FOREIGN, cityId, rootCityId: null, contextCityIds: [] };
  }
  if (cityId === rootCityId) {
    // The selected mother is a valid focused-map anchor too. Consume this
    // repeated tap before V7 can apply its normal toggle-off/dehighlight.
    return { action: 'enter-map', role: GLOBE_CITY_ROLE.ROOT, cityId, rootCityId, contextCityIds, consume: true };
  }
  if (contextCityIds.includes(cityId)) {
    return { action: 'enter-map', role: GLOBE_CITY_ROLE.CONTEXT, cityId, rootCityId, contextCityIds, consume: true };
  }
  // This is intentionally consumed. The next independent tap becomes the
  // normal `select-root` path only after the old context was visibly cleared.
  return { action: 'clear-context', role: GLOBE_CITY_ROLE.FOREIGN, cityId, rootCityId, contextCityIds, consume: true };
}
