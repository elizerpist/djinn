import {
  buildFocusedG6V2Subgraph,
  focusedG6CardSize,
  focusedG6V2Lod,
  focusedG6V2Positions,
  knowledgeEdges,
  knowledgeNodes,
} from './knowledge-map.js?rev=142';
import { buildFocusedG6V2RenderData } from './focused-g6-v2-render-data.js?rev=1';
import { createFocusedG6V2StageControls } from './focused-g6-v2-stage-controls.js?rev=1';
import {
  FOCUSED_G6_V2_STAGE_ZOOM,
  focusedG6V2NextStageZoom,
  focusedG6V2ResolveStageFocus,
  focusedG6V2ShouldRefreshLod,
} from './focused-g6-v2-stage-state.js?rev=1';

const bounded = (value, minimum, maximum) => Math.max(minimum, Math.min(maximum, Number(value) || 0));

/**
 * Reusable runtime adapter for the existing Focused Map v2 renderer.
 *
 * The Globe transition snapshot only carries the entry context and pose. Once
 * the handoff has finished, this stage deliberately uses the canonical full
 * knowledge graph: any visible city can become the dynamic centre card and
 * the existing near/mid/far G6 V2 LOD map appears through native zoom-out.
 */
export function createFocusedG6V2Stage({ mount, onNodeClick, onReady } = {}) {
  if (!mount) throw new Error('Focused G6 V2 stage mount is required');
  const host = document.createElement('div');
  host.className = 'focused-g6-v2-stage-root';
  host.setAttribute('aria-label', 'G6 fókuszált térkép v2');
  mount.replaceChildren(host);

  let graph = null;
  let controls = null;
  let ready = false;
  let disposed = false;
  let snapshot = null;
  let activeFocusCityId = null;
  let entryPositions = null;
  let stageZoom = 1;
  let activeLodKey = '';
  let visibleNodeCount = 0;
  let resizeObserver = null;
  let lodRefreshQueued = false;
  let resolveReady;
  const readyPromise = new Promise((resolve) => { resolveReady = resolve; });

  const viewport = () => ({
    width: Math.max(host.clientWidth || 0, 320),
    height: Math.max(host.clientHeight || 0, 420),
  });

  // V7 city ids are drawn from the same knowledge domain. Falling back to the
  // transition snapshot keeps this stage usable in an isolated fixture too.
  const domainNodes = () => knowledgeNodes.length ? knowledgeNodes : (snapshot?.nodes || []);
  const domainEdges = () => knowledgeEdges.length ? knowledgeEdges : (snapshot?.edges || []);

  const readGraphZoom = () => {
    try {
      return bounded(graph?.getZoom?.(), FOCUSED_G6_V2_STAGE_ZOOM.min, FOCUSED_G6_V2_STAGE_ZOOM.max);
    } catch {
      return stageZoom;
    }
  };

  const syncZoomAndLod = () => {
    if (disposed || !graph || !snapshot) return;
    stageZoom = readGraphZoom();
    if (!focusedG6V2ShouldRefreshLod(activeLodKey, stageZoom, focusedG6V2Lod) || lodRefreshQueued) return;
    // Native G6 keeps the current canvas transform. Only rebind data when an
    // actual LOD threshold was crossed, never once per pinch/wheel frame.
    lodRefreshQueued = true;
    window.requestAnimationFrame(() => {
      lodRefreshQueued = false;
      if (!disposed && graph && snapshot) render({ preserveEntryLayout: false });
    });
  };

  const focusActiveCard = (animated = true) => {
    if (!graph || !activeFocusCityId || typeof graph.focusElement !== 'function') return;
    void Promise.resolve(graph.focusElement(activeFocusCityId, {
      duration: animated ? 420 : 0,
      easing: 'ease-in-out',
    })).then(syncZoomAndLod);
  };

  const render = ({ entryLayout, animated = false, preserveEntryLayout = false } = {}) => {
    if (!graph || !snapshot) return null;
    if (entryLayout instanceof Map) entryPositions = entryLayout;
    else if (!preserveEntryLayout) entryPositions = null;
    const { width, height } = viewport();
    // During the Globe → Map morph the entry layout intentionally contains
    // only the selected root/context cities. Rendering the full 700-node
    // domain against that partial position map leaves edges pointing at
    // missing G6 elements and makes the first render reject synchronously.
    // Keep prewarm/showEntryLayout on the immutable transition snapshot; once
    // the morph settles, clearing entryPositions switches to the full
    // canonical knowledge graph and native zoom-out remains available.
    const entryRender = entryPositions instanceof Map && Array.isArray(snapshot.nodes) && snapshot.nodes.length > 0;
    const nodes = entryRender ? snapshot.nodes : domainNodes();
    const edges = entryRender ? (Array.isArray(snapshot.edges) ? snapshot.edges : []) : domainEdges();
    const focusCityId = focusedG6V2ResolveStageFocus(activeFocusCityId, nodes, snapshot.focusCityId);
    if (!focusCityId) return null;
    activeFocusCityId = focusCityId;
    const data = buildFocusedG6V2RenderData({
      focusId: focusCityId,
      nodes,
      edges,
      includeNode: () => true,
      zoom: stageZoom,
      width,
      height,
      dark: true,
      buildSubgraph: buildFocusedG6V2Subgraph,
      getLod: focusedG6V2Lod,
      getPositions: focusedG6V2Positions,
      getCardSize: focusedG6CardSize,
      positionById: entryPositions,
    });
    activeLodKey = data.lodKey;
    visibleNodeCount = data.nodes.length;
    graph.setData({ nodes: data.nodes, edges: data.edges });
    void Promise.resolve(graph.render()).then(() => {
      if (!disposed && animated) focusActiveCard(true);
    });
    return data;
  };

  const setActiveFocus = (cityId, { animated = true, notify = true } = {}) => {
    const nextFocusId = focusedG6V2ResolveStageFocus(cityId, domainNodes(), activeFocusCityId || snapshot?.focusCityId);
    if (!nextFocusId) return false;
    const previousFocusCityId = activeFocusCityId;
    activeFocusCityId = nextFocusId;
    entryPositions = null;
    const data = render({ animated });
    if (notify) onNodeClick?.(nextFocusId, {
      snapshot,
      previousFocusCityId,
      focusCityId: activeFocusCityId,
      visibleNodeCount: data?.nodes.length || 0,
    });
    return Boolean(data);
  };

  const zoom = (direction) => {
    if (!graph) return;
    const nextZoom = focusedG6V2NextStageZoom(readGraphZoom(), direction);
    stageZoom = nextZoom;
    void Promise.resolve(graph.zoomTo?.(nextZoom, { duration: 210, easing: 'ease-out' }, graph.getCanvasCenter?.()))
      .then(syncZoomAndLod);
  };

  const makeGraph = (attempt = 0) => {
    if (disposed || graph) return;
    const G6 = window.G6;
    if (!G6?.Graph) {
      if (attempt < 60) window.requestAnimationFrame(() => makeGraph(attempt + 1));
      return;
    }
    const { width, height } = viewport();
    graph = new G6.Graph({
      container: host,
      width,
      height,
      data: { nodes: [], edges: [] },
      animation: { duration: 0, easing: 'ease-in-out' },
      zoomRange: [FOCUSED_G6_V2_STAGE_ZOOM.min, FOCUSED_G6_V2_STAGE_ZOOM.max],
      behaviors: [{ type: 'drag-canvas' }, { type: 'zoom-canvas', enableOptimize: true }],
    });
    graph.on('node:click', (event) => {
      const cityId = event.target?.id;
      if (cityId) setActiveFocus(cityId, { animated: true, notify: true });
    });
    graph.on('canvas:dblclick', () => zoom('in'));
    graph.on('aftertransform', syncZoomAndLod);
    controls = createFocusedG6V2StageControls({
      host,
      onZoomIn: () => zoom('in'),
      onZoomOut: () => zoom('out'),
      onCenter: () => focusActiveCard(true),
    });
    resizeObserver = new ResizeObserver(() => {
      if (disposed || !graph) return;
      graph.resize();
      render({ entryLayout: entryPositions, preserveEntryLayout: true });
    });
    resizeObserver.observe(host);
    ready = true;
    resolveReady(true);
    onReady?.();
  };
  makeGraph();

  return {
    get isReady() { return ready; },
    get graph() { return graph; },
    get activeFocusCityId() { return activeFocusCityId; },
    get zoom() { return stageZoom; },
    get visibleNodeCount() { return visibleNodeCount; },
    whenReady() { return readyPromise; },
    setOpacity(opacity) { mount.style.opacity = String(bounded(opacity, 0, 1)); },
    setInputEnabled(enabled) {
      mount.style.pointerEvents = enabled ? 'auto' : 'none';
      mount.setAttribute('aria-hidden', String(!enabled));
    },
    async prewarm(nextSnapshot, { entryLayout = null } = {}) {
      snapshot = nextSnapshot;
      await readyPromise;
      if (disposed) return null;
      activeFocusCityId = focusedG6V2ResolveStageFocus(nextSnapshot?.focusCityId, domainNodes(), nextSnapshot?.focusCityId);
      stageZoom = 1;
      activeLodKey = '';
      return render({ entryLayout });
    },
    showEntryLayout(nextEntryLayout) { return render({ entryLayout: nextEntryLayout }); },
    settleToFocusedLayout() { return render({ entryLayout: null, animated: true }); },
    setFocusCity(cityId, options) { return setActiveFocus(cityId, options); },
    zoomIn() { zoom('in'); },
    zoomOut() { zoom('out'); },
    focusActiveCard() { focusActiveCard(true); },
    getSnapshot() { return snapshot; },
    getState() {
      return Object.freeze({
        focusCityId: activeFocusCityId,
        zoom: stageZoom,
        lodKey: activeLodKey,
        visibleNodeCount,
      });
    },
    dispose() {
      disposed = true;
      resizeObserver?.disconnect();
      resizeObserver = null;
      controls?.dispose();
      controls = null;
      try { graph?.destroy?.(); } catch { /* a route disposer must remain safe */ }
      graph = null;
      host.remove();
    },
  };
}
