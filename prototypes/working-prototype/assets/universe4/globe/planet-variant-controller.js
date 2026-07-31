import {
  clearCityConnections,
  selectCityConnections,
} from '../../city-selection-arcs.js?rev=9';

const snapshot = (selection) => ({
  ...selection,
  selectedConnectionIds: [...selection.selectedConnectionIds],
  selectedCityArcData: selection.selectedCityArcData.map((arc) => ({ ...arc })),
});

/**
 * Owns city selection for exactly one planet variant. Rendering is deliberately
 * left to callers, so this module remains independent of Globe.gl and the DOM.
 */
export function createPlanetVariantController({
  variant,
  edges = [],
  nodesById,
  trace,
} = {}) {
  let selection = clearCityConnections();
  const record = (type, cityId, reason) => {
    if (typeof trace !== 'function') return;
    trace({ type, variant, cityId, ...(reason === undefined ? {} : { reason }) });
  };

  return {
    tap(cityId) {
      const previousCityId = selection.selectedCityId;
      if (previousCityId === cityId) {
        selection = clearCityConnections();
        record('selection.dehighlight', cityId);
        return { action: 'dehighlight', selection: snapshot(selection) };
      }

      selection = selectCityConnections({ variant, cityId, edges, nodesById });
      const action = previousCityId === null ? 'focus' : 'replace';
      record(`selection.${action}`, cityId);
      return { action, selection: snapshot(selection) };
    },

    clear(reason) {
      const previousCityId = selection.selectedCityId;
      selection = clearCityConnections();
      record('selection.clear', previousCityId, reason);
      return { action: 'clear', selection: snapshot(selection) };
    },

    state() {
      return snapshot(selection);
    },
  };
}
