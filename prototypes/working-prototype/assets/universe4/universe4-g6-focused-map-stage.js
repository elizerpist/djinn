import { createFocusedG6V2Stage } from '../focused-g6-v2-stage.js?rev=3';

// Universe-specific lifecycle wrapper. The reusable Focused Map v2 stage stays
// unaware of Globe, Force, transition state, or input ownership.
export function createUniverse4G6FocusedMapStage({ mount, onNodeClick, onReady } = {}) {
  const stage = createFocusedG6V2Stage({ mount, onNodeClick, onReady });
  return Object.freeze({
    get isReady() { return stage.isReady; },
    get graph() { return stage.graph; },
    get activeFocusCityId() { return stage.activeFocusCityId; },
    get zoom() { return stage.zoom; },
    get visibleNodeCount() { return stage.visibleNodeCount; },
    whenReady: () => stage.whenReady(),
    setOpacity: (opacity) => stage.setOpacity(opacity),
    setInputEnabled: (enabled) => stage.setInputEnabled(enabled),
    prewarm: (snapshot, options) => stage.prewarm(snapshot, options),
    showEntryLayout: (entryLayout) => stage.showEntryLayout(entryLayout),
    settleToFocusedLayout: () => stage.settleToFocusedLayout(),
    setFocusCity: (cityId, options) => stage.setFocusCity(cityId, options),
    zoomIn: () => stage.zoomIn(),
    zoomOut: () => stage.zoomOut(),
    focusActiveCard: () => stage.focusActiveCard(),
    getSnapshot: () => stage.getSnapshot(),
    getState: () => stage.getState(),
    dispose: () => stage.dispose(),
  });
}
